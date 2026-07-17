import os
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"

import json
import random
import logging
import numpy as np
from numpy.linalg import norm
import pdfplumber
from sentence_transformers import SentenceTransformer
from groq import Groq
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
from supabase import create_client, Client

load_dotenv()

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────

EMBED_MODEL  = "all-MiniLM-L6-v2"
GROQ_MODEL   = "llama-3.3-70b-versatile"
CHUNK_SIZE   = 6000
CHUNK_OVERLAP = 500   # overlap between chunks to prevent questions being split at page boundaries

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_embed_model      = None
_groq_client      = None
_supabase: Client = None

def get_embed_model():
    global _embed_model
    if _embed_model is None:
        _embed_model = SentenceTransformer(EMBED_MODEL)
    return _embed_model

def get_groq_client():
    global _groq_client
    if _groq_client is None:
        _groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    return _groq_client

def get_supabase() -> Client:
    global _supabase
    if _supabase is None:
        url = os.getenv("SUPABASE_URL")
        key = os.getenv("SUPABASE_KEY")
        if not url or not key:
            raise RuntimeError("SUPABASE_URL and SUPABASE_KEY must be set in .env")
        _supabase = create_client(url, key)
    return _supabase

# ── Step 1 — PDF Parsing ──────────────────────────────────────────────────────

def extract_raw_text(pdf_bytes: bytes) -> str:
    import io
    import unicodedata

    def _clean(text: str) -> str:
        text = unicodedata.normalize("NFKC", text)
        return "\n".join(
            line for line in text.splitlines()
            if line.strip()
        )

    full_text = ""

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            # 1. Normal text layer
            text = page.extract_text(x_tolerance=3, y_tolerance=3)

            # 2. Table-aware fallback
            if not text or len(text.strip()) < 40:
                tables = page.extract_tables()
                if tables:
                    rows = []
                    for table in tables:
                        for row in table:
                            rows.append("  |  ".join(cell or "" for cell in row))
                    text = "\n".join(rows)

            # 3. Words-based reconstruction
            if not text or len(text.strip()) < 40:
                words = page.extract_words(
                    x_tolerance=3,
                    y_tolerance=3,
                    keep_blank_chars=False,
                    use_text_flow=True,
                )
                if words:
                    text = " ".join(w["text"] for w in words)

            if text:
                full_text += _clean(text) + "\n"

    # 4. OCR fallback for image-only PDFs
    if len(full_text.strip()) < 200:
        full_text = _ocr_fallback(pdf_bytes)

    return full_text


def _ocr_fallback(pdf_bytes: bytes) -> str:
    try:
        from pdf2image import convert_from_bytes
        import pytesseract

        images = convert_from_bytes(pdf_bytes, dpi=300)
        pages_text = []
        for img in images:
            text = pytesseract.image_to_string(img, config="--psm 6")
            if text.strip():
                pages_text.append(text.strip())
        return "\n".join(pages_text)

    except ImportError:
        logger.warning(
            "[ocr_fallback] pdf2image or pytesseract not installed — "
            "image-only PDFs will extract empty. "
            "Run: pip install pdf2image pytesseract"
        )
        return ""
    except Exception as e:
        logger.warning(f"[ocr_fallback] failed: {e}")
        return ""

# ── Step 1b — Overlapping chunks ─────────────────────────────────────────────
# Prevents questions that span a page break from being truncated.
# Each chunk overlaps with the previous by CHUNK_OVERLAP characters.
# After extraction, near-duplicate questions are deduplicated by text similarity.

def _make_chunks(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start += size - overlap
    return chunks

def _deduplicate_questions(questions: list[dict]) -> list[dict]:
    """
    Remove near-duplicate questions that arise from overlapping chunks.
    Two questions are considered duplicates if their texts share more than
    80% of their words. Keeps the one with higher confidence_score.
    """
    def word_overlap(a: str, b: str) -> float:
        wa = set(a.lower().split())
        wb = set(b.lower().split())
        if not wa or not wb:
            return 0.0
        return len(wa & wb) / min(len(wa), len(wb))

    kept = []
    for q in questions:
        is_dup = False
        for i, existing in enumerate(kept):
            if word_overlap(q["question_text"], existing["question_text"]) > 0.8:
                # keep whichever has higher confidence
                if q.get("confidence_score", 1.0) > existing.get("confidence_score", 1.0):
                    kept[i] = q
                is_dup = True
                break
        if not is_dup:
            kept.append(q)
    return kept

# ── Step 2 — Question Extraction ─────────────────────────────────────────────
#
# Key improvements over v1:
#
# 1. sub_parts — multi-part questions are now extracted as a JSON array of
#    {text, marks, marks_inferred} objects on the parent question. The parent
#    question_text holds the stem only. This matches the schema's sub_parts jsonb column.
#
# 2. topic granularity — the prompt now forces the LLM to go one level deeper
#    than the obvious concept. "Sorting" is rejected; "merge sort recurrence" is correct.
#    Negative examples are included to prevent vague tags.
#
# 3. MCQ options — MCQ questions now extract options into a structured array
#    and attempt to identify correct_index if an answer key is present.
#    If no answer key, correct_index is null.
#
# 4. doc_type awareness — the prompt adjusts based on whether this is a PYQ,
#    tutorial, or other document type so extraction rules match the document.

def extract_questions_from_text(
    raw_text: str,
    subject: str,
    paper_year: int,
    exam_type: str,
    doc_type: str = "pyq",
) -> list[dict]:
    client = get_groq_client()
    chunks = _make_chunks(raw_text)
    all_questions = []

    for chunk_idx, chunk in enumerate(chunks):
        prompt = f"""You are extracting exam questions from a scanned {doc_type} document for the subject {subject}.

WHAT TO EXTRACT:
- Every complete, standalone question a student must answer
- For multi-part questions (Q1a, Q1b, Q1c), extract the PARENT question as one item with sub_parts
- For MCQ questions, include the full question stem AND parse options into the options array

WHAT TO IGNORE:
- Headers, footers, college names, dates, roll number fields
- Instructions like "attempt any 5", "all questions carry equal marks"
- Page numbers, section dividers
- Answers, solutions, or marking schemes (unless doc_type is solution)

RULES:
- question_text: for multi-part questions this is the stem only ("Explain the following concepts:")
  for single questions this is the full question text
  for MCQs this is the question stem WITHOUT the options
- marks: extract if shown (e.g. "[5]", "(5 marks)", "5M"), else estimate from question type
- question_type: mcq | short_answer | long_answer | numerical
- topic: BE SPECIFIC — go one level deeper than the obvious concept.
  BAD examples (too vague): "algorithms", "networking", "data structures", "graphs"
  GOOD examples (specific): "Dijkstra's shortest path", "TCP three-way handshake",
  "AVL tree rotation", "Fourier transform properties", "dynamic programming memoisation",
  "Bayes theorem conditional probability", "B+ tree insertion"
  Rule: if your topic label could apply to an entire textbook chapter, go deeper.
- has_diagram: true ONLY if the question references a figure, graph, or table
  that is NOT present in the extracted text (student needs original paper to answer)
- marks_inferred: true if marks were not explicitly written, you had to estimate
- confidence_score: 1.000 = clean complete question, 0.700-0.900 = minor formatting
  issues, below 0.700 = possibly truncated or garbled — flag these for review
- sub_parts: if the question has labelled parts (a, b, c or i, ii, iii), extract
  each as an object with text (string), marks (integer), marks_inferred (boolean).
  If no sub-parts, use an empty array [].
- options: for MCQ only — array of exactly 4 strings [option_a, option_b, option_c, option_d].
  For non-MCQ, use null.
- correct_index: for MCQ only — 0=A, 1=B, 2=C, 3=D. Use null if answer key not present.

Return ONLY a JSON array. No markdown, no backticks, no explanation.
Each item must have ALL of these fields:
  question_text      (string)
  marks              (integer — total marks including sub-parts)
  question_type      (mcq | short_answer | long_answer | numerical)
  topic              (string — specific 2-6 word concept label)
  has_diagram        (boolean)
  marks_inferred     (boolean)
  confidence_score   (decimal 0.000 to 1.000)
  sub_parts          (array of {{text, marks, marks_inferred}} objects, or empty array)
  options            (array of 4 strings for MCQ, or null)
  correct_index      (0-3 for MCQ if answer known, or null)

Text:
{chunk}"""

        try:
            response = client.chat.completions.create(
                model=GROQ_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
            )
            raw = response.choices[0].message.content.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            parsed = json.loads(raw)
            for q in parsed:
                q["subject"]          = subject
                q["paper_year"]       = paper_year
                q["exam_type"]        = exam_type
                q["doc_type"]         = doc_type
                q["marks"]            = int(round(q.get("marks", 0)))
                q["topic"]            = q.get("topic", "")
                q["has_diagram"]      = bool(q.get("has_diagram", False))
                q["marks_inferred"]   = bool(q.get("marks_inferred", False))
                q["confidence_score"] = float(q.get("confidence_score", 1.0))
                q["sub_parts"]        = q.get("sub_parts", [])
                q["options"]          = q.get("options", None)
                q["correct_index"]    = q.get("correct_index", None)
            all_questions.extend(parsed)
        except Exception as e:
            logger.warning(f"[extract_questions] chunk {chunk_idx} failed: {e}")
            continue

    return _deduplicate_questions(all_questions)

# ── Step 2b — Solution Sheet Matching ────────────────────────────────────────
#
# When doc_type = "solution", instead of extracting questions we extract
# answer blocks and match them to existing questions in the bank using
# embedding similarity. Above a threshold, we write model_answer and set
# answer_source = 'professor' on the matched question row.
#
# This is the highest quality signal for Nova and the AI evaluator —
# professor answers are always preferred over AI-generated fallbacks.

def _extract_answer_blocks(raw_text: str, subject: str) -> list[dict]:
    """Extract answer blocks from a solution sheet."""
    client = get_groq_client()
    chunks = _make_chunks(raw_text)
    all_answers = []

    for chunk_idx, chunk in enumerate(chunks):
        prompt = f"""You are extracting model answers from a solution sheet for {subject}.

Extract every answer block you find. Each block is the professor's written answer to one question.

Return ONLY a JSON array. No markdown, no backticks.
Each item must have:
  question_hint   (string — the question text or number if visible, else first sentence of answer)
  answer_text     (string — the full answer text exactly as written)
  marks           (integer — marks this answer is worth, 0 if not stated)

Text:
{chunk}"""

        try:
            response = client.chat.completions.create(
                model=GROQ_MODEL,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.1,
            )
            raw = response.choices[0].message.content.strip()
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            parsed = json.loads(raw)
            all_answers.extend(parsed)
        except Exception as e:
            logger.warning(f"[extract_answers] chunk {chunk_idx} failed: {e}")
            continue

    return all_answers


def match_and_write_solutions(
    pdf_bytes: bytes,
    subject: str,
    college: str,
    subject_id: str | None = None,
    similarity_threshold: float = 0.82,
) -> dict:
    """
    Solution sheet pipeline:
    1. Extract answer blocks from the solution PDF
    2. Load existing questions for this subject from Supabase
    3. For each answer block, embed the question_hint and find the closest
       matching question by cosine similarity
    4. Above threshold, write model_answer and answer_source = 'professor'

    Returns counts of matched and unmatched answers.
    """
    sb = get_supabase()
    model = get_embed_model()

    # Extract answers from the solution sheet
    raw_text = extract_raw_text(pdf_bytes)
    answer_blocks = _extract_answer_blocks(raw_text, subject)

    if not answer_blocks:
        return {"matched": 0, "unmatched": 0, "total_answers": 0}

    # Load existing questions for this subject
    existing_questions, existing_embeddings = load_bank_and_embeddings(college, subject)

    if not existing_questions:
        logger.warning(f"[match_solutions] no existing questions for subject={subject}, college={college}")
        return {"matched": 0, "unmatched": len(answer_blocks), "total_answers": len(answer_blocks)}

    # Embed the question hints from the solution sheet
    hints = [a.get("question_hint", a.get("answer_text", "")[:200]) for a in answer_blocks]
    hint_embeddings = model.encode(hints)

    matched = 0
    unmatched = 0

    for answer_block, hint_emb in zip(answer_blocks, hint_embeddings):
        # Find best matching question by cosine similarity
        sims = [cosine_sim(hint_emb, ex_emb) for ex_emb in existing_embeddings]
        best_idx = int(np.argmax(sims))
        best_sim = sims[best_idx]

        if best_sim >= similarity_threshold:
            question_id = existing_questions[best_idx]["id"]
            answer_text = answer_block.get("answer_text", "")

            try:
                sb.table("questions").update({
                    "model_answer":  answer_text,
                    "answer_source": "professor",
                }).eq("id", question_id).execute()
                matched += 1
                logger.info(f"[match_solutions] matched answer to question {question_id} (sim={best_sim:.3f})")
            except Exception as e:
                logger.warning(f"[match_solutions] failed to update question {question_id}: {e}")
                unmatched += 1
        else:
            unmatched += 1
            logger.debug(f"[match_solutions] no match found (best_sim={best_sim:.3f})")

    return {
        "matched":       matched,
        "unmatched":     unmatched,
        "total_answers": len(answer_blocks),
    }

# ── Step 3 — Embeddings ───────────────────────────────────────────────────────

def embed_questions(questions: list[dict]) -> np.ndarray:
    model = get_embed_model()
    texts = [q["question_text"] for q in questions]
    return model.encode(texts)

# ── Step 4 — MMR Algorithm ────────────────────────────────────────────────────

def cosine_sim(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.dot(a, b) / (norm(a) * norm(b) + 1e-9))

def mmr(
    query_embedding: np.ndarray,
    candidate_embeddings: np.ndarray,
    candidate_questions: list[dict],
    k: int = 5,
    alpha: float = 0.7,
    seed: int | None = None,
) -> list[dict]:
    rng = random.Random(seed)
    indices = list(range(len(candidate_questions)))
    if seed is not None:
        rng.shuffle(indices)
        candidate_questions = [candidate_questions[i] for i in indices]
        candidate_embeddings = candidate_embeddings[indices]

    query_sims = [cosine_sim(query_embedding, e) for e in candidate_embeddings]
    selected, selected_embeddings, remaining = [], [], list(range(len(candidate_questions)))

    for _ in range(min(k, len(remaining))):
        mmr_scores = []
        for i in remaining:
            relevance = query_sims[i]
            diversity = (
                max(cosine_sim(candidate_embeddings[i], s) for s in selected_embeddings)
                if selected_embeddings else 0
            )
            score = alpha * relevance - (1 - alpha) * diversity
            mmr_scores.append((i, score))

        best = max(mmr_scores, key=lambda x: x[1])[0]
        selected.append(candidate_questions[best])
        selected_embeddings.append(candidate_embeddings[best])
        remaining.remove(best)

    return selected

# ── Exam type filter ──────────────────────────────────────────────────────────

_EXAM_TYPE_ALLOWED: dict[str, set[str]] = {
    "quiz1":  {"quiz1",  "generated"},
    "midsem": {"midsem", "quiz1",  "generated"},
    "quiz2":  {"quiz2",  "midsem", "quiz1",  "generated"},
    "compre": {"compre", "quiz2",  "midsem", "quiz1", "generated"},
}

def _filter_by_exam_type(
    questions: list[dict],
    embeddings: np.ndarray,
    exam_type: str | None,
) -> tuple[list[dict], np.ndarray]:
    if not exam_type:
        return questions, embeddings
    allowed = _EXAM_TYPE_ALLOWED.get(exam_type.lower())
    if not allowed:
        return questions, embeddings
    indices = [
        i for i, q in enumerate(questions)
        if (q.get("exam_type") or "").lower() in allowed
    ]
    if not indices:
        return questions, embeddings
    return (
        [questions[i] for i in indices],
        embeddings[indices],
    )

# ── Step 5 — Open-ended Question Generation ───────────────────────────────────

def generate_question(subject: str, examples: list[dict]) -> str:
    client = get_groq_client()
    examples_text = "\n\n".join(
        f"Example {i+1} ({q.get('marks', '?')} marks, {q.get('question_type', 'unknown')}, topic: {q.get('topic', 'unknown')}):\n{q['question_text']}"
        for i, q in enumerate(examples)
    )
    prompt = f"""You are an exam question generator for {subject}.
Below are example questions from previous exams at this college.
These set the difficulty level and style standard.

{examples_text}

Generate ONE new original exam question in the same style and difficulty range.
Return ONLY the question text. No explanation, no preamble, no label."""

    response = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    raw = response.choices[0].message.content.strip()
    import re
    raw = re.sub(r'^(Q\.?\s*\d+[\.\)]\s*|\d+[\.\)]\s*)', '', raw, flags=re.IGNORECASE).strip()
    return raw

# ── Step 5b — MCQ Generation ──────────────────────────────────────────────────

def generate_mcq(subject: str, examples: list[dict]) -> dict:
    client = get_groq_client()
    examples_text = "\n\n".join(
        f"Example {i+1} ({q.get('marks', '?')} marks, topic: {q.get('topic', 'unknown')}):\n{q['question_text']}"
        for i, q in enumerate(examples)
    )
    prompt = f"""You are an exam MCQ generator for {subject}.
Below are example questions from previous exams at this college.
Use them to calibrate the difficulty and topic coverage.

{examples_text}

Generate ONE new original MCQ question at a similar difficulty level.

Return ONLY a valid JSON object with exactly these fields — no markdown, no backticks, no extra text:
{{
  "question": "<full question text>",
  "option_a": "<option text>",
  "option_b": "<option text>",
  "option_c": "<option text>",
  "option_d": "<option text>",
  "correct_index": <0, 1, 2, or 3 — 0=A, 1=B, 2=C, 3=D>,
  "marks": <integer, typically 1 or 2>,
  "subject": "{subject}"
}}"""

    response = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.8,
    )
    raw = response.choices[0].message.content.strip()
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    parsed = json.loads(raw.strip())
    return {
        "question":      parsed["question"],
        "options":       [parsed["option_a"], parsed["option_b"], parsed["option_c"], parsed["option_d"]],
        "correct_index": int(parsed["correct_index"]),
        "subject":       parsed.get("subject", subject),
        "marks":         int(parsed.get("marks", 1)),
    }

# ── Step 5c — Model Answer Generation ────────────────────────────────────────

def generate_model_answer(question_text: str, subject: str, marks: int) -> str:
    client = get_groq_client()

    if marks <= 3:
        structure = (
            "Write 2–3 sentences that DIRECTLY answer this specific question. "
            "If it asks to define, state the definition. "
            "If it asks to explain, give the actual explanation. "
            "Bold key technical terms. No headings, no bullet points."
        )
    elif marks <= 6:
        structure = (
            "DIRECTLY answer this specific question. Do NOT give generic background theory.\n\n"
            "If the question asks to compute, calculate, or derive:\n"
            "  - Show the actual step-by-step working using the specific values given\n"
            "  - Use `### Steps` as the heading\n"
            "  - Each step should show the formula applied with real numbers\n"
            "  - End with the final numerical result\n\n"
            "If the question asks to explain or describe:\n"
            "  - One opening sentence directly answering what is asked\n"
            "  - `### Key points` with 3–4 bullets of substance specific to the question\n"
            "  - Each bullet must add real information, not restate the question\n\n"
            "Keep under 150 words."
        )
    else:
        structure = (
            "DIRECTLY answer this specific question with full working. Do NOT give generic theory.\n\n"
            "If the question contains specific data (numbers, tables, probabilities, matrices):\n"
            "  - Use that exact data in your answer\n"
            "  - Show full step-by-step computation under `### Working`\n"
            "  - Use a markdown table if presenting computed results per state/variable\n"
            "  - Conclude with `### Result` stating the final answer clearly\n\n"
            "If the question asks to explain/compare/design:\n"
            "  - `### Approach` — 2-3 sentences directly answering the question\n"
            "  - `### Explanation` — 3-4 bullets with substance specific to this question\n"
            "  - `### Conclusion` — one sentence summary\n\n"
            "Keep under 250 words. Every sentence must be specific to this question."
        )

    prompt = f"""You are a {subject} professor marking an exam. Write a model answer for the question below worth {marks} marks.

CRITICAL RULE: Your answer must be SPECIFIC to the exact question asked. If the question gives specific numbers, states, probabilities, or data — use them in your answer. Never write a generic answer that could apply to any question.

Question:
{question_text}

Instructions:
{structure}

Strict formatting rules:
- Use **bold** only for key technical terms or final answers
- Use `backticks` for formulas, variable names, or computed values inline
- Use ### for section headings only (no ## or #)
- Use - for bullet points
- For results with multiple states/variables, use a markdown table: | Header | Header | with | --- | --- | separator row
- Do NOT write a preamble like "Here is the answer:" or "Model answer:"
- Do NOT repeat the question text
- Return ONLY the answer markdown, nothing else"""

    response = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
    )
    return response.choices[0].message.content.strip()

# ── I/O Layer — Supabase ──────────────────────────────────────────────────────

def load_bank_and_embeddings(
    college: str,
    subject: str | None = None,
    academic_year: int | None = None,
) -> tuple[list[dict], np.ndarray]:
    """
    Load questions and embeddings from Supabase.

    academic_year — optional filter. When provided, only loads questions from
    that academic year. Prevents first-year students from seeing third-year
    paper questions in their MMR pool, which improves generation relevance.
    """
    sb = get_supabase()
    query = sb.table("questions").select(
        "id, question_text, marks, question_type, subject, paper_year, "
        "exam_type, embedding, topic, academic_year"
    ).eq("college", college)

    if subject:
        query = query.eq("subject", subject)

    if academic_year is not None:
        query = query.eq("academic_year", academic_year)

    response = query.execute()
    rows = response.data or []

    if not rows:
        return [], np.empty((0, 384), dtype=np.float32)

    questions = []
    embeddings = []
    for row in rows:
        questions.append({
            "id":            row["id"],
            "question_text": row["question_text"],
            "marks":         row["marks"],
            "question_type": row["question_type"],
            "subject":       row["subject"],
            "paper_year":    row["paper_year"],
            "exam_type":     row["exam_type"],
            "topic":         row.get("topic", ""),
            "academic_year": row.get("academic_year"),
        })
        emb = row.get("embedding")
        if emb is not None:
            if isinstance(emb, str):
                emb = json.loads(emb)
            embeddings.append(np.array(emb, dtype=np.float32))
        else:
            embeddings.append(np.zeros(384, dtype=np.float32))

    return questions, np.vstack(embeddings)


def save_questions_with_embeddings(
    questions: list[dict],
    embeddings: np.ndarray,
    college: str,
    subject_id: str | None = None,
    campus_id: str | None = None,
    source_pdf_id: str | None = None,
    doc_type: str = "pyq",
) -> int:
    sb = get_supabase()
    rows = []
    for q, emb in zip(questions, embeddings):
        row = {
            "question_text":    q["question_text"],
            "marks":            q["marks"],
            "question_type":    q["question_type"],
            "subject":          q["subject"],       # legacy text — keep
            "college":          college,             # legacy text — keep
            "paper_year":       q["paper_year"],
            "exam_type":        q["exam_type"],
            "embedding":        emb.tolist(),
            "published":        False,
            "doc_type":         doc_type,
            "topic":            q.get("topic", ""),
            "has_diagram":      q.get("has_diagram", False),
            "marks_inferred":   q.get("marks_inferred", False),
            "confidence_score": q.get("confidence_score", 1.0),
            "sub_parts":        q.get("sub_parts", []),
        }
        # MCQ options — only write if present
        if q.get("options"):
            row["options"]        = q["options"]
            row["correct_index"]  = q.get("correct_index")  # may be null if no answer key

        # Only write uuid columns if values were supplied
        if subject_id:
            row["subject_id"] = subject_id
        if campus_id:
            row["campus_id"] = campus_id
        if source_pdf_id:
            row["source_pdf_id"] = source_pdf_id
        rows.append(row)

    if not rows:
        return 0

    batch_size = 50
    inserted = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i + batch_size]
        sb.table("questions").insert(batch).execute()
        inserted += len(batch)

    return inserted

# ── uploaded_pdfs helpers ─────────────────────────────────────────────────────

def _create_pdf_record(
    sb: Client,
    uploaded_by: str | None,
    storage_path: str,
    doc_type: str,
    subject_id: str | None,
    campus_id: str | None,
    exam_type: str | None,
    paper_year: int | None,
) -> str:
    row: dict = {
        "uploaded_as":  "student",
        "storage_path": storage_path,
        "doc_type":     doc_type,
        "status":       "running",
    }
    if uploaded_by:
        row["uploaded_by"] = uploaded_by
    if subject_id:
        row["subject_id"] = subject_id
    if campus_id:
        row["campus_id"] = campus_id
    if exam_type:
        row["exam_type"] = exam_type
    if paper_year:
        row["paper_year"] = paper_year

    response = sb.table("uploaded_pdfs").insert(row).execute()
    return response.data[0]["id"]


def _update_pdf_record(
    sb: Client,
    pdf_id: str,
    status: str,
    questions_extracted: int,
    questions_failed: int,
) -> None:
    sb.table("uploaded_pdfs").update({
        "status":               status,
        "questions_extracted":  questions_extracted,
        "questions_failed":     questions_failed,
    }).eq("id", pdf_id).execute()

# ── Main pipeline entry points ────────────────────────────────────────────────

def run_generate(
    subject: str,
    college: str,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    academic_year: int | None = None,
    current_topic: str | None = None,
) -> str:
    """
    academic_year — scopes the question bank to this year only.
    current_topic — uses the student's current study topic as the MMR query
                    anchor instead of just the subject name. Dramatically
                    improves relevance when the handout topic_schedule is
                    available and passed by the Flutter app.
    """
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    # If current_topic is provided, use it as the MMR anchor — much more
    # relevant than the broad subject name.
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]
    examples = mmr(query_embedding, embeddings, all_questions, k=k)
    return generate_question(subject, examples)


def run_generate_mcq_batch(
    subject: str,
    college: str,
    count: int = 5,
    exam_type: str | None = None,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    academic_year: int | None = None,
    current_topic: str | None = None,
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    all_questions, embeddings = _filter_by_exam_type(all_questions, embeddings, exam_type)

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            examples = mmr(query_embedding, embeddings, all_questions, k=k, seed=worker_idx)
            return generate_mcq(subject, examples)
        except Exception as e:
            logger.warning(f"[generate_mcq worker={worker_idx}] failed: {e}")
            return None

    results: list[dict] = []
    max_workers = min(count, 3)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    return results


def run_generate_open_batch(
    subject: str,
    college: str,
    count: int = 5,
    exam_type: str | None = None,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    with_answers: bool = True,
    academic_year: int | None = None,
    current_topic: str | None = None,
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject, academic_year)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("paper_year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    all_questions, embeddings = _filter_by_exam_type(all_questions, embeddings, exam_type)

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    written_questions = [
        q for q in all_questions
        if q.get("question_type", "short_answer") != "mcq"
    ]
    if not written_questions:
        written_questions = all_questions

    model = get_embed_model()
    written_texts = [q["question_text"] for q in written_questions]
    written_embeddings = model.encode(written_texts)
    query_text = current_topic if current_topic else subject
    query_embedding = model.encode([query_text])[0]

    def _generate_one(worker_idx: int) -> dict | None:
        try:
            examples = mmr(query_embedding, written_embeddings, written_questions, k=k, seed=worker_idx)
            marks_list = [e.get("marks", 5) for e in examples]
            target_marks = sorted(marks_list)[len(marks_list) // 2]

            question_text = generate_question(subject, examples)
            model_answer = ""
            if with_answers:
                model_answer = generate_model_answer(question_text, subject, target_marks)

            return {
                "question":     question_text,
                "subject":      subject,
                "marks":        target_marks,
                "model_answer": model_answer,
            }
        except Exception as e:
            logger.warning(f"[generate_open worker={worker_idx}] failed: {e}")
            return None

    results: list[dict] = []
    max_workers = min(count, 3)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    return results


def run_upload_pyq(
    pdf_bytes: bytes,
    subject: str,
    paper_year: int,
    exam_type: str,
    college: str,
    subject_id: str | None = None,
    campus_id: str | None = None,
    uploaded_by: str | None = None,
    doc_type: str = "pyq",
    storage_path: str = "direct_upload",
) -> dict:
    """
    Full upload pipeline with audit trail.

    For doc_type = "solution": routes to match_and_write_solutions instead
    of extracting new questions. Returns match counts instead of insert counts.

    For all other doc_types: extracts questions and inserts into questions table.
    """
    sb = get_supabase()

    # Route solution sheets to the matching pipeline
    if doc_type == "solution":
        pdf_id: str | None = None
        try:
            pdf_id = _create_pdf_record(
                sb=sb,
                uploaded_by=uploaded_by,
                storage_path=storage_path,
                doc_type=doc_type,
                subject_id=subject_id,
                campus_id=campus_id,
                exam_type=exam_type,
                paper_year=paper_year,
            )
        except Exception as e:
            logger.warning(f"[upload_solution] failed to create uploaded_pdfs row: {e}")

        try:
            result = match_and_write_solutions(
                pdf_bytes=pdf_bytes,
                subject=subject,
                college=college,
                subject_id=subject_id,
            )
            if pdf_id:
                status = "succeeded" if result["unmatched"] == 0 else "partial"
                _update_pdf_record(sb, pdf_id, status, result["matched"], result["unmatched"])
            return {**result, "pdf_id": pdf_id}
        except Exception:
            if pdf_id:
                _update_pdf_record(sb, pdf_id, "failed", 0, 0)
            raise

    # All other doc types — standard extraction pipeline
    pdf_id = None
    try:
        pdf_id = _create_pdf_record(
            sb=sb,
            uploaded_by=uploaded_by,
            storage_path=storage_path,
            doc_type=doc_type,
            subject_id=subject_id,
            campus_id=campus_id,
            exam_type=exam_type,
            paper_year=paper_year,
        )
        logger.info(f"[upload_pyq] created uploaded_pdfs row: {pdf_id}")
    except Exception as e:
        logger.warning(f"[upload_pyq] failed to create uploaded_pdfs row: {e}")

    raw_text = extract_raw_text(pdf_bytes)
    new_questions = extract_questions_from_text(
        raw_text, subject, paper_year, exam_type, doc_type=doc_type
    )

    if not new_questions:
        if pdf_id:
            _update_pdf_record(sb, pdf_id, "failed", 0, 0)
        raise ValueError("No questions could be extracted from the PDF.")

    new_embeddings = embed_questions(new_questions)

    questions_failed = 0
    try:
        inserted = save_questions_with_embeddings(
            questions=new_questions,
            embeddings=new_embeddings,
            college=college,
            subject_id=subject_id,
            campus_id=campus_id,
            source_pdf_id=pdf_id,
            doc_type=doc_type,
        )
    except Exception as e:
        logger.error(f"[upload_pyq] save_questions failed: {e}")
        if pdf_id:
            _update_pdf_record(sb, pdf_id, "failed", 0, len(new_questions))
        raise

    questions_failed = len(new_questions) - inserted

    if pdf_id:
        status = "succeeded" if questions_failed == 0 else "partial"
        _update_pdf_record(sb, pdf_id, status, inserted, questions_failed)
        logger.info(f"[upload_pyq] status={status}, extracted={inserted}, failed={questions_failed}")

    return {
        "added":         inserted,
        "pdf_id":        pdf_id,
        "new_questions": [q["question_text"][:80] + "..." for q in new_questions],
    }


def save_generated_test(
    questions: list[dict],
    college: str,
    subject: str,
    exam_type: str,
    published_by: str | None = None,
) -> str:
    sb = get_supabase()

    rows = []
    for q in questions:
        row = {
            "question_text": q.get("question", q.get("question_text", "")),
            "marks":         int(q.get("marks", 0)),
            "question_type": "mcq" if "correct_index" in q else "short_answer",
            "subject":       subject,
            "college":       college,
            "exam_type":     exam_type,
            "published":     True,
            "published_by":  published_by,
            "published_at":  "now()",
            "doc_type":      "generated",
            "topic":         "",
            "sub_parts":     [],
        }
        if q.get("options"):
            row["options"]       = q["options"]
            row["correct_index"] = q.get("correct_index")
        rows.append(row)

    response = sb.table("questions").insert(rows).execute()
    question_ids = [row["id"] for row in response.data]

    test_response = sb.table("published_tests").insert({
        "college":      college,
        "subject":      subject,
        "exam_type":    exam_type,
        "question_ids": question_ids,
        "published_by": published_by,
    }).execute()

    return test_response.data[0]["id"]