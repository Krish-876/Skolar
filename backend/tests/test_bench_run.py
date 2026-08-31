"""
Unit tests for bench/run.py's own reliability logic: a fake Groq client
(no real API calls / quota spent) exercises the rate-limit/daily-cap ->
partial .meta.json path, and the reasoning_effort='none' omission rule.

Uses the real vendored cola data (bench/data/COLA) with --limit so it stays
fast and offline; only the Groq client is faked.
"""

import json
import sys
from pathlib import Path
from types import SimpleNamespace

import httpx
import pytest
from groq import RateLimitError

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import bench.cache as cache_mod  # noqa: E402
import bench.run as run_mod  # noqa: E402


@pytest.fixture(autouse=True)
def _isolated_response_cache(tmp_path, monkeypatch):
    """Every test here calls run_mod.run() against a fake Groq client, which
    now consults bench.cache's on-disk response cache -- without this, a
    prompt-identical config in one test (they mostly share the same cola
    zero_shot fixture args) would silently reuse another test's fake
    'acceptable' response instead of exercising the fake client, and would
    pollute the real gitignored bench/.cache/responses/ on disk."""
    monkeypatch.setattr(cache_mod, "CACHE_DIR", tmp_path / "response_cache")


class _FakeUsage:
    prompt_tokens = 5
    completion_tokens = 1


class _FakeMessage:
    def __init__(self, content):
        self.content = content


class _FakeChoice:
    def __init__(self, content):
        self.message = _FakeMessage(content)


class _FakeResponse:
    def __init__(self, content):
        self.choices = [_FakeChoice(content)]
        self.usage = _FakeUsage()


def _daily_cap_error() -> RateLimitError:
    request = httpx.Request("POST", "https://api.groq.com/openai/v1/chat/completions")
    response = httpx.Response(429, request=request, headers={"retry-after": "1"})
    return RateLimitError(
        "Rate limit reached for model in organization on requests per day (RPD): "
        "Limit 1000, Used 1000, Requested 1.",
        response=response,
        body=None,
    )


class _DailyCapCompletions:
    """Succeeds once, then raises a daily-cap RateLimitError forever after."""

    def __init__(self):
        self.calls: list[dict] = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if len(self.calls) == 1:
            return _FakeResponse("acceptable")
        raise _daily_cap_error()


class _RecordingCompletions:
    def __init__(self):
        self.calls: list[dict] = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        return _FakeResponse("acceptable")


class _FakeChat:
    def __init__(self, completions):
        self.completions = completions


class _FakeClient:
    def __init__(self, completions):
        self.chat = _FakeChat(completions)


def _zero_shot_args(out_path: Path, model: str = "fake-model", reasoning_effort: str = "none") -> SimpleNamespace:
    return SimpleNamespace(
        dataset="cola",
        setting="zero_shot",
        k=3,
        alpha=0.5,
        pool_multiplier=2,
        backend="tfidf",
        model=model,
        reasoning_effort=reasoning_effort,
        limit=3,
        out=out_path,
    )


def test_run_marks_meta_partial_and_stops_when_daily_cap_hit(tmp_path, monkeypatch):
    completions = _DailyCapCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    out_path = tmp_path / "out.jsonl"

    with pytest.raises(SystemExit, match="stopped early"):
        run_mod.run(_zero_shot_args(out_path))

    meta_path = Path(str(out_path) + ".meta.json")
    meta = json.loads(meta_path.read_text(encoding="utf-8"))

    assert meta["partial"] is True
    assert meta["n_samples_written"] == 1
    assert meta["n_samples_total"] == 3

    written_lines = out_path.read_text(encoding="utf-8").strip().splitlines()
    assert len(written_lines) == 1  # the first (successful) sample was still written, not dropped


def test_run_marks_meta_complete_on_success(tmp_path, monkeypatch):
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    out_path = tmp_path / "out.jsonl"
    run_mod.run(_zero_shot_args(out_path))

    meta = json.loads(Path(str(out_path) + ".meta.json").read_text(encoding="utf-8"))
    assert meta["partial"] is False
    assert meta["n_samples_written"] == 3
    assert len(out_path.read_text(encoding="utf-8").strip().splitlines()) == 3


def test_run_omits_reasoning_effort_when_none(tmp_path, monkeypatch):
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    run_mod.run(_zero_shot_args(tmp_path / "out.jsonl", reasoning_effort="none"))

    assert all("reasoning_effort" not in call for call in completions.calls)


def test_run_passes_reasoning_effort_when_set(tmp_path, monkeypatch):
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    run_mod.run(_zero_shot_args(tmp_path / "out.jsonl", reasoning_effort="medium"))

    assert all(call["reasoning_effort"] == "medium" for call in completions.calls)


def test_run_uses_model_from_args_not_hardcoded_groq_model(tmp_path, monkeypatch):
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    run_mod.run(_zero_shot_args(tmp_path / "out.jsonl", model="a-totally-different-model"))

    assert all(call["model"] == "a-totally-different-model" for call in completions.calls)


def test_run_meta_records_every_cli_arg(tmp_path, monkeypatch):
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    out_path = tmp_path / "out.jsonl"
    args = _zero_shot_args(out_path)
    run_mod.run(args)

    meta = json.loads(Path(str(out_path) + ".meta.json").read_text(encoding="utf-8"))
    for field in ("dataset", "setting", "k", "alpha", "pool_multiplier", "backend", "model", "reasoning_effort", "limit"):
        assert meta[field] == getattr(args, field)
