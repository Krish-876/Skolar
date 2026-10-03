# Bench report

## How to run

```bash
cd backend

# Smoke sequence: zero_shot baseline + few_shot + mmr_few_shot on COLA, capped
# at 20 samples so it's fast and cheap to sanity-check end to end.
python bench/run.py --dataset cola --setting zero_shot \
    --model openai/gpt-oss-120b --reasoning-effort none \
    --limit 20 --out bench/results/raw/cola_zero_shot.jsonl

python bench/run.py --dataset cola --setting few_shot --k 4 \
    --backend sbert --model openai/gpt-oss-120b --reasoning-effort none \
    --limit 20 --out bench/results/raw/cola_few_shot_k4.jsonl

python bench/run.py --dataset cola --setting mmr_few_shot --k 4 --alpha 0.7 \
    --backend sbert --model openai/gpt-oss-120b --reasoning-effort none \
    --limit 20 --out bench/results/raw/cola_mmr_k4_a0.7.jsonl

# Turn every raw config under bench/results/raw/ into bench/results/REPORT.md,
# and append one row to bench/results/history.jsonl.
python bench/report.py --results-dir bench/results/raw --out-dir bench/results
```

## How these are selected

Two different things get "selected" in a bench run: which test rows a config
is scored on, and which train examples get shown to the model per query.

**Test rows run in this sweep** (from each config's `.meta.json` and its
`.jsonl` row count under `bench/results/raw/`):

| dataset | test split size | rows run | how |
| --- | --- | --- | --- |
| cola | 1043 | 300 (all 3 configs) | `--limit 300` |
| rte | 277 | 277 (all 3 configs) | no `--limit` -- full test split |
| sst2 | 872 | 20 (all 3 configs) | `--limit 20` (the smoke-run limit from "How to run" above) |
| trec | 500 | 250 for `few_shot`/`zero_shot`; **234** for `mmr_few_shot` | `--limit 250`, but see note |

Note: `trec_mmr_k7_a0.7.jsonl` has only 234 rows on disk even though its
`.meta.json` claims `n_samples_written: 250` and `partial: false` -- a stale
or overwritten meta sidecar. Section 1's "Datasets tested" line reports
trec's n as 234 because it takes the *minimum* row count across that
dataset's configs, not the `--limit` that was actually passed. Re-run that
config to get a clean, consistent trec count before leaning on cross-config
comparisons for it.

**1. Which test rows a config runs on.** `bench/run.py` loads the full
`test.jsonl` for the dataset, sorts it by its id field (`idx` for
SST2/COLA/RTE, `index` for TREC), and -- if `--limit N` was passed -- keeps
only the first N rows in that sorted order. This is a deterministic prefix,
not a random sample. The slice happens *after* the retrieval backend encodes
the full test split, so one on-disk embedding cache serves every `--limit`
value for a split. Without `--limit`, the whole test split runs (as RTE did
here).

**2. Which train examples are shown as in-context examples**
(`few_shot`/`mmr_few_shot` only -- `zero_shot` shows none). The candidate
pool is the dataset's `train.jsonl`, pre-capped *once*, not per run, to at
most 5000 rows by `bench/subsample_data.py`: stratified by label (so class
proportions are preserved) with a fixed seed (reproducible/auditable). cola
and sst2's original train splits exceeded 5000 and were capped down to it;
rte (2241) and trec (4907) were already under the cap and are untouched. For
each query:
- `few_shot` retrieves the top-k most similar train examples by cosine
  similarity over the configured `--backend` embeddings (sbert in this
  sweep).
- `mmr_few_shot` first retrieves a pool of `pool_multiplier * k` candidates
  the same way, then reranks that pool down to k with Maximal Marginal
  Relevance, trading off similarity-to-query against similarity-to-already-picked
  examples via `--alpha` (0.7 here).

Both selection methods are deterministic given the config -- confirmed by
section 2's `determinism` check below -- so re-running the same config
reproduces the same example sets.

## Metric glossary

**grid_completion** -- Measures whether every config in the requested grid produced a complete (non-partial) results file. Good: PASS, i.e. every config finished. A FAIL here means at least one config was cut short (see run.py's `partial` flag) -- usually the Groq daily cap. Knob: re-run the missing config(s), or lower `--limit` so a sweep fits inside the daily request budget.

**api_errors** -- Splits API failures into 429 rate-limit errors vs everything else, plus how many retries were spent recovering from them. Good: low counts of both, and few retries. Not recorded by the current harness -- call_with_backoff() only logs a warning on retry and never persists the count; needs a counter written into meta.json.

**tokens_per_minute** -- Peak tokens/minute against Groq's free-tier ceiling (8000 tok/min). Good: peak comfortably under the ceiling. A peak near or over it means requests are being throttled/dropped even if the run eventually completes. Not recorded -- no per-request timestamp is written alongside prompt_tokens/completion_tokens, so no per-minute series can be reconstructed. Needs a timestamp per row.

**degenerate_sets** -- Flags configs where a query's selected example set came back smaller than the requested k, or where selection degenerated (e.g. duplicate examples in one set). Good: zero occurrences. Non-zero usually means the train corpus for that dataset is smaller than pool_multiplier * k, or alpha/pool_multiplier are set so aggressively that MMR runs out of distinct candidates. Knob: raise `--pool-multiplier`, or lower `k` for that dataset.

**latency** -- Per-config request latency, p50/p95. Good: low and consistent (p95 not far above p50). High p95 alone usually means intermittent throttling or provider-side queuing, not a code problem. Not recorded -- run.py never times individual client.chat.completions.create() calls. Needs a wall-clock timestamp before/after each request, persisted per row or in meta.json.

**determinism** -- Re-invokes select_examples with identical inputs and checks the selected example ids come back in the same order. Good: PASS (selection is a pure function of the cached vectors and config, so this should always hold; a FAIL would indicate real nondeterminism -- e.g. an unstable sort ties on floating-point similarity -- worth investigating in pyq.rag.core, not silently re-run). This checks *selection* determinism only, not whether the Groq API returns identical completions run-over-run, which is outside this harness's control (see bench/README.md).

**accuracy_delta** -- Accuracy of a few_shot/mmr_few_shot config minus the matching zero_shot baseline for the same (dataset, model, reasoning_effort). Good: positive and larger than run-to-run variance. A negative delta means the retrieved examples are actively hurting the model versus no examples at all -- check the diversity/redundancy numbers for that config before assuming the model itself is at fault.

**alpha_pivot** -- Accuracy as alpha (MMR's relevance/diversity tradeoff) varies, holding k and backend fixed, per dataset. Good: a visible peak somewhere between the extremes -- alpha=1 degenerates to plain top-k retrieval, alpha=0 maximizes diversity at the expense of relevance. A flat curve means alpha isn't the lever moving accuracy for this dataset; look at k or the backend instead.

**mean_pairwise_distance** -- Mean of (1 - similarity) over every pair within a selected example set, averaged across all queries in the config. Good: higher means the k examples shown to the model are more mutually distinct. Near zero means the set is effectively k copies of the same example. Knob: lower alpha (mmr_few_shot) to push MMR toward diversity.

**mean_sim_to_query** -- Mean similarity of each selected example to its query, averaged across the config. Good: higher means the examples are actually relevant to what's being classified. This trades off directly against mean pairwise distance -- raising alpha raises this at diversity's expense.

**redundancy** -- Mean, across queries, of the single highest pairwise similarity found within that query's selected set. Good: lower. High redundancy alongside a low accuracy delta is the specific signature of 'the pool retrieval is fine but MMR isn't diversifying' -- check alpha before blaming the embedding backend.

**pool_coverage** -- Fraction of the training corpus that was selected at least once across the whole test split, for this config. Good: higher generally means selection is drawing from a broad slice of the corpus rather than funneling most queries toward a small repeated set of examples. Low coverage with a large corpus can be a sign the embedding backend clusters queries too tightly.

**topic_match_rate** -- Fraction of selected examples that share the query's topic/category label, for datasets where one exists. Good: higher indicates the retrieval backend is finding genuinely on-topic neighbors, not just lexically similar ones. Not applicable to SST2/COLA/RTE -- their labels are the classification target itself (sentiment/acceptability/entailment), not an independent topic field, so using them here would be circular. TREC's label is a genuine topic category (entity/human/location/...), so it's computed there.

<!-- BENCH:BEGIN -->
## 1. Run header

- **Generated (UTC):** 2026-09-10T09:07:44.853658+00:00
- **Git SHA:** 6b55f398fb4a538fc2cf406dfe97c1ca6fcdaec5 (dirty: True)
- **Package versions:** groq=1.6.0, sentence-transformers=5.6.1, scikit-learn=1.9.0, scipy=1.18.1, numpy=2.5.1
- **Models:** openai/gpt-oss-120b
- **Reasoning effort:** none
- **Config grid:** {"k": [4, 7], "alpha": [0.7], "pool_multiplier": [3], "backend": ["sbert"], "setting": ["few_shot", "mmr_few_shot", "zero_shot"]}
- **Wall clock:** 2026-08-31T13:06:01.867545+00:00 -> 2026-09-10T09:02:51.333930+00:00
- **Total tokens:** 735465 prompt + 305152 completion
- **Configs in this sweep:** 12

**Datasets tested:** 4 — cola (n=300), rte (n=277), sst2 (n=20), trec (n=234)

| dataset | train rows | test rows |
| --- | --- | --- |
| cola | 5000 | 1043 |
| rte | 2241 | 277 |
| sst2 | 5000 | 872 |
| trec | 4907 | 500 |

## 2. Health status

| check | status | detail |
| --- | --- | --- |
| every config completed | PASS | - |
| API errors (429 vs other) / retries | NOT RECORDED | - |
| peak tokens/minute vs 8000 ceiling | NOT RECORDED (peak) | avg (context only): cola_few_shot_k4.jsonl=5720.1, cola_mmr_k4_a0.7.jsonl=7228.0, cola_zero_shot.jsonl=5375.1, rte_few_shot_k7.jsonl=15753.8, rte_mmr_k7_a0.7.jsonl=184058.6, rte_zero_shot.jsonl=6205.4, sst2_few_k4.jsonl=24017.4, sst2_mmr_k4_a70.jsonl=11303.1, sst2_zero.jsonl=18791.7, trec_few_shot_k7.jsonl=7088.8, trec_mmr_k7_a0.7.jsonl=6727.2, trec_zero_shot.jsonl=35043.2 |
| fewer-than-k / empty / duplicate sets | PASS | - |
| latency p50/p95 per config | NOT RECORDED | - |
| determinism (same seed twice -> identical selection) | PASS | checked on the first 3 test rows per config; selection only, not LLM output. |

## 3. Results

| dataset | setting | backend | k | alpha | accuracy | macro_f1 | zero_shot_acc | delta |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| cola | few_shot | sbert | 4 | - | 0.8500 | 0.8348 | 0.8367 | +0.0133 |  |
| cola | mmr_few_shot | sbert | 4 | 0.70 | 0.8567 | 0.8435 | 0.8367 | +0.0200 | **best** |
| rte | few_shot | sbert | 7 | - | 0.9422 | 0.9422 | 0.9422 | +0.0000 | **best** |
| rte | mmr_few_shot | sbert | 7 | 0.70 | 0.9422 | 0.9422 | 0.9422 | +0.0000 |  |
| sst2 | few_shot | sbert | 4 | - | 0.9500 | 0.9499 | 0.9000 | +0.0500 | **best** |
| sst2 | mmr_few_shot | sbert | 4 | 0.70 | 0.9500 | 0.9499 | 0.9000 | +0.0500 |  |
| trec | few_shot | sbert | 7 | - | 0.9280 | 0.7687 | 0.8680 | +0.0600 | **best** |
| trec | mmr_few_shot | sbert | 7 | 0.70 | 0.9145 | 0.7575 | 0.8680 | +0.0465 |  |

### Accuracy vs. alpha -- cola

| alpha | k | backend | accuracy |
| --- | --- | --- | --- |
| 0.70 | 4 | sbert | 0.8567 |

### Accuracy vs. alpha -- rte

| alpha | k | backend | accuracy |
| --- | --- | --- | --- |
| 0.70 | 7 | sbert | 0.9422 |

### Accuracy vs. alpha -- sst2

| alpha | k | backend | accuracy |
| --- | --- | --- | --- |
| 0.70 | 4 | sbert | 0.9500 |

### Accuracy vs. alpha -- trec

| alpha | k | backend | accuracy |
| --- | --- | --- | --- |
| 0.70 | 7 | sbert | 0.9145 |

## 4. Diversity

| config | mean pairwise dist. | mean sim to query | redundancy | pool coverage | topic match rate |
| --- | --- | --- | --- | --- | --- |
| cola_few_shot_k4.jsonl | 0.1925 | 0.8374 | 0.9177 | 0.1964 | N/A (no topic field) |
| cola_mmr_k4_a0.7.jsonl | 0.2374 | 0.8314 | 0.8444 | 0.1984 | N/A (no topic field) |
| rte_few_shot_k7.jsonl | 0.3248 | 0.7265 | 0.8659 | 0.5471 | N/A (no topic field) |
| rte_mmr_k7_a0.7.jsonl | 0.3638 | 0.7188 | 0.7564 | 0.5622 | N/A (no topic field) |
| sst2_few_k4.jsonl | 0.2598 | 0.7737 | 0.8375 | 0.0152 | N/A (no topic field) |
| sst2_mmr_k4_a70.jsonl | 0.3047 | 0.7683 | 0.7395 | 0.0160 | N/A (no topic field) |
| trec_few_shot_k7.jsonl | 0.2930 | 0.7603 | 0.8607 | 0.2466 | 0.5754 |
| trec_mmr_k7_a0.7.jsonl | 0.3336 | 0.7528 | 0.7690 | 0.2429 | 0.5922 |

## 6. Verdict

- cola: best observed config is mmr_few_shot (k=4, alpha=0.7, backend=sbert) at accuracy=0.8567 (delta=+0.0200 vs zero_shot). Not enough evidence to call this significant -- only 1 seed was run for this config in this sweep, so this delta cannot be distinguished from seed-to-seed noise. Re-run it with sweep.py's `seeds` axis set to 2+ seeds before recommending a default.
- rte: best observed config is few_shot (k=7, alpha=None, backend=sbert) at accuracy=0.9422 (delta=+0.0000 vs zero_shot). Not enough evidence to call this significant -- only 1 seed was run for this config in this sweep, so this delta cannot be distinguished from seed-to-seed noise. Re-run it with sweep.py's `seeds` axis set to 2+ seeds before recommending a default.
- sst2: best observed config is few_shot (k=4, alpha=None, backend=sbert) at accuracy=0.9500 (delta=+0.0500 vs zero_shot). Not enough evidence to call this significant -- only 1 seed was run for this config in this sweep, so this delta cannot be distinguished from seed-to-seed noise. Re-run it with sweep.py's `seeds` axis set to 2+ seeds before recommending a default.
- trec: best observed config is few_shot (k=7, alpha=None, backend=sbert) at accuracy=0.9280 (delta=+0.0600 vs zero_shot). Not enough evidence to call this significant -- only 1 seed was run for this config in this sweep, so this delta cannot be distinguished from seed-to-seed noise. Re-run it with sweep.py's `seeds` axis set to 2+ seeds before recommending a default.
<!-- BENCH:END -->
