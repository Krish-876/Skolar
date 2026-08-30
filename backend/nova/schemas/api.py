from typing import Literal

from pydantic import BaseModel

from nova.services.reasoning_service import TriggerType


class ChatRequest(BaseModel):
    question: str


class ChatResponse(BaseModel):
    answer: str


class FactsResponse(BaseModel):
    snapshot: dict
    patch: dict  # empty {} unless something changed since the last call


class ReasoningRunRequest(BaseModel):
    trigger_type: TriggerType = "full_pass"


class ReasoningRunResponse(BaseModel):
    plan: dict
    stale: bool
    note: str | None = None


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    supabase: bool
    groq: bool
    groq_backup: bool