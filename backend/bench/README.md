# bench/ -- measurement harness

This is a small harness for deciding provider-hierarchy questions (reasoning
effort, model tier, `k`, `alpha`) **with numbers instead of guesses**, by
running Skolar's actual retrieval/reranking code against labelled
classification data.

**This is NOT a replication of the Diverse-ICL (SIGIR'25) paper.** We reuse
its four datasets and its retrieve-then-rerank *method* (top-k retrieval,
optionally MMR-reranked from a larger pool), but not its models or
hyperparameters. Results here are **not comparable** to the numbers in that
paper's table -- different models (Groq-hosted, not LLaMA3.1-8B/Mistral-7B/
Phi3-2.8B), different `k`/`alpha`/pool sizes, different prompts.

Every retrieval and reranking call in this harness goes through
`backend/pyq/rag/core/{retrieval,mmr,features}.py` -- `retrieve_top_k`,
`mmr`, `SbertBackend`, `TfidfBackend` are imported, never reimplemented. The
point of this harness is that its numbers describe the code Skolar actually
ships, not a separate research implementation.

## Layout

| File | Purpose |
|---|---|
| `datasets.py` | Loads the vendored JSONL, extracts text/labels per dataset. |
| `select.py` | The three ICL settings (`zero_shot`/`few_shot`/`mmr_few_shot`), built on `core.retrieval.retrieve_top_k` and `core.mmr.mmr`. |
| `prompts.py` | One prompt builder per dataset, so every setting shares identical wording -- only the examples differ. |
| `run.py` | CLI that runs a single configuration end-to-end against Groq and writes results. |
| `score.py` | Reads one or more results files and prints accuracy / macro-F1 / parse-failure rate / token totals. |
| `subsample_data.py` | The script that produced `data/*/train.jsonl` -- stratified subsampling to a row cap. Reproducible/auditable; see below. |
| `data/` | Vendored datasets (see below). |
| `.cache/` | Encoding cache, keyed by `(dataset, backend, split)`. Gitignored, regenerated on first use. |

## Datasets

`data/{SST2,COLA,RTE,TREC}/{train,val,test}.jsonl` are vendored copies of the
four Diverse-ICL datasets, taken from
[github.com/Krish-876/Diverse-ICL](https://github.com/Krish-876/Diverse-ICL)
at commit
[`0d4d7d74580fc5de05f6a8310af83034274b8c6a`](https://github.com/Krish-876/Diverse-ICL/tree/0d4d7d74580fc5de05f6a8310af83034274b8c6a)
(`Datasets/{SST2,RTE,TREC,COLA}/*.jsonl`), which packages GLUE SST2/CoLA/RTE
and TREC-6 for that paper's pipeline. Only the datasets are vendored -- none
of that repo's scripts.

`val.jsonl`/`test.jsonl` are vendored as-is, byte-for-byte. `train.jsonl` is
**subsampled** by `bench/subsample_data.py` -- see below.

If the `data/` files are ever missing (e.g. a shallow checkout that excluded
them), re-fetch and re-subsample with:

```bash
git clone --depth 1 https://github.com/Krish-876/Diverse-ICL /tmp/diverse-icl
cp /tmp/diverse-icl/Datasets/SST2/SST2_train.jsonl backend/bench/data/SST2/train.jsonl
cp /tmp/diverse-icl/Datasets/SST2/SST2_val.jsonl   backend/bench/data/SST2/val.jsonl
cp /tmp/diverse-icl/Datasets/SST2/SST2_test.jsonl  backend/bench/data/SST2/test.jsonl
cp /tmp/diverse-icl/Datasets/RTE/rte_train.jsonl   backend/bench/data/RTE/train.jsonl
cp /tmp/diverse-icl/Datasets/RTE/rte_val.jsonl     backend/bench/data/RTE/val.jsonl
cp /tmp/diverse-icl/Datasets/RTE/rte_test.jsonl    backend/bench/data/RTE/test.jsonl
cp /tmp/diverse-icl/Datasets/TREC/trec_train.jsonl backend/bench/data/TREC/train.jsonl
cp /tmp/diverse-icl/Datasets/TREC/trec_val.jsonl   backend/bench/data/TREC/val.jsonl
cp /tmp/diverse-icl/Datasets/TREC/trec_test.jsonl  backend/bench/data/TREC/test.jsonl
cp /tmp/diverse-icl/Datasets/COLA/cola_train.jsonl backend/bench/data/COLA/train.jsonl
cp /tmp/diverse-icl/Datasets/COLA/cola_val.jsonl   backend/bench/data/COLA/val.jsonl
cp /tmp/diverse-icl/Datasets/COLA/cola_test.jsonl  backend/bench/data/COLA/test.jsonl
python bench/subsample_data.py
```

### train.jsonl subsampling

The retrieval corpus a bench run draws its candidate pool from only needs
enough examples to draw a pool of ~50 from (`select.py`'s
`pool_multiplier * k`) -- it doesn't need the full training split, and a
smaller vendored corpus keeps this repo lighter. `bench/subsample_data.py`
subsamples each dataset's `train.jsonl` to **at most 5000 rows**, stratified
by label so the class distribution is preserved (largest-remainder
rounding), using `numpy.random.RandomState(seed=0)`. A dataset already at or
under the cap is kept whole, unchanged.

| Dataset | Rows before | Rows after | Subsampled? |
|---|---:|---:|---|
| SST2 | 63982 | 5000 | yes |
| COLA | 7696 | 5000 | yes |
| RTE | 2241 | 2241 | no (already under the 5000 cap) |
| TREC | 4907 | 4907 | no (already under the 5000 cap) |

- **Source:** [github.com/Krish-876/Diverse-ICL](https://github.com/Krish-876/Diverse-ICL) @ `0d4d7d74580fc5de05f6a8310af83034274b8c6a`
- **Seed:** `0` (`numpy.random.RandomState(0)`)
- **Cap:** 5000 rows

Because the retrieval corpus for SST2 and COLA is a stratified 5000-row
*subset* of their full training splits rather than the full split, **results
from this harness are not comparable to any run over the full training
corpus** (this harness's own full-corpus results included, if it's ever run
against the un-subsampled vendored files) -- a smaller, differently-composed
candidate pool changes what `retrieve_top_k`/`mmr` can select from.

Per-dataset text/label handling (see `datasets.py`):

| Dataset | Text field(s) | Label map |
|---|---|---|
| SST2 | `sentence` | `{0: negative, 1: positive}` (fixed) |
| COLA | `sentence` | `{0: unacceptable, 1: acceptable}` (fixed) |
| RTE | `sentence1` + `sentence2` | `{0: entailment, 1: not entailment}` (fixed) |
| TREC | `text` | derived from the data itself (the set of distinct `label` strings actually present) -- not hardcoded, so a change to the vendored file is reflected automatically |

## Running

```bash
cd backend
python bench/run.py \
    --dataset sst2 --setting mmr_few_shot \
    --k 4 --alpha 0.7 --pool-multiplier 3 \
    --backend sbert --model llama-3.3-70b-versatile --reasoning-effort none \
    --limit 5 \
    --out bench/results/sst2_mmr_smoke.jsonl
```

Requires `GROQ_API_KEY` in the environment (same as the rest of `pyq.rag`;
`run.py` reuses `pyq.rag.llm.client.get_groq_client`).

### Flags

| Flag | Meaning |
|---|---|
| `--dataset` | One of `sst2`, `cola`, `rte`, `trec`. |
| `--setting` | `zero_shot` (no examples), `few_shot` (top-`k` by `retrieve_top_k`), `mmr_few_shot` (retrieve a pool of `pool_multiplier * k`, then `mmr` reranks it to `k`). |
| `--k` | Number of in-context examples (ignored for `zero_shot`). |
| `--alpha` | MMR relevance/diversity tradeoff (`mmr_few_shot` only). |
| `--pool-multiplier` | Pool size for `mmr_few_shot` is `pool_multiplier * k`, capped at the train corpus size. |
| `--backend` | `sbert` (`all-MiniLM-L6-v2`) or `tfidf`. Both are `pyq.rag.core.features` backends. |
| `--model` | Groq model id. **Always required** -- `run.py` never falls back to `llm/client.py`'s hardcoded `GROQ_MODEL`, so different models can be compared directly. |
| `--reasoning-effort` | `none`, `low`, `medium`, or `high`. Passed as Groq's `reasoning_effort` param. `none` **omits the param entirely** rather than sending the literal string, since this is a separate axis from `--model` -- you can hold the model fixed and sweep this. |
| `--limit` | Only run the first N test samples (sorted by id). Omit for the full test split. |
| `--out` | Output JSONL path. A `<out>.meta.json` sidecar recording every CLI arg is always written alongside it. |

### Output

One JSONL row per sample: `id`, `gold`, `raw_completion`, `prediction`
(`null` on parse failure -- never silently dropped), `prompt_tokens`,
`completion_tokens`.

`<out>.meta.json` records every CLI arg plus `seed`, `n_samples_total`,
`n_samples_written`, `started_at`/`finished_at`, and `partial` (`true` if the
run stopped before finishing all samples -- e.g. the Groq daily cap was hit
-- so a results file is always traceable to exactly the config and coverage
that produced it).

### Determinism

- `temperature=0`, a fixed internal seed, and sorted iteration (test samples
  are always processed in ascending id order) -- two runs with identical args
  against identical model responses produce byte-identical output files.
- Encodings are cached to disk under `.cache/`, keyed by
  `(dataset, backend, split)`, so re-running the same dataset/backend combo
  doesn't re-embed.
- This guarantees *our* harness is deterministic. It does not guarantee the
  Groq API itself returns identical completions run-over-run -- that's
  outside this harness's control.

### Rate limits

Groq's free tier is 30 requests/minute and 1000 requests/day. `run.py`:

- proactively throttles to 30 RPM client-side (not just reactive backoff),
- retries on 429 with backoff,
- detects a daily-cap 429 (or exhausting the RPM retry budget) and stops the
  run immediately rather than burning through remaining retries -- the
  partial output and `.meta.json` (`partial: true`) are still written, so
  nothing already spent is lost, and the failure is loud (a raised
  `SystemExit` with the partial-file path), never a silent truncated file.

## Scoring

```bash
python bench/score.py bench/results/a.jsonl bench/results/b.jsonl
```

Prints a comparison table: `n`, `accuracy`, `macro_f1`, `parse_fail_rate`,
`prompt_tok`, `completion_tok`, one row per file. Parse failures count
against accuracy and macro-F1 like any other wrong answer (never dropped
from the denominator), and are also reported as their own rate so a bad
prompt can be told apart from a bad model.

## Tests

`backend/tests/test_bench_*.py` cover `datasets.py` parsing, `select.py`
setting behaviour, `prompts.py` formatting, `score.py` metrics on synthetic
data, and `run.py`'s own rate-limit/partial-meta and CLI-plumbing logic --
all against a faked Groq client, no real API calls or quota spent. Run them
with:

```bash
cd backend
python -m pytest tests/test_bench_datasets.py tests/test_bench_select.py \
    tests/test_bench_prompts.py tests/test_bench_score.py tests/test_bench_run.py
```
