"""
bench/run.py -- run one (dataset, setting, backend, model, reasoning-effort)
configuration over a labelled classification split and write predictions.

This is NOT a replication of the Diverse-ICL (SIGIR'25) paper -- we reuse its
datasets and its retrieve-then-rerank *method*, but its Skolar implementation
(backend/pyq/rag/core) is what actually gets measured here: retrieve_top_k,
mmr, and the Backend classes are imported from there, never reimplemented.
See bench/README.md.

Usage:
    python bench/run.py --dataset sst2 --setting mmr_few_shot --k 4 --alpha 0.7 \
        --backend sbert --model llama-3.3-70b-versatile --reasoning-effort none \
        --limit 5 --out bench/results/sst2_mmr_smoke.jsonl
"""

import argparse
import json
import logging
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
from scipy import sparse

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.features import Backend, SbertBackend, TfidfBackend  # noqa: E402
from pyq.rag.llm.client import get_groq_client  # noqa: E402

from bench.datasets import (  # noqa: E402
    DATASET_NAMES,
    extract_text,
    gold_label,
    label_map,
    load_split,
    sample_id,
)
from bench.prompts import build_prompt, parse_prediction  # noqa: E402
from bench.select import SETTING_NAMES, select_examples  # noqa: E402

try:
    from groq import RateLimitError
except ImportError:  # pragma: no cover -- groq is a hard dependency in requirements.txt
    RateLimitError = None

logger = logging.getLogger("bench.run")

CACHE_DIR = Path(__file__).resolve().parent / ".cache"

# Groq free tier: 30 requests/min, 1000 requests/day.
GROQ_RPM_LIMIT = 30
MAX_RATE_LIMIT_RETRIES = 5

SEED = 0  # fixed for reproducibility; nothing in this harness is randomized,
          # this just guards against any library defaulting to nondeterministic state.


class DailyCapReached(RuntimeError):
    """Raised when Groq's daily request cap (or persistent rate limiting) is hit."""


# ── Encoding cache: keyed by (dataset, backend, split) ────────────────────────

def _cache_file(dataset: str, backend_name: str, split: str, is_sparse: bool) -> Path:
    ext = "npz" if is_sparse else "npy"
    return CACHE_DIR / f"{dataset}__{backend_name}__{split}.{ext}"


def _load_cached_vectors(dataset: str, backend_name: str, split: str):
    dense_path = _cache_file(dataset, backend_name, split, is_sparse=False)
    if dense_path.exists():
        return np.load(dense_path)
    sparse_path = _cache_file(dataset, backend_name, split, is_sparse=True)
    if sparse_path.exists():
        return sparse.load_npz(sparse_path)
    return None


def _save_cached_vectors(dataset: str, backend_name: str, split: str, vecs) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if sparse.issparse(vecs):
        sparse.save_npz(_cache_file(dataset, backend_name, split, is_sparse=True), vecs)
    else:
        np.save(_cache_file(dataset, backend_name, split, is_sparse=False), vecs)


def encode_cached(dataset: str, backend_name: str, backend: Backend, split: str, texts: list[str]):
    cached = _load_cached_vectors(dataset, backend_name, split)
    if cached is not None:
        return cached
    vecs = backend.encode(texts)
    _save_cached_vectors(dataset, backend_name, split, vecs)
    return vecs


def get_backend(name: str) -> Backend:
    name = name.lower()
    if name == "sbert":
        return SbertBackend()
    if name == "tfidf":
        return TfidfBackend()
    raise ValueError(f"Unknown backend {name!r}. Expected 'sbert' or 'tfidf'.")


# ── Rate limiting / retry ──────────────────────────────────────────────────────

class RateLimiter:
    """Proactive client-side limiter so we don't rely solely on 429 retries."""

    def __init__(self, max_per_minute: int = GROQ_RPM_LIMIT):
        self.max_per_minute = max_per_minute
        self._timestamps: list[float] = []

    def wait(self) -> None:
        now = time.monotonic()
        self._timestamps = [t for t in self._timestamps if now - t < 60]
        if len(self._timestamps) >= self.max_per_minute:
            sleep_for = 60 - (now - self._timestamps[0]) + 0.1
            if sleep_for > 0:
                time.sleep(sleep_for)
            now = time.monotonic()
            self._timestamps = [t for t in self._timestamps if now - t < 60]
        self._timestamps.append(now)


def _is_daily_cap_message(message: str) -> bool:
    lowered = message.lower()
    return "per day" in lowered or "rpd" in lowered


def _retry_after_seconds(exc, default: float) -> float:
    response = getattr(exc, "response", None)
    if response is not None:
        header = response.headers.get("retry-after")
        if header is not None:
            try:
                return float(header)
            except ValueError:
                pass
    return default


def call_with_backoff(fn, *args, **kwargs):
    """Calls fn(*args, **kwargs), retrying on Groq 429s with backoff. Raises
    DailyCapReached (rather than retrying forever) once the error message
    indicates a per-day limit, or after MAX_RATE_LIMIT_RETRIES RPM retries."""
    delay = 2.0
    for attempt in range(1, MAX_RATE_LIMIT_RETRIES + 1):
        try:
            return fn(*args, **kwargs)
        except RateLimitError as exc:
            message = str(exc)
            if _is_daily_cap_message(message):
                raise DailyCapReached(f"Groq daily rate limit reached: {message}") from exc
            if attempt == MAX_RATE_LIMIT_RETRIES:
                raise DailyCapReached(
                    f"Exceeded {MAX_RATE_LIMIT_RETRIES} retries against Groq's per-minute "
                    f"rate limit: {message}"
                ) from exc
            wait_for = _retry_after_seconds(exc, default=delay)
            logger.warning(
                f"[bench] rate limited (attempt {attempt}/{MAX_RATE_LIMIT_RETRIES}), "
                f"retrying in {wait_for:.1f}s"
            )
            time.sleep(wait_for)
            delay = min(delay * 2, 60.0)
    raise AssertionError("unreachable")  # pragma: no cover


# ── CLI ─────────────────────────────────────────────────────────────────────

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        description="Measure a retrieval/reranking + model configuration on labelled classification data."
    )
    p.add_argument("--dataset", required=True, choices=DATASET_NAMES)
    p.add_argument("--setting", required=True, choices=SETTING_NAMES)
    p.add_argument("--k", type=int, default=4, help="Number of in-context examples (ignored for zero_shot).")
    p.add_argument("--alpha", type=float, default=0.7, help="MMR relevance/diversity tradeoff (mmr_few_shot only).")
    p.add_argument(
        "--pool-multiplier", type=int, default=3, dest="pool_multiplier",
        help="mmr_few_shot retrieves a pool of pool_multiplier * k candidates before reranking to k.",
    )
    p.add_argument("--backend", choices=("sbert", "tfidf"), default="sbert")
    p.add_argument("--model", required=True, help="Groq model id, e.g. llama-3.3-70b-versatile.")
    p.add_argument(
        "--reasoning-effort", choices=("none", "low", "medium", "high"), default="none",
        dest="reasoning_effort",
        help="Groq reasoning_effort param. 'none' omits the param entirely rather than sending it.",
    )
    p.add_argument("--limit", type=int, default=None, help="Only run the first N test samples (sorted by id).")
    p.add_argument("--out", required=True, type=Path, help="Output JSONL path.")
    return p


# ── Main ────────────────────────────────────────────────────────────────────

def run(args: argparse.Namespace) -> None:
    if RateLimitError is None:  # pragma: no cover
        raise RuntimeError("groq package is required to run bench/run.py (see requirements.txt).")

    np.random.seed(SEED)

    dataset = args.dataset.lower()
    setting = args.setting.lower()

    train_records = load_split(dataset, "train")
    test_records = load_split(dataset, "test")
    test_records = sorted(test_records, key=lambda s: sample_id(dataset, s))
    if args.limit is not None:
        test_records = test_records[: args.limit]

    label_map_ = label_map(dataset, train_records)

    train_vecs = test_vecs = None
    backend = get_backend(args.backend)
    if setting != "zero_shot":
        train_texts = [extract_text(dataset, s) for s in train_records]
        test_texts = [extract_text(dataset, s) for s in test_records]
        backend.fit(train_texts)
        train_vecs = encode_cached(dataset, args.backend, backend, "train", train_texts)
        test_vecs = encode_cached(dataset, args.backend, backend, "test", test_texts)

    client = get_groq_client()
    limiter = RateLimiter()

    args.out.parent.mkdir(parents=True, exist_ok=True)
    meta_path = Path(str(args.out) + ".meta.json")

    meta = {
        "dataset": dataset,
        "setting": setting,
        "k": args.k,
        "alpha": args.alpha,
        "pool_multiplier": args.pool_multiplier,
        "backend": args.backend,
        "model": args.model,
        "reasoning_effort": args.reasoning_effort,
        "limit": args.limit,
        "out": str(args.out),
        "seed": SEED,
        "n_samples_total": len(test_records),
        "n_samples_written": 0,
        "partial": True,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "finished_at": None,
    }

    n_written = 0
    completed = False
    try:
        with open(args.out, "w", encoding="utf-8") as out_f:
            for i, sample in enumerate(test_records):
                query_vec = test_vecs[i] if test_vecs is not None else None
                examples = select_examples(
                    setting,
                    query_vec,
                    train_vecs,
                    train_records,
                    k=args.k,
                    alpha=args.alpha,
                    pool_multiplier=args.pool_multiplier,
                    backend=backend,
                )
                prompt = build_prompt(dataset, sample, examples, label_map_)

                completion_kwargs = {"model": args.model, "temperature": 0}
                if args.reasoning_effort != "none":
                    completion_kwargs["reasoning_effort"] = args.reasoning_effort

                limiter.wait()
                response = call_with_backoff(
                    client.chat.completions.create,
                    messages=[{"role": "user", "content": prompt}],
                    **completion_kwargs,
                )

                raw_completion = response.choices[0].message.content.strip()
                prediction = parse_prediction(raw_completion, label_map_)
                usage = response.usage

                row = {
                    "id": sample_id(dataset, sample),
                    "gold": gold_label(dataset, sample, label_map_),
                    "raw_completion": raw_completion,
                    "prediction": prediction,
                    "prompt_tokens": usage.prompt_tokens if usage else None,
                    "completion_tokens": usage.completion_tokens if usage else None,
                }
                out_f.write(json.dumps(row, sort_keys=True) + "\n")
                out_f.flush()
                n_written += 1
        completed = True
    except DailyCapReached as exc:
        logger.error(f"[bench] {exc}")
    finally:
        meta["n_samples_written"] = n_written
        meta["partial"] = not completed
        meta["finished_at"] = datetime.now(timezone.utc).isoformat()
        with open(meta_path, "w", encoding="utf-8") as meta_f:
            json.dump(meta, meta_f, indent=2, sort_keys=True)

    if not completed:
        raise SystemExit(
            f"bench run stopped early after {n_written}/{len(test_records)} samples -- "
            f"see {meta_path} (partial=true) for what was recorded before it stopped."
        )


def main(argv: list[str] | None = None) -> None:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    args = build_arg_parser().parse_args(argv)
    run(args)


if __name__ == "__main__":
    main()
