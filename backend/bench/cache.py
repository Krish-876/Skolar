"""
bench/cache.py -- on-disk cache for Groq chat-completion responses, keyed by
the exact (model, reasoning_effort, prompt) triple that produced them.

This is what makes re-running a sweep cheap: a zero_shot prompt doesn't
depend on k/alpha/seed at all, and a config re-run against unchanged data
reproduces byte-identical prompts -- so after the first real call, every
later recurrence of that exact prompt is a free cache hit instead of a spent
API call. See bench/README.md#sweeping.

CACHE_DIR is a plain module global (not a constructor arg), the same pattern
bench/run.py's own CACHE_DIR (for cached embeddings) already uses, so tests
can monkeypatch it to a tmp directory instead of touching the real
gitignored bench/.cache/ on disk.
"""

import hashlib
import json
from pathlib import Path

CACHE_DIR = Path(__file__).resolve().parent / ".cache" / "responses"


def response_cache_key(model: str, reasoning_effort: str, prompt: str) -> str:
    """sha256 over model + reasoning_effort + the exact prompt string. An
    ASCII unit-separator sits between fields so e.g. model='a', effort='bc'
    can never hash the same as model='ab', effort='c'."""
    payload = "\x1f".join([model, reasoning_effort, prompt]).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _cache_path(key: str) -> Path:
    return CACHE_DIR / f"{key}.json"


def get_cached_response(key: str) -> dict | None:
    path = _cache_path(key)
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save_cached_response(key: str, response: dict) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    path = _cache_path(key)
    # Write-then-rename so a sweep killed mid-write never leaves a truncated
    # cache entry that a later run would try (and fail) to parse.
    tmp_path = path.with_suffix(".json.tmp")
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(response, f, sort_keys=True)
    tmp_path.replace(path)
