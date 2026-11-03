# Open-source model extension plan

This file is the actual new work this paper needs beyond what's already
been run (`03-results-so-far.md`). It covers which models to target, what
(if anything) needs to change in the harness to run them, how results will
be compared against the source paper's baselines, and what "success" means
concretely for this specific extension.

## Which models

- **`openai/gpt-oss-120b` via Groq** — confirmed available and already the
  only model this harness has been run against to date (every result in
  `03-results-so-far.md`, and the hardcoded default in both shipped sweep
  YAMLs and `bench/run.py`'s own smoke-sequence documentation).
- **`qwen3-27b` and `gpt-oss-20b`, as alternates** — nominated for this
  extension's model-scale/family axis. **Not independently confirmed by
  this audit as currently available on Groq's model catalog** — hosted
  model catalogs change without this repo's knowledge (the same caveat
  `06-reproducibility-and-methodology-notes.md` raises about the primary
  model), so their exact model-id strings and availability should be
  checked against Groq's live model list immediately before committing any
  sweep budget to them, not assumed from this plan.

These three give a genuine model-scale spread within the "open-weight,
hosted" category (20B/27B/120B), which is useful on its own even before
comparing against the source paper's much smaller local models — it lets
this extension ask "does the effect change with scale *within* the hosted
regime," not just "hosted vs. local."

## What needs to change in the harness

**Less than it might seem — model swapping is already a first-class,
supported axis.** Specifically:

- `bench/run.py`'s `--model` flag is already required with no hardcoded
  fallback (`02-our-implementation-audit.md` §3) — the harness was built
  from the start so different models can be compared directly. Running
  against a different model today is just `--model qwen3-27b` (or
  whatever the confirmed exact id is) on an existing `bench/run.py`
  invocation; no code change needed for a single ad hoc run.
- `bench/cache.py`'s response-cache key already includes the model string
  in its hash (`sha256(model + reasoning_effort + prompt)`), so swapping
  models cannot accidentally reuse another model's cached completions.
- The embedding cache is **independent of the generation model** — it's
  keyed on `(dataset, backend, split)` only, since retrieval/embedding
  uses `SbertBackend`/`TfidfBackend`, not the generation model itself. A
  generation-model swap reuses the exact same cached embeddings and
  candidate pools, which is exactly what's wanted here: it isolates the
  comparison to the one variable this extension actually wants to vary
  (the generation model), holding retrieval/selection fixed.

**What does need to change for a real multi-model sweep (not just one-off
runs):**

- Both shipped grid YAMLs (`sweeps/default.yaml`, `sweeps/full.yaml`)
  hardcode a single `model:` string, and `sweep.py`'s `expand_grid()`
  reads `grid["model"]` as one string, not a list — there is currently no
  way to declare a multi-model grid in one YAML file. Two options, neither
  large:
  1. **No code change:** write one grid YAML per model (copy
     `sweeps/full.yaml`, change only the `model:` line). Simplest, but
     needs care with the next point.
  2. **Small code change:** add `model` as a genuine cartesian-product axis
     in `expand_grid()`, alongside `k`/`alpha`/`seed`. More invasive since
     `SweepConfig.label` and `SweepConfig.out` (the output filename
     pattern) currently encode `dataset__setting__k__alpha__seed` with
     **no model component at all** — meaning two configs that differ only
     by model currently compute the *same* output filename and would
     silently overwrite each other's raw results.
- **Either way, output paths need a model component before running more
  than one model against the same `out_dir`.** This is true even for
  option 1 (separate YAML files) — each grid's `out_dir` (or a
  model-specific subdirectory under it) must be set explicitly distinct
  per model, or a second model's run will silently clobber the first
  model's `results/raw/*.jsonl` files, since neither the current naming
  scheme nor `report.py`'s discovery logic distinguishes by model.
- `report.py` itself needs no change to *read* multi-model results
  correctly — its run-header already collects `models` as a set and its
  results/verdict logic is keyed by `(dataset, model, reasoning_effort)`
  for matching a few-shot config to its zero-shot baseline. The gap is
  purely on the *writing* side (output-path collision), not the
  reporting side.

## Comparison methodology against the source paper's baselines

- **Held constant:** the four datasets and their splits (same vendored
  files), the metric (accuracy + macro-F1), and the nominal method
  (zero-shot / few-shot / MMR-few-shot via the same
  `core/retrieval.py`/`core/mmr.py` code).
- **Not held constant, and not claimed to be:** the exact `k`/`alpha`/
  `pool_multiplier` grid (this repo's own grids are not confirmed to match
  the source paper's swept ranges — see `01-source-paper-summary.md`), the
  model itself (the entire point of this extension), quantization,
  prompt wording, tokenizer, and inference stack (all inevitably differ
  between a hosted API call and the source paper's fully local setup, on
  top of raw parameter count — see
  `06-reproducibility-and-methodology-notes.md`).
- **The comparison this extension can actually support:** a
  replication-of-method-under-model-substitution — i.e., "here is what the
  same selection method produces on a different model family/scale," not
  a head-to-head accuracy comparison against the source paper's published
  table. This repo's own documentation already states this position for
  the single-model result set that exists today (`bench/README.md`:
  "Results here are not comparable to the numbers in that paper's table")
  and the same caveat applies, unchanged, once a second and third model
  are added — more models does not make the comparison more literal, it
  just gives more data points for the *directional* question in
  `00-goal-and-scope.md`.
- Any accuracy-number comparison that crosses the model-scale boundary
  (this project's numbers vs. the source paper's numbers) should be
  reported as directionally suggestive only, explicitly caveated, never
  presented as a controlled experiment — too many variables differ
  simultaneously to attribute a difference to model scale alone.

## What "success" looks like for this extension, concretely

Three bars, each strictly building on the last — none of them are met
today (see `03-results-so-far.md`/`04-gaps-and-drawbacks.md`):

1. **Minimum bar.** The same 4-dataset, 3-setting, single-alpha (`0.7`)
   grid run to **completion on full test splits** (not smoke-limited) for
   at least **2 models** (`gpt-oss-120b` plus one confirmed alternate),
   each with **2+ seeds**. This is the first point at which
   `report.py`'s own verdict logic can move past its current fixed
   "not enough evidence" line for any dataset/model pair — it's a
   floor, not a real finding yet.
2. **Real bar.** A `sweeps/full.yaml`-scale grid (multi-`k`, multi-`alpha`,
   multi-seed) run for at least 2 models, so each dataset's alpha-pivot
   table has more than the single existing row. This is the point at
   which the extension can actually characterize *how* the
   relevance/diversity tradeoff shifts with model scale — not just
   whether one fixed, unvalidated `alpha=0.7` happens to beat a baseline.
3. **Instrumentation bar.** The currently-unrecorded health metrics
   (API error counts, peak tokens/minute, per-request latency — see
   `04-gaps-and-drawbacks.md` item 4) captured for at least the models
   actually compared. A claim like "the effect held at 120B parameters but
   the study couldn't scale past N seeds because of hosted-provider rate
   limits" needs those operational numbers to be credible evidence, not an
   assertion.

## Explicit non-goal (repeated from `00-goal-and-scope.md`)

This extension stays scoped to the four classification datasets. It makes
no claim, and should cite no evidence, about any other use of this
codebase's retrieval/MMR implementation outside this benchmark — there is
no ground-truth accuracy signal available there to support such a claim
either way.
