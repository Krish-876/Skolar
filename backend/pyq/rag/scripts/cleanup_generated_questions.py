"""
Lists (and optionally deletes) questions.doc_type='generated' rows -- the
rows /generate-batch and /generate-open-batch used to write to the question
bank as a side effect of generating, before that became opt-in via the
`persist` request field. Not run automatically; a human runs this once
existing generated rows have been reviewed.

Usage (from backend/):
    python -m pyq.rag.scripts.cleanup_generated_questions              # dry run: list + summary only
    python -m pyq.rag.scripts.cleanup_generated_questions --delete     # actually delete unreferenced rows

Safety:
    - Defaults to a dry-run listing. Nothing is deleted unless --delete is
      passed explicitly.
    - Before deleting anything, checks whether any doc_type='generated' row
      is referenced by published_tests.question_ids -- deleting a question a
      published test points at would leave a dangling reference in that
      test's question_ids array. Referenced rows are always reported
      separately and are skipped by --delete unless --include-referenced is
      also passed.
"""

import argparse
import sys
from collections import Counter
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent.parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.store.supabase import get_supabase  # noqa: E402

_DELETE_BATCH_SIZE = 50


# ── Pure logic (unit-testable without a live Supabase connection) ────────────

def summarize_generated(questions: list[dict]) -> dict:
    """count, breakdown by exam_type, breakdown by published status, and the
    created_at range -- so a human can see what's about to be removed and
    whether any of it was ever published to students before it's deleted."""
    exam_type_counts = Counter(q.get("exam_type") or "(none)" for q in questions)
    published_counts = Counter(bool(q.get("published")) for q in questions)
    created_ats = [q["created_at"] for q in questions if q.get("created_at")]

    return {
        "total": len(questions),
        "by_exam_type": dict(exam_type_counts),
        "by_published": {
            "published": published_counts.get(True, 0),
            "unpublished": published_counts.get(False, 0),
        },
        "created_at_min": min(created_ats) if created_ats else None,
        "created_at_max": max(created_ats) if created_ats else None,
    }


def referenced_ids_from_published_tests(published_tests: list[dict]) -> set[str]:
    """Flattens published_tests.question_ids across all rows into one set of
    referenced question ids."""
    referenced: set[str] = set()
    for row in published_tests:
        referenced.update(row.get("question_ids") or [])
    return referenced


def partition_by_reference(
    questions: list[dict],
    referenced_ids: set[str],
) -> tuple[list[dict], list[dict]]:
    """Returns (referenced, unreferenced). Referenced rows must never be
    silently deleted -- a published test's question_ids array would end up
    pointing at a row that no longer exists."""
    referenced = [q for q in questions if q["id"] in referenced_ids]
    unreferenced = [q for q in questions if q["id"] not in referenced_ids]
    return referenced, unreferenced


def format_summary(
    summary: dict,
    referenced: list[dict],
    unreferenced: list[dict],
    will_delete: bool,
    include_referenced: bool,
) -> str:
    lines = []
    lines.append("=" * 70)
    lines.append("  GENERATED QUESTIONS CLEANUP")
    lines.append("=" * 70)
    lines.append(f"Total doc_type='generated' rows: {summary['total']}")
    lines.append("")

    lines.append("By exam_type:")
    for exam_type, count in sorted(summary["by_exam_type"].items(), key=lambda kv: -kv[1]):
        lines.append(f"  {exam_type:<20} {count}")
    lines.append("")

    lines.append("By published status:")
    lines.append(f"  published:     {summary['by_published']['published']}")
    lines.append(f"  unpublished:   {summary['by_published']['unpublished']}")
    lines.append("")

    if summary["created_at_min"] is not None:
        lines.append(f"created_at range: {summary['created_at_min']}  ->  {summary['created_at_max']}")
    else:
        lines.append("created_at range: (no rows)")
    lines.append("")

    lines.append(
        f"Referenced by published_tests.question_ids: {len(referenced)} "
        f"({'INCLUDED in deletion' if include_referenced else 'always SKIPPED'})"
    )
    for q in referenced:
        preview = (q.get("question_text") or "")[:80]
        lines.append(f"    id={q['id']}  exam_type={q.get('exam_type')}  published={q.get('published')}  {preview!r}")
    lines.append("")

    lines.append(f"Not referenced -- eligible for deletion: {len(unreferenced)}")
    for q in unreferenced:
        preview = (q.get("question_text") or "")[:80]
        lines.append(f"    id={q['id']}  exam_type={q.get('exam_type')}  published={q.get('published')}  {preview!r}")
    lines.append("")

    if will_delete:
        to_delete = len(unreferenced) + (len(referenced) if include_referenced else 0)
        lines.append(f"--delete passed: will delete {to_delete} row(s).")
    else:
        lines.append(
            f"DRY RUN -- no rows deleted. Pass --delete to delete the "
            f"{len(unreferenced)} eligible row(s) above."
        )

    return "\n".join(lines)


# ── Supabase I/O ──────────────────────────────────────────────────────────────

def fetch_generated_questions(sb) -> list[dict]:
    response = (
        sb.table("questions")
        .select("id, question_text, exam_type, published, created_at, college, subject")
        .eq("doc_type", "generated")
        .execute()
    )
    return response.data or []


def fetch_published_tests(sb) -> list[dict]:
    response = sb.table("published_tests").select("id, question_ids").execute()
    return response.data or []


def delete_questions(sb, ids: list[str]) -> int:
    deleted = 0
    for i in range(0, len(ids), _DELETE_BATCH_SIZE):
        batch = ids[i:i + _DELETE_BATCH_SIZE]
        sb.table("questions").delete().in_("id", batch).execute()
        deleted += len(batch)
    return deleted


# ── CLI ─────────────────────────────────────────────────────────────────────

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--delete", action="store_true",
        help="Actually delete eligible (unreferenced) rows. Without this, only lists and summarizes.",
    )
    parser.add_argument(
        "--include-referenced", action="store_true",
        help="Also delete rows referenced by published_tests.question_ids (dangerous -- leaves "
             "dangling references in those tests). Only takes effect together with --delete.",
    )
    return parser


def main(argv: list[str] | None = None) -> None:
    args = build_arg_parser().parse_args(argv)

    sb = get_supabase()
    questions = fetch_generated_questions(sb)
    published_tests = fetch_published_tests(sb)
    referenced_ids = referenced_ids_from_published_tests(published_tests)
    referenced, unreferenced = partition_by_reference(questions, referenced_ids)
    summary = summarize_generated(questions)

    print(format_summary(
        summary, referenced, unreferenced,
        will_delete=args.delete, include_referenced=args.include_referenced,
    ))

    if not args.delete:
        return

    to_delete_ids = [q["id"] for q in unreferenced]
    if args.include_referenced:
        to_delete_ids += [q["id"] for q in referenced]

    if not to_delete_ids:
        print("\nNothing to delete.")
        return

    deleted = delete_questions(sb, to_delete_ids)
    print(f"\nDeleted {deleted} row(s).")


if __name__ == "__main__":
    main()
