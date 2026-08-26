from datetime import datetime
from pydantic import BaseModel


class DeferredPassEntry(BaseModel):

    user_id: str
    attempted_at: datetime
    reason: str  # e.g. "groq_unavailable", "nemotron_shadow_only", "tpm_cap_exceeded"
    retry_at_next_trigger: bool = True