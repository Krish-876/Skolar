# Source paper summary

**Citation:** Kapuriya et al., *"Exploring the Role of Diversity in Example
Selection for In-Context Learning,"* SIGIR '25, arXiv:2505.01842.

## A note on provenance, before anything else

This repository vendors the source paper's **datasets only** — not the
paper's text, its equations, or its result tables. Everything below that
isn't derived directly from this repository's own code/data is being
carried over from the general description of the paper (its own public
abstract/listing, and background knowledge about it), **not independently
verified against the paper's PDF in this audit**. Specifically flagged as
needing verification before this summary is cited in an actual paper
draft:

- The exact model list and their parameter counts/quantization scheme.
- The exact hyperparameter grid (which `k`, `alpha`, `pool_multiplier`
  values the paper itself swept).
- The exact significance-testing procedure and threshold.
- The exact per-dataset/per-model accuracy numbers.

This caution isn't boilerplate — this repo's own internal documentation
(`backend/bench/DICL_MAPPING.md`, `backend/bench/README.md`) independently
arrived at the same conclusion when mapping this project's implementation
onto the source paper's method, and flags the same categories of claim as
unverified. Treat every claim in this file as "this is what we currently
believe the paper says," not "this is confirmed from the paper."

## Method

A two-stage retrieve-then-rerank approach to selecting in-context examples
for classification prompts:

1. **Stage 1 — retrieval.** Embed the query and every candidate example
   from a labelled training corpus; retrieve a pool of the top-N most
   similar candidates by embedding similarity.
2. **Stage 2 — MMR reranking.** Greedily rerank that pool down to `k`
   examples using Maximal Marginal Relevance: at each step, pick the
   candidate maximizing `alpha * relevance_to_query - (1 - alpha) *
   max_similarity_to_already_selected`. `alpha` controls the
   relevance/diversity tradeoff — `alpha = 1` degenerates to plain top-k
   retrieval (no diversity term at all); lower `alpha` pushes selection
   toward more mutually dissimilar examples at some relevance cost.

The paper compares three prompting conditions per dataset/model: **zero-shot**
(no examples), **few-shot** (plain top-k by similarity, no MMR reranking),
and **MMR-few-shot** (the two-stage method above).

## Datasets

Four text classification tasks, all binary or small-label-set
classification with a fixed, known ground-truth label per example:

| Dataset | Task | Label set |
|---|---|---|
| SST2 | Sentiment classification | `{negative, positive}` |
| CoLA | Grammatical acceptability | `{unacceptable, acceptable}` |
| RTE | Textual entailment | `{entailment, not entailment}` |
| TREC | Question-type classification | free-text category names (e.g. `entity`, `human`, `location`, ...) |

## Models

Per the paper's public description (not independently re-verified against
the paper text in this audit — flagged above): **Phi2-2.7B, Mistral-7B-v0.3,
and LLaMA-3.1-8B**, all run locally, all **quantized to 4-bit**. This is a
fully local, self-controlled inference setup — no third-party hosted API
involved, no serving-stack nondeterminism (see
`06-reproducibility-and-methodology-notes.md` for why this matters as a
point of contrast with this project's own setup).

## Hyperparameter grid

The paper is understood to sweep at least the following axes (per its
public description — exact swept *values* not independently confirmed from
this repo and should be pulled from the paper directly):

- `k` — number of in-context examples shown to the model.
- `alpha` — the MMR relevance/diversity tradeoff.
- `pool_multiplier` (or equivalent) — how large a candidate pool is
  retrieved before MMR reranks it down to `k`.

This repo's own harness (see `02-our-implementation-audit.md`) treats these
as the same three tunable axes, and its own wide-sweep configuration
(`sweeps/full.yaml`) exists specifically to explore a grid across them —
independently of whether that grid matches the paper's own swept range,
which remains unconfirmed.

## Significance testing

Per the working understanding of the paper's methodology: a **paired
t-test at p = 0.05** is used to determine whether an observed accuracy
delta (e.g. MMR-few-shot vs. few-shot, per dataset/model) is statistically
distinguishable from zero, presumably paired at the per-query-prediction
level across a fixed test set. **No equivalent test exists anywhere in
this repo's own harness** (see `02-our-implementation-audit.md` and
`04-gaps-and-drawbacks.md`) — this is one of the more consequential
methodological gaps to close before this project's own numbers can be
compared to the source paper's on equal footing.

## Reported findings (per the paper's public description)

- **SST2 is the paper's weakest dataset for showing a diversity gain** —
  i.e., MMR-few-shot's improvement over few-shot is smallest and/or least
  reliable on SST2 relative to the other three datasets.
- **RTE and TREC show the strongest gains** from diversity-aware selection.
- More generally, the diversity effect is **dataset-dependent, not
  universal** — some tasks benefit substantially from diverse example
  sets, others barely at all. This project's own `DICL_MAPPING.md`
  document independently paraphrases this same finding when motivating why
  this repo's bench harness reports per-dataset deltas separately rather
  than one pooled number.

These specific findings (which datasets are strong/weak) are a useful prior
for interpreting this project's own results (`03-results-so-far.md`) —
notably, this project's own committed run also shows TREC's MMR-few-shot
config *underperforming* its own few-shot baseline, which is at least
directionally consistent with "gains are not universal across datasets,"
though with far too little data (single seed, no significance test) to
treat as a confirmation of the paper's specific per-dataset pattern. See
`04-gaps-and-drawbacks.md`.

## Why this project builds on this specific paper

This repo's own retrieval/MMR implementation (`backend/pyq/rag/core/mmr.py`,
`backend/pyq/rag/core/retrieval.py`) is presented, in its own code comments
and in `backend/bench/selection.py`'s docstring, as implementing exactly
this two-stage method — `bench/selection.py`'s inline comment names it
directly: *"this is Diverse-ICL's two-stage method."* The measurement
harness built around it (`backend/bench/`) vendors this paper's own four
datasets specifically so its numbers can be interpreted against this
paper's framing. See `02-our-implementation-audit.md` for the exact code
this maps onto, and the one open question about whether the formula match
is confirmed (it currently is not — inferred from this repo's own prose
description of the method, not checked against the paper's equations).
