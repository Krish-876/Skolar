"""
Run with:
    uvicorn main:app --reload --port 8000

Endpoints:
    POST /generate          → returns one AI-generated open-ended question
    POST /generate-batch    → returns N AI-generated MCQs for mock tests
    POST /upload-pyq        → accepts a PDF, adds questions to the bank
    GET  /health            → sanity check
    GET  /stats             → question bank stats
    GET  /questions         → browse / filter the question bank
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn

from pipeline import (
    run_generate,
    run_generate_mcq_batch,
    run_upload_pyq,
    load_bank_and_embeddings,
)

# ── App setup ─────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Skolar AI API",
    description="DICL-based exam question generation using college PYQs",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request / Response models ─────────────────────────────────────────────────

class GenerateRequest(BaseModel):
    subject: str
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    k: Optional[int] = 5

class GenerateResponse(BaseModel):
    question: str
    subject: str
    examples_used: int

# Each item in the batch response matches Flutter's QuizQuestion shape exactly
class McqQuestion(BaseModel):
    question: str
    options: list[str]          # always length 4
    correct_index: int          # 0-3
    subject: str
    marks: int

class GenerateBatchRequest(BaseModel):
    subject: str
    count: Optional[int] = 5       # number of MCQs to generate (1-20)
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    k: Optional[int] = 5          # MMR examples per generation call

class GenerateBatchResponse(BaseModel):
    questions: list[McqQuestion]
    subject: str
    requested: int
    generated: int              # may be < requested if some LLM calls failed

class UploadResponse(BaseModel):
    message: str
    added: int
    total: int
    preview: list[str]

class StatsResponse(BaseModel):
    total_questions: int
    subjects: dict
    years: list[int]

class QuestionItem(BaseModel):
    question_text: str
    marks: int
    question_type: str
    subject: str
    year: int
    exam_type: str

class QuestionsResponse(BaseModel):
    total: int
    questions: list[QuestionItem]

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "Skolar AI API"}


@app.get("/stats", response_model=StatsResponse)
def stats():
    try:
        questions, _ = load_bank_and_embeddings()
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Question bank not found.")

    subjects: dict[str, int] = {}
    years: set[int] = set()
    for q in questions:
        subj = q.get("subject", "Unknown")
        subjects[subj] = subjects.get(subj, 0) + 1
        yr = q.get("year")
        if yr:
            years.add(yr)

    return StatsResponse(
        total_questions=len(questions),
        subjects=subjects,
        years=sorted(years),
    )


@app.get("/questions", response_model=QuestionsResponse)
def get_questions(
    subject: Optional[str] = Query(None),
    year: Optional[int] = Query(None),
    exam_type: Optional[str] = Query(None),
    question_type: Optional[str] = Query(None),
):
    try:
        questions, _ = load_bank_and_embeddings()
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Question bank not found.")

    if subject:
        questions = [q for q in questions if q.get("subject", "").lower() == subject.lower()]
    if year:
        questions = [q for q in questions if q.get("year") == year]
    if exam_type:
        questions = [q for q in questions if q.get("exam_type", "").lower() == exam_type.lower()]
    if question_type:
        questions = [q for q in questions if q.get("question_type", "").lower() == question_type.lower()]

    return QuestionsResponse(
        total=len(questions),
        questions=[
            QuestionItem(
                question_text=q.get("question_text", ""),
                marks=int(round(q.get("marks", 0))),
                question_type=q.get("question_type", "unknown"),
                subject=q.get("subject", "Unknown"),
                year=q.get("year", 0),
                exam_type=q.get("exam_type", "unknown"),
            )
            for q in questions
        ],
    )


@app.post("/generate", response_model=GenerateResponse)
def generate(req: GenerateRequest):
    """Generate one new open-ended exam question using the DICL pipeline."""
    year_range = None
    if req.year_from and req.year_to:
        if req.year_from > req.year_to:
            raise HTTPException(status_code=400, detail="year_from must be <= year_to")
        year_range = (req.year_from, req.year_to)

    k = max(1, min(req.k or 5, 10))

    try:
        question = run_generate(subject=req.subject, year_range=year_range, k=k)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    return GenerateResponse(question=question, subject=req.subject, examples_used=k)


@app.post("/generate-batch", response_model=GenerateBatchResponse)
def generate_batch(req: GenerateBatchRequest):
    """
    Generate N MCQ questions in parallel for a mock test session.

    The questions are topically diverse (each gets an independent MMR pass)
    and formatted with 4 options + a correct_index, ready for the Flutter quiz UI.

    Body:
        {
          "subject":    "Artificial Intelligence",
          "count":      5,
          "year_from":  2024,
          "year_to":    2026,
          "k":          5
        }
    """
    count = max(1, min(req.count or 5, 20))

    year_range = None
    if req.year_from and req.year_to:
        if req.year_from > req.year_to:
            raise HTTPException(status_code=400, detail="year_from must be <= year_to")
        year_range = (req.year_from, req.year_to)

    k = max(1, min(req.k or 5, 10))

    try:
        raw = run_generate_mcq_batch(
            subject=req.subject,
            count=count,
            year_range=year_range,
            k=k,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    if not raw:
        raise HTTPException(
            status_code=500,
            detail="All MCQ generation attempts failed. Check Groq API key and question bank."
        )

    questions = [
        McqQuestion(
            question=q["question"],
            options=q["options"],
            correct_index=q["correct_index"],
            subject=q["subject"],
            marks=q["marks"],
        )
        for q in raw
    ]

    return GenerateBatchResponse(
        questions=questions,
        subject=req.subject,
        requested=count,
        generated=len(questions),
    )


@app.post("/upload-pyq", response_model=UploadResponse)
async def upload_pyq(
    file: UploadFile = File(...),
    subject: str = Form(...),
    year: int = Form(...),
    exam_type: str = Form("unknown"),
):
    """Upload a PYQ PDF -> extract questions -> add to question bank."""
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are accepted.")

    pdf_bytes = await file.read()
    if len(pdf_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        result = run_upload_pyq(
            pdf_bytes=pdf_bytes,
            subject=subject,
            year=year,
            exam_type=exam_type,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")

    return UploadResponse(
        message=f"Successfully added {result['added']} questions from {file.filename}",
        added=result["added"],
        total=result["total"],
        preview=result["new_questions"],
    )


# ── Dev entrypoint ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)