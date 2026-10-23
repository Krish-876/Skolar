"""
Nova tasks service -- backend write path for the weekly timetable.

All functions take ``supabase`` (a server-role Client that bypasses RLS) and
``user_id`` explicitly.  They do NOT import from deps.py or privacy.py and
have no FastAPI coupling -- keeping the layer unit-testable with a fake
Supabase client.

Schema reference: supabase/migrations/20261012143354_add_tasks_and_complete_task_rpc.sql
Design reference: TASKS_PLAN.md sections B.5, B.6, C

Design rules enforced here (verified against the migration):
- ``replan_weekly_tasks`` never touches tasks whose status is ``done``.
- Dropping omitted pending tasks only happens when the incoming plan is a
  non-empty, fully-parsed list.  Empty or invalid input raises ValueError
  and leaves existing tasks untouched.
- ``reschedule_missed_tasks`` keeps status ``pending`` when rolling a task
  forward within its week (incrementing reschedule_count + advancing
  planned_for).  A task only becomes ``missed`` once its week has fully
  ended -- i.e. when planned_for < week_start of the *as_of_date* week.
- ``update_task_timer`` writes a nova_why_log entry with
  entry_type=``one_off_override`` and facts_snapshot=None (allowed per the
  nova_why_log_full_needs_snapshot constraint which only requires a snapshot
  for entry_type=``full_pass``).
- timer_seconds is validated against the lower bound read from
  nova_config.focus_min_duration_seconds before the DB write, so the
  application layer and the DB CHECK (>= 60 AND <= 86400) stay in sync.
- week_start must come from a caller-supplied local date; this module never
  calls date.today() internally.
"""

from __future__ import annotations

import logging
from datetime import date
from typing import Any, cast

from supabase import Client

from nova.services.week_utils import week_start_for

logger = logging.getLogger(__name__)

# Hard upper bound from activity_log_duration_check and tasks CHECK constraint.
_TIMER_MAX_SECONDS = 86400

# Fallback minimum if nova_config cannot be read.
_TIMER_MIN_FALLBACK = 60


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _read_focus_min_seconds(supabase: Client) -> int:
    """Read ``focus_min_duration_seconds`` from nova_config.

    Returns the global default (60) if the row is missing or malformed.
    This mirrors how get_activity_daily reads the same key in SQL.
    """
    try:
        rows = cast(
            list[dict[str, Any]],
            supabase.table("nova_config")
            .select("value")
            .eq("key", "focus_min_duration_seconds")
            .is_("user_id", "null")
            .limit(1)
            .execute()
            .data,
        )
        if rows:
            raw = rows[0].get("value")
            # Supabase returns jsonb scalars as their Python equivalents.
            if isinstance(raw, (int, float)) and int(raw) > 0:
                return int(raw)
    except Exception:
        logger.warning("Could not read focus_min_duration_seconds from nova_config; defaulting to 60")
    return _TIMER_MIN_FALLBACK


_REQUIRED_TASK_KEYS = ("topic", "title", "planned_for", "timer_seconds", "priority", "reason")


def _validate_timer_seconds(min_seconds: int, timer_seconds: int) -> None:
    """Raise ValueError if timer_seconds is out of the allowed range.

    ``min_seconds`` is read once per call by the caller via
    ``_read_focus_min_seconds`` rather than once per task.
    """
    if isinstance(timer_seconds, bool) or not isinstance(timer_seconds, int):
        raise ValueError(f"timer_seconds must be an integer, got {timer_seconds!r}")
    if timer_seconds < min_seconds:
        raise ValueError(
            f"timer_seconds {timer_seconds} is below the minimum {min_seconds} "
            f"(nova_config.focus_min_duration_seconds)"
        )
    if timer_seconds > _TIMER_MAX_SECONDS:
        raise ValueError(
            f"timer_seconds {timer_seconds} exceeds the maximum {_TIMER_MAX_SECONDS}"
        )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------


def create_weekly_tasks(
    supabase: Client,
    user_id: str,
    week_start: str,
    tasks: list[dict[str, Any]],
    why_log_id: str,
) -> list[dict[str, Any]]:
    """Insert an initial set of tasks for the given week.

    Parameters
    ----------
    supabase:
        Server-role Supabase client (bypasses RLS).
    user_id:
        The student this week belongs to.
    week_start:
        ISO date string for the Monday/Sunday that opens the week.
        Must be computed by the caller from the client-supplied local date
        using ``week_start_for()``.
    tasks:
        List of task dicts.  Each entry must contain at minimum:

        ``topic`` (str), ``title`` (str), ``planned_for`` (ISO date str),
        ``timer_seconds`` (int), ``priority`` (int), ``reason`` (str).

        Optional: ``user_subject_id`` (UUID str | None).

    why_log_id:
        FK into nova_why_log for the reasoning pass that generated this plan.

    Returns
    -------
    list[dict]
        The inserted rows as returned by Supabase.

    Raises
    ------
    ValueError
        If ``tasks`` is empty or a task's ``timer_seconds`` is out of range.
    """
    if not tasks:
        raise ValueError("tasks must be a non-empty list")

    min_seconds = _read_focus_min_seconds(supabase)
    rows: list[dict[str, Any]] = []
    for t in tasks:
        _validate_timer_seconds(min_seconds, t["timer_seconds"])
        rows.append(
            {
                "user_id": user_id,
                "week_start": week_start,
                "planned_for": t["planned_for"],
                "user_subject_id": t.get("user_subject_id"),
                "topic": t["topic"],
                "title": t["title"],
                "timer_seconds": t["timer_seconds"],
                "priority": t["priority"],
                "reason": t["reason"],
                "status": "pending",
                "reschedule_count": 0,
                "why_log_id": why_log_id,
            }
        )

    result = cast(
        list[dict[str, Any]],
        supabase.table("tasks").insert(rows).execute().data,
    )
    return result


def replan_weekly_tasks(
    supabase: Client,
    user_id: str,
    week_start: str,
    updated_tasks: list[dict[str, Any]],
    why_log_id: str,
) -> dict[str, Any]:
    """Apply Nova's updated plan for an existing week in-place.

    Design rules:
    - NEVER modifies ``done`` tasks; incoming entries whose id belongs to a
      ``done`` task are skipped.
    - Validates every incoming task (required keys, timer range) before any
      write, so a bad entry leaves the DB unchanged.
    - Only marks omitted pending tasks as ``dropped`` when ``updated_tasks``
      is a fully-parsed, non-empty list.  An empty or None list raises
      ValueError so the caller can retry instead of silently clearing data.
    - Upserts (UPDATE existing row by ID, or INSERT if id absent in the plan).

    Parameters
    ----------
    supabase:
        Server-role Supabase client.
    user_id:
        Tenant boundary -- only this student's tasks for the given week are
        touched.
    week_start:
        ISO date string identifying the week.
    updated_tasks:
        Non-empty list of task dicts.  Each dict may contain:

        Required: ``topic``, ``title``, ``planned_for``, ``timer_seconds``,
        ``priority``, ``reason``.

        Optional: ``id`` (if omitted, a new row is created instead of
        updating an existing one), ``user_subject_id``.

    why_log_id:
        FK for the reasoning pass that produced this update.

    Returns
    -------
    dict with keys ``upserted`` (list), ``dropped`` (list of IDs).

    Raises
    ------
    ValueError
        If ``updated_tasks`` is empty/None (safety guard against silent data
        loss from an invalid or empty LLM response).
    """
    if not updated_tasks:
        raise ValueError(
            "updated_tasks is empty or None -- refusing to drop existing tasks. "
            "Ensure the incoming plan is fully parsed and non-empty before calling replan."
        )

    # Validate every incoming task before any write so a bad entry midway
    # cannot leave a half-applied plan.
    min_seconds = _read_focus_min_seconds(supabase)
    for t in updated_tasks:
        missing = [k for k in _REQUIRED_TASK_KEYS if k not in t]
        if missing:
            raise ValueError(f"task is missing required keys: {', '.join(missing)}")
        _validate_timer_seconds(min_seconds, t["timer_seconds"])

    # Fetch the current week's tasks so we know which ones to update, drop or skip.
    existing_rows = cast(
        list[dict[str, Any]],
        supabase.table("tasks")
        .select("id, status")
        .eq("user_id", user_id)
        .eq("week_start", week_start)
        .execute()
        .data,
    )
    done_ids: set[str] = {r["id"] for r in existing_rows if r["status"] == "done"}
    existing_by_id: dict[str, dict[str, Any]] = {
        r["id"]: r for r in existing_rows if r["status"] != "done"
    }

    incoming_ids: set[str] = set()
    upserted: list[dict[str, Any]] = []

    for t in updated_tasks:
        task_id: str | None = t.get("id")
        if task_id and task_id in done_ids:
            # Done tasks are immutable; skip rather than insert a duplicate.
            continue

        payload: dict[str, Any] = {
            "user_id": user_id,
            "week_start": week_start,
            "planned_for": t["planned_for"],
            "user_subject_id": t.get("user_subject_id"),
            "topic": t["topic"],
            "title": t["title"],
            "timer_seconds": t["timer_seconds"],
            "priority": t["priority"],
            "reason": t["reason"],
            "why_log_id": why_log_id,
        }

        if task_id and task_id in existing_by_id:
            # Update existing non-done task in place (never touches done tasks
            # because existing_by_id only contains non-done rows).
            updated_row = cast(
                list[dict[str, Any]],
                supabase.table("tasks")
                .update(payload)
                .eq("id", task_id)
                .eq("user_id", user_id)
                .neq("status", "done")
                .execute()
                .data,
            )
            upserted.extend(updated_row)
            incoming_ids.add(task_id)
        else:
            # New task (no id, or id not in existing non-done set).
            payload["status"] = "pending"
            payload["reschedule_count"] = 0
            inserted_row = cast(
                list[dict[str, Any]],
                supabase.table("tasks").insert(payload).execute().data,
            )
            upserted.extend(inserted_row)
            if task_id:
                incoming_ids.add(task_id)

    # Drop pending tasks that Nova omitted from the new plan.
    # Only pending tasks are dropped -- missed are left alone (they have
    # already rolled over and changing them to ``dropped`` here would
    # contradict the ``missed`` lifecycle).
    ids_to_drop = [
        row_id
        for row_id, row in existing_by_id.items()
        if row["status"] == "pending" and row_id not in incoming_ids
    ]

    if ids_to_drop:
        supabase.table("tasks").update({"status": "dropped", "why_log_id": why_log_id}).in_(
            "id", ids_to_drop
        ).execute()

    return {"upserted": upserted, "dropped": ids_to_drop}


def reschedule_missed_tasks(
    supabase: Client,
    user_id: str,
    as_of_date: str,
    week_start_day: int,
    why_log_id: str,
) -> dict[str, Any]:
    """Roll forward or mark-missed overdue pending tasks.

    "Roll forward" rule (from TASKS_PLAN.md C and design decisions):
    - A task whose ``planned_for < as_of_date`` but whose ``week_start`` is
      the same as the current week stays ``pending`` -- it is advanced
      to ``as_of_date`` and ``reschedule_count`` is incremented.
    - A task whose ``week_start`` belongs to a **past** week (i.e.
      ``week_start < current_week_start``) is marked ``missed``.

    Parameters
    ----------
    supabase:
        Server-role Supabase client.
    user_id:
        Tenant boundary.
    as_of_date:
        ISO date string of the device-local current date.  The caller must
        supply this; the service must not call ``date.today()`` internally.
    week_start_day:
        Dart convention (1=Mon...7=Sun).  Used to compute the week boundary
        from ``as_of_date``.
    why_log_id:
        FK for the nova_why_log entry that triggered this pass.

    Returns
    -------
    dict with keys ``rolled_forward`` (list of IDs) and ``marked_missed``
    (list of IDs).
    """
    as_of = date.fromisoformat(as_of_date)
    current_week_start = week_start_for(as_of, week_start_day)
    current_week_start_str = current_week_start.isoformat()

    # All pending tasks that are overdue as of today.
    overdue = cast(
        list[dict[str, Any]],
        supabase.table("tasks")
        .select("id, week_start, planned_for, reschedule_count")
        .eq("user_id", user_id)
        .eq("status", "pending")
        .lt("planned_for", as_of_date)
        .execute()
        .data,
    )

    rolled_forward: list[str] = []
    marked_missed: list[str] = []

    for row in overdue:
        task_id = row["id"]
        task_week_start = row["week_start"]

        if task_week_start >= current_week_start_str:
            # Still within the current week: roll forward to today.
            supabase.table("tasks").update(
                {
                    "planned_for": as_of_date,
                    "reschedule_count": row["reschedule_count"] + 1,
                    "why_log_id": why_log_id,
                }
            ).eq("id", task_id).execute()
            rolled_forward.append(task_id)
        else:
            # Past week: mark missed.
            supabase.table("tasks").update(
                {"status": "missed", "why_log_id": why_log_id}
            ).eq("id", task_id).execute()
            marked_missed.append(task_id)

    return {"rolled_forward": rolled_forward, "marked_missed": marked_missed}


def update_task_timer(
    supabase: Client,
    user_id: str,
    task_id: str,
    new_timer_seconds: int,
    reason: str,
) -> dict[str, Any]:
    """Update a task's timer following a student chat request.

    Writes a nova_why_log entry (entry_type=``one_off_override``,
    facts_snapshot=None -- allowed by the nova_why_log_full_needs_snapshot
    constraint which only requires a snapshot for ``full_pass``), then updates
    the task row and links the new why_log row.

    Parameters
    ----------
    supabase:
        Server-role Supabase client.
    user_id:
        Tenant boundary -- the task must belong to this user.
    task_id:
        UUID of the task to update.
    new_timer_seconds:
        New timer value.  Must satisfy
        focus_min_duration_seconds <= value <= 86400.
    reason:
        Human-readable reason from the student / chat layer.

    Returns
    -------
    dict with keys ``why_log_id`` (str) and ``updated_task`` (dict).

    Raises
    ------
    ValueError
        If ``new_timer_seconds`` is out of the allowed range, the task
        does not exist / does not belong to ``user_id``, or the task is not
        ``pending`` (complete_task compares duration against timer_seconds, so
        changing it on a finished task is meaningless).
    """
    _validate_timer_seconds(_read_focus_min_seconds(supabase), new_timer_seconds)

    # Verify task ownership before writing anything.
    task_rows = cast(
        list[dict[str, Any]],
        supabase.table("tasks")
        .select("id, status")
        .eq("id", task_id)
        .eq("user_id", user_id)
        .limit(1)
        .execute()
        .data,
    )
    if not task_rows:
        raise ValueError(f"Task {task_id} not found or does not belong to user {user_id}")
    if task_rows[0]["status"] != "pending":
        raise ValueError(
            f"Task {task_id} has status {task_rows[0]['status']!r}; "
            "only pending tasks can have their timer changed"
        )

    # Write nova_why_log entry.
    # - entry_type = ``one_off_override``
    # - facts_snapshot = None  (constraint allows this for non-full_pass types)
    # - reasoning_summary captures the student's reason
    why_log_row = cast(
        dict[str, Any],
        supabase.table("nova_why_log")
        .insert(
            {
                "user_id": user_id,
                "entry_type": "one_off_override",
                "facts_snapshot": None,
                "plan_output": None,
                "reasoning_summary": f"Student requested timer change: {reason}",
            }
        )
        .execute()
        .data[0],
    )
    why_log_id: str = why_log_row["id"]

    # Update the task.
    updated_rows = cast(
        list[dict[str, Any]],
        supabase.table("tasks")
        .update(
            {
                "timer_seconds": new_timer_seconds,
                "why_log_id": why_log_id,
            }
        )
        .eq("id", task_id)
        .eq("user_id", user_id)
        .execute()
        .data,
    )

    return {"why_log_id": why_log_id, "updated_task": updated_rows[0] if updated_rows else {}}
