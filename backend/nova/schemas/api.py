from typing import Literal

from pydantic import BaseModel, Field

TriggerType = Literal["full_pass", "minor_trigger_rerank"]


class ChatRequest(BaseModel):
    """A single free-text question sent to Nova's chat endpoint."""
    question: str = Field(..., description="Student's question, as typed in the app.")


class ChatResponse(BaseModel):
    answer: str = Field(..., description="Nova's natural-language reply.")


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