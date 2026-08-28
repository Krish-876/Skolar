"""
Tests for pyq/rag/scripts/cleanup_generated_questions.py's pure logic:
summarizing doc_type='generated' rows, detecting which ones are referenced
by published_tests.question_ids (must never be silently deleted), and the
dry-run/--delete/--include-referenced CLI wiring against a fake Supabase
client (no live DB connection).
"""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.scripts.cleanup_generated_questions import (  # noqa: E402
    _DELETE_BATCH_SIZE,
    format_summary,
    main,
    partition_by_reference,
    referenced_ids_from_published_tests,
    summarize_generated,
)


def _q(id_, exam_type="midsem", published=False, created_at="2026-06-01T00:00:00Z", text="a question"):
    return {
        "id": id_, "exam_type": exam_type, "published": published,
        "created_at": created_at, "question_text": text, "doc_type": "generated",
    }


# ── summarize_generated ─────────────────────────────────────────────────────────

def test_summarize_generated_counts_and_breakdowns():
    questions = [
        _q("1", exam_type="midsem", published=True),
        _q("2", exam_type="midsem", published=False),
        _q("3", exam_type="compre", published=False),
    ]
    summary = summarize_generated(questions)

    assert summary["total"] == 3
    assert summary["by_exam_type"] == {"midsem": 2, "compre": 1}
    assert summary["by_published"] == {"published": 1, "unpublished": 2}


def test_summarize_generated_created_at_range():
    questions = [
        _q("1", created_at="2026-06-15T00:00:00Z"),
        _q("2", created_at="2026-05-01T00:00:00Z"),
        _q("3", created_at="2026-07-20T00:00:00Z"),
    ]
    summary = summarize_generated(questions)

    assert summary["created_at_min"] == "2026-05-01T00:00:00Z"
    assert summary["created_at_max"] == "2026-07-20T00:00:00Z"


def test_summarize_generated_empty_list():
    summary = summarize_generated([])
    assert summary["total"] == 0
    assert summary["by_exam_type"] == {}
    assert summary["by_published"] == {"published": 0, "unpublished": 0}
    assert summary["created_at_min"] is None
    assert summary["created_at_max"] is None


def test_summarize_generated_missing_exam_type_grouped_as_none_label():
    questions = [_q("1", exam_type=None)]
    summary = summarize_generated(questions)
    assert summary["by_exam_type"] == {"(none)": 1}


# ── referenced_ids_from_published_tests ───────────────────────────────────────

def test_referenced_ids_flattens_across_rows():
    published_tests = [
        {"id": "t1", "question_ids": ["1", "2"]},
        {"id": "t2", "question_ids": ["3"]},
    ]
    assert referenced_ids_from_published_tests(published_tests) == {"1", "2", "3"}


def test_referenced_ids_handles_missing_or_empty_question_ids():
    published_tests = [
        {"id": "t1", "question_ids": None},
        {"id": "t2", "question_ids": []},
        {"id": "t3"},
    ]
    assert referenced_ids_from_published_tests(published_tests) == set()


def test_referenced_ids_empty_input():
    assert referenced_ids_from_published_tests([]) == set()


# ── partition_by_reference ───────────────────────────────────────────────────────

def test_partition_by_reference_splits_correctly():
    questions = [_q("1"), _q("2"), _q("3")]
    referenced, unreferenced = partition_by_reference(questions, referenced_ids={"2"})

    assert [q["id"] for q in referenced] == ["2"]
    assert [q["id"] for q in unreferenced] == ["1", "3"]


def test_partition_by_reference_none_referenced():
    questions = [_q("1"), _q("2")]
    referenced, unreferenced = partition_by_reference(questions, referenced_ids=set())

    assert referenced == []
    assert len(unreferenced) == 2


def test_partition_by_reference_all_referenced():
    questions = [_q("1"), _q("2")]
    referenced, unreferenced = partition_by_reference(questions, referenced_ids={"1", "2"})

    assert len(referenced) == 2
    assert unreferenced == []


# ── format_summary ───────────────────────────────────────────────────────────────

def test_format_summary_dry_run_mentions_no_deletion():
    questions = [_q("1"), _q("2")]
    summary = summarize_generated(questions)
    referenced, unreferenced = partition_by_reference(questions, referenced_ids=set())

    output = format_summary(summary, referenced, unreferenced, will_delete=False, include_referenced=False)

    assert "DRY RUN" in output
    assert "2" in output  # eligible count appears


def test_format_summary_lists_referenced_rows_as_skipped_by_default():
    questions = [_q("1"), _q("2")]
    summary = summarize_generated(questions)
    referenced, unreferenced = partition_by_reference(questions, referenced_ids={"1"})

    output = format_summary(summary, referenced, unreferenced, will_delete=False, include_referenced=False)

    assert "always SKIPPED" in output
    assert "id=1" in output


def test_format_summary_include_referenced_changes_label():
    questions = [_q("1")]
    summary = summarize_generated(questions)
    referenced, unreferenced = partition_by_reference(questions, referenced_ids={"1"})

    output = format_summary(summary, referenced, unreferenced, will_delete=True, include_referenced=True)

    assert "INCLUDED in deletion" in output


def test_format_summary_will_delete_reports_count_to_delete():
    questions = [_q("1"), _q("2"), _q("3")]
    summary = summarize_generated(questions)
    referenced, unreferenced = partition_by_reference(questions, referenced_ids={"1"})

    output = format_summary(summary, referenced, unreferenced, will_delete=True, include_referenced=False)

    assert "will delete 2 row(s)" in output


# ── main(): CLI wiring against a fake Supabase client ─────────────────────────

class _FakeTable:
    def __init__(self, store, deleted_ids):
        self._store = store
        self._deleted_ids = deleted_ids
        self._table_name = None
        self._filters: list[tuple[str, object]] = []
        self._delete_mode = False

    def __call__(self, table_name):
        self._table_name = table_name
        return self

    def select(self, *_cols):
        return self

    def eq(self, col, val):
        self._filters.append(("eq", col, val))
        return self

    def in_(self, col, vals):
        self._filters.append(("in", col, list(vals)))
        return self

    def delete(self):
        self._delete_mode = True
        return self

    def execute(self):
        if self._delete_mode:
            (_, _, ids) = self._filters[-1]
            self._deleted_ids.extend(ids)
            return _Response([])
        rows = self._store.get(self._table_name, [])
        for f in self._filters:
            if f[0] == "eq":
                _, col, val = f
                rows = [r for r in rows if r.get(col) == val]
        return _Response(rows)


class _Response:
    def __init__(self, data):
        self.data = data


class _FakeSupabase:
    def __init__(self, questions, published_tests):
        self._store = {"questions": questions, "published_tests": published_tests}
        self.deleted_ids: list[str] = []

    def table(self, name):
        return _FakeTable(self._store, self.deleted_ids)(name)


def test_main_dry_run_does_not_delete(monkeypatch, capsys):
    questions = [_q("1"), _q("2")]
    fake_sb = _FakeSupabase(questions, published_tests=[])
    monkeypatch.setattr(
        "pyq.rag.scripts.cleanup_generated_questions.get_supabase", lambda: fake_sb
    )

    main([])

    assert fake_sb.deleted_ids == []
    out = capsys.readouterr().out
    assert "DRY RUN" in out


def test_main_delete_removes_only_unreferenced(monkeypatch, capsys):
    questions = [_q("1"), _q("2"), _q("3")]
    published_tests = [{"id": "t1", "question_ids": ["2"]}]
    fake_sb = _FakeSupabase(questions, published_tests)
    monkeypatch.setattr(
        "pyq.rag.scripts.cleanup_generated_questions.get_supabase", lambda: fake_sb
    )

    main(["--delete"])

    assert set(fake_sb.deleted_ids) == {"1", "3"}
    out = capsys.readouterr().out
    assert "Deleted 2 row(s)" in out


def test_main_delete_with_include_referenced_deletes_everything(monkeypatch, capsys):
    questions = [_q("1"), _q("2")]
    published_tests = [{"id": "t1", "question_ids": ["1"]}]
    fake_sb = _FakeSupabase(questions, published_tests)
    monkeypatch.setattr(
        "pyq.rag.scripts.cleanup_generated_questions.get_supabase", lambda: fake_sb
    )

    main(["--delete", "--include-referenced"])

    assert set(fake_sb.deleted_ids) == {"1", "2"}


def test_main_delete_with_nothing_eligible_prints_nothing_to_delete(monkeypatch, capsys):
    questions = [_q("1")]
    published_tests = [{"id": "t1", "question_ids": ["1"]}]
    fake_sb = _FakeSupabase(questions, published_tests)
    monkeypatch.setattr(
        "pyq.rag.scripts.cleanup_generated_questions.get_supabase", lambda: fake_sb
    )

    main(["--delete"])

    assert fake_sb.deleted_ids == []
    out = capsys.readouterr().out
    assert "Nothing to delete" in out


def test_delete_batch_size_is_positive():
    # Sanity check on the batching constant used by delete_questions.
    assert _DELETE_BATCH_SIZE > 0
