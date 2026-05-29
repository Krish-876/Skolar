import os
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["OMP_NUM_THREADS"] = "1"

import json
import numpy as np
from numpy.linalg import norm
import pdfplumber
from sentence_transformers import SentenceTransformer
from groq import Groq
from dotenv import load_dotenv
from concurrent.futures import ThreadPoolExecutor, as_completed
from supabase import create_client, Client

load_dotenv()

# ── Constants ────────────────────────────────────────────────────────────────

EMBED_MODEL = "all-MiniLM-L6-v2"
GROQ_MODEL  = "llama-3.3-70b-versatile"
CHUNK_SIZE  = 6000

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_embed_model   = None
_groq_client   = None
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
    full_text = ""
    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        for page in pdf.pages:
            text = page.extract_text()
            if text:
                full_text += text + "\n"
    return full_text

# ── Step 2 — Question Extraction ──────────────────────────────────────────────

def extract_questions_from_text(raw_text: str, subject: str, year: int, exam_type: str) -> list[dict]:
    client = get_groq_client()
    chunks = [raw_text[i:i+CHUNK_SIZE] for i in range(0, len(raw_text), CHUNK_SIZE)]
    all_questions = []

    for chunk in chunks:
        prompt = f"""You are extracting exam questions from a scanned question paper.

Rules:
- Extract ONLY complete, standalone questions a student must answer
- NEVER extract MCQ options (like "A) ...", "B) ...", answer choices)
- NEVER extract answers, solutions, or marking schemes
- For MCQ questions, include the full question stem AND all its options together in question_text
- If you see "Q1.", "Q.1", "1.", treat it as a question start
- Ignore headers, instructions, college names, dates, and page numbers
- marks: extract the number if shown (e.g. "[5]", "(5 marks)"), else estimate based on question type
- question_type: mcq if it has options A/B/C/D, numerical if it asks to calculate a number, long_answer if it requires explanation (>5 marks), else short_answer

Return ONLY a JSON array. No markdown, no backticks, no explanation.
Each item must have:
- question_text (string) — complete question including options if MCQ
- marks (integer)
- question_type (one of: mcq, short_answer, long_answer, numerical)

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
                q["subject"]   = subject
                q["year"]      = year
                q["exam_type"] = exam_type
                q["marks"]     = int(round(q.get("marks", 0)))
            all_questions.extend(parsed)
        except Exception:
            continue

    return all_questions

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
) -> list[dict]:
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

# ── Step 5 — Open-ended Question Generation ───────────────────────────────────

def generate_question(subject: str, examples: list[dict]) -> str:
    client = get_groq_client()
    examples_text = "\n\n".join(
        f"Example {i+1} ({q.get('marks', '?')} marks, {q.get('question_type', 'unknown')}):\n{q['question_text']}"
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
        f"Example {i+1} ({q.get('marks', '?')} marks, {q.get('question_type', 'unknown')}):\n{q['question_text']}"
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
    """
    Generate a structured markdown model answer that directly answers the specific question.
    - 1-3 marks : 2-3 sentences of direct answer, bold key terms
    - 4-6 marks : direct answer + ### Steps or ### Key points with specific content
    - 7+  marks : full worked answer with ### headings tailored to question type
    If the question contains numbers, tables, or asks to compute/derive/prove something,
    the answer MUST show the actual working with those specific values.
    """
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
) -> tuple[list[dict], np.ndarray]:
    sb = get_supabase()
    query = sb.table("questions").select(
        "id, question_text, marks, question_type, subject, year, exam_type, embedding"
    ).eq("college", college)

    if subject:
        query = query.eq("subject", subject)

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
            "year":          row["year"],
            "exam_type":     row["exam_type"],
        })
        emb = row.get("embedding")
        if emb is not None:
            if isinstance(emb, str):
                import json as _json
                emb = _json.loads(emb)
            embeddings.append(np.array(emb, dtype=np.float32))
        else:
            embeddings.append(np.zeros(384, dtype=np.float32))

    return questions, np.vstack(embeddings)


def save_questions_with_embeddings(
    questions: list[dict],
    embeddings: np.ndarray,
    college: str,
) -> int:
    sb = get_supabase()
    rows = []
    for q, emb in zip(questions, embeddings):
        rows.append({
            "question_text": q["question_text"],
            "marks":         q["marks"],
            "question_type": q["question_type"],
            "subject":       q["subject"],
            "year":          q["year"],
            "exam_type":     q["exam_type"],
            "college":       college,
            "embedding":     emb.tolist(),
        })

    if not rows:
        return 0

    batch_size = 50
    inserted = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i:i + batch_size]
        sb.table("questions").insert(batch).execute()
        inserted += len(batch)

    return inserted

# ── Main pipeline entry points ────────────────────────────────────────────────

def run_generate(
    subject: str,
    college: str,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
) -> str:
    all_questions, embeddings = load_bank_and_embeddings(college, subject)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    query_embedding = model.encode([subject])[0]
    examples = mmr(query_embedding, embeddings, all_questions, k=k)
    return generate_question(subject, examples)


def run_generate_mcq_batch(
    subject: str,
    college: str,
    count: int = 5,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
) -> list[dict]:
    all_questions, embeddings = load_bank_and_embeddings(college, subject)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

    if not all_questions:
        raise ValueError(f"No questions found for subject='{subject}', college='{college}'.")

    model = get_embed_model()
    query_embedding = model.encode([subject])[0]

    def _generate_one(_: int) -> dict | None:
        try:
            examples = mmr(query_embedding, embeddings, all_questions, k=k)
            return generate_mcq(subject, examples)
        except Exception:
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
    year_range: tuple[int, int] | None = None,
    k: int = 5,
    with_answers: bool = True,
) -> list[dict]:
    """
    Generate `count` open-ended questions in parallel, each with a pre-generated
    model answer. Used for Quiz, Midsem, and Compre Part B practice modes.

    Returns list of dicts:
        { question, subject, marks, model_answer }
    """
    all_questions, embeddings = load_bank_and_embeddings(college, subject)

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("year", 0) <= year_range[1]
        ]
        all_questions = [all_questions[i] for i in indices]
        embeddings    = embeddings[indices]

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
    query_embedding = model.encode([subject])[0]

    def _generate_one(_: int) -> dict | None:
        try:
            examples = mmr(query_embedding, written_embeddings, written_questions, k=k)
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
        except Exception:
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
    year: int,
    exam_type: str,
    college: str,
) -> dict:
    raw_text      = extract_raw_text(pdf_bytes)
    new_questions = extract_questions_from_text(raw_text, subject, year, exam_type)

    if not new_questions:
        raise ValueError("No questions could be extracted from the PDF.")

    new_embeddings = embed_questions(new_questions)
    inserted = save_questions_with_embeddings(new_questions, new_embeddings, college)

    return {
        "added":         inserted,
        "new_questions": [q["question_text"][:80] + "..." for q in new_questions],
    }