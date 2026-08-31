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
from pyq.rag.core.features import TfidfBackend  # noqa: E402


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


# ── Embedding cache: one file must serve every --limit value ─────────────────
#
# encode_cached keys its on-disk cache on (dataset, backend, split) -- not on
# --limit. _prepare always encodes the *full* test split and applies --limit
# afterward by slicing (see bench/run.py, bench/README.md#determinism). These
# tests use a tiny fake dataset (via monkeypatching bench.run.load_split)
# rather than the real vendored data, because exercising the real retrieval
# path (few_shot's retrieve_top_k) against a several-thousand-row train split
# is slow -- a synthetic 5-train/6-test split keeps this fast while still
# going through _prepare/encode_cached/select_examples for real.

def _fake_bench_records(split: str) -> list[dict]:
    if split == "train":
        return [
            {"idx": i, "sentence": f"train sentence {i} about topic {i % 3}", "label": i % 2}
            for i in range(5)
        ]
    if split == "test":
        # Deliberately out of id order, to prove the ascending-id sort (see
        # README's Determinism section) still holds after slicing by --limit.
        return [
            {"idx": i, "sentence": f"test sentence {i} about topic {i % 3}", "label": i % 2}
            for i in (5, 2, 4, 0, 3, 1)
        ]
    raise AssertionError(f"unexpected split {split!r}")


def _fake_load_split(dataset: str, split: str, data_dir=None) -> list[dict]:
    return _fake_bench_records(split)


def _few_shot_args(out_path: Path, limit: int | None) -> SimpleNamespace:
    return SimpleNamespace(
        dataset="cola",
        setting="few_shot",
        k=2,
        alpha=0.5,
        pool_multiplier=2,
        backend="tfidf",
        model="fake-model",
        reasoning_effort="none",
        limit=limit,
        out=out_path,
    )


@pytest.fixture
def _isolated_embed_cache(tmp_path, monkeypatch):
    """Isolates bench.run's embedding cache (separate from the response cache
    the autouse fixture above handles) to a tmp dir, and swaps in the tiny
    fake dataset above so encoding stays fast."""
    monkeypatch.setattr(run_mod, "CACHE_DIR", tmp_path / "embed_cache")
    monkeypatch.setattr(run_mod, "load_split", _fake_load_split)


@pytest.fixture
def _counting_tfidf_encode(monkeypatch):
    """Counts real TfidfBackend.encode() calls across every run() in the
    test, so a test can assert a second run reused the on-disk cache (0 new
    calls) instead of re-encoding."""
    original_encode = TfidfBackend.encode
    calls = {"n": 0}

    def counting_encode(self, texts):
        calls["n"] += 1
        return original_encode(self, texts)

    monkeypatch.setattr(TfidfBackend, "encode", counting_encode)
    return calls


def _row_ids(path: Path) -> list[int]:
    lines = path.read_text(encoding="utf-8").strip().splitlines()
    return [json.loads(line)["id"] for line in lines]


def test_encode_cache_serves_full_run_after_limited_run(
    tmp_path, monkeypatch, _isolated_embed_cache, _counting_tfidf_encode
):
    """A --limit run followed by an unlimited run against the same cache dir
    must not crash (this used to raise IndexError -- see bench/run.py's
    encode_cached/_prepare) and must reuse the cached embeddings rather than
    re-encoding."""
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    limited_out = tmp_path / "limited.jsonl"
    run_mod.run(_few_shot_args(limited_out, limit=3))
    assert _counting_tfidf_encode["n"] == 2  # train + test, each encoded once (full test split)
    assert _row_ids(limited_out) == [0, 1, 2]  # ascending id order, first 3 of 6

    full_out = tmp_path / "full.jsonl"
    run_mod.run(_few_shot_args(full_out, limit=None))  # must not raise IndexError
    assert _counting_tfidf_encode["n"] == 2  # cache hit -- no re-encode
    assert _row_ids(full_out) == [0, 1, 2, 3, 4, 5]


def test_encode_cache_serves_limited_run_after_full_run(
    tmp_path, monkeypatch, _isolated_embed_cache, _counting_tfidf_encode
):
    """Same guarantee in the opposite order: an unlimited run followed by a
    --limit run must reuse the cache (not just tolerate a size mismatch by
    re-encoding every time) and must agree with the unlimited run's own
    first N rows."""
    completions = _RecordingCompletions()
    monkeypatch.setattr(run_mod, "get_groq_client", lambda: _FakeClient(completions))

    full_out = tmp_path / "full.jsonl"
    run_mod.run(_few_shot_args(full_out, limit=None))
    assert _counting_tfidf_encode["n"] == 2
    assert _row_ids(full_out) == [0, 1, 2, 3, 4, 5]

    limited_out = tmp_path / "limited.jsonl"
    run_mod.run(_few_shot_args(limited_out, limit=3))
    assert _counting_tfidf_encode["n"] == 2  # cache hit -- no re-encode

    def _rows(path: Path) -> list[dict]:
        return [
            {k: v for k, v in json.loads(line).items() if k != "cached"}
            for line in path.read_text(encoding="utf-8").strip().splitlines()
        ]

    full_rows = _rows(full_out)
    limited_rows = _rows(limited_out)
    assert [r["id"] for r in limited_rows] == [0, 1, 2]
    assert limited_rows == full_rows[:3]  # same predictions, same order
