"""
Conversation propose/confirm layer - spec §5.

Chat never writes standing_flags/situation_flags/nova_history/career_units
directly. It stages a candidate row in nova_unconfirmed_proposals, which has
zero effect on facts_service/reasoning (it isn't one of the fetched tables).
Only confirm_proposal()/confirm_turn() ever touch the real destination
tables, and only in response to an explicit student action - never inferred
from free text.

Supersession (spec §2a's contradiction rule) is resolved at confirm time,
not at proposal-creation time, so a proposal sitting unconfirmed for a while
never goes stale against facts that changed in the meantime.
"""

from datetime import datetime, timezone
from typing import Any, cast

from supabase import Client

from nova.schemas.proposals import (
    PendingProposal,
    ProposalResolution,
    ProposalSummary,
    RawProposedFact,
)

_TABLE_FOR_KIND: dict[str, str] = {
    "standing_flag": "standing_flags",
    "situation_flag": "situation_flags",
    "nova_history": "nova_history",
}

_TEXT_FIELD_FOR_KIND: dict[str, str] = {
    "standing_flag": "instruction_text",
    "situation_flag": "flag_text",
    "nova_history": "content",
}


def _resolve_subject_id(snapshot: dict, name: str | None) -> str | None:
    if not name:
        return None
    needle = name.strip().lower()
    for row in snapshot.get("user_subjects", []):
        subj = row.get("subjects") or {}
        custom = row.get("custom_subjects") or {}
        candidates = [subj.get("name"), subj.get("short_name"), custom.get("name")]
        if any(c and c.strip().lower() == needle for c in candidates):
            return row.get("id")
    return None


def _resolve_career_unit_id(snapshot: dict, name: str | None) -> str | None:
    if not name:
        return None
    needle = name.strip().lower()
    for row in snapshot.get("career_units", []):
        if (row.get("name") or "").strip().lower() == needle:
            return row.get("id")
    return None


def _summarize(fact: RawProposedFact, subject_name: str | None, career_name: str | None) -> str:
    target = subject_name or career_name
    suffix = f" ({target})" if target else ""
    labels = {
        "standing_flag": "Remember",
        "situation_flag": "Note",
        "nova_history": "Remember what's worked",
        "career_unit": "Start tracking",
    }
    return f"{labels[fact.kind]}{suffix}: {fact.text}"


def create_proposals(
    supabase: Client,
    user_id: str,
    turn_id: str,
    raw_facts: list[RawProposedFact],
    snapshot: dict,
) -> list[ProposalSummary]:
    """Stages each candidate fact as a pending row. Never writes to the
    real destination tables - that only happens on confirm."""
    created: list[ProposalSummary] = []

    for fact in raw_facts:
        user_subject_id = _resolve_subject_id(snapshot, fact.target_subject_name)
        career_unit_id = (
            None if fact.kind == "career_unit" else _resolve_career_unit_id(snapshot, fact.target_career_unit_name)
        )

        if fact.kind == "career_unit":
            payload: dict[str, Any] = {"name": fact.text, "description": fact.description}
        else:
            payload = {_TEXT_FIELD_FOR_KIND[fact.kind]: fact.text}

        summary = _summarize(fact, fact.target_subject_name, fact.target_career_unit_name)

        row = cast(
            dict[str, Any],
            (
                supabase.table("nova_unconfirmed_proposals")
                .insert(
                    {
                        "user_id": user_id,
                        "turn_id": turn_id,
                        "proposal_type": fact.kind,
                        "user_subject_id": user_subject_id,
                        "career_unit_id": career_unit_id,
                        "payload": payload,
                        "proposed_summary": summary,
                    }
                )
                .execute()
                .data[0]
            ),
        )
        created.append(
            ProposalSummary(id=row["id"], turn_id=turn_id, kind=fact.kind, summary=summary)
        )

    return created


def get_pending_proposals(supabase: Client, user_id: str) -> list[PendingProposal]:
    rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("nova_unconfirmed_proposals")
            .select("*")
            .eq("user_id", user_id)
            .eq("status", "pending")
            .order("created_at", desc=False)
            .execute()
            .data
        ),
    )
    return [
        PendingProposal(
            id=r["id"],
            turn_id=r["turn_id"],
            kind=r["proposal_type"],
            summary=r["proposed_summary"],
            created_at=r["created_at"],
        )
        for r in rows
    ]


def _fetch_pending_proposal(supabase: Client, user_id: str, proposal_id: str) -> dict[str, Any]:
    rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("nova_unconfirmed_proposals")
            .select("*")
            .eq("id", proposal_id)
            .eq("user_id", user_id)
            .eq("status", "pending")
            .limit(1)
            .execute()
            .data
        ),
    )
    if not rows:
        raise ValueError(f"No pending proposal {proposal_id} for this student")
    return rows[0]


def _find_active_row(
    supabase: Client, table: str, user_id: str, user_subject_id: str | None, career_unit_id: str | None
) -> str | None:
    """Same-unit match for the supersession rule: same table, same
    (user_subject_id, career_unit_id) pair, including both-null for a
    user-level fact. Only the most recent currently-active row matters."""
    query = (
        supabase.table(table)
        .select("id")
        .eq("user_id", user_id)
        .is_("superseded_at", "null")
        .not_.is_("confirmed_at", "null")
    )
    query = query.eq("user_subject_id", user_subject_id) if user_subject_id else query.is_("user_subject_id", "null")
    query = query.eq("career_unit_id", career_unit_id) if career_unit_id else query.is_("career_unit_id", "null")
    rows = cast(
        list[dict[str, Any]],
        query.order("created_at", desc=True).limit(1).execute().data,
    )
    return rows[0]["id"] if rows else None


def _confirm_flag_or_history(supabase: Client, user_id: str, proposal: dict[str, Any]) -> str:
    table = _TABLE_FOR_KIND[proposal["proposal_type"]]
    user_subject_id = proposal.get("user_subject_id")
    career_unit_id = proposal.get("career_unit_id")

    superseded_id = _find_active_row(supabase, table, user_id, user_subject_id, career_unit_id)

    now = datetime.now(timezone.utc).isoformat()
    insert_payload: dict[str, Any] = {
        "user_id": user_id,
        "user_subject_id": user_subject_id,
        "career_unit_id": career_unit_id,
        **proposal["payload"],
        "confirmed_at": now,
        "supersedes_id": superseded_id,
    }
    if table != "situation_flags":
        insert_payload["source"] = "conversation"

    new_row = cast(
        dict[str, Any],
        (
            supabase.table(table)
            .insert(insert_payload)
            .execute()
            .data[0]
        ),
    )

    if superseded_id:
        supabase.table(table).update({"superseded_at": now}).eq("id", superseded_id).execute()

    return new_row["id"]


def _confirm_career_unit(supabase: Client, user_id: str, proposal: dict[str, Any]) -> str:
    """Career units use pause/resume, not supersession (README's stated
    design) - a repeated interest un-pauses the existing row instead of
    creating a duplicate."""
    name = proposal["payload"]["name"]
    description = proposal["payload"].get("description")
    needle = name.strip().lower()

    # Exact case-insensitive match done in Python, not via .ilike(): ILIKE
    # treats % and _ in `name` as SQL wildcards, which would cross-match
    # unrelated rows (e.g. "100% Placement Prep" wildcard-matching "100X
    # Placement Prep"). Mirrors _resolve_career_unit_id's comparison.
    all_rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("career_units")
            .select("id, name, paused_at, confirmed_at")
            .eq("user_id", user_id)
            .order("created_at", desc=True)
            .execute()
            .data
        ),
    )
    existing = [row for row in all_rows if (row.get("name") or "").strip().lower() == needle]

    now = datetime.now(timezone.utc).isoformat()

    if existing:
        row = existing[0]
        update: dict[str, Any] = {"updated_at": now}
        if row["paused_at"] is not None:
            update["paused_at"] = None
        if row["confirmed_at"] is None:
            update["confirmed_at"] = now
        if description:
            update["description"] = description
        supabase.table("career_units").update(update).eq("id", row["id"]).execute()
        return row["id"]

    new_row = cast(
        dict[str, Any],
        (
            supabase.table("career_units")
            .insert(
                {
                    "user_id": user_id,
                    "name": name,
                    "description": description,
                    "confirmed_at": now,
                    "source": "conversation",
                }
            )
            .execute()
            .data[0]
        ),
    )
    return new_row["id"]


def confirm_proposal(supabase: Client, user_id: str, proposal_id: str) -> ProposalResolution:
    proposal = _fetch_pending_proposal(supabase, user_id, proposal_id)

    if proposal["proposal_type"] == "career_unit":
        resulting_row_id = _confirm_career_unit(supabase, user_id, proposal)
    else:
        resulting_row_id = _confirm_flag_or_history(supabase, user_id, proposal)

    now = datetime.now(timezone.utc).isoformat()
    supabase.table("nova_unconfirmed_proposals").update(
        {"status": "confirmed", "resolved_at": now, "resulting_row_id": resulting_row_id}
    ).eq("id", proposal_id).execute()

    return ProposalResolution(
        id=proposal_id,
        kind=proposal["proposal_type"],
        status="confirmed",
        resulting_row_id=resulting_row_id,
    )


def reject_proposal(supabase: Client, user_id: str, proposal_id: str) -> ProposalResolution:
    proposal = _fetch_pending_proposal(supabase, user_id, proposal_id)  # 404s if not pending/not owned
    now = datetime.now(timezone.utc).isoformat()
    supabase.table("nova_unconfirmed_proposals").update(
        {"status": "rejected", "resolved_at": now}
    ).eq("id", proposal_id).execute()
    return ProposalResolution(id=proposal_id, kind=proposal["proposal_type"], status="rejected")


def _pending_ids_for_turn(supabase: Client, user_id: str, turn_id: str) -> list[str]:
    rows = cast(
        list[dict[str, Any]],
        (
            supabase.table("nova_unconfirmed_proposals")
            .select("id")
            .eq("user_id", user_id)
            .eq("turn_id", turn_id)
            .eq("status", "pending")
            .execute()
            .data
        ),
    )
    return [r["id"] for r in rows]


def confirm_turn(supabase: Client, user_id: str, turn_id: str) -> list[ProposalResolution]:
    return [confirm_proposal(supabase, user_id, pid) for pid in _pending_ids_for_turn(supabase, user_id, turn_id)]


def reject_turn(supabase: Client, user_id: str, turn_id: str) -> list[ProposalResolution]:
    return [reject_proposal(supabase, user_id, pid) for pid in _pending_ids_for_turn(supabase, user_id, turn_id)]


PROPOSAL_KIND_TO_DIRTY_TABLE: dict[str, str] = {
    "standing_flag": "standing_flags",
    "situation_flag": "situation_flags",
    "nova_history": "nova_history",
    "career_unit": "career_units",
}
