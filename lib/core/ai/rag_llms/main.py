"""
main.py — Skolar FastAPI Server
Place this in: nova/lib/core/ai/rag_llms/

Run with:
    uvicorn main:app --reload --port 8000

Endpoints:
    POST /generate      → returns a new AI-generated question
    POST /upload-pyq    → accepts a PDF, adds questions to the bank
    GET  /health        → sanity check
    GET  /stats         → question bank stats
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn

from pipeline import run_generate, run_upload_pyq, load_bank_and_embeddings

# ── App setup ─────────────────────────────────────────────────────────────────

app = FastAPI(
    title="Skolar AI API",
    description="DICL-based exam question generation using college PYQs",
    version="1.0.0",
)

# Allow Flutter app (any origin during development)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Request / Response models ─────────────────────────────────────────────────

class GenerateRequest(BaseModel):
    subject: str                        # e.g. "Artificial Intelligence"
    year_from: Optional[int] = None     # e.g. 2024
    year_to: Optional[int] = None       # e.g. 2026
    k: Optional[int] = 5               # number of MMR examples

class GenerateResponse(BaseModel):
    question: str
    subject: str
    examples_used: int

class UploadResponse(BaseModel):
    message: str
    added: int
    total: int
    preview: list[str]

class StatsResponse(BaseModel):
    total_questions: int
    subjects: dict
    years: list[int]

# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "ok", "service": "Skolar AI API"}


@app.get("/stats", response_model=StatsResponse)
def stats():
    """Return question bank statistics."""
    try:
        questions, _ = load_bank_and_embeddings()
    except FileNotFoundError:
        raise HTTPException(status_code=500, detail="Question bank not found. Run the notebook first.")

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


@app.post("/generate", response_model=GenerateResponse)
def generate(req: GenerateRequest):
    """
    Generate one new exam question using DICL pipeline.

    Body:
        {
          "subject": "Artificial Intelligence",
          "year_from": 2024,
          "year_to": 2026,
          "k": 5
        }
    """
    year_range = None
    if req.year_from and req.year_to:
        if req.year_from > req.year_to:
            raise HTTPException(status_code=400, detail="year_from must be <= year_to")
        year_range = (req.year_from, req.year_to)

    k = max(1, min(req.k or 5, 10))  # clamp between 1 and 10

    try:
        question = run_generate(subject=req.subject, year_range=year_range, k=k)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline error: {str(e)}")

    return GenerateResponse(
        question=question,
        subject=req.subject,
        examples_used=k,
    )


@app.post("/upload-pyq", response_model=UploadResponse)
async def upload_pyq(
    file: UploadFile = File(...),
    subject: str = Form(...),
    year: int = Form(...),
    exam_type: str = Form("unknown"),   # e.g. "midsem", "compre", "endsem"
):
    """
    Upload a PYQ PDF → extract questions → add to question bank.

    Form fields:
        file      : PDF file
        subject   : e.g. "Artificial Intelligence"
        year      : e.g. 2025
        exam_type : e.g. "compre"
    """
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