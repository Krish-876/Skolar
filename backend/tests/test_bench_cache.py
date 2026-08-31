"""
Unit tests for bench/cache.py's on-disk response cache: key composition and
a get/save round trip. No API calls, no real bench/.cache/ writes -- CACHE_DIR
is monkeypatched to a tmp path.
"""

import sys
from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import bench.cache as cache_mod  # noqa: E402


@pytest.fixture(autouse=True)
def _isolated_cache_dir(tmp_path, monkeypatch):
    monkeypatch.setattr(cache_mod, "CACHE_DIR", tmp_path / "responses")


def test_get_cached_response_is_none_before_any_save():
    key = cache_mod.response_cache_key("m", "none", "prompt")
    assert cache_mod.get_cached_response(key) is None


def test_save_then_get_round_trips():
    key = cache_mod.response_cache_key("m", "none", "prompt")
    payload = {
        "raw_completion": "positive",
        "prediction": "positive",
        "prompt_tokens": 12,
        "completion_tokens": 1,
    }
    cache_mod.save_cached_response(key, payload)
    assert cache_mod.get_cached_response(key) == payload


def test_key_changes_with_model_reasoning_effort_or_prompt():
    base = cache_mod.response_cache_key("model-a", "none", "hello")
    assert base != cache_mod.response_cache_key("model-b", "none", "hello")
    assert base != cache_mod.response_cache_key("model-a", "high", "hello")
    assert base != cache_mod.response_cache_key("model-a", "none", "goodbye")


def test_key_does_not_collide_across_field_boundaries():
    # Without a delimiter, model="a"+effort="bc" and model="ab"+effort="c"
    # would hash identically since "a"+"bc" == "ab"+"c" as plain concatenation.
    a = cache_mod.response_cache_key("a", "bc", "prompt")
    b = cache_mod.response_cache_key("ab", "c", "prompt")
    assert a != b


def test_identical_inputs_produce_identical_key():
    a = cache_mod.response_cache_key("m", "none", "same prompt")
    b = cache_mod.response_cache_key("m", "none", "same prompt")
    assert a == b
