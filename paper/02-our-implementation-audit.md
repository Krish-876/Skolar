# Implementation audit

Everything below is read directly from the code as of this audit (branch
`docs/dicl-report`, working tree on top of commit `43a7d6b`). File paths
are given relative to `backend/`. Where something is inferred rather than
read directly, it's marked **(inferred)**.

## 1. The core retrieval/MMR implementation

Three files under `pyq/rag/core/`, pure math, no I/O, no network — this is
the actual code both the benchmark harness and (see §7) one other code path
in this repository call into. It is never reimplemented by the benchmark;
the benchmark imports it directly.

### `pyq/rag/core/features.py`

- `EMBED_MODEL = "all-MiniLM-L6-v2"` — the sentence-transformers model id.
- `get_embed_model()` — process-wide singleton loader; loaded once, reused
  everywhere in-process.
- `similarity(a, b)` — cosine similarity **rescaled to `[0, 1]`** via
  `(1 + cosine) / 2`, not raw cosine. Works for dense `ndarray`s and scipy
  sparse rows alike (a manual dot/norm implementation routes sparse inputs
  through `scipy.sparse.linalg.norm` instead of densifying, since
  `np.linalg.norm` raises on sparse input).
- `Backend` — a `Protocol` with `fit(train_texts)`, `encode(texts)`,
  `similarity(a, b)`.
- `SbertBackend` — `fit()` is a no-op (pretrained model, nothing to fit);
  `encode()` calls the singleton's `.encode()`.
- `TfidfBackend` — wraps `sklearn.feature_extraction.text.TfidfVectorizer`;
  `fit()` is required before `encode()`; `encode()` returns a sparse
  matrix.

### `pyq/rag/core/retrieval.py` — first-stage retrieval

```python
def retrieve_top_k(query_vec, corpus_vecs, k, backend=None) -> tuple[list[int], list[float]]:
```

Brute-force: computes `backend.similarity(query_vec, corpus_vecs[i])` for
**every** row in the corpus (no approximate nearest-neighbor index, no
early termination), sorts descending, returns the top-`k` indices and their
scores. Defaults to `SbertBackend()` if no backend is passed.

### `pyq/rag/core/mmr.py` — second-stage reranking

```python
def cosine_sim(a, b) -> float:  # raw, un-rescaled cosine
def mmr(query_embedding, candidate_embeddings, candidate_questions, alpha, k, backend=None) -> list[dict]:
```

- `cosine_sim` is a separate, raw (not `[0,1]`-rescaled) cosine
  implementation. It is **not called by `mmr()`** — `mmr()` uses
  `backend.similarity` (the rescaled one). `cosine_sim` exists for a
  different, unrelated call site elsewhere in this codebase (a
  similarity-threshold check, not part of ICL example selection) and is
  noted here only so a reader isn't confused by two cosine functions
  living in the same file.
- `mmr()` is a **pure greedy selection**, no randomness:
  - First pick has no diversity penalty (`selected_embeddings` starts
    empty, so `diversity = 0` for the first step).
  - Each subsequent step: `score = alpha * relevance - (1 - alpha) *
    diversity`, where `relevance` is similarity to the query and
    `diversity` is the **max** similarity to any already-selected example
    (not mean — a single close duplicate among already-picked examples is
    enough to penalize a candidate).
  - Selects `min(k, len(remaining))` items — if the candidate pool is
    smaller than `k`, `mmr()` silently returns fewer than `k` examples
    rather than raising. This is exactly the "fewer than k" condition the
    reporting layer's health check screens for (§4).
  - The function's own comment states permuting the input candidate order
    cannot change which candidate wins at a given step — i.e. the greedy
    argmax is order-independent, so there is no seed/shuffle anywhere in
    this function.
  - The `candidate_questions` parameter name is a naming leftover from
    this function's original call site outside the benchmark; in the
    benchmark's own use, that argument holds classification-dataset
    training records (sentence + label + id), not anything
    question-specific — the function itself is domain-agnostic, it just
    returns whatever dicts it's given, reranked.

## 2. `bench/selection.py` — wiring the three ICL settings

**Note on the filename:** this module was renamed from `bench/select.py`
in commit `43a7d6b` ("fix: rename bench/select.py to avoid stdlib import
collision," PR #110). Two docs elsewhere in this repo
(`bench/README.md`, `pyq/ONBOARDING.md`) still reference the pre-rename
name — see `04-gaps-and-drawbacks.md` item 12.

```python
SETTING_NAMES = ("zero_shot", "few_shot", "mmr_few_shot")

def select_examples(setting, query_vec, train_vecs, train_records, k,
                     alpha=0.7, pool_multiplier=3, backend=None) -> list[dict]:
```

- `zero_shot` → `[]` (no examples).
- `few_shot` → `retrieve_top_k(query_vec, train_vecs, k, backend)` directly
  — plain top-k similarity, no MMR involved at all.
- `mmr_few_shot` → `pool_size = min(pool_multiplier * k, train_vecs.shape[0])`;
  retrieve that many candidates by `retrieve_top_k`; then `mmr()` reranks
  that pool down to `k`.

This module's own docstring states it is "intentionally thin" and **must**
import `retrieve_top_k`, `mmr`, and the `Backend` classes from
`pyq.rag.core` rather than reimplementing them — the explicit design intent
is that this harness's numbers describe the exact retrieval/reranking code
this repository ships in one place, not a separate research
reimplementation.

## 3. `bench/run.py` — single-configuration runner

CLI flags: `--dataset` (`sst2`/`cola`/`rte`/`trec`), `--setting`
(`zero_shot`/`few_shot`/`mmr_few_shot`), `--k` (default 4), `--alpha`
(default 0.7), `--pool-multiplier` (default 3), `--backend` (`sbert`
default, or `tfidf`), `--model` (**required**, no hardcoded fallback — the
harness never silently reuses a default model, specifically so different
models are directly comparable), `--reasoning-effort` (`none`/`low`/
`medium`/`high`; `none` **omits the API parameter entirely** rather than
sending the literal string `"none"`), `--limit` (keep only the first N test
rows after sorting by id — omit for the full split), `--seed` (default 0,
currently inert, see below), `--out` (JSONL path; a `.meta.json` sidecar is
always written alongside it).

**Data flow (`_prepare()`):** loads the full train+test splits, sorts test
records ascending by id, fits/encodes the **full** train and test corpora
(train is never limited by `--limit`), and only then slices the test
records/vectors to the first `--limit` rows if given. This ordering exists
specifically so the on-disk embedding cache (below) is valid for any
`--limit` value, not just the one a particular invocation happened to use.

**Embedding cache:** `.cache/<dataset>__<backend[-embedmodel]>__<split>.{npy,npz}`,
keyed by `(dataset, backend, split)` — **not** by `--limit`. The sbert key
additionally includes the embedding model id, so a model change can't
silently reuse stale vectors. A cached array whose row count doesn't match
the current full split is treated as a cache miss and re-encoded (a
self-healing guard against a cache file written under an earlier, buggy
caching scheme).

**Groq call path:** uses the bare `pyq.rag.llm.client.get_groq_client()`
(the raw SDK client) — **not** the rate-limited
`create_chat_completion()`/`TokenBudgetLimiter` wrapper that a different
call site in this codebase uses for its own 8000-tokens-per-minute budget.
Instead, `bench/run.py` implements its own client-side `RateLimiter`
throttling to **30 requests/minute** (`GROQ_RPM_LIMIT = 30`, Groq's stated
free-tier per-minute ceiling — a *request*-count ceiling, distinct from a
*token*-count ceiling), plus reactive 429 backoff (exponential, capped at
60s, `MAX_RATE_LIMIT_RETRIES = 5`) and a daily-cap detector
(`_is_daily_cap_message` checks the error text for `"per day"`/`"rpd"`)
that raises `DailyCapReached` and halts the run immediately — writing
whatever was completed plus a `.meta.json` with `"partial": true` — rather
than exhausting retries against a cap that won't lift.

**Response cache (`bench/cache.py`):** `sha256(model + "\x1f" +
reasoning_effort + "\x1f" + exact_prompt_string)` as the key; a JSON blob
(`raw_completion`, `prediction`, `prompt_tokens`, `completion_tokens`) on
disk under `.cache/responses/`, written via write-to-temp-then-rename so a
killed process never leaves a truncated, unparseable cache entry. A cache
hit skips the Groq call entirely and marks the output row `"cached": true`.

**Output:** one JSONL row per test sample — `id`, `gold`, `raw_completion`,
`prediction` (`null` on parse failure, never silently dropped),
`prompt_tokens`, `completion_tokens`, `cached`. The `.meta.json` sidecar
records every CLI argument plus `seed`, `n_samples_total`,
`n_samples_written`, `n_cache_hits`, `started_at`/`finished_at` (UTC ISO
timestamps), and `partial`.

**Determinism, precisely scoped:** `temperature=0` always; test rows always
processed in ascending-id order; `--seed` (default 0) is currently **inert**
— plumbed all the way through the CLI and into `bench/sweep.py`'s grid
expansion, but nothing in the selection or prompting code reads it for any
random decision today (there is no RNG call anywhere in `core/retrieval.py`
or `core/mmr.py`). It exists so `bench/sweep.py` can already sweep a
`seeds` axis the day selection gains any seed-dependent behavior, without
a CLI/schema change. See `06-reproducibility-and-methodology-notes.md` for
what this does and doesn't guarantee about reproducibility at the
API-response level.

## 4. `bench/sweep.py` — YAML-grid orchestration

Runs a grid of `bench/run.py` configs **in-process** (imports and calls
`run()` directly, never subprocess-per-config), specifically so the
process-wide `SentenceTransformer` singleton loads once for an entire
sweep instead of once per config.

- `expand_grid()` expands the grid **per-setting**, not as one flat
  cartesian product across every axis for every setting: `zero_shot` only
  varies by `seed` (its prompt never depends on `k`/`alpha`); `few_shot`
  varies by `k` and `seed` (ignores `alpha`, since plain top-k retrieval
  has no diversity tradeoff); `mmr_few_shot` varies by `k`, `alpha`, and
  `seed`. This avoids generating literal duplicate configs an
  axis-blind-to-a-setting would otherwise produce.
- `--estimate` is a pure-CPU dry run: it calls `iter_prompts()`, which
  shares the **exact same** `_prepare()` → `select_examples()` →
  `build_prompt()` code path a real run would use, so the estimate cannot
  drift from what a real invocation would actually send. Each built prompt
  is checked against the on-disk response cache; the printed summary is
  `configs` / `total_rows` / `cache_hits` / `net_new_calls` /
  `est_tokens` (rough: `len(prompt) // 4` chars-per-token, plus a flat 20
  assumed completion tokens, since these are one-label classification
  answers) against the grid's `max_calls`.
- Every grid YAML **must** declare `max_calls` and `model` — `load_grid()`
  raises immediately if either is missing, no silent fallback. `main()`
  re-checks `net_new_calls > max_calls` immediately before actually
  running (not just at `--estimate` time) and refuses with `SystemExit` if
  so — a sweep can never silently spend more calls than its own declared
  budget, even if something changed between an `--estimate` check and the
  real run.

### `sweeps/default.yaml`

`max_calls: 300`, `model: openai/gpt-oss-120b`, `reasoning_effort: none`,
`backend: sbert`, `pool_multiplier: 3`, `limit: 50`, `datasets: [sst2]`
(single dataset), `settings:` all three, `k: [4]`, `alpha: [0.3, 0.7]`,
`seeds: [0, 1]`. This is what `python -m bench.sweep` runs with no
`--config` flag.

### `sweeps/full.yaml`

`max_calls: 5000`, same model, `limit: null` (**full test split, all four
datasets**), `k: [2, 4, 8]`, `alpha: [0.3, 0.5, 0.7, 0.9]`,
`seeds: [0, 1, 2]`. Opt-in via `--config bench/sweeps/full.yaml`.

**As of this audit, `full.yaml` has never been executed and committed.**
`REPORT.md`'s own recorded `config_grid` field shows only `k: [4, 7]`,
`alpha: [0.7]`, and no `seeds` key at all — i.e. every committed result to
date came from ad hoc, hand-run `bench/run.py` invocations across several
sessions (see `03-results-so-far.md`'s provenance table), not from a single
coherent `sweep.py` run of either shipped grid. See
`04-gaps-and-drawbacks.md` item 1.

## 5. `bench/report.py` — turning raw output into `REPORT.md`

Reads every `.jsonl` + `.meta.json` pair under `results/raw/`. Because
`run.py` itself never logs which train examples it selected for a given
query (only the final prompt/completion), `report.py`'s
`reconstruct_selection()` **replays** `select_examples()` against
freshly-encoded query vectors and the same cached train vectors `run.py`
used, using the exact config recorded in each run's `.meta.json` — same
production code path, not a separate reimplementation.

Produces, per invocation:

- **Section 1 (run header):** git SHA + dirty flag (`git rev-parse
  HEAD`/`git status --porcelain`, run live at report-generation time — this
  reflects whatever commit is checked out *when `report.py` runs*, not
  necessarily the commit whose code produced the raw rows being
  summarized; see `06-reproducibility-and-methodology-notes.md`), tracked
  package versions (via `importlib.metadata`), the config grid actually
  present in the raw files, wall-clock span, total prompt/completion
  tokens, and a **"Datasets tested" row count per dataset** that is
  `min(len(rows))` across that dataset's own configs — **not** the
  `--limit` value any single config was run with. See
  `04-gaps-and-drawbacks.md` item 8 for a case where this produces a
  misleading number for one dataset.
- **Section 2 (health):**
  - `grid_completion` — PASS/FAIL from each config's `.meta.json`
    `partial` flag and `n_samples_written == n_samples_total` — **both of
    these come from the same self-reported `.meta.json`, so a `.meta.json`
    that is itself wrong (see item 8 below) passes this check anyway.**
  - `api_errors` — hardcoded `"NOT RECORDED"`. No 429/other/retry counter
    exists anywhere in `run.py`'s `call_with_backoff()`; it only logs a
    warning on retry.
  - `tokens_per_minute` — the **peak** is hardcoded `"NOT RECORDED"`.
    What *is* computed is an "average, context only" figure per config:
    `total_tokens / (wall_clock_seconds / 60)`. This is not a real
    peak-load measurement and can be actively misleading when much of a
    config's wall-clock time was spent on response-cache hits (near-instant)
    rather than live API calls — see `04-gaps-and-drawbacks.md` for a
    concrete case where this figure comes out at roughly 23x the stated
    free-tier ceiling as a pure caching artifact.
  - `degenerate_sets` — replays selection and flags any config where a
    selected set came back smaller than `k`, empty, or contained duplicate
    ids. Zero occurrences in every run committed to date.
  - `latency` — hardcoded `"NOT RECORDED"`. No per-request timing exists.
  - `determinism` — re-invokes `select_examples()` **twice** on the first
    3 test rows of each non-`zero_shot` config and diffs the resulting id
    order. This checks **selection determinism only** (a pure function of
    cached vectors + config), never LLM-output determinism.
- **Section 3 (results):** accuracy/macro-F1 per config via
  `bench/score.py`'s `compute_metrics()` (imported directly, so `report.py`
  and standalone `score.py` invocations never compute accuracy
  differently); `delta_vs_zero_shot` against the matching `zero_shot`
  config sharing `(dataset, model, reasoning_effort)`; a "best per dataset"
  flag; per-dataset alpha-pivot tables (currently trivial — every run to
  date used exactly one `alpha` value, `0.7`, so each pivot table has
  exactly one row).
- **Section 4 (diversity):** `mean_pairwise_distance`, `mean_sim_to_query`,
  `redundancy` (mean, across queries, of the single highest pairwise
  similarity within that query's selected set), `pool_coverage` (fraction
  of the train corpus ever selected across a whole config's run),
  `topic_match_rate` (**TREC only** — its label field is a genuine topic
  category; the other three datasets' labels are the classification target
  itself, so computing a "topic match rate" against them would be
  circular).
- **Section 6 (verdict):** groups rows sharing everything except `seed`
  (`_config_key`: `setting, k, alpha, backend, pool_multiplier`) and counts
  distinct seeds actually run for the winning config in each dataset. With
  fewer than 2 seeds — **true for every config committed to date** — it
  always emits a fixed "not enough evidence... cannot be distinguished from
  seed-to-seed noise" line and stops there. With 2+ seeds it would compare
  the delta's magnitude against the observed seed-to-seed accuracy spread —
  **this is a heuristic spread comparison, not a computed statistical
  test** (no t-test, no p-value anywhere in this codebase). See
  `04-gaps-and-drawbacks.md` item 5.

**`history.jsonl`:** one append-only JSON line per `report.py` invocation
— timestamp, git SHA/dirty, models, config grid, a compact health summary,
and per-config accuracy/macro-F1/delta/diversity. Existing lines are never
rewritten.

**`REPORT.md` structure:** a static, hand-edited top half ("How to run" +
metric glossary, written once when the file doesn't exist and never
touched again) and a generated region between `<!-- BENCH:BEGIN -->` /
`<!-- BENCH:END -->` markers, rewritten on every `report.py` run. Missing,
duplicated, or out-of-order markers cause `report.py` to refuse to guess
and exit loudly rather than clobber hand-edited content.

## 6. Supporting modules

- **`bench/score.py`** — `compute_metrics()`: accuracy, macro-F1 (via
  per-label precision/recall from confusion counts), parse-failure rate,
  prompt/completion token totals. Parse failures (`prediction is None`)
  count as wrong answers in both accuracy and macro-F1, never dropped from
  the denominator.
- **`bench/prompts.py`** — one fixed instruction string per dataset for
  SST2/CoLA/RTE; TREC's instruction is built dynamically from whatever
  distinct label strings are actually present in the loaded data, not
  hardcoded. One `build_prompt()` shared by all three settings — identical
  wording regardless of setting; only whether/which examples are included
  differs, by construction, so no setting can win purely from a
  prompt-wording difference. `parse_prediction()` checks exact match, then
  prefix match, then substring match, always checking longer label strings
  first (so `"not entailment"` can't be mis-matched via `"entailment"`
  being a substring of it).
- **`bench/datasets.py`** — loads the vendored plain JSONL (no HuggingFace
  `datasets` dependency); one text-extractor and one id-field name per
  dataset (`idx` for SST2/CoLA/RTE, `index` for TREC); fixed label maps for
  SST2/CoLA/RTE; TREC's label map is derived from the data itself (sorted
  distinct label strings present in the training records), not hardcoded.
- **`bench/subsample_data.py`** — the one-time (already-run, not
  re-executed by any live `run.py` invocation) script that produced the
  committed `data/*/train.jsonl` files: stratified-by-label subsampling to
  a 5000-row cap via largest-remainder rounding (so per-label target
  counts sum exactly to the cap), `numpy.random.RandomState(seed=0)`.
  Actual before/after row counts: SST2 63982→5000, CoLA 7696→5000, RTE
  2241→2241 (already under the cap, untouched), TREC 4907→4907 (already
  under the cap, untouched).

## 7. The one other call site sharing this same MMR/retrieval code

`pyq/rag/services/generate.py` is a second consumer of the same
`core/retrieval.py`/`core/mmr.py` functions this benchmark measures, used
for a different (non-classification, no ground-truth label) purpose
outside this paper's scope. It's noted here only for two facts that
directly bear on how far this benchmark's findings can be assumed to
transfer, both confirmed by direct code reading:

- It hardcodes the same `alpha = 0.7` default this benchmark's CLI also
  defaults to — meaning `0.7` is used in two places in this codebase, and
  **validated by neither** (see `04-gaps-and-drawbacks.md` item 2).
- Its candidate-pool-size helper computes `max(10 * k, 50)`, which is a
  **different formula** than this benchmark's `pool_multiplier * k`
  (default `pool_multiplier=3`). Any pool-size sensitivity this benchmark
  eventually measures does not directly translate to that other call
  site's pool sizing without re-deriving the mapping between the two
  formulas.

Nothing else about that call site (what it's used for, what data it reads)
is in scope for this paper.

## 8. What's implemented vs. stubbed vs. aspirational

| Status | Item |
|---|---|
| **Implemented and exercised** | zero_shot/few_shot/mmr_few_shot selection; sbert and tfidf backends; response + embedding caching; YAML sweep grid expansion, `--estimate` cost preview, `max_calls` budget enforcement; accuracy/macro-F1/delta scoring; diversity metrics; single-seed selection-determinism check; `REPORT.md`/`history.jsonl` generation. |
| **Implemented but never executed at scale** | `sweeps/full.yaml`'s multi-seed/multi-alpha/multi-k grid — the code path is real and covered by synthetic-client tests, but has never been run for real against Groq and committed. |
| **Explicitly stubbed** (`report.py`'s own output says so) | `api_errors` (429-vs-other counts, retries), `tokens_per_minute` peak, per-request `latency` (p50/p95) — all hardcoded `"NOT RECORDED"`; no instrumentation exists in `run.py` to produce any of them. |
| **Not implemented at all** | Any formal significance test (paired t-test or otherwise) — `report.py`'s "verdict" is a seed-spread heuristic requiring 2+ seeds, not a computed statistic. |

## 9. Tests covering this code

`backend/tests/test_bench_{cache,datasets,prompts,run,score,selection,
subsample_data,sweep}.py` — all against synthetic data or a faked Groq
client, no live API calls or quota spent. `test_golden.py` separately
protects that the module split which produced `core/mmr.py` and
`core/retrieval.py` in their current form preserved byte-identical
behavior for `cosine_sim`/`mmr` (among other functions) against
pre-refactor captured values.
