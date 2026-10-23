"""
Unit tests for nova.services.tasks_service.

All tests use a fake Supabase client (no live DB required).  The fake client
follows the same pattern established in test_proposals_service.py.

Coverage:
- create_weekly_tasks: inserts correct rows, raises on empty input,
  raises on out-of-range timer_seconds.
- replan_weekly_tasks: updates non-done tasks, never touches done tasks,
  drops omitted pending tasks, raises on empty input.
- reschedule_missed_tasks: rolls forward tasks still in the current week,
  marks as missed tasks from a past week.
- update_task_timer: writes nova_why_log (one_off_override, facts_snapshot
  None), updates task row, raises on bad timer, raises on unknown task.
"""

import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from nova.services.tasks_service import (  # noqa: E402
    _read_focus_min_seconds,
    create_weekly_tasks,
    replan_weekly_tasks,
    reschedule_missed_tasks,
    update_task_timer,
)


# ---------------------------------------------------------------------------
# Minimal fake Supabase client
# (mirrors the pattern from test_proposals_service.py but richer to support
# .lt(), .neq(), .in_() and .is_() needed by tasks_service)
# ---------------------------------------------------------------------------


class _FakeResult:
    def __init__(self, data: list[dict[str, Any]]):
        self.data = data


class _FakeQuery:
    def __init__(
        self,
        table: "_FakeTable",
        rows: list[dict[str, Any]],
        update_payload: dict[str, Any] | None = None,
    ):
        self.table = table
        self.rows = list(rows)
        self.update_payload = update_payload

    def select(self, *_a: Any, **_kw: Any) -> "_FakeQuery":
        return self

    def eq(self, col: str, val: Any) -> "_FakeQuery":
        self.rows = [r for r in self.rows if r.get(col) == val]
        return self

    def neq(self, col: str, val: Any) -> "_FakeQuery":
        self.rows = [r for r in self.rows if r.get(col) != val]
        return self

    def lt(self, col: str, val: Any) -> "_FakeQuery":
        self.rows = [r for r in self.rows if str(r.get(col, "")) < str(val)]
        return self

    def is_(self, col: str, val: Any) -> "_FakeQuery":
        if val in ("null", None):
            self.rows = [r for r in self.rows if r.get(col) is None]
        else:
            self.rows = [r for r in self.rows if r.get(col) == val]
        return self

    def in_(self, col: str, values: list) -> "_FakeQuery":
        self.rows = [r for r in self.rows if r.get(col) in values]
        return self

    def limit(self, n: int) -> "_FakeQuery":
        self.rows = self.rows[:n]
        return self

    def order(self, *_a: Any, **_kw: Any) -> "_FakeQuery":
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

    def select(self, *_a: Any, **_kw: Any) -> _FakeQuery:
        return _FakeQuery(self, self.rows.copy())

    def insert(self, payload: Any) -> _FakeQuery:
        if isinstance(payload, list):
            inserted: list[dict[str, Any]] = []
            for p in payload:
                row = dict(p)
                if "id" not in row:
                    row["id"] = str(uuid.uuid4())
                row.setdefault("created_at", datetime.now(timezone.utc).isoformat())
                row.setdefault("updated_at", datetime.now(timezone.utc).isoformat())
                self.rows.append(row)
                inserted.append(row)
            return _FakeQuery(self, inserted)
        else:
            row = dict(payload)
            if "id" not in row:
                row["id"] = str(uuid.uuid4())
            row.setdefault("created_at", datetime.now(timezone.utc).isoformat())
            row.setdefault("updated_at", datetime.now(timezone.utc).isoformat())
            self.rows.append(row)
            return _FakeQuery(self, [row])

    def update(self, payload: dict[str, Any]) -> _FakeQuery:
        return _FakeQuery(self, self.rows, update_payload=dict(payload))


class _FakeSupabase:
    def __init__(self) -> None:
        self._tables: dict[str, _FakeTable] = {}

    def table(self, name: str) -> _FakeTable:
        if name not in self._tables:
            self._tables[name] = _FakeTable()
        return self._tables[name]

    def seed_nova_config(self, key: str, value: Any) -> None:
        """Helper to pre-load a nova_config row."""
        self.table("nova_config").rows.append(
            {"id": str(uuid.uuid4()), "user_id": None, "key": key, "value": value}
        )


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

USER_A = "user-aaa"
WEEK_START = "2026-10-04"   # Sunday
WHY_LOG_ID = str(uuid.uuid4())


def _make_task(
    *,
    user_id: str = USER_A,
    week_start: str = WEEK_START,
    planned_for: str = "2026-10-05",
    topic: str = "Mathematics",
    title: str = "Solve integrals",
    timer_seconds: int = 1500,
    priority: int = 1,
    reason: str = "High priority",
    user_subject_id: str | None = None,
) -> dict[str, Any]:
    return {
        "topic": topic,
        "title": title,
        "planned_for": planned_for,
        "timer_seconds": timer_seconds,
        "priority": priority,
        "reason": reason,
        "user_subject_id": user_subject_id,
    }


@pytest.fixture
def fake_db() -> _FakeSupabase:
    db = _FakeSupabase()
    db.seed_nova_config("focus_min_duration_seconds", 60)
    return db


# ---------------------------------------------------------------------------
# create_weekly_tasks
# ---------------------------------------------------------------------------


class TestCreateWeeklyTasks:
    def test_inserts_correct_rows(self, fake_db: _FakeSupabase) -> None:
        tasks = [_make_task(), _make_task(priority=2, title="Read chapter")]
        result = create_weekly_tasks(fake_db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]

        assert len(result) == 2
        task_table = fake_db.table("tasks")
        assert len(task_table.rows) == 2

        for row in task_table.rows:
            assert row["user_id"] == USER_A
            assert row["week_start"] == WEEK_START
            assert row["status"] == "pending"
            assert row["reschedule_count"] == 0
            assert row["why_log_id"] == WHY_LOG_ID

        titles = {r["title"] for r in task_table.rows}
        assert titles == {"Solve integrals", "Read chapter"}

    def test_raises_on_empty_input(self, fake_db: _FakeSupabase) -> None:
        with pytest.raises(ValueError, match="non-empty"):
            create_weekly_tasks(fake_db, USER_A, WEEK_START, [], WHY_LOG_ID)  # type: ignore[arg-type]

    def test_raises_on_timer_too_low(self, fake_db: _FakeSupabase) -> None:
        tasks = [_make_task(timer_seconds=30)]
        with pytest.raises(ValueError, match="minimum"):
            create_weekly_tasks(fake_db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]

    def test_raises_on_timer_too_high(self, fake_db: _FakeSupabase) -> None:
        tasks = [_make_task(timer_seconds=86401)]
        with pytest.raises(ValueError, match="maximum"):
            create_weekly_tasks(fake_db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]

    def test_minimum_timer_boundary(self, fake_db: _FakeSupabase) -> None:
        """Exactly at the minimum (60s) must succeed."""
        tasks = [_make_task(timer_seconds=60)]
        result = create_weekly_tasks(fake_db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]
        assert len(result) == 1

    def test_maximum_timer_boundary(self, fake_db: _FakeSupabase) -> None:
        """Exactly at the maximum (86400s) must succeed."""
        tasks = [_make_task(timer_seconds=86400)]
        result = create_weekly_tasks(fake_db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]
        assert len(result) == 1

    def test_raises_on_missing_key_before_any_write(self, fake_db: _FakeSupabase) -> None:
        bad = _make_task()
        del bad["title"]
        with pytest.raises(ValueError, match="title"):
            create_weekly_tasks(fake_db, USER_A, WEEK_START, [_make_task(), bad], WHY_LOG_ID)  # type: ignore[arg-type]
        assert fake_db.table("tasks").rows == []

    def test_nova_config_min_respected(self) -> None:
        """If nova_config sets a higher minimum (e.g. 300s), lower values fail."""
        db = _FakeSupabase()
        db.seed_nova_config("focus_min_duration_seconds", 300)
        tasks = [_make_task(timer_seconds=120)]  # below 300
        with pytest.raises(ValueError, match="minimum"):
            create_weekly_tasks(db, USER_A, WEEK_START, tasks, WHY_LOG_ID)  # type: ignore[arg-type]


class TestReadFocusMinSeconds:
    @pytest.mark.parametrize("value", [True, False, "300", None])
    def test_non_numeric_or_bool_falls_back_to_60(self, value: Any) -> None:
        db = _FakeSupabase()
        db.seed_nova_config("focus_min_duration_seconds", value)
        assert _read_focus_min_seconds(db) == 60  # type: ignore[arg-type]

    @pytest.mark.parametrize("value", [0, -5, 30])
    def test_below_floor_clamped_to_60(self, value: int) -> None:
        db = _FakeSupabase()
        db.seed_nova_config("focus_min_duration_seconds", value)
        assert _read_focus_min_seconds(db) == 60  # type: ignore[arg-type]

    def test_above_floor_kept(self) -> None:
        db = _FakeSupabase()
        db.seed_nova_config("focus_min_duration_seconds", 300)
        assert _read_focus_min_seconds(db) == 300  # type: ignore[arg-type]


# ---------------------------------------------------------------------------
# replan_weekly_tasks
# ---------------------------------------------------------------------------


def _seed_task(
    db: _FakeSupabase,
    *,
    user_id: str = USER_A,
    week_start: str = WEEK_START,
    status: str = "pending",
    title: str = "Old task",
) -> str:
    """Seed a task row directly into the fake DB and return its ID."""
    task_id = str(uuid.uuid4())
    db.table("tasks").rows.append(
        {
            "id": task_id,
            "user_id": user_id,
            "week_start": week_start,
            "planned_for": "2026-10-05",
            "topic": "Math",
            "title": title,
            "timer_seconds": 1500,
            "priority": 1,
            "reason": "seeded",
            "status": status,
            "reschedule_count": 0,
            "why_log_id": None,
            "completed_at": "2026-10-05T10:00:00Z" if status == "done" else None,
        }
    )
    return task_id


class TestReplanWeeklyTasks:
    def test_raises_on_empty_plan(self, fake_db: _FakeSupabase) -> None:
        with pytest.raises(ValueError, match="empty or None"):
            replan_weekly_tasks(fake_db, USER_A, WEEK_START, [], WHY_LOG_ID)  # type: ignore[arg-type]

    def test_raises_on_none_plan(self, fake_db: _FakeSupabase) -> None:
        with pytest.raises(ValueError, match="empty or None"):
            replan_weekly_tasks(fake_db, USER_A, WEEK_START, None, WHY_LOG_ID)  # type: ignore[arg-type]

    def test_updates_existing_pending_task(self, fake_db: _FakeSupabase) -> None:
        task_id = _seed_task(fake_db, title="Old title")
        new_plan = [_make_task(title="New title") | {"id": task_id}]
        result = replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        task_table = fake_db.table("tasks")
        row = next(r for r in task_table.rows if r["id"] == task_id)
        assert row["title"] == "New title"
        assert len(result["dropped"]) == 0

    def test_never_touches_done_tasks(self, fake_db: _FakeSupabase) -> None:
        done_id = _seed_task(fake_db, status="done", title="Completed task")
        # Attempt to overwrite the done task via replan (with its id in the plan)
        new_plan = [_make_task(title="Overwrite attempt") | {"id": done_id}]
        replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        task_table = fake_db.table("tasks")
        row = next(r for r in task_table.rows if r["id"] == done_id)
        # Done task must be completely unchanged
        assert row["status"] == "done"
        assert row["title"] == "Completed task"
        # ...and no duplicate pending row may be created from the skipped entry.
        assert len(task_table.rows) == 1

    def test_bad_timer_midway_leaves_db_unchanged(self, fake_db: _FakeSupabase) -> None:
        kept_id = _seed_task(fake_db, title="Original")
        omitted_id = _seed_task(fake_db, title="Omitted")
        before = [dict(r) for r in fake_db.table("tasks").rows]

        new_plan = [
            _make_task(title="Would update") | {"id": kept_id},
            _make_task(title="Bad timer", timer_seconds=5),
            _make_task(title="Would insert"),
        ]
        with pytest.raises(ValueError, match="minimum"):
            replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        assert fake_db.table("tasks").rows == before
        assert omitted_id in {r["id"] for r in fake_db.table("tasks").rows}

    def test_missing_required_key_leaves_db_unchanged(self, fake_db: _FakeSupabase) -> None:
        _seed_task(fake_db)
        before = [dict(r) for r in fake_db.table("tasks").rows]
        bad = _make_task()
        del bad["reason"]
        with pytest.raises(ValueError, match="reason"):
            replan_weekly_tasks(fake_db, USER_A, WEEK_START, [_make_task(), bad], WHY_LOG_ID)  # type: ignore[arg-type]
        assert fake_db.table("tasks").rows == before

    def test_drops_omitted_pending_tasks(self, fake_db: _FakeSupabase) -> None:
        kept_id = _seed_task(fake_db, title="Keep me")
        dropped_id = _seed_task(fake_db, title="Omitted task")

        new_plan = [_make_task(title="Updated Keep") | {"id": kept_id}]
        result = replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        assert dropped_id in result["dropped"]

        task_table = fake_db.table("tasks")
        dropped_row = next(r for r in task_table.rows if r["id"] == dropped_id)
        assert dropped_row["status"] == "dropped"

    def test_drop_skips_rows_no_longer_pending(self, fake_db: _FakeSupabase) -> None:
        """A row completed after the initial read must not be dropped or reported."""
        raced_id = _seed_task(fake_db, title="Completes mid-replan")
        tasks_table = fake_db.table("tasks")
        real_insert = tasks_table.insert

        def insert_then_complete(payload: Any) -> _FakeQuery:
            result = real_insert(payload)
            tasks_table.rows = [
                {**r, "status": "done", "completed_at": "2026-10-05T10:00:00Z"}
                if r["id"] == raced_id
                else r
                for r in tasks_table.rows
            ]
            return result

        tasks_table.insert = insert_then_complete  # type: ignore[method-assign]

        result = replan_weekly_tasks(
            fake_db, USER_A, WEEK_START, [_make_task(title="Fresh")], WHY_LOG_ID  # type: ignore[arg-type]
        )

        assert result["dropped"] == []
        row = next(r for r in tasks_table.rows if r["id"] == raced_id)
        assert row["status"] == "done"

    def test_done_tasks_not_dropped(self, fake_db: _FakeSupabase) -> None:
        """Done tasks must never be marked ``dropped`` even if omitted from the plan."""
        done_id = _seed_task(fake_db, status="done")
        # New plan that does NOT reference the done task
        new_plan = [_make_task(title="Brand new")]
        result = replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        assert done_id not in result["dropped"]
        task_table = fake_db.table("tasks")
        done_row = next(r for r in task_table.rows if r["id"] == done_id)
        assert done_row["status"] == "done"

    def test_creates_new_task_without_id(self, fake_db: _FakeSupabase) -> None:
        """Tasks in the plan without an id must be inserted as new rows."""
        new_plan = [_make_task(title="Fresh task")]
        result = replan_weekly_tasks(fake_db, USER_A, WEEK_START, new_plan, WHY_LOG_ID)  # type: ignore[arg-type]

        assert len(result["upserted"]) == 1
        assert fake_db.table("tasks").rows[0]["title"] == "Fresh task"


# ---------------------------------------------------------------------------
# reschedule_missed_tasks
# ---------------------------------------------------------------------------


class TestRescheduleMissedTasks:
    # For these tests, week_start_day=7 (Sunday), as_of=2026-10-07 (Wed)
    # Current week: Sun 2026-10-04 to Sat 2026-10-10
    AS_OF = "2026-10-07"
    WEEK_START_DAY = 7  # Sunday
    CURRENT_WEEK_START = "2026-10-04"
    PAST_WEEK_START = "2026-09-27"  # previous Sunday-start week

    def _seed_pending(
        self,
        db: _FakeSupabase,
        *,
        week_start: str,
        planned_for: str,
    ) -> str:
        task_id = str(uuid.uuid4())
        db.table("tasks").rows.append(
            {
                "id": task_id,
                "user_id": USER_A,
                "week_start": week_start,
                "planned_for": planned_for,
                "topic": "Math",
                "title": "Pending task",
                "timer_seconds": 1500,
                "priority": 1,
                "reason": "seeded",
                "status": "pending",
                "reschedule_count": 0,
                "why_log_id": None,
            }
        )
        return task_id

    def test_rolls_forward_current_week_task(self, fake_db: _FakeSupabase) -> None:
        """planned_for < as_of but week_start == current week -> roll forward."""
        task_id = self._seed_pending(
            fake_db,
            week_start=self.CURRENT_WEEK_START,
            planned_for="2026-10-05",  # Monday, before Wednesday as_of
        )
        result = reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )

        assert task_id in result["rolled_forward"]
        assert task_id not in result["marked_missed"]

        row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert row["status"] == "pending"
        assert row["planned_for"] == self.AS_OF
        assert row["reschedule_count"] == 1

    def test_marks_missed_past_week_task(self, fake_db: _FakeSupabase) -> None:
        """week_start belongs to a previous week -> mark missed."""
        task_id = self._seed_pending(
            fake_db,
            week_start=self.PAST_WEEK_START,
            planned_for="2026-10-01",  # Thursday last week
        )
        result = reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )

        assert task_id in result["marked_missed"]
        assert task_id not in result["rolled_forward"]

        row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert row["status"] == "missed"

    def test_not_overdue_tasks_untouched(self, fake_db: _FakeSupabase) -> None:
        """Tasks with planned_for >= as_of must not be touched."""
        task_id = self._seed_pending(
            fake_db,
            week_start=self.CURRENT_WEEK_START,
            planned_for="2026-10-08",  # Thursday, after Wednesday as_of
        )
        result = reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )

        assert task_id not in result["rolled_forward"]
        assert task_id not in result["marked_missed"]

        row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert row["status"] == "pending"
        assert row["planned_for"] == "2026-10-08"

    def test_reschedule_count_increments(self, fake_db: _FakeSupabase) -> None:
        """Existing reschedule_count should be incremented by 1 per roll."""
        task_id = self._seed_pending(
            fake_db,
            week_start=self.CURRENT_WEEK_START,
            planned_for="2026-10-05",
        )
        # Manually set reschedule_count to 2
        row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        row["reschedule_count"] = 2

        reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )

        updated_row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert updated_row["reschedule_count"] == 3

    def test_roll_forward_and_missed_respect_user_and_status(self, fake_db: _FakeSupabase) -> None:
        """Updates are scoped by user_id and status, not just id."""
        own_id = self._seed_pending(
            fake_db, week_start=self.PAST_WEEK_START, planned_for="2026-10-01"
        )
        tasks_table = fake_db.table("tasks")
        real_update = tasks_table.update

        def update_after_complete(payload: dict[str, Any]) -> _FakeQuery:
            # Simulate the task being completed after the overdue select.
            tasks_table.rows = [{**r, "status": "done"} for r in tasks_table.rows]
            return real_update(payload)

        tasks_table.update = update_after_complete  # type: ignore[method-assign]
        reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )
        row = next(r for r in tasks_table.rows if r["id"] == own_id)
        assert row["status"] == "done"

    def test_empty_when_no_overdue_tasks(self, fake_db: _FakeSupabase) -> None:
        result = reschedule_missed_tasks(
            fake_db, USER_A, self.AS_OF, self.WEEK_START_DAY, WHY_LOG_ID  # type: ignore[arg-type]
        )
        assert result == {"rolled_forward": [], "marked_missed": []}


# ---------------------------------------------------------------------------
# update_task_timer
# ---------------------------------------------------------------------------


class TestUpdateTaskTimer:
    def _seed_task(self, db: _FakeSupabase, status: str = "pending") -> str:
        task_id = str(uuid.uuid4())
        db.table("tasks").rows.append(
            {
                "id": task_id,
                "user_id": USER_A,
                "week_start": WEEK_START,
                "planned_for": "2026-10-05",
                "topic": "Math",
                "title": "Study task",
                "timer_seconds": 1500,
                "priority": 1,
                "reason": "seeded",
                "status": status,
                "reschedule_count": 0,
                "why_log_id": None,
            }
        )
        return task_id

    @pytest.mark.parametrize("status", ["done", "missed", "dropped"])
    def test_raises_on_non_pending_task(self, fake_db: _FakeSupabase, status: str) -> None:
        task_id = self._seed_task(fake_db, status=status)
        with pytest.raises(ValueError, match="only pending"):
            update_task_timer(fake_db, USER_A, task_id, 1800, "reason")  # type: ignore[arg-type]
        task_row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert task_row["timer_seconds"] == 1500
        assert len(fake_db.table("nova_why_log").rows) == 0

    def test_writes_why_log_entry(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        result = update_task_timer(  # type: ignore[arg-type]
            fake_db, USER_A, task_id, 1800, "I need more time"
        )

        why_log_rows = fake_db.table("nova_why_log").rows
        assert len(why_log_rows) == 1
        log_row = why_log_rows[0]

        assert log_row["user_id"] == USER_A
        assert log_row["entry_type"] == "one_off_override"
        assert log_row["facts_snapshot"] is None  # constraint allows None for non-full_pass
        assert "Student requested timer change" in log_row["reasoning_summary"]
        assert "I need more time" in log_row["reasoning_summary"]
        assert result["why_log_id"] == log_row["id"]

    def test_raises_if_task_completed_between_check_and_update(
        self, fake_db: _FakeSupabase
    ) -> None:
        task_id = self._seed_task(fake_db)
        why_table = fake_db.table("nova_why_log")
        real_insert = why_table.insert

        def insert_then_complete(payload: Any) -> _FakeQuery:
            for r in fake_db.table("tasks").rows:
                r["status"] = "done"
            return real_insert(payload)

        why_table.insert = insert_then_complete  # type: ignore[method-assign]

        with pytest.raises(ValueError, match="changed state"):
            update_task_timer(fake_db, USER_A, task_id, 1800, "reason")  # type: ignore[arg-type]
        task_row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert task_row["timer_seconds"] == 1500

    def test_returns_updated_row(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        result = update_task_timer(fake_db, USER_A, task_id, 1800, "reason")  # type: ignore[arg-type]
        assert result["updated_task"]["id"] == task_id
        assert result["updated_task"]["timer_seconds"] == 1800

    def test_updates_task_timer_seconds(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        update_task_timer(fake_db, USER_A, task_id, 1800, "More time please")  # type: ignore[arg-type]

        task_row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert task_row["timer_seconds"] == 1800

    def test_links_why_log_on_task(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        result = update_task_timer(fake_db, USER_A, task_id, 1800, "More time please")  # type: ignore[arg-type]

        task_row = next(r for r in fake_db.table("tasks").rows if r["id"] == task_id)
        assert task_row["why_log_id"] == result["why_log_id"]

    def test_raises_on_timer_too_low(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        with pytest.raises(ValueError, match="minimum"):
            update_task_timer(fake_db, USER_A, task_id, 30, "Quick change")  # type: ignore[arg-type]

    def test_raises_on_timer_too_high(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)
        with pytest.raises(ValueError, match="maximum"):
            update_task_timer(fake_db, USER_A, task_id, 99999, "Long change")  # type: ignore[arg-type]

    def test_raises_on_unknown_task(self, fake_db: _FakeSupabase) -> None:
        with pytest.raises(ValueError, match="not found"):
            update_task_timer(fake_db, USER_A, str(uuid.uuid4()), 1500, "reason")  # type: ignore[arg-type]

    def test_raises_on_wrong_user(self, fake_db: _FakeSupabase) -> None:
        task_id = self._seed_task(fake_db)  # owned by USER_A
        with pytest.raises(ValueError, match="not found"):
            update_task_timer(fake_db, "user-bbb", task_id, 1500, "reason")  # type: ignore[arg-type]

    def test_why_log_not_written_on_validation_failure(self, fake_db: _FakeSupabase) -> None:
        """No why_log row must be written if validation fails before the insert."""
        task_id = self._seed_task(fake_db)
        with pytest.raises(ValueError):
            update_task_timer(fake_db, USER_A, task_id, 30, "Bad change")  # type: ignore[arg-type]
        assert len(fake_db.table("nova_why_log").rows) == 0
