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

load_dotenv()

# ── Constants ────────────────────────────────────────────────────────────────

BASE_DIR        = os.path.dirname(os.path.abspath(__file__))
QUESTION_BANK   = os.path.join(BASE_DIR, "question_bank.json")
EMBEDDINGS_FILE = os.path.join(BASE_DIR, "embeddings.npy")
EMBED_MODEL     = "all-MiniLM-L6-v2"
GROQ_MODEL      = "llama-3.3-70b-versatile"
CHUNK_SIZE      = 6000

# ── Shared resources (loaded once at startup) ─────────────────────────────────

_embed_model = None
_groq_client = None

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

# ── Step 1 — PDF Parsing ──────────────────────────────────────────────────────

def extract_raw_text(pdf_bytes: bytes) -> str:
    """Extract plain text from PDF bytes using pdfplumber."""
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
    """
    Send raw text to Groq LLM in chunks and extract structured questions.
    Returns a list of question dicts.
    """
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
            # Strip accidental markdown fences
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
        except (json.JSONDecodeError, Exception):
            # Skip bad chunks silently — LLM sometimes returns nothing for non-question pages
            continue

    return all_questions

# ── Step 3 — Embeddings ───────────────────────────────────────────────────────

def embed_questions(questions: list[dict]) -> np.ndarray:
    """Convert question texts to embedding vectors. Shape: (N, 384)."""
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
    """
    Maximal Marginal Relevance — select k diverse questions relevant to query.
    alpha: 0.7 = 70% relevance, 30% diversity (matches DICL paper setting).
    """
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
    """Generate one new original question using diverse PYQ examples as context."""
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
    return response.choices[0].message.content.strip()

# ── Step 5b — MCQ Generation ──────────────────────────────────────────────────

def generate_mcq(subject: str, examples: list[dict]) -> dict:
    """
    Generate one new MCQ question with 4 options, correct index, and marks.
    Returns a dict matching the QuizQuestion shape expected by Flutter.
    Raises ValueError if the LLM response cannot be parsed after retries.
    """
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

    # Strip accidental markdown fences
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    parsed = json.loads(raw)

    # Normalise into the shape Flutter's QuizQuestion expects
    return {
        "question":      parsed["question"],
        "options": [
            parsed["option_a"],
            parsed["option_b"],
            parsed["option_c"],
            parsed["option_d"],
        ],
        "correct_index": int(parsed["correct_index"]),
        "subject":       parsed.get("subject", subject),
        "marks":         int(parsed.get("marks", 1)),
    }

# ── Main pipeline entry points ────────────────────────────────────────────────

def load_bank_and_embeddings() -> tuple[list[dict], np.ndarray]:
    """Load existing question bank and embeddings from disk."""
    with open(QUESTION_BANK, "r") as f:
        questions = json.load(f)
    embeddings = np.load(EMBEDDINGS_FILE)
    return questions, embeddings

def save_bank_and_embeddings(questions: list[dict], embeddings: np.ndarray):
    """Persist question bank and embeddings to disk."""
    with open(QUESTION_BANK, "w") as f:
        json.dump(questions, f, indent=2)
    np.save(EMBEDDINGS_FILE, embeddings)


def run_generate(subject: str, year_range: tuple[int, int] | None = None, k: int = 5) -> str:
    """
    Full pipeline: load bank → filter → embed query → MMR → generate open-ended question.
    Returns the generated question string.
    """
    all_questions, embeddings = load_bank_and_embeddings()

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("year", 0) <= year_range[1]
        ]
        filtered_questions  = [all_questions[i] for i in indices]
        filtered_embeddings = embeddings[indices]
    else:
        filtered_questions  = all_questions
        filtered_embeddings = embeddings

    if not filtered_questions:
        raise ValueError("No questions found for the given filters.")

    model = get_embed_model()
    query_embedding = model.encode([subject])[0]

    examples = mmr(query_embedding, filtered_embeddings, filtered_questions, k=k)
    return generate_question(subject, examples)


def run_generate_mcq_batch(
    subject: str,
    count: int = 5,
    year_range: tuple[int, int] | None = None,
    k: int = 5,
) -> list[dict]:
    """
    Generate `count` MCQ questions in parallel.

    Each question gets its own independent MMR call so questions are topically
    diverse from each other (different random seeds via temperature=0.8 on the
    LLM side).  Uses a ThreadPoolExecutor because the Groq SDK is synchronous.

    Returns a list of dicts, each matching Flutter's QuizQuestion shape:
        { question, options: [a,b,c,d], correct_index, subject, marks }

    Raises ValueError if no questions are found for the given filters.
    Silently drops any individual questions that fail to parse (LLM hiccup),
    so the returned list may be shorter than `count` — the caller handles this.
    """
    all_questions, embeddings = load_bank_and_embeddings()

    if year_range:
        indices = [
            i for i, q in enumerate(all_questions)
            if year_range[0] <= q.get("year", 0) <= year_range[1]
        ]
        filtered_questions  = [all_questions[i] for i in indices]
        filtered_embeddings = embeddings[indices]
    else:
        filtered_questions  = all_questions
        filtered_embeddings = embeddings

    if not filtered_questions:
        raise ValueError("No questions found for the given filters.")

    model = get_embed_model()
    query_embedding = model.encode([subject])[0]

    def _generate_one(_: int) -> dict | None:
        """Single MCQ generation task — runs inside a thread."""
        try:
            examples = mmr(query_embedding, filtered_embeddings, filtered_questions, k=k)
            return generate_mcq(subject, examples)
        except Exception:
            return None

    results: list[dict] = []
    # Cap parallelism to avoid hammering the Groq rate limit
    max_workers = min(count, 5)
    with ThreadPoolExecutor(max_workers=max_workers) as pool:
        futures = [pool.submit(_generate_one, i) for i in range(count)]
        for future in as_completed(futures):
            result = future.result()
            if result is not None:
                results.append(result)

    return results


def run_upload_pyq(pdf_bytes: bytes, subject: str, year: int, exam_type: str) -> dict:
    """
    Full pipeline: parse PDF → extract questions → embed → append to bank.
    Returns a summary of what was added.
    """
    raw_text      = extract_raw_text(pdf_bytes)
    new_questions = extract_questions_from_text(raw_text, subject, year, exam_type)

    if not new_questions:
        raise ValueError("No questions could be extracted from the PDF.")

    all_questions, existing_embeddings = load_bank_and_embeddings()
    new_embeddings = embed_questions(new_questions)

    all_questions  = all_questions + new_questions
    all_embeddings = np.vstack([existing_embeddings, new_embeddings])

    save_bank_and_embeddings(all_questions, all_embeddings)

    return {
        "added":         len(new_questions),
        "total":         len(all_questions),
        "new_questions": [q["question_text"][:80] + "..." for q in new_questions],
    }