"""
bench/report.py -- turn one sweep of bench/run.py outputs into bench/results/REPORT.md,
a single persistent report file, plus one appended row in bench/results/history.jsonl.

REPORT.md has two halves. The top half (How to run + the metric glossary) is
static and hand-editable -- this script writes it only once, when the file
doesn't exist yet, and never touches it again. Everything between
<!-- BENCH:BEGIN --> and <!-- BENCH:END --> is regenerated on every run; if
those markers are missing from an existing file, this script refuses to guess
and exits loudly rather than overwriting hand-edited content.

This module only *reads* what bench/run.py already wrote (bench/results/raw/<out>.jsonl
+ <out>.jsonl.meta.json) and calls back into bench.score / bench.select for
scoring and selection -- it never reimplements or re-tunes anything in
pyq.rag.core. Where the harness doesn't currently record a metric (per-request
latency, retry counts, 429-vs-other error counts, tokens/minute), the report
says so explicitly ("not recorded" / `null` in history.jsonl) instead of
approximating it.

For the diversity metrics (section 4) and the selection-health checks
(fewer-than-k / degenerate sets / determinism, section 2), the *example
selection itself* isn't in the output schema either -- run.py never logs
which train examples it picked for a given query. Those are recovered by
replaying bench.select.select_examples with the exact config recorded in
each run's meta.json against freshly-encoded query vectors and the same
cached train vectors run.py uses -- same production code path, not a
reimplementation, just called again after the fact.

Usage:
    python bench/report.py bench/results/raw/*.jsonl
    python bench/report.py --results-dir bench/results/raw --out-dir bench/results
"""

import argparse
import json
import subprocess
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from importlib.metadata import PackageNotFoundError, version
from pathlib import Path
from statistics import mean

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.core.features import Backend  # noqa: E402

from bench.datasets import extract_text, load_split, sample_id  # noqa: E402
from bench.run import encode_cached, get_backend  # noqa: E402
from bench.score import compute_metrics, load_results  # noqa: E402
from bench.select import select_examples  # noqa: E402

RESULTS_DIR = Path(__file__).resolve().parent / "results"
RAW_DIR = RESULTS_DIR / "raw"
GROQ_FREE_TIER_TOK_PER_MIN = 8000
PACKAGES_TRACKED = ("groq", "sentence-transformers", "scikit-learn", "scipy", "numpy")
DETERMINISM_SAMPLE_SIZE = 3  # rows per config re-checked for selection determinism

BEGIN_MARKER = "<!-- BENCH:BEGIN -->"
END_MARKER = "<!-- BENCH:END -->"

# ── Static "How to run" copy ─────────────────────────────────────────────────
# Kept identical (verbatim) to the matching block in bench/README.md -- if you
# change one, change the other so they don't drift.

HOW_TO_RUN = """\
cd backend

# Smoke sequence: zero_shot baseline + few_shot + mmr_few_shot on COLA, capped
# at 20 samples so it's fast and cheap to sanity-check end to end.
python bench/run.py --dataset cola --setting zero_shot \\
    --model openai/gpt-oss-120b --reasoning-effort none \\
    --limit 20 --out bench/results/raw/cola_zero_shot.jsonl

python bench/run.py --dataset cola --setting few_shot --k 4 \\
    --backend sbert --model openai/gpt-oss-120b --reasoning-effort none \\
    --limit 20 --out bench/results/raw/cola_few_shot_k4.jsonl

python bench/run.py --dataset cola --setting mmr_few_shot --k 4 --alpha 0.7 \\
    --backend sbert --model openai/gpt-oss-120b --reasoning-effort none \\
    --limit 20 --out bench/results/raw/cola_mmr_k4_a0.7.jsonl

# Turn every raw config under bench/results/raw/ into bench/results/REPORT.md,
# and append one row to bench/results/history.jsonl.
python bench/report.py --results-dir bench/results/raw --out-dir bench/results\
"""

# ── Interpretation copy ──────────────────────────────────────────────────────
# Static "what/direction/knob" prose for every metric surfaced in sections 2-4.
# The per-run number/finding is appended alongside this at render time --
# it can't live in this constant because it's data, not fixed prose.

EXPLANATIONS = {
    "grid_completion": (
        "Measures whether every config in the requested grid produced a complete "
        "(non-partial) results file. Good: PASS, i.e. every config finished. A FAIL "
        "here means at least one config was cut short (see run.py's `partial` flag) "
        "-- usually the Groq daily cap. Knob: re-run the missing config(s), or "
        "lower `--limit` so a sweep fits inside the daily request budget."
    ),
    "api_errors": (
        "Splits API failures into 429 rate-limit errors vs everything else, plus "
        "how many retries were spent recovering from them. Good: low counts of "
        "both, and few retries. Not recorded by the current harness -- "
        "call_with_backoff() only logs a warning on retry and never persists "
        "the count; needs a counter written into meta.json."
    ),
    "tokens_per_minute": (
        f"Peak tokens/minute against Groq's free-tier ceiling ({GROQ_FREE_TIER_TOK_PER_MIN} "
        "tok/min). Good: peak comfortably under the ceiling. A peak near or over it "
        "means requests are being throttled/dropped even if the run eventually "
        "completes. Not recorded -- no per-request timestamp is written alongside "
        "prompt_tokens/completion_tokens, so no per-minute series can be "
        "reconstructed. Needs a timestamp per row."
    ),
    "degenerate_sets": (
        "Flags configs where a query's selected example set came back smaller "
        "than the requested k, or where selection degenerated (e.g. duplicate "
        "examples in one set). Good: zero occurrences. Non-zero usually means the "
        "train corpus for that dataset is smaller than pool_multiplier * k, or "
        "alpha/pool_multiplier are set so aggressively that MMR runs out of "
        "distinct candidates. Knob: raise `--pool-multiplier`, or lower `k` for "
        "that dataset."
    ),
    "latency": (
        "Per-config request latency, p50/p95. Good: low and consistent (p95 not "
        "far above p50). High p95 alone usually means intermittent throttling or "
        "provider-side queuing, not a code problem. Not recorded -- run.py never "
        "times individual client.chat.completions.create() calls. Needs a "
        "wall-clock timestamp before/after each request, persisted per row or in "
        "meta.json."
    ),
    "determinism": (
        "Re-invokes select_examples with identical inputs and checks the selected "
        "example ids come back in the same order. Good: PASS (selection is a pure "
        "function of the cached vectors and config, so this should always hold; "
        "a FAIL would indicate real nondeterminism -- e.g. an unstable sort ties "
        "on floating-point similarity -- worth investigating in pyq.rag.core, not "
        "silently re-run). This checks *selection* determinism only, not whether "
        "the Groq API returns identical completions run-over-run, which is outside "
        "this harness's control (see bench/README.md)."
    ),
    "accuracy_delta": (
        "Accuracy of a few_shot/mmr_few_shot config minus the matching zero_shot "
        "baseline for the same (dataset, model, reasoning_effort). Good: positive "
        "and larger than run-to-run variance. A negative delta means the retrieved "
        "examples are actively hurting the model versus no examples at all -- "
        "check the diversity/redundancy numbers for that config before assuming "
        "the model itself is at fault."
    ),
    "alpha_pivot": (
        "Accuracy as alpha (MMR's relevance/diversity tradeoff) varies, holding k "
        "and backend fixed, per dataset. Good: a visible peak somewhere between "
        "the extremes -- alpha=1 degenerates to plain top-k retrieval, alpha=0 "
        "maximizes diversity at the expense of relevance. A flat curve means alpha "
        "isn't the lever moving accuracy for this dataset; look at k or the "
        "backend instead."
    ),
    "mean_pairwise_distance": (
        "Mean of (1 - similarity) over every pair within a selected example set, "
        "averaged across all queries in the config. Good: higher means the k "
        "examples shown to the model are more mutually distinct. Near zero means "
        "the set is effectively k copies of the same example. Knob: lower alpha "
        "(mmr_few_shot) to push MMR toward diversity."
    ),
    "mean_sim_to_query": (
        "Mean similarity of each selected example to its query, averaged across "
        "the config. Good: higher means the examples are actually relevant to "
        "what's being classified. This trades off directly against mean pairwise "
        "distance -- raising alpha raises this at diversity's expense."
    ),
    "redundancy": (
        "Mean, across queries, of the single highest pairwise similarity found "
        "within that query's selected set. Good: lower. High redundancy alongside "
        "a low accuracy delta is the specific signature of 'the pool retrieval is "
        "fine but MMR isn't diversifying' -- check alpha before blaming the "
        "embedding backend."
    ),
    "pool_coverage": (
        "Fraction of the training corpus that was selected at least once across "
        "the whole test split, for this config. Good: higher generally means "
        "selection is drawing from a broad slice of the corpus rather than "
        "funneling most queries toward a small repeated set of examples. Low "
        "coverage with a large corpus can be a sign the embedding backend "
        "clusters queries too tightly."
    ),
    "topic_match_rate": (
        "Fraction of selected examples that share the query's topic/category "
        "label, for datasets where one exists. Good: higher indicates the "
        "retrieval backend is finding genuinely on-topic neighbors, not just "
        "lexically similar ones. Not applicable to SST2/COLA/RTE -- their labels "
        "are the classification target itself (sentiment/acceptability/entailment), "
        "not an independent topic field, so using them here would be circular. "
        "TREC's label is a genuine topic category (entity/human/location/...), so "
        "it's computed there."
    ),
}


# ── Data loading ──────────────────────────────────────────────────────────────

@dataclass
class ConfigRun:
    jsonl_path: Path
    meta: dict
    rows: list = field(default_factory=list)


def _meta_path_for(jsonl_path: Path) -> Path:
    return Path(str(jsonl_path) + ".meta.json")


def discover_configs(paths: list[Path]) -> list[ConfigRun]:
    """Pairs each .jsonl with its .meta.json sidecar. Files with no sidecar
    are skipped (with a warning) -- without meta.json a file can't be placed
    in the config grid at all."""
    runs = []
    for jsonl_path in paths:
        meta_path = _meta_path_for(jsonl_path)
        if not meta_path.exists():
            print(f"[report] skipping {jsonl_path} -- no sidecar {meta_path.name}", file=sys.stderr)
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        rows = load_results(jsonl_path)
        runs.append(ConfigRun(jsonl_path=jsonl_path, meta=meta, rows=rows))
    return runs


def resolve_input_paths(explicit: list[Path], results_dir: Path) -> list[Path]:
    if explicit:
        return explicit
    return sorted(results_dir.glob("*.jsonl"))


# ── Selection reconstruction (reuses bench.select / pyq.rag.core, read-only) ──

def reconstruct_selection(cr: ConfigRun) -> list[list[dict]] | None:
    """Replays select_examples() for every row in this config's output,
    against freshly-encoded query vectors and cached train vectors. Returns
    None for zero_shot configs (nothing was ever selected)."""
    meta = cr.meta
    if meta["setting"] == "zero_shot":
        return None

    dataset = meta["dataset"]
    backend_name = meta["backend"]
    train_records = load_split(dataset, "train")
    train_texts = [extract_text(dataset, s) for s in train_records]

    backend: Backend = get_backend(backend_name)
    backend.fit(train_texts)
    train_vecs = encode_cached(dataset, backend_name, backend, "train", train_texts)

    test_records = load_split(dataset, "test")
    by_id = {sample_id(dataset, s): s for s in test_records}

    query_rows = [row for row in cr.rows if row["id"] in by_id]
    query_texts = [extract_text(dataset, by_id[row["id"]]) for row in query_rows]
    query_vecs = backend.encode(query_texts) if query_texts else backend.encode([])

    selections = []
    for i, row in enumerate(cr.rows):
        if row["id"] not in by_id:
            selections.append(None)
            continue
        qi = query_rows.index(row)  # rows/query_rows share order for matched ids
        query_vec = query_vecs[qi]
        examples = select_examples(
            meta["setting"],
            query_vec,
            train_vecs,
            train_records,
            k=meta["k"],
            alpha=meta["alpha"],
            pool_multiplier=meta["pool_multiplier"],
            backend=backend,
        )
        selections.append(examples)
    return selections


def _check_determinism(cr: ConfigRun, backend: Backend, train_vecs, train_records, sample_query_vecs) -> bool:
    meta = cr.meta
    for query_vec in sample_query_vecs:
        first = select_examples(
            meta["setting"], query_vec, train_vecs, train_records,
            k=meta["k"], alpha=meta["alpha"], pool_multiplier=meta["pool_multiplier"], backend=backend,
        )
        second = select_examples(
            meta["setting"], query_vec, train_vecs, train_records,
            k=meta["k"], alpha=meta["alpha"], pool_multiplier=meta["pool_multiplier"], backend=backend,
        )
        first_ids = [sample_id(meta["dataset"], r) for r in first]
        second_ids = [sample_id(meta["dataset"], r) for r in second]
        if first_ids != second_ids:
            return False
    return True


# ── Section 1: run header ────────────────────────────────────────────────────

def _git_info() -> dict:
    try:
        sha = subprocess.run(
            ["git", "rev-parse", "HEAD"], cwd=BACKEND_DIR, capture_output=True, text=True, check=True
        ).stdout.strip()
        dirty = bool(
            subprocess.run(
                ["git", "status", "--porcelain"], cwd=BACKEND_DIR, capture_output=True, text=True, check=True
            ).stdout.strip()
        )
        return {"sha": sha, "dirty": dirty}
    except (subprocess.CalledProcessError, FileNotFoundError):
        return {"sha": "unknown", "dirty": None}


def _package_versions() -> dict:
    out = {}
    for name in PACKAGES_TRACKED:
        try:
            out[name] = version(name)
        except PackageNotFoundError:
            out[name] = "not installed"
    return out


def build_run_header(config_runs: list[ConfigRun]) -> dict:
    datasets = sorted({cr.meta["dataset"] for cr in config_runs})
    dataset_sizes = {}
    for ds in datasets:
        dataset_sizes[ds] = {
            "train": len(load_split(ds, "train")),
            "test": len(load_split(ds, "test")),
        }

    models = sorted({cr.meta["model"] for cr in config_runs})
    reasoning_efforts = sorted({cr.meta["reasoning_effort"] for cr in config_runs})

    grid_axes = {
        "k": sorted({cr.meta["k"] for cr in config_runs}),
        "alpha": sorted({cr.meta["alpha"] for cr in config_runs if cr.meta["setting"] == "mmr_few_shot"}),
        "pool_multiplier": sorted({cr.meta["pool_multiplier"] for cr in config_runs if cr.meta["setting"] != "zero_shot"}),
        "backend": sorted({cr.meta["backend"] for cr in config_runs if cr.meta["setting"] != "zero_shot"}),
        "setting": sorted({cr.meta["setting"] for cr in config_runs}),
    }

    started = [cr.meta["started_at"] for cr in config_runs if cr.meta.get("started_at")]
    finished = [cr.meta["finished_at"] for cr in config_runs if cr.meta.get("finished_at")]
    wall_clock = {
        "earliest_start": min(started) if started else None,
        "latest_finish": max(finished) if finished else None,
    }

    total_prompt_tokens = sum(r.get("prompt_tokens") or 0 for cr in config_runs for r in cr.rows)
    total_completion_tokens = sum(r.get("completion_tokens") or 0 for cr in config_runs for r in cr.rows)

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "git": _git_info(),
        "package_versions": _package_versions(),
        "datasets": dataset_sizes,
        "models": models,
        "reasoning_efforts": reasoning_efforts,
        "grid": grid_axes,
        "wall_clock": wall_clock,
        "total_tokens": {"prompt": total_prompt_tokens, "completion": total_completion_tokens},
        "n_configs": len(config_runs),
    }


# ── Section 2: health ────────────────────────────────────────────────────────

def compute_health(config_runs: list[ConfigRun], selections_by_run: dict) -> dict:
    incomplete = [cr for cr in config_runs if cr.meta.get("partial") or cr.meta["n_samples_written"] != cr.meta["n_samples_total"]]
    grid_completion = {
        "status": "PASS" if not incomplete else "FAIL",
        "incomplete_configs": [str(cr.jsonl_path) for cr in incomplete],
    }

    degenerate = {}
    for cr in config_runs:
        selections = selections_by_run.get(cr.jsonl_path)
        if selections is None:
            continue
        k = cr.meta["k"]
        short = sum(1 for ex in selections if ex is not None and len(ex) < k)
        empty = sum(1 for ex in selections if ex is not None and len(ex) == 0)
        dup = 0
        for ex in selections:
            if not ex:
                continue
            ids = [sample_id(cr.meta["dataset"], e) for e in ex]
            if len(set(ids)) != len(ids):
                dup += 1
        if short or empty or dup:
            degenerate[str(cr.jsonl_path)] = {"fewer_than_k": short, "empty_sets": empty, "sets_with_duplicates": dup}
    degenerate_check = {
        "status": "PASS" if not degenerate else "WARN",
        "configs": degenerate,
    }

    determinism_failures = []
    for cr in config_runs:
        if cr.meta["setting"] == "zero_shot":
            continue
        dataset = cr.meta["dataset"]
        train_records = load_split(dataset, "train")
        train_texts = [extract_text(dataset, s) for s in train_records]
        backend = get_backend(cr.meta["backend"])
        backend.fit(train_texts)
        train_vecs = encode_cached(dataset, cr.meta["backend"], backend, "train", train_texts)

        test_records = load_split(dataset, "test")
        by_id = {sample_id(dataset, s): s for s in test_records}
        sample_rows = [r for r in cr.rows if r["id"] in by_id][:DETERMINISM_SAMPLE_SIZE]
        sample_texts = [extract_text(dataset, by_id[r["id"]]) for r in sample_rows]
        sample_vecs = backend.encode(sample_texts) if sample_texts else backend.encode([])

        if not _check_determinism(cr, backend, train_vecs, train_records, list(sample_vecs)):
            determinism_failures.append(str(cr.jsonl_path))

    determinism_check = {
        "status": "PASS" if not determinism_failures else "FAIL",
        "failed_configs": determinism_failures,
        "note": f"checked on the first {DETERMINISM_SAMPLE_SIZE} test rows per config; selection only, not LLM output.",
    }

    avg_tok_per_min = {}
    for cr in config_runs:
        started, finished = cr.meta.get("started_at"), cr.meta.get("finished_at")
        if not started or not finished:
            continue
        total_toks = sum((r.get("prompt_tokens") or 0) + (r.get("completion_tokens") or 0) for r in cr.rows)
        seconds = (datetime.fromisoformat(finished) - datetime.fromisoformat(started)).total_seconds()
        if seconds > 0:
            avg_tok_per_min[str(cr.jsonl_path)] = round(total_toks / (seconds / 60.0), 1)

    return {
        "grid_completion": grid_completion,
        "api_errors": {"status": "NOT RECORDED"},
        "tokens_per_minute": {
            "status": "NOT RECORDED (peak)",
            "average_for_context_only": avg_tok_per_min,
        },
        "degenerate_sets": degenerate_check,
        "latency": {"status": "NOT RECORDED"},
        "determinism": determinism_check,
    }


def build_health_summary(config_runs: list[ConfigRun], health: dict) -> dict:
    """Compact per-run health snapshot for history.jsonl -- not the full table
    from section 2, just enough to tell a throttled/partial run apart from a
    clean one when comparing across weeks. Fields the harness genuinely can't
    supply (api_errors) are `null`, never 0 and never guessed."""
    total = len(config_runs)
    completed = sum(
        1 for cr in config_runs
        if not cr.meta.get("partial") and cr.meta["n_samples_written"] == cr.meta["n_samples_total"]
    )
    degenerate_total = sum(
        counts["fewer_than_k"] + counts["empty_sets"] + counts["sets_with_duplicates"]
        for counts in health["degenerate_sets"]["configs"].values()
    )
    return {
        "partial": completed != total,
        "configs_total": total,
        "configs_completed": completed,
        "api_errors": {"rate_limit": None, "other": None, "retries": None},
        "degenerate_sets": degenerate_total,
    }


# ── Section 3: results ───────────────────────────────────────────────────────

def _non_setting_key(meta: dict) -> tuple:
    return (meta["dataset"], meta["model"], meta["reasoning_effort"])


def build_results_table(config_runs: list[ConfigRun]) -> dict:
    zero_shot_metrics = {}
    for cr in config_runs:
        if cr.meta["setting"] == "zero_shot":
            zero_shot_metrics[_non_setting_key(cr.meta)] = compute_metrics(cr.rows)

    rows = []
    for cr in config_runs:
        if cr.meta["setting"] == "zero_shot":
            continue
        metrics = compute_metrics(cr.rows)
        baseline = zero_shot_metrics.get(_non_setting_key(cr.meta))
        rows.append({
            "jsonl_path": str(cr.jsonl_path),
            "dataset": cr.meta["dataset"],
            "setting": cr.meta["setting"],
            "model": cr.meta["model"],
            "reasoning_effort": cr.meta["reasoning_effort"],
            "backend": cr.meta["backend"],
            "k": cr.meta["k"],
            "alpha": cr.meta["alpha"] if cr.meta["setting"] == "mmr_few_shot" else None,
            "pool_multiplier": cr.meta["pool_multiplier"],
            "seed": cr.meta["seed"],
            "accuracy": metrics["accuracy"],
            "macro_f1": metrics["macro_f1"],
            "zero_shot_accuracy": baseline["accuracy"] if baseline else None,
            "delta_vs_zero_shot": (metrics["accuracy"] - baseline["accuracy"]) if baseline else None,
        })

    best_by_dataset = {}
    for row in rows:
        ds = row["dataset"]
        if ds not in best_by_dataset or row["accuracy"] > best_by_dataset[ds]["accuracy"]:
            best_by_dataset[ds] = row

    alpha_pivot = defaultdict(list)
    for row in rows:
        if row["setting"] == "mmr_few_shot":
            alpha_pivot[row["dataset"]].append({
                "alpha": row["alpha"], "k": row["k"], "backend": row["backend"], "accuracy": row["accuracy"],
            })
    for ds in alpha_pivot:
        alpha_pivot[ds].sort(key=lambda r: (r["alpha"], r["k"], r["backend"]))

    return {
        "rows": rows,
        "zero_shot": {
            "|".join(str(x) for x in key): metrics for key, metrics in zero_shot_metrics.items()
        },
        "best_by_dataset": {ds: row["jsonl_path"] for ds, row in best_by_dataset.items()},
        "alpha_pivot": dict(alpha_pivot),
    }


# ── Section 4: diversity ─────────────────────────────────────────────────────

def compute_diversity(cr: ConfigRun, selections: list, backend: Backend, train_vecs, train_records) -> dict:
    dataset = cr.meta["dataset"]
    index_by_id = {sample_id(dataset, r): i for i, r in enumerate(train_records)}

    pairwise_distances, sims_to_query, redundancies = [], [], []
    selected_ids_ever = set()

    test_records = load_split(dataset, "test")
    by_id = {sample_id(dataset, s): s for s in test_records}

    for row, examples in zip(cr.rows, selections):
        if not examples:
            continue
        sample = by_id.get(row["id"])
        if sample is None:
            continue
        query_vec = backend.encode([extract_text(dataset, sample)])[0]

        ex_vecs = [train_vecs[index_by_id[sample_id(dataset, ex)]] for ex in examples]
        ex_ids = [sample_id(dataset, ex) for ex in examples]
        selected_ids_ever.update(ex_ids)

        sims_to_query.extend(backend.similarity(query_vec, v) for v in ex_vecs)

        if len(ex_vecs) >= 2:
            pair_sims = [
                backend.similarity(ex_vecs[i], ex_vecs[j])
                for i in range(len(ex_vecs)) for j in range(i + 1, len(ex_vecs))
            ]
            pairwise_distances.extend(1.0 - s for s in pair_sims)
            redundancies.append(max(pair_sims))

    topic_match_rate = None
    if dataset == "trec":
        matches, total = 0, 0
        for row, examples in zip(cr.rows, selections):
            if not examples:
                continue
            for ex in examples:
                total += 1
                if ex.get("label") == row.get("gold"):
                    matches += 1
        topic_match_rate = (matches / total) if total else None

    return {
        "mean_pairwise_distance": mean(pairwise_distances) if pairwise_distances else None,
        "mean_sim_to_query": mean(sims_to_query) if sims_to_query else None,
        "redundancy": mean(redundancies) if redundancies else None,
        "pool_coverage": (len(selected_ids_ever) / len(train_records)) if train_records else None,
        "topic_match_rate": topic_match_rate,
        "topic_match_applicable": dataset == "trec",
    }


def build_diversity_section(config_runs: list[ConfigRun], selections_by_run: dict) -> dict:
    out = {}
    for cr in config_runs:
        if cr.meta["setting"] == "zero_shot":
            continue
        selections = selections_by_run.get(cr.jsonl_path)
        if not selections:
            continue
        dataset = cr.meta["dataset"]
        train_records = load_split(dataset, "train")
        train_texts = [extract_text(dataset, s) for s in train_records]
        backend = get_backend(cr.meta["backend"])
        backend.fit(train_texts)
        train_vecs = encode_cached(dataset, cr.meta["backend"], backend, "train", train_texts)
        out[str(cr.jsonl_path)] = compute_diversity(cr, selections, backend, train_vecs, train_records)
    return out


# ── Section 6: verdict ───────────────────────────────────────────────────────

def _config_key(row: dict) -> tuple:
    """Identifies "the same config run under a different seed": everything
    that defines a config except seed itself."""
    return (row["setting"], row["k"], row["alpha"], row["backend"], row["pool_multiplier"])


def build_verdict(results: dict, health: dict) -> list:
    lines = []
    if health["grid_completion"]["status"] != "PASS":
        lines.append(
            "Not enough evidence -- one or more configs in the grid did not finish "
            f"({health['grid_completion']['incomplete_configs']}). Re-run those before "
            "drawing conclusions from section 3."
        )
        return lines

    deltas_by_dataset = defaultdict(list)
    for row in results["rows"]:
        if row["delta_vs_zero_shot"] is not None:
            deltas_by_dataset[row["dataset"]].append(row)

    for dataset, rows in deltas_by_dataset.items():
        best = max(rows, key=lambda r: r["accuracy"])
        # Each row's meta.json records the --seed it ran with (bench/sweep.py
        # sweeps a seeds axis, run.py takes --seed) -- n_seeds is the number
        # of distinct seeds actually run for *this specific* winning config
        # (same setting/k/alpha/backend/pool_multiplier), not the whole
        # sweep, so a sweep mixing single-seed and multi-seed configs for
        # this dataset doesn't over-claim evidence it doesn't have.
        same_config_rows = [r for r in rows if _config_key(r) == _config_key(best)]
        seeds = {r["seed"] for r in same_config_rows}
        n_seeds = len(seeds)

        if n_seeds < 2:
            lines.append(
                f"{dataset}: best observed config is {best['setting']} "
                f"(k={best['k']}, alpha={best['alpha']}, backend={best['backend']}) at "
                f"accuracy={best['accuracy']:.4f} (delta={best['delta_vs_zero_shot']:+.4f} vs zero_shot). "
                f"Not enough evidence to call this significant -- only {n_seeds} seed "
                f"{'was' if n_seeds == 1 else 'were'} run for this config in this sweep, so this "
                "delta cannot be distinguished from seed-to-seed noise. Re-run it with "
                "sweep.py's `seeds` axis set to 2+ seeds before recommending a default."
            )
        else:
            seed_accuracies = [r["accuracy"] for r in same_config_rows]
            seed_spread = max(seed_accuracies) - min(seed_accuracies)
            delta = best["delta_vs_zero_shot"]
            exceeds = abs(delta) > seed_spread
            verdict_clause = (
                f"exceeding the observed seed-to-seed accuracy spread "
                f"({seed_spread:.4f} across {n_seeds} seeds)."
                if exceeds else
                f"but within the observed seed-to-seed accuracy spread "
                f"({seed_spread:.4f} across {n_seeds} seeds) -- not distinguishable from seed "
                "noise at this sample size."
            )
            lines.append(
                f"{dataset}: {'recommend' if exceeds else 'tentatively favor'} {best['setting']} "
                f"(k={best['k']}, alpha={best['alpha']}, backend={best['backend']}) -- "
                f"accuracy={best['accuracy']:.4f}, delta={delta:+.4f} vs zero_shot, {verdict_clause}"
            )
    return lines


# ── History ───────────────────────────────────────────────────────────────────

def build_history_row(header: dict, health: dict, results: dict, diversity: dict, config_runs: list[ConfigRun]) -> dict:
    """One line for bench/results/history.jsonl -- timestamp, git SHA, model,
    config grid, per-config accuracy/f1/delta, diversity metrics, and a
    compact health summary. Never mutates or rewrites prior lines; callers
    append this as its own line."""
    configs = []
    for row in results["rows"]:
        d = diversity.get(row["jsonl_path"], {})
        configs.append({
            "dataset": row["dataset"],
            "setting": row["setting"],
            "backend": row["backend"],
            "k": row["k"],
            "alpha": row["alpha"],
            "pool_multiplier": row["pool_multiplier"],
            "accuracy": row["accuracy"],
            "macro_f1": row["macro_f1"],
            "delta_vs_zero_shot": row["delta_vs_zero_shot"],
            "diversity": {
                "mean_pairwise_distance": d.get("mean_pairwise_distance"),
                "mean_sim_to_query": d.get("mean_sim_to_query"),
                "redundancy": d.get("redundancy"),
                "pool_coverage": d.get("pool_coverage"),
                "topic_match_rate": d.get("topic_match_rate"),
            },
        })

    return {
        "timestamp": header["generated_at"],
        "git_sha": header["git"]["sha"],
        "git_dirty": header["git"]["dirty"],
        "models": header["models"],
        "config_grid": header["grid"],
        "health": build_health_summary(config_runs, health),
        "configs": configs,
    }


# ── Rendering ─────────────────────────────────────────────────────────────────

def _md_table(headers: list[str], rows: list[list[str]]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join("---" for _ in headers) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(row) + " |")
    return "\n".join(lines)


def _fmt(v, nd=4) -> str:
    if v is None:
        return "-"
    if isinstance(v, float):
        return f"{v:.{nd}f}"
    return str(v)


def render_glossary() -> str:
    """The static metric glossary (formerly generated section 5) -- lives in
    REPORT.md's hand-editable static half, generated once at file-creation
    time from the EXPLANATIONS constant, never regenerated after that."""
    parts = ["## Metric glossary\n"]
    for key, text in EXPLANATIONS.items():
        parts.append(f"**{key}** -- {text}")
        parts.append("")
    return "\n".join(parts)


def render_static_header() -> str:
    """The full static top half of a freshly-created REPORT.md: How to run,
    then the metric glossary. Written once; never regenerated."""
    return (
        "# Bench report\n\n"
        "## How to run\n\n"
        f"```bash\n{HOW_TO_RUN}\n```\n\n"
        f"{render_glossary()}\n"
    )


def render_generated_region(header: dict, health: dict, results: dict, diversity: dict, verdict: list) -> str:
    """Everything between <!-- BENCH:BEGIN --> and <!-- BENCH:END -->:
    sections 1 (run header), 2 (health), 3 (results), 4 (diversity), 6
    (verdict). Section 5 (interpretation) lives in the static glossary
    instead and is never part of this region."""
    parts = []

    # 1. Run header
    parts.append("## 1. Run header\n")
    parts.append(f"- **Generated (UTC):** {header['generated_at']}")
    parts.append(f"- **Git SHA:** {header['git']['sha']} (dirty: {header['git']['dirty']})")
    parts.append(f"- **Package versions:** {', '.join(f'{k}={v}' for k, v in header['package_versions'].items())}")
    parts.append(f"- **Models:** {', '.join(header['models'])}")
    parts.append(f"- **Reasoning effort:** {', '.join(header['reasoning_efforts'])}")
    parts.append(f"- **Config grid:** {json.dumps(header['grid'])}")
    parts.append(f"- **Wall clock:** {header['wall_clock']['earliest_start']} -> {header['wall_clock']['latest_finish']}")
    parts.append(
        f"- **Total tokens:** {header['total_tokens']['prompt']} prompt + "
        f"{header['total_tokens']['completion']} completion"
    )
    parts.append(f"- **Configs in this sweep:** {header['n_configs']}")
    parts.append("")
    parts.append(_md_table(
        ["dataset", "train rows", "test rows"],
        [[ds, str(sizes["train"]), str(sizes["test"])] for ds, sizes in header["datasets"].items()],
    ))
    parts.append("")

    # 2. Health
    parts.append("## 2. Health status\n")

    def _name(path_str: str) -> str:
        return Path(path_str).name

    incomplete = ", ".join(_name(p) for p in health["grid_completion"]["incomplete_configs"]) or "-"
    avg_tok_min = health["tokens_per_minute"]["average_for_context_only"]
    avg_tok_min_str = ", ".join(f"{_name(p)}={v}" for p, v in avg_tok_min.items()) or "-"
    degenerate = health["degenerate_sets"]["configs"]
    degenerate_str = "; ".join(
        f"{_name(p)}: {json.dumps(counts)}" for p, counts in degenerate.items()
    ) or "-"
    determinism_failed = ", ".join(_name(p) for p in health["determinism"]["failed_configs"]) \
        or health["determinism"]["note"]

    health_rows = [
        ["every config completed", health["grid_completion"]["status"], incomplete],
        ["API errors (429 vs other) / retries", health["api_errors"]["status"], "-"],
        ["peak tokens/minute vs 8000 ceiling", health["tokens_per_minute"]["status"],
         f"avg (context only): {avg_tok_min_str}"],
        ["fewer-than-k / empty / duplicate sets", health["degenerate_sets"]["status"], degenerate_str],
        ["latency p50/p95 per config", health["latency"]["status"], "-"],
        ["determinism (same seed twice -> identical selection)", health["determinism"]["status"],
         determinism_failed],
    ]
    parts.append(_md_table(["check", "status", "detail"], health_rows))
    parts.append("")

    # 3. Results
    parts.append("## 3. Results\n")
    result_rows = []
    for row in sorted(results["rows"], key=lambda r: (r["dataset"], r["setting"], r["k"], r["alpha"] or 0)):
        is_best = results["best_by_dataset"].get(row["dataset"]) == row["jsonl_path"]
        result_rows.append([
            row["dataset"], row["setting"], row["backend"], str(row["k"]), _fmt(row["alpha"], 2),
            _fmt(row["accuracy"]), _fmt(row["macro_f1"]), _fmt(row["zero_shot_accuracy"]),
            _fmt(row["delta_vs_zero_shot"], 4) if row["delta_vs_zero_shot"] is None else f"{row['delta_vs_zero_shot']:+.4f}",
            "**best**" if is_best else "",
        ])
    parts.append(_md_table(
        ["dataset", "setting", "backend", "k", "alpha", "accuracy", "macro_f1", "zero_shot_acc", "delta", ""],
        result_rows,
    ))
    parts.append("")

    for dataset, pivot_rows in results["alpha_pivot"].items():
        parts.append(f"### Accuracy vs. alpha -- {dataset}\n")
        parts.append(_md_table(
            ["alpha", "k", "backend", "accuracy"],
            [[_fmt(r["alpha"], 2), str(r["k"]), r["backend"], _fmt(r["accuracy"])] for r in pivot_rows],
        ))
        parts.append("")

    # 4. Diversity
    parts.append("## 4. Diversity\n")
    div_rows = []
    for path, d in diversity.items():
        div_rows.append([
            Path(path).name, _fmt(d["mean_pairwise_distance"]), _fmt(d["mean_sim_to_query"]),
            _fmt(d["redundancy"]), _fmt(d["pool_coverage"]),
            _fmt(d["topic_match_rate"]) if d["topic_match_applicable"] else "N/A (no topic field)",
        ])
    parts.append(_md_table(
        ["config", "mean pairwise dist.", "mean sim to query", "redundancy", "pool coverage", "topic match rate"],
        div_rows,
    ))
    parts.append("")

    # 6. Verdict
    parts.append("## 6. Verdict\n")
    if verdict:
        for line in verdict:
            parts.append(f"- {line}")
    else:
        parts.append("- No non-zero-shot configs found in this sweep -- nothing to recommend.")

    return "\n".join(parts)


# ── REPORT.md marker splice ──────────────────────────────────────────────────

def update_report_md(report_path: Path, generated_region: str) -> None:
    """Writes/updates REPORT.md, touching only the region between
    BEGIN_MARKER/END_MARKER. Missing file -> create with the static half
    (How to run + glossary) plus this run's generated region. Existing file
    with the markers missing, duplicated, or out of order -> refuse and exit
    loudly rather than guess where the generated region belongs."""
    block = f"{BEGIN_MARKER}\n{generated_region}\n{END_MARKER}"

    if not report_path.exists():
        report_path.write_text(render_static_header() + block + "\n", encoding="utf-8")
        return

    text = report_path.read_text(encoding="utf-8")
    if text.count(BEGIN_MARKER) != 1 or text.count(END_MARKER) != 1:
        raise SystemExit(
            f"{report_path} exists but does not contain exactly one {BEGIN_MARKER} "
            f"and one {END_MARKER}. Refusing to guess where the generated region "
            "belongs -- restore the markers by hand, or delete the file to have it "
            "regenerated fresh."
        )

    begin_idx = text.index(BEGIN_MARKER)
    end_idx = text.index(END_MARKER)
    if begin_idx > end_idx:
        raise SystemExit(
            f"{report_path}: {BEGIN_MARKER} appears after {END_MARKER}. Refusing to "
            "guess -- fix the marker order by hand, or delete the file to regenerate it."
        )

    new_text = text[:begin_idx] + block + text[end_idx + len(END_MARKER):]
    report_path.write_text(new_text, encoding="utf-8")


# ── CLI ───────────────────────────────────────────────────────────────────────

def build_arg_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Turn one bench sweep into bench/results/REPORT.md + history.jsonl.")
    p.add_argument(
        "results", nargs="*", type=Path,
        help="Explicit .jsonl result files (each needs a sibling .meta.json). "
             "Defaults to every *.jsonl in --results-dir.",
    )
    p.add_argument(
        "--results-dir", type=Path, default=RAW_DIR,
        help="Directory of raw run.py output to glob when no files are given (default: bench/results/raw).",
    )
    p.add_argument(
        "--out-dir", type=Path, default=RESULTS_DIR,
        help="Where REPORT.md and history.jsonl live (default: bench/results).",
    )
    return p


def compute_report_data(config_runs: list[ConfigRun]) -> tuple[dict, dict, dict, dict, list]:
    selections_by_run = {cr.jsonl_path: reconstruct_selection(cr) for cr in config_runs}

    header = build_run_header(config_runs)
    health = compute_health(config_runs, selections_by_run)
    results = build_results_table(config_runs)
    diversity = build_diversity_section(config_runs, selections_by_run)
    verdict = build_verdict(results, health)
    return header, health, results, diversity, verdict


def main(argv: list[str] | None = None) -> None:
    args = build_arg_parser().parse_args(argv)
    paths = resolve_input_paths(args.results, args.results_dir)
    if not paths:
        raise SystemExit(f"No .jsonl result files found (looked in {args.results_dir}).")

    config_runs = discover_configs(paths)
    if not config_runs:
        raise SystemExit("No config runs with a valid .meta.json sidecar were found.")

    header, health, results, diversity, verdict = compute_report_data(config_runs)
    generated_region = render_generated_region(header, health, results, diversity, verdict)

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    report_path = out_dir / "REPORT.md"
    update_report_md(report_path, generated_region)

    history_path = out_dir / "history.jsonl"
    history_row = build_history_row(header, health, results, diversity, config_runs)
    with open(history_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(history_row, sort_keys=True, default=str) + "\n")

    print(f"[report] updated {report_path}")
    print(f"[report] appended a row to {history_path}")


if __name__ == "__main__":
    main()
