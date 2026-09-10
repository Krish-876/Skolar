"""
bench/sweep.py -- run a grid of bench/run.py configs from a YAML spec, with
built-in cost controls: a cheap `--estimate` preview, a hard `max_calls`
budget the grid can't silently exceed, and cache-aware execution so
re-running a sweep after it's already run once costs close to nothing.

Configs run in-process (import + call bench.run.run(), never a subprocess per
config) so the process-wide SentenceTransformer singleton in
pyq.rag.core.features.get_embed_model() is loaded once for the whole sweep,
not once per config -- see bench/README.md#sweeping.

Usage:
    python -m bench.sweep --estimate                              # cost preview, no API calls
    python -m bench.sweep                                          # run sweeps/default.yaml
    python -m bench.sweep --config bench/sweeps/full.yaml --estimate
    python -m bench.sweep --config bench/sweeps/full.yaml

See bench/README.md#sweeping for the grid YAML schema.
"""

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from types import SimpleNamespace

import yaml

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.features import Backend  # noqa: E402

from bench.cache import get_cached_response, response_cache_key  # noqa: E402
from bench.datasets import DATASET_NAMES  # noqa: E402
from bench.run import get_backend, iter_prompts, run  # noqa: E402
from bench.selection import SETTING_NAMES  # noqa: E402

DEFAULT_CONFIG = Path(__file__).resolve().parent / "sweeps" / "default.yaml"

# Rough, deliberately conservative heuristic (English averages ~4 chars/token)
# -- --estimate only needs to be in the right ballpark to stop someone from
# accidentally starting a five-figure-call run, not to predict Groq's exact
# billed tokens.
_CHARS_PER_TOKEN = 4
_ASSUMED_COMPLETION_TOKENS = 20  # these are one-label classification answers


@dataclass
class SweepConfig:
    dataset: str
    setting: str
    k: int
    alpha: float
    seed: int
    backend: str
    model: str
    reasoning_effort: str
    pool_multiplier: int
    limit: int | None
    out: Path

    def to_namespace(self) -> SimpleNamespace:
        return SimpleNamespace(
            dataset=self.dataset, setting=self.setting, k=self.k, alpha=self.alpha,
            pool_multiplier=self.pool_multiplier, backend=self.backend, model=self.model,
            reasoning_effort=self.reasoning_effort, limit=self.limit, seed=self.seed,
            out=self.out,
        )

    @property
    def label(self) -> str:
        parts = [self.dataset, self.setting]
        if self.setting != "zero_shot":
            parts.append(f"k{self.k}")
        if self.setting == "mmr_few_shot":
            parts.append(f"a{self.alpha}")
        parts.append(f"seed{self.seed}")
        return "__".join(parts)


def load_grid(path: Path) -> dict:
    with open(path, encoding="utf-8") as f:
        grid = yaml.safe_load(f)
    if "max_calls" not in grid:
        raise ValueError(
            f"{path} is missing a `max_calls` key -- every sweep grid must set an "
            "explicit budget so a sweep can never silently spend more calls than you "
            "meant it to. See bench/README.md#sweeping."
        )
    if "model" not in grid:
        raise ValueError(f"{path} is missing `model` (a Groq model id).")
    return grid


def expand_grid(grid: dict, out_dir: Path) -> list[SweepConfig]:
    """Cartesian-expands the grid, but only over the axes each setting
    actually reads: alpha never changes few_shot's prompt, and neither k nor
    alpha changes zero_shot's -- looping them anyway would just enumerate
    literal duplicate configs (the response cache would make the repeats free
    API-cost-wise, but there's no reason to even generate them).

    `seed` is looped for every setting regardless. Retrieval/MMR selection is
    currently fully deterministic (see bench/run.py's --seed help and
    README's Determinism section), so today two configs that differ only by
    seed produce byte-identical prompts -- this is exactly the kind of
    cross-config recurrence the response cache is designed to make free, and
    it's a genuine axis the day selection gains any seed-dependent behavior.
    """
    datasets = grid.get("datasets") or list(DATASET_NAMES)
    settings = grid.get("settings") or list(SETTING_NAMES)
    ks = grid.get("k") or [4]
    alphas = grid.get("alpha") or [0.7]
    seeds = grid.get("seeds") or [0]

    backend = grid.get("backend", "sbert")
    model = grid["model"]
    reasoning_effort = grid.get("reasoning_effort", "none")
    pool_multiplier = grid.get("pool_multiplier", 3)
    limit = grid.get("limit")

    configs: list[SweepConfig] = []
    for dataset in datasets:
        if dataset not in DATASET_NAMES:
            raise ValueError(f"Unknown dataset {dataset!r} in grid. Expected one of {DATASET_NAMES}.")

        for setting in settings:
            if setting == "zero_shot":
                axis = [(ks[0], alphas[0])]
            elif setting == "few_shot":
                axis = [(k, alphas[0]) for k in ks]
            elif setting == "mmr_few_shot":
                axis = [(k, alpha) for k in ks for alpha in alphas]
            else:
                raise ValueError(f"Unknown setting {setting!r} in grid. Expected one of {SETTING_NAMES}.")

            for k, alpha in axis:
                for seed in seeds:
                    configs.append(SweepConfig(
                        dataset=dataset, setting=setting, k=k, alpha=alpha, seed=seed,
                        backend=backend, model=model, reasoning_effort=reasoning_effort,
                        pool_multiplier=pool_multiplier, limit=limit,
                        out=out_dir / f"{dataset}__{setting}__k{k}__a{alpha}__seed{seed}.jsonl",
                    ))
    return configs


@dataclass
class Estimate:
    configs: int
    total_rows: int
    cache_hits: int
    net_new_calls: int
    est_tokens: int


def _shared_backend(cfg: SweepConfig, cache: dict[str, Backend]) -> Backend:
    key = f"{cfg.dataset}:{cfg.backend}"
    if key not in cache:
        cache[key] = get_backend(cfg.backend)
    return cache[key]


def estimate_sweep(configs: list[SweepConfig]) -> Estimate:
    """Builds every prompt every config would send (pure CPU work -- no API
    calls) and checks each one against the on-disk response cache, so the
    printed number is the real number of calls this sweep would spend right
    now, not a worst-case count that ignores what's already cached."""
    total_rows = 0
    cache_hits = 0
    est_tokens = 0
    seen_this_pass: set[str] = set()  # catches duplicates *within* this sweep
                                       # that haven't hit disk yet (see below)
    shared_backends: dict[str, Backend] = {}

    for cfg in configs:
        backend = _shared_backend(cfg, shared_backends)
        for _sample, prompt in iter_prompts(cfg.to_namespace(), backend=backend):
            total_rows += 1
            key = response_cache_key(cfg.model, cfg.reasoning_effort, prompt)
            if key in seen_this_pass or get_cached_response(key) is not None:
                cache_hits += 1
            else:
                seen_this_pass.add(key)
                est_tokens += len(prompt) // _CHARS_PER_TOKEN + _ASSUMED_COMPLETION_TOKENS

    return Estimate(
        configs=len(configs), total_rows=total_rows, cache_hits=cache_hits,
        net_new_calls=total_rows - cache_hits, est_tokens=est_tokens,
    )


def print_estimate(estimate: Estimate, max_calls: int) -> None:
    print(f"configs:          {estimate.configs}")
    print(f"total rows:       {estimate.total_rows}  (= calls with an empty cache)")
    print(f"cache hits:       {estimate.cache_hits}")
    print(f"net new calls:    {estimate.net_new_calls}")
    print(f"est. tokens:      ~{estimate.est_tokens:,} (prompt + completion, net-new calls only, rough)")
    print(f"max_calls budget: {max_calls}")
    if estimate.net_new_calls > max_calls:
        print(f"\nEXCEEDS max_calls ({estimate.net_new_calls} > {max_calls}) -- refusing to start.")
    else:
        print("\nwithin max_calls budget.")


def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Run a bench/run.py grid from a YAML sweep spec.")
    p.add_argument(
        "--config", type=Path, default=DEFAULT_CONFIG,
        help="Sweep grid YAML (default: bench/sweeps/default.yaml).",
    )
    p.add_argument("--estimate", action="store_true", help="Print a cost preview and exit -- no API calls.")
    return p


def main(argv: list[str] | None = None) -> None:
    args = build_arg_parser().parse_args(argv)

    grid = load_grid(args.config)
    out_dir = Path(grid.get("out_dir", "bench/results/raw"))
    configs = expand_grid(grid, out_dir)
    max_calls = grid["max_calls"]

    estimate = estimate_sweep(configs)
    print_estimate(estimate, max_calls)

    if args.estimate:
        return

    if estimate.net_new_calls > max_calls:
        raise SystemExit(
            f"\nRefusing to start: {estimate.net_new_calls} net-new calls exceeds "
            f"max_calls={max_calls} in {args.config}. Raise max_calls deliberately if "
            "this is really what you want, or narrow the grid."
        )

    print(f"\nRunning {len(configs)} configs...\n")
    shared_backends: dict[str, Backend] = {}
    for i, cfg in enumerate(configs, start=1):
        backend = _shared_backend(cfg, shared_backends)
        print(f"[{i}/{len(configs)}] {cfg.label} -> {cfg.out}")
        run(cfg.to_namespace(), backend=backend)


if __name__ == "__main__":
    main()
