"""
Tests for llm/generation.py's generate_question() prompt-leak stripping.

generate_question() builds its few-shot prompt by prefixing each example with
a header: "{marks} marks, {type}, topic: {topic}:\n{question_text}". Some rows
stored in the bank already carry that same header baked into question_text
itself (a leftover of the extraction step), so when such a row is used as an
example the model sometimes echoes the header back verbatim in its own
output instead of returning just the question -- a prompt leak into the
generated question text.
"""

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import pyq.rag.llm.generation as generation_mod  # noqa: E402


class _FakeMessage:
    def __init__(self, content):
        self.content = content


class _FakeChoice:
    def __init__(self, content):
        self.message = _FakeMessage(content)


class _FakeResponse:
    def __init__(self, content):
        self.choices = [_FakeChoice(content)]
        self.usage = None


def _stub_completion(content):
    def _fake_create_chat_completion(*, messages, **kwargs):
        return _FakeResponse(content)
    return _fake_create_chat_completion


def test_generate_question_strips_extraction_schema_header(monkeypatch):
    # Observed leak: the model echoes back the few-shot header format instead
    # of just the question.
    before = "5 marks, short_answer, topic: Deadlocks:\nExplain the Banker's algorithm with an example."
    monkeypatch.setattr(generation_mod, "create_chat_completion", _stub_completion(before))

    after = generation_mod.generate_question(
        subject="Operating Systems",
        examples=[{"marks": 5, "question_type": "short_answer", "topic": "Deadlocks",
                   "question_text": "Explain the Banker's algorithm with an example."}],
    )

    assert after == "Explain the Banker's algorithm with an example."
    assert "marks" not in after.lower()
    assert "topic:" not in after.lower()


def test_generate_question_leaves_clean_output_untouched(monkeypatch):
    clean = "Explain the Banker's algorithm with an example."
    monkeypatch.setattr(generation_mod, "create_chat_completion", _stub_completion(clean))

    after = generation_mod.generate_question(subject="Operating Systems", examples=[])

    assert after == clean


def test_generate_question_still_strips_q_prefix(monkeypatch):
    monkeypatch.setattr(
        generation_mod, "create_chat_completion",
        _stub_completion("Q3. What is a race condition?"),
    )

    after = generation_mod.generate_question(subject="Operating Systems", examples=[])

    assert after == "What is a race condition?"
