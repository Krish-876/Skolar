from datetime import datetime
from pydantic import BaseModel


class FactsSnapshot(BaseModel):
    snapshot_taken_at: datetime
    user_subject_exams: list[dict]
    capacity_today: list[dict]
    staleness_tracker: list[dict]
    standing_flags: list[dict]
    situation_flags: list[dict]
    nova_history: list[dict]
    career_units: list[dict]
    question_results: list[dict]
    user_topic_weights: list[dict]
    study_plans: list[dict]
    topics: list[dict]

    def row_count(self) -> int:
        return sum(
            len(v) for k, v in self.model_dump().items() if isinstance(v, list)
        )