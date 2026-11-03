import json
import logging

from ..ingest.chunking import _deduplicate_questions, _make_chunks
from .client import GROQ_MODEL, get_groq_client

logger = logging.getLogger(__name__)

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
  topic               (string — specific 2-6 word concept label)
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
                raw = raw.removeprefix("json")
            parsed = json.loads(raw)
            for q in parsed:
                q["subject"]          = subject
                q["paper_year"]       = paper_year
                q["exam_type"]        = exam_type
                q["doc_type"]         = doc_type
                q["marks"]            = round(q.get("marks", 0))
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
                raw = raw.removeprefix("json")
            parsed = json.loads(raw)
            all_answers.extend(parsed)
        except Exception as e:
            logger.warning(f"[extract_answers] chunk {chunk_idx} failed: {e}")
            continue

    return all_answers


class ExamTypeUndeterminedError(ValueError):
    """Raised by run_upload_pyq when no exam_type was provided and none could
    be guessed from the document's own content."""


def guess_exam_type_from_text(text: str) -> str | None:
    """Scan the first 2000 characters of extracted text (case-insensitive)
    for exam-type keywords. Same keyword categories as batch_upload.py's
    _guess_exam_type, applied to document content instead of the filename."""
    snippet = text[:2000].lower()
    if "compre" in snippet:
        return "compre"
    if "mid-sem" in snippet or "mid sem" in snippet or "midsem" in snippet:
        return "midsem"
    if "test1" in snippet or "quiz1" in snippet or "quiz-1" in snippet or "quiz-i" in snippet:
        return "quiz1"
    if "test2" in snippet or "quiz2" in snippet or "quiz-2" in snippet or "quiz-ii" in snippet:
        return "quiz2"
    if "test3" in snippet or "test-3" in snippet:
        return "compre"
    return None
