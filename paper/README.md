# paper/ — Diverse-ICL model-substitution study

This folder is the single source of truth for writing up a paper about
whether MMR-based diverse example selection for in-context learning (ICL)
still helps when the generating model changes from small, locally-hosted,
4-bit-quantized models to a much larger open-weight model served via a
third-party hosted API. It builds on, and is explicitly scoped as an
extension of:

> Kapuriya et al., *"Exploring the Role of Diversity in Example Selection
> for In-Context Learning,"* SIGIR '25, arXiv:2505.01842.

**Audience for everything in this folder:** a co-author or professor with
zero context on the surrounding codebase — no file here assumes you know
anything about the product this code also ships inside. Where a file
mentions a specific file path or function, it's because that code directly
implements or measures the ICL example-selection mechanism this paper is
about, not because it's asking you to understand the wider system.

## Files, in reading order

| File | What it is |
|---|---|
| [`00-goal-and-scope.md`](00-goal-and-scope.md) | The paper's thesis, stated as a question with three possible answers (positive/negative/null) and what each would mean. Read this first. |
| [`01-source-paper-summary.md`](01-source-paper-summary.md) | Faithful summary of Kapuriya et al.'s method, datasets, models, hyperparameter grid, significance testing, and findings — what we're building on. Flags exactly which claims are independently verified from this repo vs. carried over from the paper's public listing and need checking against the paper itself. |
| [`02-our-implementation-audit.md`](02-our-implementation-audit.md) | Exact, code-referenced description of the MMR/retrieval implementation and the measurement harness built on top of it: file paths, function signatures, defaults, what's implemented vs. stubbed vs. aspirational. |
| [`03-results-so-far.md`](03-results-so-far.md) | Every number actually produced to date, with an explicit confidence flag on each (smoke test / partial sample / full split), all single-seed, none significance-tested. |
| [`04-gaps-and-drawbacks.md`](04-gaps-and-drawbacks.md) | An unflattering, specific list of every weakness found in the current setup and results — including two data-integrity issues found during this audit that aren't recorded anywhere else. |
| [`05-open-source-model-extension-plan.md`](05-open-source-model-extension-plan.md) | The actual new work this paper needs: which models to add, what (if anything) needs to change in the harness to run them, how to compare against the source paper's baselines, and what "success" means concretely. |
| [`06-reproducibility-and-methodology-notes.md`](06-reproducibility-and-methodology-notes.md) | What a reviewer needs to actually reproduce a number from this project: environment, caching behavior, determinism guarantees and their limits (especially hosted-model nondeterminism vs. the source paper's fully local setup), dataset provenance. |

## Current status (as of 2026-09-22)

The implementation is real, tested, and already produces numbers — but
**nothing here answers the paper's central question yet.** Every committed
result is single-seed, most are partial-sample (one dataset's result set is
a 20-row smoke test), and no significance test of any kind has been run. See
`03-results-so-far.md` for the numbers and `04-gaps-and-drawbacks.md` for
why none of them should be treated as validated.

**Next milestone:** run the harness's own wide sweep configuration
end-to-end (multi-seed, multi-alpha, full test splits) for the current model
and at least one additional open-weight model, and add the health
instrumentation the harness currently lacks (API error counts, peak
tokens/minute, per-request latency), before drawing any conclusion in either
direction. See `05-open-source-model-extension-plan.md` for the concrete
plan and `04-gaps-and-drawbacks.md` item 1 for why the existing results
don't already cover this.
