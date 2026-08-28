"""
Tests that /generate-batch and /generate-open-batch only call
save_generated_test (writing to the question bank + published feed) when the
request's `persist` field is true, and that it defaults to False -- writing
should be an explicit choice by the caller, not a side effect of generating.
"""

import sys
from pathlib import Path

from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import pyq.rag.main as main_mod  # noqa: E402

client = TestClient(main_mod.app)

_MCQ_ROW = {
    "question": "What causes starvation under FCFS scheduling?",
    "options": ["A", "B", "C", "D"],
    "correct_index": 0,
    "subject": "Operating Systems",
    "marks": 2,
}

_OPEN_ROW = {
    "question": "Explain the dining philosophers problem.",
    "subject": "Operating Systems",
    "marks": 5,
    "model_answer": "A worked answer.",
}


def _base_batch_body(**overrides) -> dict:
    body = {"subject": "Operating Systems", "college": "BPHC", "count": 1}
    body.update(overrides)
    return body


def _base_open_batch_body(**overrides) -> dict:
    body = {"subject": "Operating Systems", "college": "BPHC", "count": 1}
    body.update(overrides)
    return body


class _SaveCallRecorder:
    def __init__(self):
        self.calls: list[dict] = []

    def __call__(self, **kwargs):
        self.calls.append(kwargs)
        return "fake-test-id"


# ── /generate-batch ────────────────────────────────────────────────────────────

def test_generate_batch_does_not_persist_by_default(monkeypatch):
    recorder = _SaveCallRecorder()
    monkeypatch.setattr(main_mod, "run_generate_mcq_batch", lambda **kw: [_MCQ_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", recorder)

    response = client.post("/generate-batch", json=_base_batch_body())

    assert response.status_code == 200
    assert recorder.calls == []
    assert response.json()["questions"][0]["question"] == _MCQ_ROW["question"]


def test_generate_batch_persists_when_requested(monkeypatch):
    recorder = _SaveCallRecorder()
    monkeypatch.setattr(main_mod, "run_generate_mcq_batch", lambda **kw: [_MCQ_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", recorder)

    response = client.post("/generate-batch", json=_base_batch_body(persist=True))

    assert response.status_code == 200
    assert len(recorder.calls) == 1


def test_generate_batch_explicit_persist_false_does_not_persist(monkeypatch):
    recorder = _SaveCallRecorder()
    monkeypatch.setattr(main_mod, "run_generate_mcq_batch", lambda **kw: [_MCQ_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", recorder)

    response = client.post("/generate-batch", json=_base_batch_body(persist=False))

    assert response.status_code == 200
    assert recorder.calls == []


def test_generate_batch_returns_questions_regardless_of_persist(monkeypatch):
    monkeypatch.setattr(main_mod, "run_generate_mcq_batch", lambda **kw: [_MCQ_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", lambda **kw: "id")

    no_persist = client.post("/generate-batch", json=_base_batch_body(persist=False))
    with_persist = client.post("/generate-batch", json=_base_batch_body(persist=True))

    assert no_persist.json()["questions"] == with_persist.json()["questions"]


# ── /generate-open-batch ──────────────────────────────────────────────────────

def test_generate_open_batch_does_not_persist_by_default(monkeypatch):
    recorder = _SaveCallRecorder()
    monkeypatch.setattr(main_mod, "run_generate_open_batch", lambda **kw: [_OPEN_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", recorder)

    response = client.post("/generate-open-batch", json=_base_open_batch_body())

    assert response.status_code == 200
    assert recorder.calls == []


def test_generate_open_batch_persists_when_requested(monkeypatch):
    recorder = _SaveCallRecorder()
    monkeypatch.setattr(main_mod, "run_generate_open_batch", lambda **kw: [_OPEN_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", recorder)

    response = client.post("/generate-open-batch", json=_base_open_batch_body(persist=True))

    assert response.status_code == 200
    assert len(recorder.calls) == 1


def test_generate_open_batch_persist_failure_does_not_fail_the_request(monkeypatch):
    # save_generated_test failing must be logged, not surfaced as a 500 --
    # matches the pre-existing try/except around it.
    def failing_save(**kw):
        raise RuntimeError("supabase write failed")

    monkeypatch.setattr(main_mod, "run_generate_open_batch", lambda **kw: [_OPEN_ROW])
    monkeypatch.setattr(main_mod, "save_generated_test", failing_save)

    response = client.post("/generate-open-batch", json=_base_open_batch_body(persist=True))

    assert response.status_code == 200
