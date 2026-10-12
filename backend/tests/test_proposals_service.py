import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.schemas.proposals import RawProposedFact  # noqa: E402
from nova.services.proposals_service import (  # noqa: E402
    confirm_proposal,
    confirm_turn,
    create_proposals,
    get_pending_proposals,
    reject_proposal,
    reject_turn,
)


class _FakeResult:
    def __init__(self, data: list[dict[str, Any]]):
        self.data = data


class _NotHelper:
    def __init__(self, query: "_FakeQuery"):
        self._query = query

    def is_(self, col: str, val: Any) -> "_FakeQuery":
        if val == "null" or val is None:
            self._query.rows = [r for r in self._query.rows if r.get(col) is not None]
        else:
            self._query.rows = [r for r in self._query.rows if r.get(col) != val]
        return self._query


class _FakeQuery:
    def __init__(self, table: "_FakeTable", rows: list[dict[str, Any]], update_payload: dict[str, Any] | None = None):
        self.table = table
        self.rows = rows
        self.update_payload = update_payload
        self.not_ = _NotHelper(self)

    def select(self, *_args: Any, **_kwargs: Any) -> "_FakeQuery":
        return self

    def eq(self, col: str, val: Any) -> "_FakeQuery":
        self.rows = [r for r in self.rows if r.get(col) == val]
        return self

    def is_(self, col: str, val: Any) -> "_FakeQuery":
        if val == "null" or val is None:
            self.rows = [r for r in self.rows if r.get(col) is None]
        else:
            self.rows = [r for r in self.rows if r.get(col) == val]
        return self

    def order(self, col: str, desc: bool = False) -> "_FakeQuery":
        def sort_key(r: dict[str, Any]) -> Any:
            v = r.get(col)
            return ("" if v is None else str(v))

        self.rows.sort(key=sort_key, reverse=desc)
        return self

    def limit(self, count: int) -> "_FakeQuery":
        self.rows = self.rows[:count]
        return self

    def execute(self) -> _FakeResult:
        if self.update_payload is not None:
            for r in self.rows:
                r.update(self.update_payload)
            return _FakeResult(self.rows)
        return _FakeResult(self.rows)


class _FakeTable:
    def __init__(self) -> None:
        self.rows: list[dict[str, Any]] = []

    def select(self, *_args: Any, **_kwargs: Any) -> _FakeQuery:
        return _FakeQuery(self, self.rows.copy())

    def insert(self, payload: dict[str, Any]) -> _FakeQuery:
        row = dict(payload)
        if "id" not in row:
            row["id"] = str(uuid.uuid4())
        if "created_at" not in row:
            row["created_at"] = datetime.now(timezone.utc).isoformat()
        if "status" not in row:
            row["status"] = "pending"
        self.rows.append(row)
        return _FakeQuery(self, [row])

    def update(self, payload: dict[str, Any]) -> _FakeQuery:
        return _FakeQuery(self, self.rows, update_payload=dict(payload))


class _FakeSupabase:
    def __init__(self) -> None:
        self._tables: dict[str, _FakeTable] = {
            "nova_unconfirmed_proposals": _FakeTable(),
            "standing_flags": _FakeTable(),
            "situation_flags": _FakeTable(),
            "nova_history": _FakeTable(),
            "career_units": _FakeTable(),
        }

    def table(self, name: str) -> _FakeTable:
        if name not in self._tables:
            self._tables[name] = _FakeTable()
        return self._tables[name]


@pytest.fixture
def fake_supabase() -> _FakeSupabase:
    return _FakeSupabase()


@pytest.fixture
def dummy_snapshot() -> dict[str, Any]:
    return {
        "user_subjects": [
            {
                "id": "subj-cs-1",
                "subjects": {"name": "Computer Networks", "short_name": "CN"},
            }
        ],
        "career_units": [
            {
                "id": "cu-quant-1",
                "name": "Quant Trading",
            }
        ],
    }


def test_stage_proposals(fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]) -> None:
    user_id = "user-test"
    turn_id = "turn-1"
    facts = [
        RawProposedFact(kind="standing_flag", text="Always explain derivations", target_subject_name="CN"),
        RawProposedFact(kind="situation_flag", text="Exams starting Monday"),
        RawProposedFact(kind="career_unit", text="Robotics Engineer", description="Hardware and control"),
    ]

    summaries = create_proposals(fake_supabase, user_id, turn_id, facts, dummy_snapshot)  # type: ignore[arg-type]
    assert len(summaries) == 3

    pending = get_pending_proposals(fake_supabase, user_id)  # type: ignore[arg-type]
    assert len(pending) == 3

    # Staging only: destination tables must remain empty
    assert len(fake_supabase.table("standing_flags").rows) == 0
    assert len(fake_supabase.table("situation_flags").rows) == 0
    assert len(fake_supabase.table("career_units").rows) == 0


def test_confirm_situation_flag_drops_source_column(
    fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]
) -> None:
    user_id = "user-test"
    turn_id = "turn-sf"
    facts = [RawProposedFact(kind="situation_flag", text="Recovering from flu")]

    summaries = create_proposals(fake_supabase, user_id, turn_id, facts, dummy_snapshot)  # type: ignore[arg-type]
    pid = summaries[0].id

    res = confirm_proposal(fake_supabase, user_id, pid)  # type: ignore[arg-type]
    assert res.status == "confirmed"

    sf_rows = fake_supabase.table("situation_flags").rows
    assert len(sf_rows) == 1
    sf_row = sf_rows[0]
    assert sf_row["id"] == res.resulting_row_id
    assert sf_row["flag_text"] == "Recovering from flu"
    # CRITICAL: situation_flags schema does NOT have source column
    assert "source" not in sf_row


def test_confirm_and_supersede_all_four_kinds(
    fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]
) -> None:
    user_id = "user-test"

    # 1. standing_flag
    now = datetime.now(timezone.utc).isoformat()
    old_sf = fake_supabase.table("standing_flags").insert({
        "user_id": user_id,
        "user_subject_id": None,
        "career_unit_id": None,
        "instruction_text": "Prefer bullet points",
        "confirmed_at": now,
        "superseded_at": None,
        "source": "conversation",
    }).execute().data[0]

    p1 = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t1",
        [RawProposedFact(kind="standing_flag", text="Prefer detailed paragraphs")],
        dummy_snapshot,
    )[0]
    res1 = confirm_proposal(fake_supabase, user_id, p1.id)  # type: ignore[arg-type]

    new_sf = [r for r in fake_supabase.table("standing_flags").rows if r["id"] == res1.resulting_row_id][0]
    assert new_sf["source"] == "conversation"
    assert new_sf["supersedes_id"] == old_sf["id"]
    assert old_sf["superseded_at"] is not None

    # 2. situation_flag
    old_sit = fake_supabase.table("situation_flags").insert({
        "user_id": user_id,
        "user_subject_id": None,
        "career_unit_id": None,
        "flag_text": "Mild headache",
        "confirmed_at": now,
        "superseded_at": None,
    }).execute().data[0]

    p2 = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t2",
        [RawProposedFact(kind="situation_flag", text="Severe migraine")],
        dummy_snapshot,
    )[0]
    res2 = confirm_proposal(fake_supabase, user_id, p2.id)  # type: ignore[arg-type]

    new_sit = [r for r in fake_supabase.table("situation_flags").rows if r["id"] == res2.resulting_row_id][0]
    assert "source" not in new_sit
    assert new_sit["supersedes_id"] == old_sit["id"]
    assert old_sit["superseded_at"] is not None

    # 3. nova_history
    old_hist = fake_supabase.table("nova_history").insert({
        "user_id": user_id,
        "user_subject_id": None,
        "career_unit_id": None,
        "content": "Flashcards worked well for Organic Chem",
        "confirmed_at": now,
        "superseded_at": None,
        "source": "conversation",
    }).execute().data[0]

    p3 = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t3",
        [RawProposedFact(kind="nova_history", text="Mind maps worked better for Organic Chem")],
        dummy_snapshot,
    )[0]
    res3 = confirm_proposal(fake_supabase, user_id, p3.id)  # type: ignore[arg-type]

    new_hist = [r for r in fake_supabase.table("nova_history").rows if r["id"] == res3.resulting_row_id][0]
    assert new_hist["source"] == "conversation"
    assert new_hist["supersedes_id"] == old_hist["id"]
    assert old_hist["superseded_at"] is not None

    # 4. career_unit (new unit created with source="conversation")
    p4 = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t4",
        [RawProposedFact(kind="career_unit", text="Data Scientist")],
        dummy_snapshot,
    )[0]
    res4 = confirm_proposal(fake_supabase, user_id, p4.id)  # type: ignore[arg-type]
    cu_rows = [r for r in fake_supabase.table("career_units").rows if r["id"] == res4.resulting_row_id]
    assert len(cu_rows) == 1
    assert cu_rows[0]["source"] == "conversation"


def test_career_unit_unpause_by_name(fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]) -> None:
    user_id = "user-test"
    paused_time = "2026-01-01T00:00:00Z"
    existing_cu = fake_supabase.table("career_units").insert({
        "user_id": user_id,
        "name": "Machine Learning Engineer",
        "description": "Old description",
        "paused_at": paused_time,
        "confirmed_at": paused_time,
        "source": "conversation",
    }).execute().data[0]

    # New proposal with whitespace and different casing
    p = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t-unpause",
        [RawProposedFact(kind="career_unit", text="  machine learning engineer  ", description="New description")],
        dummy_snapshot,
    )[0]

    res = confirm_proposal(fake_supabase, user_id, p.id)  # type: ignore[arg-type]
    assert res.resulting_row_id == existing_cu["id"]

    # Verify no duplicate row was created
    all_cus = fake_supabase.table("career_units").rows
    assert len(all_cus) == 1
    # Verify unpaused
    assert all_cus[0]["paused_at"] is None
    assert all_cus[0]["description"] == "New description"


def test_reject_proposal(fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]) -> None:
    user_id = "user-test"
    p = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "t-rej",
        [RawProposedFact(kind="standing_flag", text="Unwanted advice")],
        dummy_snapshot,
    )[0]

    res = reject_proposal(fake_supabase, user_id, p.id)  # type: ignore[arg-type]
    assert res.status == "rejected"

    prop_row = fake_supabase.table("nova_unconfirmed_proposals").rows[0]
    assert prop_row["status"] == "rejected"
    assert prop_row.get("resulting_row_id") is None
    assert len(fake_supabase.table("standing_flags").rows) == 0


def test_turn_batch_confirm_and_reject(
    fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]
) -> None:
    user_id = "user-test"
    turn_id = "turn-batch"
    facts = [
        RawProposedFact(kind="standing_flag", text="Note 1"),
        RawProposedFact(kind="situation_flag", text="Note 2"),
    ]
    create_proposals(fake_supabase, user_id, turn_id, facts, dummy_snapshot)  # type: ignore[arg-type]

    results = confirm_turn(fake_supabase, user_id, turn_id)  # type: ignore[arg-type]
    assert len(results) == 2
    assert all(r.status == "confirmed" for r in results)

    # Batch reject on a second turn
    turn_2 = "turn-batch-2"
    create_proposals(fake_supabase, user_id, turn_2, facts, dummy_snapshot)  # type: ignore[arg-type]
    rej_results = reject_turn(fake_supabase, user_id, turn_2)  # type: ignore[arg-type]
    assert len(rej_results) == 2
    assert all(r.status == "rejected" for r in rej_results)


def test_supersession_scoped_to_table_and_units(
    fake_supabase: _FakeSupabase, dummy_snapshot: dict[str, Any]
) -> None:
    user_id = "user-test"
    now = datetime.now(timezone.utc).isoformat()

    # Scope 1: standing_flags for Subject A
    row_subj_a = fake_supabase.table("standing_flags").insert({
        "user_id": user_id,
        "user_subject_id": "subj-cs-1",
        "career_unit_id": None,
        "instruction_text": "Networks old rule",
        "confirmed_at": now,
        "superseded_at": None,
        "source": "conversation",
    }).execute().data[0]

    # Scope 2: standing_flags for Subject B
    row_subj_b = fake_supabase.table("standing_flags").insert({
        "user_id": user_id,
        "user_subject_id": "subj-diff",
        "career_unit_id": None,
        "instruction_text": "Different subject rule",
        "confirmed_at": now,
        "superseded_at": None,
        "source": "conversation",
    }).execute().data[0]

    # Scope 3: standing_flags global (user-level)
    row_global = fake_supabase.table("standing_flags").insert({
        "user_id": user_id,
        "user_subject_id": None,
        "career_unit_id": None,
        "instruction_text": "Global rule",
        "confirmed_at": now,
        "superseded_at": None,
        "source": "conversation",
    }).execute().data[0]

    # Scope 4: situation_flags for Subject A (different table)
    row_sit = fake_supabase.table("situation_flags").insert({
        "user_id": user_id,
        "user_subject_id": "subj-cs-1",
        "career_unit_id": None,
        "flag_text": "Networks situation",
        "confirmed_at": now,
        "superseded_at": None,
    }).execute().data[0]

    # Propose new standing flag for Subject A ("CN" resolves to "subj-cs-1")
    p = create_proposals(
        fake_supabase,  # type: ignore[arg-type]
        user_id,
        "turn-scope",
        [RawProposedFact(kind="standing_flag", text="Networks NEW rule", target_subject_name="CN")],
        dummy_snapshot,
    )[0]

    res = confirm_proposal(fake_supabase, user_id, p.id)  # type: ignore[arg-type]

    new_row = [r for r in fake_supabase.table("standing_flags").rows if r["id"] == res.resulting_row_id][0]
    # Only row_subj_a should be superseded
    assert new_row["supersedes_id"] == row_subj_a["id"]
    assert row_subj_a["superseded_at"] is not None

    # Other scopes must NOT be touched
    assert row_subj_b["superseded_at"] is None
    assert row_global["superseded_at"] is None
    assert row_sit["superseded_at"] is None
