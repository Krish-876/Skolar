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

- **Generated (UTC):** 2026-08-31T13:08:16.559809+00:00
- **Git SHA:** f4440c619b525f3d7f5ee8ad79181e6ae5256015 (dirty: True)
- **Package versions:** groq=1.6.0, sentence-transformers=5.6.1, scikit-learn=1.9.0, scipy=1.18.1, numpy=2.5.1
- **Models:** openai/gpt-oss-120b
- **Reasoning effort:** none
- **Config grid:** {"k": [4], "alpha": [0.7], "pool_multiplier": [3], "backend": ["sbert"], "setting": ["few_shot", "mmr_few_shot", "zero_shot"]}
- **Wall clock:** 2026-08-31T13:06:01.867545+00:00 -> 2026-08-31T13:08:00.093210+00:00
- **Total tokens:** 10337 prompt + 5840 completion
- **Configs in this sweep:** 3

| dataset | train rows | test rows |
| --- | --- | --- |
| sst2 | 5000 | 872 |

## 2. Health status

| check | status | detail |
| --- | --- | --- |
| every config completed | PASS | - |
| API errors (429 vs other) / retries | NOT RECORDED | - |
| peak tokens/minute vs 8000 ceiling | NOT RECORDED (peak) | avg (context only): sst2_few_k4.jsonl=24017.4, sst2_mmr_k4_a70.jsonl=11303.1, sst2_zero.jsonl=18791.7 |
| fewer-than-k / empty / duplicate sets | PASS | - |
| latency p50/p95 per config | NOT RECORDED | - |
| determinism (same seed twice -> identical selection) | PASS | checked on the first 3 test rows per config; selection only, not LLM output. |

## 3. Results

| dataset | setting | backend | k | alpha | accuracy | macro_f1 | zero_shot_acc | delta |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| sst2 | few_shot | sbert | 4 | - | 0.9500 | 0.9499 | 0.9000 | +0.0500 | **best** |
| sst2 | mmr_few_shot | sbert | 4 | 0.70 | 0.9500 | 0.9499 | 0.9000 | +0.0500 |  |

### Accuracy vs. alpha -- sst2

| alpha | k | backend | accuracy |
| --- | --- | --- | --- |
| 0.70 | 4 | sbert | 0.9500 |

## 4. Diversity

| config | mean pairwise dist. | mean sim to query | redundancy | pool coverage | topic match rate |
| --- | --- | --- | --- | --- | --- |
| sst2_few_k4.jsonl | 0.2598 | 0.7737 | 0.8375 | 0.0152 | N/A (no topic field) |
| sst2_mmr_k4_a70.jsonl | 0.3047 | 0.7683 | 0.7395 | 0.0160 | N/A (no topic field) |

## 6. Verdict

- sst2: best observed config is few_shot (k=4, alpha=None, backend=sbert) at accuracy=0.9500 (delta=+0.0500 vs zero_shot). Not enough evidence to call this significant -- the harness runs a fixed seed (SEED=0 in run.py) with no repeated-seed variance measurement, so this delta cannot be distinguished from run-to-run noise. Needs multiple seeds per config before recommending a default.
<!-- BENCH:END -->
