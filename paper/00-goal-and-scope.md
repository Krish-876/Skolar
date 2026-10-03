# Goal and scope

## The question, stated plainly

Kapuriya et al. (SIGIR '25, arXiv:2505.01842) showed that MMR-based diverse
example selection for in-context learning (ICL) — retrieve a pool of
similar labelled examples, then rerank that pool to trade off relevance
against diversity — improves classification accuracy over both a zero-shot
baseline and a plain top-k-similarity ("naive") few-shot baseline, on four
text classification datasets, using small (2.7B–8B parameter), 4-bit
quantized, locally-hosted models.

This project asks: **does that effect still show up when the generating
model changes from a small, locally-hosted, quantized model to a much
larger (120B-parameter class) open-weight model served through a hosted
API?**

That single question actually splits into two nested ones, and this paper
should answer both separately, not collapse them into one number:

1. **Does few-shot (plain top-k, no diversity) still beat zero-shot** at
   this new model scale? (The more basic claim — that showing relevant
   examples at all still helps.)
2. **Does MMR-diversified few-shot still beat plain top-k few-shot** at
   this new model scale? (The paper's actual novel claim — that
   *diversity*, specifically, is what's buying the improvement, not just
   "more/better-matched context.")

## What each outcome would mean

- **Positive result** — MMR few-shot > few-shot > zero-shot, replicated
  with enough seeds and datasets to be distinguishable from run-to-run
  noise (see `04-gaps-and-drawbacks.md` for why nothing committed so far
  clears that bar). This would suggest diversity-aware example selection
  remains a real, worthwhile lever even as base model capability scales up
  — i.e., a bigger model doesn't simply absorb the redundancy problem MMR
  is designed to fix.
- **Negative result** — few-shot ≥ MMR few-shot reliably, i.e. the
  diversity gain shrinks to nothing or reverses at this scale. This would
  suggest a large, capable model's own in-context reasoning may already
  compensate for redundant/clustered examples the way MMR tries to prevent
  by construction — making the extra retrieval/reranking complexity less
  justified at this model scale, even if it still helps smaller/weaker
  models.
- **Null result** — no reliable difference between any of the three
  settings, once noise is accounted for. This is the least interesting but
  most likely-sounding outcome given current data: it could mean the four
  classification datasets are simply too easy for a 120B-class model
  (ceiling effects — ~85–95% accuracy already at zero/few-shot on most of
  these datasets per `03-results-so-far.md`, leaving little headroom for
  any selection strategy to show a gap), or that the current sample
  sizes/seed counts genuinely can't detect a real-but-small effect, or
  both. A null result at this stage does **not** distinguish those two
  explanations — see `04-gaps-and-drawbacks.md` and
  `05-open-source-model-extension-plan.md` for what "enough data to tell
  the difference" would look like.

**As of this writing, current results (`03-results-so-far.md`) cannot yet
distinguish between these three outcomes.** They are single-seed, mostly
partial-sample, and have no significance test applied. This file states
the target question; it does not claim an answer.

## How this differs from, and extends, the source paper

Same as the source paper:
- The same four datasets (SST2, CoLA, RTE, TREC) and splits, at least
  nominally (see `06-reproducibility-and-methodology-notes.md` for a
  caveat on the training-corpus subsampling used here).
- The same two-stage method: retrieve a candidate pool by embedding
  similarity, then MMR-rerank that pool down to `k`, trading relevance
  against diversity via `alpha`. Same three-way comparison: zero-shot vs.
  few-shot vs. MMR-few-shot.
- The same evaluation metric: classification accuracy and macro-F1 against
  each dataset's ground-truth label.

Different from the source paper (the actual axis of extension):
- **Model scale and family.** The source paper's models are ~2.7B–8B
  parameters, quantized to 4-bit, run locally. This project's model to
  date is `openai/gpt-oss-120b` — a different architecture/training
  lineage and roughly an order of magnitude larger, run at whatever
  precision the hosting provider uses internally (not controlled or known
  by this project).
- **Serving.** The source paper's setup is fully local and
  self-controlled. This project calls a third-party hosted API (Groq),
  whose serving stack, batching, and model versioning are outside this
  project's control and can change without notice.
- **What's being measured.** This is explicitly a
  *replication-of-method-under-model-substitution* study, not an attempt
  to reproduce the source paper's own reported accuracy numbers. Its
  numbers are not directly comparable to that paper's table — different
  models, and (per `06-reproducibility-and-methodology-notes.md`) a
  differently-sized training/retrieval corpus for two of the four
  datasets.

## Explicit non-goals

- This paper does not, and should not, make any claim about a downstream
  product feature that happens to reuse the same retrieval/MMR code for a
  different (non-classification, no ground truth) task. Nothing in this
  folder should cite that use as evidence either way — there is no
  accuracy signal available there to cite. Where a file in this folder
  mentions a specific consuming code path outside the benchmark harness,
  it is only because that code directly affects how examples are selected
  (e.g. a hardcoded default it shares, or a differently-computed pool
  size) and is noted purely as a technical caveat on transferability, not
  as part of this paper's evidence base.
- This paper does not claim the source paper's exact MMR scoring formula
  has been independently verified against this implementation — that
  match is currently inferred, not confirmed against the paper's own
  equations (see `01-source-paper-summary.md` and
  `02-our-implementation-audit.md`).
