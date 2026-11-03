# Gaps and drawbacks

Blunt, by design — this file exists so nothing gets glossed over later.
Every item below is either a direct finding from reading the code, a
finding from this audit's own data checks, or an explicit limitation
stated in this repo's own documentation. Where a number is cited, it's
reproducible from the sources in `03-results-so-far.md`.

1. **No k/alpha/seed sweep has actually been run.** `sweeps/full.yaml` —
   the grid built specifically to answer this paper's question with
   multiple seeds and multiple alpha values — has zero committed output.
   Every number in `03-results-so-far.md` came from five incremental,
   hand-run `bench/run.py`/ad hoc sessions between 2026-08-31 and
   2026-09-10 (see that file's provenance table), not from a single
   coherent `sweep.py` invocation of either shipped grid config.
2. **`alpha=0.7` is an unvalidated hardcoded default**, used both as
   `bench/run.py`'s CLI default and as a separate hardcoded default
   elsewhere in this codebase's non-benchmark retrieval/MMR call site (see
   `02-our-implementation-audit.md` §7). No bench run has ever compared
   `0.7` against any other alpha value for this model — every alpha-pivot
   table in `REPORT.md` currently has exactly one row.
3. **No seed variance has been measured anywhere.** `seed=0` for every
   committed run; the `seeds` axis both shipped sweep YAMLs define has
   never been exercised. There is currently no data at all on how much
   these accuracy numbers would move on a second independent run against
   the live model.
4. **Several operational health metrics are not recorded by the harness at
   all**, per `report.py`'s own output: API error counts (429 vs. other,
   plus retries), peak tokens/minute, and per-request latency (p50/p95)
   are all hardcoded `"NOT RECORDED"`. This matters specifically for a
   Groq-hosted setup, where "did the free-tier rate limit actually get hit,
   and how often" is part of the story a paper needs to tell honestly, not
   just an operational footnote.
5. **No significance testing is implemented.** `report.py`'s "verdict"
   section is a seed-spread heuristic that requires 2+ seeds before it
   will say anything beyond "not enough evidence" — with 1 seed (every
   config today) it always emits that same fallback line. There is no
   paired t-test, no p-value, nothing resembling the significance test the
   source paper is understood to use (`01-source-paper-summary.md`).
6. **Groq's free-tier rate limits directly constrain sweep scale.**
   `bench/run.py`'s own throttle targets 30 requests/minute and 1000
   requests/day (a different ceiling from the 8000-tokens/minute limit a
   separate part of this codebase enforces for a different purpose — see
   `02-our-implementation-audit.md` §3). `sweeps/full.yaml`'s
   `max_calls: 5000` alone would take multiple days of continuous running
   even before accounting for stalls — and a daily-cap hit halts a run
   immediately (`DailyCapReached`), requiring manual resumption, not
   automatic continuation.
7. **`results/raw/` — the actual per-row predictions — is gitignored.**
   Only `report.py`'s derived `REPORT.md`/`history.jsonl` summaries are
   committed. The RTE 6-prediction-flip finding in
   `03-results-so-far.md` required diffing the raw `.jsonl` files directly
   — that data exists only on whichever machine produced it, is not
   reproducible from git history alone, and a future re-run (even against
   an unchanged prompt, if the response cache is ever cleared) is not
   guaranteed to reproduce it, given hosted-model nondeterminism (see
   `06-reproducibility-and-methodology-notes.md`).
8. **Data-integrity issue found during this audit:
   `trec_mmr_k7_a0.7.jsonl.meta.json` misreports its own row count.** The
   sidecar claims `n_samples_written: 250, partial: false`, but the actual
   `.jsonl` file contains exactly 234 rows with 234 distinct ids (no
   duplicates — confirmed directly). `report.py`'s accuracy computation
   reads the real file and is therefore self-consistent
   (`0.9145299145299145 = 214/234`, confirmed by back-computation), but the
   `.meta.json`'s claim about *how much data this run actually covers* is
   simply false, and **nothing in the harness currently detects this
   class of mismatch** — `report.py`'s `grid_completion` health check only
   compares the sidecar's own two self-reported fields against each other
   (`n_samples_written` vs. `n_samples_total`, both of which agree with
   each other at 250, so the check passes), and never independently
   recounts the `.jsonl` file itself against those claims. This is a real
   harness bug, not merely a `--limit` difference, and it should be fixed
   (recount the file and compare) before trusting any config's row-count
   claim without spot-checking it by hand the way this audit did.
9. **sst2's entire result set is a 20-sample smoke test (2.3% of its
   872-row split)**, sitting in the same `REPORT.md` results table,
   formatted identically to cola's 300-sample and rte's full-277-sample
   rows, with no visual or statistical distinction between them in the
   table itself. A reader skimming `REPORT.md`'s results section alone
   would not know sst2's numbers rest on an order of magnitude less data
   than rte's.
10. **The RTE `delta = +0.0000` result is aggregate-coincidental, not
    "no effect."** Per-row diffing (done for this audit, not by any
    existing tool in the harness) shows MMR flipped 6 of 277 predictions —
    3 improvements, 3 regressions, netting to exactly zero. `REPORT.md`'s
    summary table cannot distinguish "MMR truly did nothing to this
    dataset" from "MMR changed real predictions that happened to cancel
    out" — these are different findings with different implications, and
    the harness has no built-in tooling (no per-row diff report) to
    surface the distinction without ad hoc scripting.
11. **TREC's mmr_few_shot underperforms its own few_shot baseline**
    (0.9145 vs. 0.9280 accuracy) — the one dataset in the current result
    set where MMR is actually worse than plain top-k retrieval, not just
    "no better." Combined with item 8's unresolved row-count issue for
    this exact config, this specific number is the least trustworthy in
    the entire result set, and should not be cited as a TREC-specific
    finding until both the data-integrity issue is resolved and at least
    one more seed confirms the direction.
12. **Stale documentation from the `select.py`→`selection.py` rename.**
    `bench/README.md` and `pyq/ONBOARDING.md` both still reference
    `bench/select.py` and `tests/test_bench_select.py` by their pre-rename
    names (commit `43a7d6b`/PR #110 renamed the module to
    `bench/selection.py` and the test file to
    `tests/test_bench_selection.py` to avoid a stdlib import collision). A
    reader following either doc's exact filenames verbatim will hit an
    import or file-not-found error.
13. **The response cache masks whether "peak tokens/minute" is even a
    meaningful number to report as-is.** `report.py`'s own "average,
    context only" tokens-per-minute figure (computed as
    `total_tokens / wall_clock_minutes`, explicitly labeled not-a-peak) has
    at least one config in the current `REPORT.md` recorded at roughly
    **184,000 tokens/minute** — over 20x the stated 8000-token/minute
    free-tier ceiling a different part of this codebase assumes, and this
    is only an *average*. The likely explanation is that a large fraction
    of that config's rows were response-cache hits (near-instantaneous),
    collapsing the wall-clock duration the average is divided by, without
    reflecting any real live throughput — but this is an inference, not
    confirmed, because the harness records no per-row timestamp to check
    it against. This figure should not be read as evidence the harness is
    somehow bypassing Groq's real ceiling; it's a measurement artifact of
    dividing by a cache-shortened wall clock, and it will keep looking
    alarming (or misleadingly safe, in the other direction) until the
    per-request timing instrumentation in item 4 actually exists.
14. **No independent verification that the implemented MMR formula
    matches the source paper's actual formula.** This repo's `mmr()`
    computes `alpha * relevance - (1 - alpha) * diversity` greedily, with
    `diversity` as the max similarity to already-selected examples. This
    is presented elsewhere in this repo as matching the source paper's
    method, but that match is inferred from this project's own prose
    description of "top-k retrieval, optionally MMR-reranked from a larger
    pool" — it has never been checked against the source paper's actual
    equations. If the formula doesn't match precisely (e.g. a different
    diversity aggregation, a different candidate-pool construction), the
    entire "replicating DICL's method on a new model" framing needs to be
    softened to "implementing a DICL-style method," which is a materially
    weaker claim.
15. **Every result to date is a single model.** `openai/gpt-oss-120b` is
    the only model this benchmark has ever actually been run against; the
    multi-model extension this paper needs (see
    `05-open-source-model-extension-plan.md`) is entirely unexecuted. Any
    observation in `03-results-so-far.md` is a single-model data point,
    not evidence about "open-weight hosted models" as a class.
16. **Provenance trail is weaker than it looks.** Every row in
    `history.jsonl` to date has `git_dirty=True` — the working tree had
    uncommitted changes at the moment every single `report.py` invocation
    ran. The recorded git SHA is therefore not sufficient on its own to
    reconstruct the exact code that produced a given number; see
    `06-reproducibility-and-methodology-notes.md`.

## What was deliberately left out of this file

A separate design document in this repository proposes an unimplemented
topic-coverage post-processing extension to the MMR reranking step, for a
completely different (non-classification, no ground-truth) downstream use
of the same `core/mmr.py` code. It's excluded from this file on purpose:
it's zero code (a proposal only), it targets a use case with no accuracy
metric this paper's method applies to, and including it here would blur
this paper's scope per `00-goal-and-scope.md`'s non-goals. It's mentioned
here only so a reader who's seen that other document doesn't wonder why
it's missing from this list.
