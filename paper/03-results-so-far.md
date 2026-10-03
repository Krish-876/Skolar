# Results so far

**Read this file's confidence flags before citing any number in it.**
Every result below is single-seed (`seed=0`, never varied — see
`02-our-implementation-audit.md` §3) and none has a significance test
applied. Nothing here should be read as confirming or refuting
`00-goal-and-scope.md`'s three candidate outcomes — current data is
compatible with all three.

Source: `backend/bench/results/REPORT.md` (regenerated region, generated
2026-09-10T09:07:44.853658+00:00, git SHA `6b55f39` **dirty=True**), plus
each config's own `.jsonl`/`.meta.json` under `backend/bench/results/raw/`,
cross-checked directly for this audit. Model throughout: `openai/gpt-oss-120b`
via Groq, `reasoning_effort=none`, backend=`sbert`, `pool_multiplier=3`.

## Provenance: how the current result set was assembled

`history.jsonl` (append-only, one line per `report.py` invocation) shows
this was **not** one coherent sweep — it's five incremental snapshots as
raw results accumulated across two sessions:

| # | Timestamp (UTC) | git SHA | dirty | non-zero-shot configs present |
|---|---|---|---|---|
| 0 | 2026-08-31T13:08:16 | `f4440c6...` | True | 2 (sst2 only) |
| 1 | 2026-09-10T07:43:25 | `6b55f39...` | True | 3 |
| 2 | 2026-09-10T08:05:09 | `6b55f39...` | True | 6 |
| 3 | 2026-09-10T09:05:32 | `6b55f39...` | True | 8 |
| 4 | 2026-09-10T09:07:44 | `6b55f39...` | True | 8 (current `REPORT.md`) |

Every row has `git_dirty=True` — the working tree had uncommitted changes
at every single `report.py` invocation to date, which weakens the
git-SHA-based provenance trail (see
`06-reproducibility-and-methodology-notes.md`). Rows 3 and 4 have identical
config numbers; row 4 is the current `REPORT.md`.

## Per-config results

| dataset | setting | k | alpha | rows run | of full test split | accuracy | macro-F1 | delta vs. zero-shot |
|---|---|---|---|---:|---:|---:|---:|---:|
| cola | zero_shot | – | – | 300 | 1043 (28.8%) | 0.8367 | – | baseline |
| cola | few_shot | 4 | – | 300 | 1043 (28.8%) | 0.8500 | 0.8348 | +0.0133 |
| cola | mmr_few_shot | 4 | 0.70 | 300 | 1043 (28.8%) | **0.8567** | 0.8435 | **+0.0200** (best) |
| rte | zero_shot | – | – | 277 | 277 (100%) | 0.9422 | – | baseline |
| rte | few_shot | 7 | – | 277 | 277 (100%) | 0.9422 | 0.9422 | +0.0000 |
| rte | mmr_few_shot | 7 | 0.70 | 277 | 277 (100%) | 0.9422 | 0.9422 | +0.0000 |
| sst2 | zero_shot | – | – | 20 | 872 (2.3%) | 0.9000 | – | baseline |
| sst2 | few_shot | 4 | – | 20 | 872 (2.3%) | 0.9500 | 0.9499 | +0.0500 |
| sst2 | mmr_few_shot | 4 | 0.70 | 20 | 872 (2.3%) | 0.9500 | 0.9499 | +0.0500 |
| trec | zero_shot | – | – | 250 | 500 (50.0%) | 0.8680 | – | baseline |
| trec | few_shot | 7 | – | 250 | 500 (50.0%) | **0.9280** | 0.7687 | **+0.0600** (best) |
| trec | mmr_few_shot | 7 | 0.70 | 234\* | 500 (46.8%\*) | 0.9145 | 0.7575 | +0.0465 |

\* See "Data-integrity caveat on trec's mmr_few_shot row" below.

## Per-dataset confidence assessment

- **sst2 — SMOKE TEST ONLY, do not cite as a finding.** n=20 out of an
  872-row test split (2.3%). This is literally the "smoke sequence"
  bench's own README documents as a fast sanity check, never scaled up to
  a real sample. At n=20, the binomial standard error alone on a ~90-95%
  accuracy estimate is large enough that the entire 0.9000→0.9500 "gain"
  could be one or two flipped predictions. **Both few_shot and
  mmr_few_shot land on the exact same accuracy (0.9500) at this n** —
  consistent with either a genuine tie or (more likely, given the tiny
  sample) simply not enough queries for the two selection strategies to
  diverge at all.
- **cola — partial sample, single seed.** n=300 out of 1043 (28.8%),
  deterministic prefix by ascending id (not random, not stratified — see
  `06-reproducibility-and-methodology-notes.md`). Better than sst2's
  smoke test but still far from the full split, still one seed, no
  significance test. This is currently the dataset with the **largest**
  MMR-vs-few-shot gap in the direction MMR helps (+0.0067 accuracy,
  mmr_few_shot over few_shot).
- **rte — full test split, single seed, and the tie is coincidental at
  the row level.** n=277/277 (100% of the split) is the strongest coverage
  of any dataset here, but the aggregate accuracy being identical between
  few_shot and mmr_few_shot (0.9422382671480144 for both, to 16 significant
  figures — not a rounding coincidence) does **not** mean MMR changed
  nothing. Diffing the two runs' predictions row-by-row (done for this
  audit; the harness itself has no tooling for this) shows **6 of 277
  predictions actually differ** between the two settings, split exactly
  3-and-3:

  | test id | gold | few_shot prediction | mmr_few_shot prediction | effect of switching to MMR |
  |---|---|---|---|---|
  | 51 | entailment | entailment (correct) | not entailment (wrong) | regression |
  | 67 | entailment | not entailment (wrong) | entailment (correct) | improvement |
  | 126 | not entailment | entailment (wrong) | not entailment (correct) | improvement |
  | 183 | not entailment | not entailment (correct) | entailment (wrong) | regression |
  | 223 | not entailment | entailment (wrong) | not entailment (correct) | improvement |
  | 248 | not entailment | not entailment (correct) | entailment (wrong) | regression |

  Three improvements, three regressions, net accuracy change exactly zero.
  **The `REPORT.md` table's `delta = +0.0000` for RTE should be read as
  "MMR changed 6 predictions and they canceled out," not "MMR had no
  effect."** This is a materially different, and more informative, finding
  than the aggregate delta alone conveys — and it's the kind of thing that
  disappears entirely if only `REPORT.md`'s summary numbers are consulted
  (see `04-gaps-and-drawbacks.md` item 10).
- **trec — partial sample for zero_shot/few_shot; the mmr_few_shot row
  carries an unresolved data-integrity issue.** zero_shot and few_shot ran
  on n=250/500 (50.0%). mmr_few_shot's output file
  (`trec_mmr_k7_a0.7.jsonl`) contains **234** rows with 234 distinct ids
  (no duplicates) — **not** 250, even though its own `.meta.json` sidecar
  claims `n_samples_written: 250, partial: false`. `report.py`'s accuracy
  computation reads the actual file, so `0.9145299145299145` is correctly
  computed as `214/234` — the reported accuracy number is internally
  consistent with the file's real contents — but the `.meta.json`'s
  provenance claim about *how many rows were run* is simply wrong, and
  nothing in the harness currently detects this class of mismatch (see
  `04-gaps-and-drawbacks.md` item 8). Treat trec's mmr_few_shot number with
  the least confidence of any result in this file until that file is
  regenerated cleanly and the discrepancy is understood.
- **trec's mmr_few_shot underperforms its own few_shot baseline**
  (0.9145 vs. 0.9280 accuracy — plain top-k retrieval beat MMR-diversified
  retrieval on this dataset, at this k/alpha, in this single run). This is
  at least directionally consistent with the source paper's own reported
  pattern of dataset-dependent, non-universal diversity gains (see
  `01-source-paper-summary.md`) — but given the unresolved row-count issue
  above and the single-seed status shared by every result here, this
  should not yet be treated as a real TREC-specific finding versus an
  artifact of noise or the data-integrity issue.
- **TREC's macro-F1 is well below its accuracy** (0.7687 few_shot / 0.7575
  mmr_few_shot, vs. 0.9280 / 0.9145 accuracy) — expected for a multi-class,
  class-imbalanced task where accuracy alone flatters performance on
  majority classes; not itself evidence of a bug, just a reminder not to
  read TREC's headline accuracy numbers as the whole picture.

## What this file does not establish

- Whether MMR-diversified retrieval helps, hurts, or makes no difference
  at this model's scale — the per-dataset signs are mixed (cola positive,
  rte a wash that's actually 6 real prediction flips canceling out, sst2
  tied at a meaningless sample size, trec negative-but-unreliable) and
  none of it is seed-varied or significance-tested.
- Whether few-shot (of either kind) reliably beats zero-shot at this
  scale — every dataset here shows a positive delta for at least one
  few-shot variant, but again, single-seed, and sst2's is a 20-sample
  smoke test.
- Anything about `sweeps/full.yaml`'s wider grid (multi-k, multi-alpha,
  multi-seed) — it has never been run; see
  `02-our-implementation-audit.md` §4 and
  `04-gaps-and-drawbacks.md` item 1.

See `05-open-source-model-extension-plan.md` for what running that grid,
plus at least one additional model, would need to look like before this
file's numbers could support a real conclusion.
