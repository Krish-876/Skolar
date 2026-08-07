"""
Tracks which parts of a student's FactsSnapshot have gone stale since it was
last built, via Realtime table-change events. Nova refetches only the
tables flagged dirty and patches them into the cached snapshot - never a
full re-pull unless nothing has been fetched yet.
"""

from threading import Lock

from nova.schemas.facts_snapshot import FactsSnapshot
from nova.services import facts_service as fs

# maps table name (as it appears in a Realtime payload) -> snapshot field(s)
# it feeds, and the single-table fetcher to call for a targeted refresh.
_TABLE_TO_FIELDS = {
    "user_subject_exams": ["user_subject_exams"],
    "nova_capacity_log": ["capacity_today"],
    "staleness_tracker": ["staleness_tracker"],
    "standing_flags": ["standing_flags"],
    "situation_flags": ["situation_flags"],
    "nova_history": ["nova_history"],
    "career_units": ["career_units"],
    "question_results": ["question_results"],
    "user_topic_weights": ["user_topic_weights"],
    "study_plans": ["study_plans"],
    "users": ["full_name", "academic_year", "branch", "current_semester"],
}


class FactsState:
    """Holds the last-built snapshot plus a set of dirty table names.
    Thread-safe since the Realtime callback fires on its own thread."""

    def __init__(self, supabase, user_id: str):
        self._supabase = supabase
        self._user_id = user_id
        self._lock = Lock()
        self._snapshot: FactsSnapshot | None = None
        self._dirty: set[str] = set()

    def mark_dirty(self, table: str) -> None:
        if table not in _TABLE_TO_FIELDS:
            return  # change on a table we don't surface to Nova - ignore
        with self._lock:
            self._dirty.add(table)

    def get(self) -> FactsSnapshot:
        """Returns an up-to-date snapshot. First call does a full fetch;
        later calls patch in only the tables that changed since."""
        with self._lock:
            if self._snapshot is None:
                self._snapshot = fs.get_facts_snapshot(self._supabase, self._user_id)
                self._dirty.clear()
                return self._snapshot

            if not self._dirty:
                return self._snapshot

            pending, self._dirty = self._dirty, set()

        patch = fs.fetch_partial(self._supabase, self._user_id, pending, _TABLE_TO_FIELDS)
        with self._lock:
            self._snapshot = self._snapshot.model_copy(update=patch)
            return self._snapshot