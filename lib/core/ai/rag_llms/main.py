"""
Run with:
    uvicorn main:app --reload --port 8000

Endpoints:
    POST /generate               → one AI-generated open-ended question
    POST /generate-batch         → N MCQs (Compre Part A / Quiz MCQ mode)
    POST /generate-open-batch    → N open-ended questions + model answers (Quiz / Midsem / Compre Part B)
    POST /upload-pyq             → PDF → extract → insert into Supabase
    GET  /health                 → sanity check
    GET  /stats                  → question bank stats (scoped by college)
    GET  /questions              → browse / filter the question bank (scoped by college)
"""

import traceback

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn

from pipeline import (
    run_generate,
    run_generate_mcq_batch,
    run_generate_open_batch,
    run_upload_pyq,
    load_bank_and_embeddings,
)

# ── App setup ─────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Skolar AI API",
    description="DICL-based exam question generation using college PYQs",
    version="2.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Valid exam types (mirrors schema CHECK constraint) ────────────────────────

_VALID_EXAM_TYPES = {"quiz1", "midsem", "quiz2", "compre", "generated"}

# ── Request / Response models ─────────────────────────────────────────────────

class GenerateRequest(BaseModel):
    subject: str
    college: str
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    k: Optional[int] = 5

class GenerateResponse(BaseModel):
    question: str
    subject: str
    examples_used: int

class McqQuestion(BaseModel):
    question: str
    options: list[str]       # always length 4
    correct_index: int       # 0-3
    subject: str
    marks: int

class GenerateBatchRequest(BaseModel):
    subject: str
    college: str
    count: Optional[int] = 5
    exam_type: Optional[str] = None
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    k: Optional[int] = 5

class GenerateBatchResponse(BaseModel):
    questions: list[McqQuestion]
    subject: str
    requested: int
    generated: int

# ── Open-ended batch (Quiz / Midsem / Compre Part B) ──────────────────────────

class OpenQuestion(BaseModel):
    question: str
    subject: str
    marks: int
    model_answer: str       # pre-generated; empty string if with_answers=False

class GenerateOpenBatchRequest(BaseModel):
    subject: str
    college: str
    count: Optional[int] = 5
    exam_type: Optional[str] = None
    year_from: Optional[int] = None
    year_to: Optional[int] = None
    k: Optional[int] = 5
    with_answers: Optional[bool] = True   # always True in practice; kept for flexibility

class GenerateOpenBatchResponse(BaseModel):
    questions: list[OpenQuestion]
    subject: str
    requested: int
    generated: int

# ── Upload / Stats / Questions ─────────────────────────────────────────────────

class UploadResponse(BaseModel):
    message: str
    added: int
    total: int
    preview: list[str]

class StatsResponse(BaseModel):
    total_questions: int
    subjects: dict
    paper_years: list[int]

class QuestionItem(BaseModel):
    question_text: str
    marks: int
    question_type: str
    subject: str
    paper_year: int
    exam_type: str

class QuestionsResponse(BaseModel):
    total: int
    questions: list[QuestionItem]

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "Skolar AI API", "version": "2.1.0"}


@app.get("/stats", response_model=StatsResponse)
def stats(college: str = Query(...)):
    try:
        questions, _ = load_bank_and_embeddings(college)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    subjects: dict[str, int] = {}
    paper_years: set[int] = set()
    for q in questions:
        subj = q.get("subject", "Unknown")
        subjects[subj] = subjects.get(subj, 0) + 1
        yr = q.get("paper_year")
        if yr:
            paper_years.add(yr)

    return StatsResponse(
        total_questions=len(questions),
        subjects=subjects,
        paper_years=sorted(paper_years),
    )


@app.get("/questions", response_model=QuestionsResponse)
def get_questions(
    college: str = Query(...),
    subject: Optional[str] = Query(None),
    paper_year: Optional[int] = Query(None),
    exam_type: Optional[str] = Query(None),
    question_type: Optional[str] = Query(None),
):
    try:
        questions, _ = load_bank_and_embeddings(college)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    if subject:
        questions = [q for q in questions if q.get("subject", "").lower() == subject.lower()]
    if paper_year:
        questions = [q for q in questions if q.get("paper_year") == paper_year]
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
                paper_year=q.get("paper_year", 0),
                exam_type=q.get("exam_type", "unknown"),
            )
            for q in questions
        ],
    )


@app.post("/generate", response_model=GenerateResponse)
def generate(req: GenerateRequest):
    year_range = None
    if req.year_from and req.year_to:
        if req.year_from > req.year_to:
            raise HTTPException(status_code=400, detail="year_from must be <= year_to")
        year_range = (req.year_from, req.year_to)

    k = max(1, min(req.k or 5, 10))

    try:
        question = run_generate(
            subject=req.subject,
            college=req.college,
            year_range=year_range,
            k=k,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    return GenerateResponse(question=question, subject=req.subject, examples_used=k)


@app.post("/generate-batch", response_model=GenerateBatchResponse)
def generate_batch(req: GenerateBatchRequest):
    """
    Generate N MCQ questions for Compre Part A practice.

    Body:
        {
          "subject": "Artificial Intelligence",
          "college": "BPHC",
          "count":   5,
          "exam_type": "compre"
        }
    """
    if req.exam_type and req.exam_type not in _VALID_EXAM_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exam_type '{req.exam_type}'. Must be one of: {sorted(_VALID_EXAM_TYPES)}",
        )

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
            college=req.college,
            count=count,
            exam_type=req.exam_type,
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
            detail="All MCQ generation attempts failed. Check Groq API key and question bank.",
        )

    return GenerateBatchResponse(
        questions=[
            McqQuestion(
                question=q["question"],
                options=q["options"],
                correct_index=q["correct_index"],
                subject=q["subject"],
                marks=q["marks"],
            )
            for q in raw
        ],
        subject=req.subject,
        requested=count,
        generated=len(raw),
    )


@app.post("/generate-open-batch", response_model=GenerateOpenBatchResponse)
def generate_open_batch(req: GenerateOpenBatchRequest):
    """
    Generate N open-ended questions with pre-generated model answers.
    Used for Quiz, Midsem, and Compre Part B practice modes.

    Body:
        {
          "subject":      "Artificial Intelligence",
          "college":      "BPHC",
          "count":        5,
          "exam_type":    "midsem",
          "with_answers": true
        }

    Longer timeout needed on the client — each question makes 2 Groq calls.
    Expect ~8-12s for 5 questions with 3 parallel workers.
    """
    if req.exam_type and req.exam_type not in _VALID_EXAM_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exam_type '{req.exam_type}'. Must be one of: {sorted(_VALID_EXAM_TYPES)}",
        )

    count = max(1, min(req.count or 5, 15))

    year_range = None
    if req.year_from and req.year_to:
        if req.year_from > req.year_to:
            raise HTTPException(status_code=400, detail="year_from must be <= year_to")
        year_range = (req.year_from, req.year_to)

    k = max(1, min(req.k or 5, 10))

    try:
        raw = run_generate_open_batch(
            subject=req.subject,
            college=req.college,
            count=count,
            exam_type=req.exam_type,
            year_range=year_range,
            k=k,
            with_answers=req.with_answers if req.with_answers is not None else True,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    if not raw:
        raise HTTPException(
            status_code=500,
            detail="All question generation attempts failed. Check Groq API key and question bank.",
        )

    return GenerateOpenBatchResponse(
        questions=[
            OpenQuestion(
                question=q["question"],
                subject=q["subject"],
                marks=q["marks"],
                model_answer=q.get("model_answer", ""),
            )
            for q in raw
        ],
        subject=req.subject,
        requested=count,
        generated=len(raw),
    )


@app.post("/upload-pyq", response_model=UploadResponse)
async def upload_pyq(
    file: UploadFile = File(...),
    subject: str = Form(...),
    paper_year: int = Form(...),
    exam_type: str = Form(...),
    college: str = Form(...),
):
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are accepted.")

    if exam_type not in _VALID_EXAM_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid exam_type '{exam_type}'. Must be one of: {sorted(_VALID_EXAM_TYPES)}",
        )

    pdf_bytes = await file.read()
    if len(pdf_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded file is empty.")

    try:
        result = run_upload_pyq(
            pdf_bytes=pdf_bytes,
            subject=subject,
            paper_year=paper_year,
            exam_type=exam_type,
            college=college,
        )
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Upload error: {str(e)}")

    return UploadResponse(
        message=f"Successfully added {result['added']} questions from {file.filename}",
        added=result["added"],
        total=result["added"],
        preview=result["new_questions"],
    )


# ── Dev entrypoint ────────────────────────────────────────────────────────────

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)