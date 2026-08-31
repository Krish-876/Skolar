"""
Unit tests for bench/sweep.py's cost controls: grid expansion (per-setting
axis dedup), max_calls validation, the --estimate cost preview, and the
max_calls refusal path.

Uses the real vendored cola data with the tfidf backend (no sentence-
transformers load, no network) and a fake Groq client is never even reached
in these tests -- --estimate and the refusal path both stop before any API
call, which is the behaviour under test.
"""

import sys
from pathlib import Path

import pytest
import yaml

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

import bench.cache as cache_mod  # noqa: E402
import bench.sweep as sweep_mod  # noqa: E402


@pytest.fixture(autouse=True)
def _isolated_response_cache(tmp_path, monkeypatch):
    monkeypatch.setattr(cache_mod, "CACHE_DIR", tmp_path / "response_cache")


def _base_grid(**overrides) -> dict:
    grid = {
        "max_calls": 100,
        "model": "fake-model",
        "reasoning_effort": "none",
        "backend": "tfidf",
        "pool_multiplier": 2,
        "limit": 2,
        "datasets": ["cola"],
        "settings": ["zero_shot"],
        "k": [2, 4],
        "alpha": [0.1, 0.9],
        "seeds": [0],
    }
    grid.update(overrides)
    return grid


# ── expand_grid: per-setting axis dedup ──────────────────────────────────────

def test_zero_shot_ignores_k_and_alpha(tmp_path):
    configs = sweep_mod.expand_grid(_base_grid(settings=["zero_shot"]), tmp_path)
    assert len(configs) == 1  # k=[2,4] x alpha=[0.1,0.9] would be 4 without dedup


def test_few_shot_ignores_alpha_but_not_k(tmp_path):
    configs = sweep_mod.expand_grid(_base_grid(settings=["few_shot"]), tmp_path)
    assert len(configs) == 2  # one per k; alpha=[0.1, 0.9] would double this without dedup
    assert sorted(c.k for c in configs) == [2, 4]


def test_mmr_few_shot_uses_both_k_and_alpha(tmp_path):
    configs = sweep_mod.expand_grid(_base_grid(settings=["mmr_few_shot"]), tmp_path)
    assert len(configs) == 4  # full k x alpha cross product


def test_seeds_multiply_every_setting(tmp_path):
    configs = sweep_mod.expand_grid(_base_grid(settings=["zero_shot"], seeds=[0, 1, 2]), tmp_path)
    assert len(configs) == 3


def test_unknown_dataset_rejected(tmp_path):
    with pytest.raises(ValueError, match="Unknown dataset"):
        sweep_mod.expand_grid(_base_grid(datasets=["not-a-real-dataset"]), tmp_path)


def test_unknown_setting_rejected(tmp_path):
    with pytest.raises(ValueError, match="Unknown setting"):
        sweep_mod.expand_grid(_base_grid(settings=["not-a-real-setting"]), tmp_path)


# ── load_grid: required keys ─────────────────────────────────────────────────

def test_load_grid_requires_max_calls(tmp_path):
    path = tmp_path / "grid.yaml"
    path.write_text(yaml.safe_dump({"model": "m"}), encoding="utf-8")
    with pytest.raises(ValueError, match="max_calls"):
        sweep_mod.load_grid(path)


def test_load_grid_requires_model(tmp_path):
    path = tmp_path / "grid.yaml"
    path.write_text(yaml.safe_dump({"max_calls": 10}), encoding="utf-8")
    with pytest.raises(ValueError, match="model"):
        sweep_mod.load_grid(path)


# ── estimate_sweep: cache-aware call counting ────────────────────────────────

def test_estimate_counts_duplicate_configs_as_cache_hits(tmp_path):
    # Two zero_shot configs differing only by seed produce byte-identical
    # prompts today (nothing in the pipeline is seed-dependent yet -- see
    # bench/run.py's --seed help), so the second should come back as 100%
    # cache hits against the first, on a fresh (empty) response cache.
    grid = _base_grid(settings=["zero_shot"], seeds=[0, 1], limit=2)
    configs = sweep_mod.expand_grid(grid, tmp_path)
    assert len(configs) == 2

    estimate = sweep_mod.estimate_sweep(configs)
    assert estimate.total_rows == 4        # 2 configs x 2 samples
    assert estimate.cache_hits == 2        # seed=1's 2 rows duplicate seed=0's
    assert estimate.net_new_calls == 2
    assert estimate.est_tokens > 0


def test_estimate_sweep_never_touches_a_fake_groq_client(tmp_path, monkeypatch):
    """--estimate must be pure CPU/disk work -- if it ever tried to call the
    API, get_groq_client() (unpatched here) would blow up on a missing
    GROQ_API_KEY before this even got to asserting anything."""
    configs = sweep_mod.expand_grid(_base_grid(), tmp_path)
    sweep_mod.estimate_sweep(configs)  # must not raise / must not need a client


# ── main(): --estimate and max_calls refusal ─────────────────────────────────

def _write_grid(tmp_path: Path, **overrides) -> Path:
    path = tmp_path / "grid.yaml"
    path.write_text(yaml.safe_dump(_base_grid(**overrides)), encoding="utf-8")
    return path


def test_main_estimate_flag_exits_cleanly_even_over_budget(tmp_path, capsys):
    config_path = _write_grid(tmp_path, max_calls=0, out_dir=str(tmp_path / "raw"))
    sweep_mod.main(["--config", str(config_path), "--estimate"])  # must not raise
    out = capsys.readouterr().out
    assert "EXCEEDS max_calls" in out


def test_main_refuses_to_run_when_over_max_calls(tmp_path):
    config_path = _write_grid(tmp_path, max_calls=0, out_dir=str(tmp_path / "raw"))
    with pytest.raises(SystemExit, match="Refusing to start"):
        sweep_mod.main(["--config", str(config_path)])
    assert not (tmp_path / "raw").exists()  # never got far enough to write output
