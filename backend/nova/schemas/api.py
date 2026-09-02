from typing import Any, Literal

from pydantic import BaseModel, Field

TriggerType = Literal["full_pass", "minor_trigger_rerank"]
NovaResponseType = Literal["chat", "quiz", "plan", "flashcard", "practice_problem"]


class ChatRequest(BaseModel):
    """A single free-text question sent to Nova's chat endpoint."""
    question: str = Field(..., description="Student's question, as typed in the app.")


class QuizQuestion(BaseModel):
    question: str = Field(..., description="The quiz question text.")
    options: list[str] = Field(..., description="4 multiple-choice options.")
    correct_index: int = Field(..., description="0-based index of the correct option (0-3).")
    explanation: str = Field(..., description="Concise academic explanation of why this answer is correct.")


class QuizPayload(BaseModel):
    title: str = Field(default="Quick Quiz", description="Quiz title or topic.")
    questions: list[QuizQuestion] = Field(..., description="List of multiple-choice questions.")


class FlashcardItem(BaseModel):
    front: str = Field(..., description="Term, law, formula, or concept name.")
    back: str = Field(..., description="Definition, formula expansion, or explanation.")
    key_takeaway: str | None = Field(default=None, description="Exam tip or common pitfall.")


class FlashcardPayload(BaseModel):
    title: str = Field(default="Key Concept Flashcards", description="Deck topic or title.")
    cards: list[FlashcardItem] = Field(..., description="List of flashcard items.")


class PracticeProblemPayload(BaseModel):
    title: str = Field(default="Practice Problem", description="Problem topic or title.")
    problem_statement: str = Field(..., description="The complete problem prompt.")
    topic: str = Field(..., description="Subject or topic name.")
    difficulty: str = Field(default="Medium", description="Easy, Medium, Hard, or Advanced.")
    hints: list[str] = Field(default_factory=list, description="1 to 3 progressive hints.")
    solution: str = Field(..., description="Complete step-by-step mathematical or logical solution.")


class PlanItem(BaseModel):
    """One actionable item in a student's study plan."""
    subject: str = Field(..., description="Subject or topic this item covers.")
    task: str = Field(..., description="What the student should actually do.")
    priority: int = Field(..., description="Rank within the plan; 1 is highest priority.")
    reason: str = Field(
        ..., description="Why this made the cut - urgency, stakes, fixability, or relevance."
    )


class StudyPlan(BaseModel):
    """Structured output Groq is expected to return. Anything that doesn't
    fit this shape fails validation instead of silently passing through."""
    items: list[PlanItem] = Field(default_factory=list)
    summary: str | None = Field(
        default=None, description="One-line human summary of today's plan."
    )


class ChatResponse(BaseModel):
    """Polymorphic response structure returned to the client."""
    type: NovaResponseType = Field(default="chat", description="UI element type to render.")
    message: str = Field(..., description="Nova's natural-language reply or component introduction.")
    data: dict[str, Any] | None = Field(
        default=None,
        description="Structured payload matching the response type (quiz, plan, flashcard, practice_problem).",
    )
    suggestions: list[str] = Field(
        default_factory=list,
        description="2 to 4 contextual next-step questions to display in follow-up chips.",
    )


class FactsResponse(BaseModel):
    snapshot: dict = Field(..., description="Full current facts snapshot for the student.")
    patch: dict = Field(
        default_factory=dict,
        description="Fields changed since the last call. Empty {} if nothing changed.",
    )


class ReasoningRunRequest(BaseModel):
    """Kicks off one reasoning pass for a student."""
    trigger_type: TriggerType = Field(
        default="full_pass",
        description=(
            "'full_pass' for a full re-ranked study plan (e.g. daily scheduled run). "
            "'minor_trigger_rerank' for a lighter re-rank off a single event, "
            "such as a new test score or a capacity update."
        ),
    )


class ReasoningRunResponse(BaseModel):
    plan: StudyPlan = Field(..., description="The generated (or carried-over) study plan.")
    stale: bool = Field(
        ..., description="True if this is yesterday's plan, carried over because generation failed."
    )
    note: str | None = Field(
        default=None, description="User-visible message explaining a stale/degraded plan."
    )
    compression_tier: int = Field(
        default=1,
        description=(
            "Which snapshot compression tier was used: 1=full, 2=compressed, 3=skeleton. "
            "Higher tier means the snapshot was too large and was trimmed before sending to the model."
        ),
    )


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    supabase: bool
    groq: bool
    groq_backup: bool