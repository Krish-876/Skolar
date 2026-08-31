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

from pyq.rag.core.features import Backend, EMBED_MODEL, SbertBackend, TfidfBackend  # noqa: E402
from pyq.rag.llm.client import get_groq_client  # noqa: E402

from bench.cache import get_cached_response, response_cache_key, save_cached_response  # noqa: E402
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


# ── Encoding cache: keyed by (dataset, backend, split) -- deliberately NOT by
# --limit, so one cache file serves every limit value for a given split. A
# run always encodes the full split (see _prepare); --limit only slices the
# already-encoded result. encode_cached also guards against a cache file that
# predates this scheme (written under a since-fixed version that keyed the
# same file to a --limit-truncated array): a shape mismatch against the
# current (full) texts list is treated as a cache miss and the file is
# rewritten, so no manual cache-busting is needed after this fix. ──────────

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


def _embedding_cache_key(backend_name: str) -> str:
    """Cache key component identifying not just the backend family but the
    exact embedding model behind it -- without this, cached sbert vectors
    would be silently (and wrongly) reused if EMBED_MODEL ever changed."""
    if backend_name == "sbert":
        return f"{backend_name}-{EMBED_MODEL}"
    return backend_name


def encode_cached(dataset: str, backend_name: str, backend: Backend, split: str, texts: list[str]):
    key = _embedding_cache_key(backend_name)
    cached = _load_cached_vectors(dataset, key, split)
    if cached is not None and cached.shape[0] == len(texts):
        return cached
    vecs = backend.encode(texts)
    _save_cached_vectors(dataset, key, split, vecs)
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
    p.add_argument(
        "--seed", type=int, default=SEED,
        help="Random seed. Currently only guards library RNG state -- retrieval/MMR selection "
             "is fully deterministic (see README's Determinism section), so this has no effect "
             "on output today. Plumbed through end to end so bench/sweep.py can sweep it, and so "
             "it's ready the day selection gains any seed-dependent behavior.",
    )
    p.add_argument("--out", required=True, type=Path, help="Output JSONL path.")
    return p


# ── Shared config prep ────────────────────────────────────────────────────────

def _prepare(args: argparse.Namespace, backend: Backend | None = None):
    """Loads data, builds the label map, and -- for non-zero_shot settings --
    fits/encodes the retrieval corpus for one (dataset, setting, backend)
    config. Shared by run() (real calls) and iter_prompts() (bench/sweep.py's
    --estimate path) so both build prompts through the exact same code path
    and can never drift out of sync with each other.

    Pass a pre-built `backend` (e.g. bench/sweep.py sharing one SbertBackend
    across every config in a sweep) to skip constructing a fresh one.

    --limit is applied *after* encoding, by slicing the already-encoded
    test_records/test_vecs, rather than by truncating test_records before
    encoding -- so encode_cached always sees (and caches) the full test
    split, and its on-disk cache file is valid for any --limit value, not
    just the one a particular run happened to pass. train_records/train_vecs
    are never limited (they weren't before this change either): the
    retrieval corpus a setting draws its k/pool examples from is always the
    full (subsampled, see README) train split.
    """
    dataset = args.dataset.lower()
    setting = args.setting.lower()

    train_records = load_split(dataset, "train")
    test_records = load_split(dataset, "test")
    test_records = sorted(test_records, key=lambda s: sample_id(dataset, s))

    label_map_ = label_map(dataset, train_records)

    train_vecs = test_vecs = None
    backend = backend or get_backend(args.backend)
    if setting != "zero_shot":
        train_texts = [extract_text(dataset, s) for s in train_records]
        test_texts = [extract_text(dataset, s) for s in test_records]
        backend.fit(train_texts)
        train_vecs = encode_cached(dataset, args.backend, backend, "train", train_texts)
        test_vecs = encode_cached(dataset, args.backend, backend, "test", test_texts)

    if args.limit is not None:
        test_records = test_records[: args.limit]
        if test_vecs is not None:
            test_vecs = test_vecs[: args.limit]

    return train_records, test_records, label_map_, train_vecs, test_vecs, backend


def iter_prompts(args: argparse.Namespace, backend: Backend | None = None):
    """Yields (sample, prompt) for every test sample this config would send
    to the model -- pure CPU work, no API calls. Used by bench/sweep.py's
    --estimate to preview exactly what a real run() of this config would
    produce."""
    train_records, test_records, label_map_, train_vecs, test_vecs, backend = _prepare(args, backend)
    dataset = args.dataset.lower()
    setting = args.setting.lower()
    for i, sample in enumerate(test_records):
        query_vec = test_vecs[i] if test_vecs is not None else None
        examples = select_examples(
            setting, query_vec, train_vecs, train_records,
            k=args.k, alpha=args.alpha, pool_multiplier=args.pool_multiplier,
            backend=backend,
        )
        prompt = build_prompt(dataset, sample, examples, label_map_)
        yield sample, prompt


# ── Main ────────────────────────────────────────────────────────────────────

def run(args: argparse.Namespace, backend: Backend | None = None) -> None:
    if RateLimitError is None:  # pragma: no cover
        raise RuntimeError("groq package is required to run bench/run.py (see requirements.txt).")

    seed = getattr(args, "seed", SEED)
    np.random.seed(seed)

    dataset = args.dataset.lower()
    setting = args.setting.lower()

    train_records, test_records, label_map_, train_vecs, test_vecs, backend = _prepare(args, backend)

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
        "seed": seed,
        "n_samples_total": len(test_records),
        "n_samples_written": 0,
        "n_cache_hits": 0,
        "partial": True,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "finished_at": None,
    }

    n_written = 0
    n_cache_hits = 0
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

                # Response cache: identical (model, reasoning_effort, prompt)
                # triples skip the API call entirely -- see bench/cache.py.
                # zero_shot rows (and anything else that recurs across a
                # sweep's k/alpha/seed axes) become free after the first hit.
                cache_key = response_cache_key(args.model, args.reasoning_effort, prompt)
                cached_row = get_cached_response(cache_key)
                if cached_row is not None:
                    raw_completion = cached_row["raw_completion"]
                    prediction = cached_row["prediction"]
                    prompt_tokens = cached_row["prompt_tokens"]
                    completion_tokens = cached_row["completion_tokens"]
                    is_cached = True
                    n_cache_hits += 1
                else:
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
                    prompt_tokens = usage.prompt_tokens if usage else None
                    completion_tokens = usage.completion_tokens if usage else None
                    is_cached = False

                    save_cached_response(cache_key, {
                        "raw_completion": raw_completion,
                        "prediction": prediction,
                        "prompt_tokens": prompt_tokens,
                        "completion_tokens": completion_tokens,
                    })

                row = {
                    "id": sample_id(dataset, sample),
                    "gold": gold_label(dataset, sample, label_map_),
                    "raw_completion": raw_completion,
                    "prediction": prediction,
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "cached": is_cached,
                }
                out_f.write(json.dumps(row, sort_keys=True) + "\n")
                out_f.flush()
                n_written += 1
        completed = True
    except DailyCapReached as exc:
        logger.error(f"[bench] {exc}")
    finally:
        meta["n_samples_written"] = n_written
        meta["n_cache_hits"] = n_cache_hits
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
