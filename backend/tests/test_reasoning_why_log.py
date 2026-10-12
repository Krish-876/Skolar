import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.api.routers.reasoning import run_reasoning  # noqa: E402
from nova.api.sessions import UserSession, _STORE  # noqa: E402
from nova.schemas.api import ReasoningRunRequest, StudyPlan  # noqa: E402
from nova.schemas.reasoning_why_log import DeferredPassEntry  # noqa: E402
from nova.services.reasoning_service import ReasoningResult  # noqa: E402


class _FakeTable:
    def __init__(self):
        self.inserted: list[dict] = []
        self.should_raise = False

    def insert(self, payload):
        if self.should_raise:
            raise RuntimeError("DB connection error")
        self.inserted.append(payload)
        return self

    def execute(self):
        return MagicMock(data=self.inserted)


class _FakeSupabase:
    def __init__(self):
        self.tables = {"nova_why_log": _FakeTable()}

    def table(self, name):
        return self.tables[name]


@pytest.fixture(autouse=True)
def _clear_sessions():
    _STORE.clear()
    yield
    _STORE.clear()


def test_run_reasoning_successful_pass_logs_real_columns():
    user_id = "test-user-1"
    fake_supabase = _FakeSupabase()
    clients = (fake_supabase, MagicMock(), None)

    mock_facts_state = MagicMock()
    mock_facts_state.get.return_value = ({"academic_standing": "good"}, {})
    _STORE[user_id] = UserSession(facts_state=mock_facts_state)

    req = ReasoningRunRequest(trigger_type="full_pass")
    mock_plan = StudyPlan(items=[], summary="Focus on DSA")
    mock_result = ReasoningResult(plan=mock_plan, stale=False)

    with patch("nova.api.routers.reasoning.run_reasoning_pass", return_value=mock_result):
        resp = run_reasoning(user_id=user_id, req=req, clients=clients)

    assert resp.stale is False
    assert resp.plan.summary == "Focus on DSA"

    why_log_table = fake_supabase.table("nova_why_log")
    assert len(why_log_table.inserted) == 1
    row = why_log_table.inserted[0]

    # Verify real columns from 20260710040155_add_nova_why_log.sql are present
    assert row["user_id"] == user_id
    assert row["entry_type"] == "full_pass"
    assert row["facts_snapshot"] == {"academic_standing": "good"}
    assert row["plan_output"] == {"items": [], "summary": "Focus on DSA"}
    assert row["reasoning_summary"] == "Focus on DSA"
    assert row["user_subject_id"] is None
    assert row["topic_id"] is None
    assert row["career_unit_id"] is None
    assert row["supersedes_id"] is None

    # Verify invalid columns are NOT present
    for bad_col in ("triggered_by", "snapshot_summary", "reasoning_output", "passed", "failure_reason"):
        assert bad_col not in row


def test_run_reasoning_minor_trigger_maps_entry_type():
    user_id = "test-user-2"
    fake_supabase = _FakeSupabase()
    clients = (fake_supabase, MagicMock(), None)

    mock_facts_state = MagicMock()
    mock_facts_state.get.return_value = ({"academic_standing": "good"}, {})
    _STORE[user_id] = UserSession(facts_state=mock_facts_state)

    req = ReasoningRunRequest(trigger_type="minor_trigger_rerank")
    mock_plan = StudyPlan(items=[], summary="Re-ranked DSA")
    mock_result = ReasoningResult(plan=mock_plan, stale=False)

    with patch("nova.api.routers.reasoning.run_reasoning_pass", return_value=mock_result):
        run_reasoning(user_id=user_id, req=req, clients=clients)

    row = fake_supabase.table("nova_why_log").inserted[0]
    assert row["entry_type"] == "minor_trigger"


def test_run_reasoning_deferred_pass_logs_real_columns():
    user_id = "test-user-3"
    fake_supabase = _FakeSupabase()
    clients = (fake_supabase, MagicMock(), None)

    mock_facts_state = MagicMock()
    mock_facts_state.get.return_value = ({"facts": 123}, {})
    _STORE[user_id] = UserSession(facts_state=mock_facts_state)

    req = ReasoningRunRequest(trigger_type="full_pass")

    def mock_run_with_failure(*_args, **kwargs):
        log_deferred = kwargs.get("log_deferred_pass")
        if log_deferred:
            log_deferred(DeferredPassEntry(user_id=user_id, attempted_at=MagicMock(), reason="groq_unavailable"))
        return ReasoningResult(plan=StudyPlan(items=[], summary="Stale plan"), stale=True)

    with patch("nova.api.routers.reasoning.run_reasoning_pass", side_effect=mock_run_with_failure):
        resp = run_reasoning(user_id=user_id, req=req, clients=clients)

    assert resp.stale is True

    why_log_table = fake_supabase.table("nova_why_log")
    assert len(why_log_table.inserted) == 1
    row = why_log_table.inserted[0]

    assert row["user_id"] == user_id
    assert row["entry_type"] == "full_pass"
    # full_pass needs snapshot not null per CHECK constraint
    assert row["facts_snapshot"] is not None
    assert row["plan_output"] is None
    assert "groq_unavailable" in row["reasoning_summary"]
    assert row["user_subject_id"] is None
    assert row["topic_id"] is None
    assert row["career_unit_id"] is None


def test_run_reasoning_why_log_failure_does_not_fail_request(caplog):
    user_id = "test-user-4"
    fake_supabase = _FakeSupabase()
    fake_supabase.table("nova_why_log").should_raise = True
    clients = (fake_supabase, MagicMock(), None)

    mock_facts_state = MagicMock()
    mock_facts_state.get.return_value = ({"facts": 123}, {})
    _STORE[user_id] = UserSession(facts_state=mock_facts_state)

    req = ReasoningRunRequest(trigger_type="full_pass")
    mock_plan = StudyPlan(items=[], summary="Plan despite log error")
    mock_result = ReasoningResult(plan=mock_plan, stale=False)

    with patch("nova.api.routers.reasoning.run_reasoning_pass", return_value=mock_result):
        resp = run_reasoning(user_id=user_id, req=req, clients=clients)

    # Request succeeds (does not raise 500)
    assert resp.plan.summary == "Plan despite log error"
    # And error was logged
    assert any("Failed to log successful pass to nova_why_log" in record.message for record in caplog.records)
