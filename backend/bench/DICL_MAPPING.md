# Mapping Diverse-ICL onto Skolar's PYQ generation system

This document grounds the "conceptual background" section of a paper about
running Skolar's retrieval/reranking pipeline (as measured by `backend/bench/`)
on `openai/gpt-oss-120b` via Groq's free tier. It maps the original
Diverse-ICL (DICL) paper's setup onto this project's PYQ generation system,
concept by concept, and is explicit about where the analogy holds and where
it breaks.

This document serves two goals, and neither should compromise the other:
(a) **Skolar's PYQ generation working well for real students** — the primary
goal; the paper is a byproduct of that work, per the team's stated priority,
not the reason the retrieval/MMR pipeline exists; and (b) **an independent
paper on how DICL's diversity-in-example-selection method behaves under a
model substitution** — modern open-weight `gpt-oss-120b` via Groq, in place
of DICL's original local Phi2/Mistral/LLaMA3 — explicitly scoped as a
replication-of-method-on-a-new-model study. That paper should not claim DICL
improves real PYQ generation quality: no ground-truth metric exists to
support such a claim (see §4/§6), so any "it works" claim must stay scoped to
the classification datasets where accuracy is actually measurable.

**Source paper:** Kapuriya et al., *"Exploring the Role of Diversity in
Example Selection for In-Context Learning,"* SIGIR '25, arXiv:2505.01842.
Paper details not directly verifiable from this repo (exact accuracy numbers,
exact model names/sizes used in the paper's own experiments, the paper's own
stated alpha/k sweep ranges) are cited below as "per the paper's public
abstract/arXiv listing" and flagged for verification before publication —
this repo vendors only the paper's **datasets**, not the paper text or its
result tables (`bench/README.md`).

---

## 1. DICL's original setup

Per `bench/README.md` and `bench/datasets.py` (which vendor and describe the
paper's own data), DICL is applied to four **text classification** tasks:

| Dataset | Task | Label set |
|---|---|---|
| SST2 | Sentiment classification | `{negative, positive}` (fixed, 2-way) |
| CoLA | Grammatical acceptability | `{unacceptable, acceptable}` (fixed, 2-way) |
| RTE | Textual entailment | `{entailment, not entailment}` (fixed, 2-way) |
| TREC | Question type classification | derived from data: free-text category names (e.g. `entity`, `human`, `location`, ...) |

A **sample** in DICL's world is one labelled row from one of these datasets,
e.g. (per `bench/datasets.py`'s field handling):

```json
{"sentence": "a stirring , funny and finally transporting re-imagining of beauty and the beast", "label": 1, "idx": 0}
```

(RTE samples carry `sentence1` + `sentence2` instead of a single `sentence`;
TREC carries `text` and a string `label` instead of an int.)

**"Label"** in DICL is always the fixed classification target for that
dataset — sentiment, grammaticality, entailment, or question-type category.
It is ground truth, known for every train and test row, and it is what the
model is being asked to predict.

**"Diversity in example selection"** in DICL means: when building a few-shot
ICL prompt for a query, don't just take the top-k most-similar labelled
examples — that risks all k examples clustering around one redundant
region of the embedding space (e.g. all near-duplicate positive-sentiment
sentences), which can bias the model's label prediction toward whatever
that cluster's label happens to be. Instead, retrieve a larger candidate
pool by similarity, then MMR-rerank it down to k, trading off relevance
(similarity to the query) against diversity (dissimilarity to
already-selected examples) via a tunable `alpha`. The goal is a few-shot
set that is both relevant to the query and non-redundant with itself, which
this repo's `bench/selection.py` reproduces exactly as
`retrieve_top_k` → `mmr` (the "two-stage method" comment there names this
directly as "Diverse-ICL's two-stage method").

The paper's accuracy metric is straightforward classification accuracy
(and macro-F1) against each dataset's ground-truth label, comparing
zero-shot / few-shot / MMR-few-shot settings.

---

## 2. This project's setup

### What a "sample" is here

A row in this project's question bank (per `store/supabase.py:load_bank_and_embeddings`,
which is the canonical read path) looks like:

```json
{
  "id": "...",
  "question_text": "Explain the working of a TLB with a suitable diagram.",
  "marks": 8,
  "question_type": "theory",
  "subject": "Operating Systems",
  "paper_year": 2023,
  "exam_type": "compre",
  "embedding": [/* 384-dim sbert vector */],
  "topic": "Virtual Memory",
  "academic_year": 2023,
  "doc_type": "pyq"
}
```

### Field-by-field contrast with DICL's row

| DICL field | This project's field | Notes |
|---|---|---|
| `sentence` (or `sentence1`+`sentence2`, `text`) | `question_text` | Both are the text that gets embedded for retrieval. |
| `label` | *(no direct equivalent — see below)* | DICL's label is a fixed classification target; nothing here plays that exact role. |
| `idx` / `index` | `id` | Row identifier, not otherwise used in selection logic. |
| *(none)* | `subject`, `exam_type`, `paper_year`, `academic_year`, `marks`, `question_type`, `topic`, `doc_type` | Metadata DICL's classification rows don't have at all — used here for filtering (`exam_type` tiering via `_filter_by_exam_type` / `_EXAM_TYPE_ALLOWED` in `services/generate.py`) and for prompt context (`generate_question`/`generate_mcq` interpolate `marks`, `question_type`, `topic` into the few-shot example text), not for retrieval or MMR scoring itself. |

### What "label" and "diversity" mean here (no classification label exists)

This project does not classify anything — `services/generate.py` and
`llm/generation.py` **generate new text** (a new question, or a new MCQ +
model answer) conditioned on retrieved examples. There is no fixed target
class being predicted, so DICL's "label" has no literal counterpart. Working
through the candidates:

- **Is the analogous "label" the `topic` field?** `topic` is stored per
  question and interpolated into the few-shot prompt (`generation.py:9,42`:
  `"topic: {q.get('topic', 'unknown')}"`), but it is **never read by
  `retrieval.py` or `mmr.py`** — grep confirms `core/mmr.py` and
  `core/retrieval.py` operate purely on `candidate_embeddings` /
  `corpus_vecs` (raw vectors) and know nothing about `topic`, `exam_type`,
  or any other metadata field. So `topic` is *prompt context* for the LLM,
  not a scoring input for diversity — it is closer to a free-text
  descriptive tag than a classification label, and nothing in this
  pipeline scores "did we retrieve the right topic."
- **Is it `exam_type`?** `exam_type` *is* used for filtering
  (`_filter_by_exam_type`), but as a hard pre-filter before retrieval, not
  as a diversity/relevance signal MMR reasons about. It narrows the pool;
  it doesn't get diversified over.
- **Is it `question_type` (numerical/theory/etc.)?** Same situation as
  `topic` — interpolated into the prompt text, never read by `core/mmr.py`
  or `core/retrieval.py`.

**Conclusion (stated explicitly since the repo doesn't say this anywhere):**
there is no analogue of DICL's ground-truth `label` in this project's
generation flow. `topic`/`exam_type`/`question_type` are metadata used for
*filtering* and *prompt framing*, not for *scoring* diversity or relevance —
that scoring is done purely over the sbert embedding of `question_text`
(confirmed in `core/features.py`: `SbertBackend.encode` embeds raw text;
`similarity`/`mmr` take only vectors). This is a genuine, load-bearing
disanalogy with DICL and not an oversight to paper over — see §3's mapping
table and §6.

Worth being precise about *what* this disanalogy actually costs, though.
Grep-confirms that in DICL's own setup — as reproduced by
`bench/selection.py`, `core/retrieval.py`, and `core/mmr.py` — `label` is
never an input to selection either: `retrieve_top_k` and `mmr` compute
relevance and diversity purely from embeddings (`train_vecs`/
`candidate_embeddings`), and `label` only enters afterward, in
`bench/prompts.py`'s `format_example` (shown to the model as part of the
few-shot text) and in `bench/datasets.py`'s `gold_label` (used to score the
model's *output* for accuracy, after selection has already happened). So the
diversity computation itself — MMR's `alpha * relevance - (1 - alpha) *
diversity` — is identical with or without a label concept, in both DICL's
setting and this one; the missing label does not degrade or change the
selection mechanism.

What the missing label actually costs is narrower: not the mechanism, but
the ability to *measure whether diversity helped* — DICL's accuracy delta
has nothing to compare against here, because there is no gold answer a
generated question could match or fail to match. That is a measurement gap,
not a selection-mechanism gap, and it is exactly the gap §6 already tracks
under "No ground-truth or proxy 'correctness' metric is defined for
generated PYQ output" — this paragraph is a restatement of that same tracked
issue in context, not a new problem.

**What "diversity" means here, concretely:** it is diversity of the
*retrieved example question set* used as few-shot context for a single
generation call — i.e. exactly DICL's mechanism (MMR over embeddings of the
candidate pool, `alpha`-weighted relevance-vs-redundancy), applied to
`question_text` embeddings instead of classification-sentence embeddings.
It is **not** diversity of the *generated output* across a batch — that is
handled by a completely separate mechanism: `services/generate.py`'s
`_dedup_generated` (word-overlap) and `_dedup_by_embedding` (cosine
similarity > 0.85 → drop, with backfill via `_backfill_shortfall`). That
dedup pass runs on the LLM's *outputs*, is not MMR, and is not part of what
DICL's method addresses. A paper describing this system should not conflate
the two: MMR diversifies *what the model sees* per call; dedup diversifies
*what the batch produces* across calls.

The query embedding itself is also worth noting as a divergence: in DICL,
the query is the test sample the model is about to classify. Here
(`services/generate.py:277-280`), the query is either the bare `subject`
name or the student's `current_topic` string — never a specific target
question being generated (there isn't one; generation is open-ended) — so
the "relevance" half of the alpha tradeoff is relevance-to-a-topic-string,
not relevance-to-a-fully-specified-query-instance the way DICL's
`sentence`/`sentence1+sentence2` query is.

`alpha` in this codebase (`core/mmr.py:mmr`) is the same formula as
presumably used by DICL per the paper's public description
(`score = alpha * relevance - (1 - alpha) * diversity`, greedy per step) —
this repo does not vendor the paper's own implementation, so the exact
formula match is inferred from `bench/README.md`'s description of DICL's
method as "top-k retrieval, optionally MMR-reranked from a larger pool,"
**not independently confirmed against the paper's equations** — flagged as
an open question in §6.

---

## 3. Direct mapping table

| DICL concept | This project's analogue | Where it breaks down |
|---|---|---|
| `sentence` / `sentence1`+`sentence2` / `text` | `question_text` | Direct match — both are the retrieval/embedding input. |
| `label` (fixed classification target, ground truth) | *no equivalent* | This project generates text; there is no target class. `topic`/`exam_type`/`question_type` exist as metadata but are used for prompt framing and hard filtering, not diversity/relevance scoring (see §2). |
| `idx` / `index` | `id` | Direct match — row identifier only. |
| `k` (number of few-shot examples) | `k` (`services/generate.py` param, default 5; bench default 4) | Direct match — same role in both. |
| `alpha` (MMR relevance/diversity tradeoff) | `alpha` (`core/mmr.py` param, hardcoded default 0.7 in `services/generate.py` and `bench/run.py`) | Direct match mechanically. Disanalogy: DICL tunes/reports alpha against a measurable accuracy signal per dataset; this project's 0.7 is not empirically derived from the bench results committed so far (see §6). |
| `pool_multiplier` (candidate pool = `pool_multiplier * k` before MMR reranks) | Same parameter name and role in `bench/selection.py`; in the live app, `services/generate.py`'s `_pool_size_for` uses `max(10 * k, 50)` instead of a multiplier | The live pipeline and the bench harness compute pool size differently (`10*k` floor-50 vs. `pool_multiplier*k`) — not the same formula, so bench's pool-size sensitivity doesn't directly transfer to the live app's default pool sizing without re-deriving it. |
| Few-shot examples (labelled rows shown to the model) | Retrieved/MMR-reranked PYQ rows shown to the model as style/difficulty exemplars (`generate_question`, `generate_mcq`) | DICL's examples carry the ground-truth label as part of the shown text (`format_example`: `"{text}\nLabel: {gold}"}`); this project's examples carry `marks`/`question_type`/`topic` as descriptive framing, not a target to reproduce. |
| Zero-shot baseline (no examples, just the instruction) | Not currently used in the live generation flow (`run_generate*` always retrieves + MMRs examples); only exists as a `bench/` setting (`zero_shot` in `bench/selection.py`) for measurement purposes | The live product has no zero-shot generation mode to compare against — the zero-shot comparison only exists inside `bench/`, run against the classification datasets, not against real PYQ generation. |
| Accuracy / macro-F1 against ground truth | *no equivalent metric for real generation* | See below. |
| Example-set diversity (mean pairwise distance, redundancy) | Same metrics, computed by `bench/report.py` over the *classification* datasets' selected example sets — **not** computed anywhere over real generated PYQ output | The bench numbers in `REPORT.md` describe selection behavior on SST2/CoLA/RTE/TREC, reusing this repo's `core/mmr.py`/`core/retrieval.py` code, but say nothing directly about diversity of PYQ example sets or PYQ generation quality — that would require a separate bench-style run against real question-bank data, which does not exist yet (§6). |

### On "correctness" and REPORT.md's proxy metrics

DICL can score accuracy directly because every test sample has a ground-truth
label. This project's generated PYQ has no ground truth to score against —
"is this a good exam question" is not a label lookup. `bench/results/REPORT.md`
(§ "Metric glossary") reflects this split cleanly: its **accuracy/macro-F1/
accuracy_delta/alpha_pivot** metrics are computed only against the vendored
classification datasets' known labels (bench mode `zero_shot`/`few_shot`/
`mmr_few_shot` predicting `sentiment`/`acceptability`/`entailment`/`question type`)
— i.e., they measure the *retrieval/reranking machinery in a setting where
ground truth exists*, as a proxy for whether that machinery works at all, not
as a measurement of real PYQ generation quality. The **diversity metrics**
(`mean_pairwise_distance`, `mean_sim_to_query`, `redundancy`, `pool_coverage`,
`topic_match_rate`) are the ones that could in principle transfer to real PYQ
data (they only need embeddings, not labels), but per REPORT.md they are also
currently computed only over the four classification datasets, not over the
question bank.

---

## 4. What transfers and what doesn't

**Reused as motivating priors (transfers as intuition, not as numbers):**

- The general **retrieve-then-MMR-rerank method** transfers directly — this
  project's `core/retrieval.py`/`core/mmr.py` *are* an implementation of
  that method, reused verbatim by `bench/` (`bench/selection.py`'s explicit
  comment: "this is Diverse-ICL's two-stage method").
- DICL's reported finding that diversity effects need **k and alpha past
  some threshold to show up** (per the paper's public abstract/arXiv
  listing — not independently re-derived in this repo, and the exact
  threshold values it reports are not vendored here, so cite them from the
  paper directly rather than from this repo) is a reasonable prior for why
  this project's bench sweep tests `k ∈ {4, 7}` and `alpha = 0.7` rather
  than, say, `k=1`/`alpha=0.1` — but this repo's own results (§ below) do
  not yet confirm or refute that threshold for gpt-oss-120b.
- DICL's finding that **some datasets are weak testbeds for diversity gains
  while others (per the paper's abstract, tasks needing more nuanced
  reasoning) show it strongly** motivates why this repo's `REPORT.md`
  reports per-dataset deltas separately rather than one pooled number —
  the current run (`REPORT.md` §3) shows exactly this kind of
  dataset-dependent effect: CoLA's mmr_few_shot beats few_shot by +0.0067
  accuracy, but RTE and SST2 show **zero** difference between few_shot and
  mmr_few_shot at their tested k/alpha, and TREC's mmr_few_shot is actually
  *worse* than plain few_shot (0.9145 vs 0.9280) — consistent with "MMR
  diversity gains are not universal across tasks," though `REPORT.md`
  itself cautions every one of these deltas is a **single-seed run** and
  "cannot be distinguished from seed-to-seed noise" (§6 Verdict block).

**Does not transfer (classification → generation gap):**

- DICL's **accuracy** as the target metric does not transfer at all — there
  is no ground truth for "is this generated exam question good," so this
  project cannot report an accuracy delta for real PYQ generation the way
  `REPORT.md` does for SST2/CoLA/RTE/TREC. Any generation-quality claim for
  the live product needs a different proxy (human rating, `evaluate.py`'s
  manual heuristic checks, or the diversity metrics applied to real PYQ
  example sets) — none of which currently produce a committed, reproducible
  number analogous to `REPORT.md`'s accuracy table.
- DICL's **label** concept (and everything downstream of it — `parse_prediction`
  matching a model completion back to one of a fixed label set, macro-F1 per
  class) has no role in real generation, where output is free text, not a
  class pick.
- The **zero-shot vs. few-shot comparison** is meaningful for DICL because
  "no examples" is a coherent alternative classification strategy; for this
  project's live product, "no examples" would mean generating a PYQ-style
  question with zero grounding in the actual college's real PYQs, which
  defeats the stated purpose of the system (`BACKEND.md`: "match that
  specific college's difficulty level, question style, and topic
  distribution") — so zero-shot is a *bench-only* comparison point, not a
  real deployment option.

---

## 4.5. Proposed extension: topic-coverage post-processing

**Status: proposed, not implemented.** This section documents a design under
consideration for `core/mmr.py`'s consumers; no code in `core/` or
`services/generate.py` implements it yet, and it is not part of this
document's replication-of-method claim for DICL (see the framing note at the
end of this section).

### Motivation

Flat MMR over `question_text` embeddings diversifies *wording*, not *topic*.
Because the query is a single embedding (the `subject` string or
`current_topic`, per §2), and MMR's diversity term only measures pairwise
embedding distance between candidates, nothing stops a topically narrow
region of the embedding space from dominating the candidate pool if that
region happens to sit closest to the query. Concretely: if 8 of the top
10-by-similarity questions for "Operating Systems" are all about paging
(because paging questions are common and textually similar to the subject
query), MMR can still return 4-of-5 selected examples on "paging" — each one
individually far enough apart in wording to score well on MMR's diversity
term, while the *topic* distribution of the few-shot set is lopsided. The
generated question then inherits that topic skew, undermining the system's
stated goal (`BACKEND.md`): matching "topic distribution," not just
difficulty/style.

### The proposed method

A two-stage pipeline, where **stage 1 is DICL's method completely
unmodified**:

1. **Stage 1 (unchanged):** run `retrieve_top_k` → `mmr` exactly as today,
   but with a target size of roughly **2-3x k** instead of exactly `k`. This
   produces an MMR-ranked shortlist — still scored purely by the existing
   `alpha * relevance - (1 - alpha) * diversity` objective, same embeddings,
   same code path. No change to `core/mmr.py`'s scoring function or to what
   stage 1 optimizes for.
2. **Stage 2 (new, post-processing only):** from that shortlist, greedily
   select the final `k` examples enforcing topic spread: group the
   shortlist by its `topic` field, then round-robin across distinct topics
   in MMR-rank order within each topic bucket (i.e., take the highest-MMR-rank
   item from topic A, then the highest-MMR-rank item from topic B, etc.,
   cycling through topics) until `k` are picked. Once every distinct topic
   in the shortlist has contributed at least one example and topics are
   exhausted before `k` is reached, fall back to plain MMR rank order over
   whatever remains in the shortlist to fill out the rest.

This is explicitly a **post-processing layer on top of MMR's output**, not a
change to MMR's objective, its embeddings, or its greedy selection procedure
— stage 1 remains a faithful, unmodified application of DICL's method.

### Why post-process after MMR rather than stratify before it

The alternative — grouping/stratifying the candidate pool by `topic` *before*
running relevance/diversity scoring, e.g. capping how many candidates per
topic enter the pool MMR reranks — was considered and rejected in favor of
the after-MMR ordering, for two reasons:

1. **Keeps MMR reportable as a clean baseline.** If topic stratification
   happens before MMR runs, there is no way to isolate "what did DICL's
   method alone produce" from "what did the topic constraint change" — the
   two effects are entangled in the candidate pool MMR even sees. Doing
   topic-coverage strictly after MMR means "MMR" and "MMR + topic-coverage"
   can be reported as two distinct, comparable ablation arms (see the
   framing note below), which a pre-stratification design would not allow.
2. **Doesn't require `topic` to be trustworthy before relevance/diversity
   scores exist.** Pre-stratification would need to partition the *entire*
   candidate pool by `topic` before knowing which candidates are even
   relevant — if `topic` values are noisy (see the precondition below), a
   bad partition could exclude a genuinely relevant, well-worded question
   from ever being scored by MMR at all. Post-processing only asks `topic`
   to distinguish already-shortlisted, already-relevant candidates from each
   other, a lower bar.

### The tradeoff (explicit, not a strict improvement)

Topic-coverage selection can promote a lower-MMR-ranked, different-topic
example over a higher-MMR-ranked, same-topic one purely to satisfy round-robin
coverage. This is a **real cost**, not a strict improvement over flat MMR: the
promoted example is by construction less relevant and/or less diverse
(by MMR's own objective) than the example it displaced. If this extension is
implemented and benchmarked, this should be reported honestly as a
relevance/diversity-quality-vs-topic-spread tradeoff, not framed as a
dominating improvement — e.g. `mean_sim_to_query` and `mean_pairwise_distance`
(REPORT.md's existing diversity metrics, computed over the final k) would be
expected to move in an unfavorable direction relative to flat MMR precisely
because topic-coverage is spending some of MMR's relevance/diversity budget
on topic spread instead.

### Blocking precondition to verify before implementing

Round-robin-by-`topic` only works if equal `topic` strings reliably mean "the
same topic." Per `llm/extraction.py`'s extraction prompt (`llm/extraction.py:59-64`),
`topic` is **LLM-assigned free text**, not a controlled taxonomy: the prompt
asks the model for "a specific 2-6 word concept label" (examples given:
"Dijkstra's shortest path," "TCP three-way handshake") with no fixed
vocabulary, no enum, and no normalization step afterward
(`extraction.py:110`: `q["topic"] = q.get("topic", "")`, passed through
verbatim). This means near-duplicate strings for the same real concept —
e.g. "Paging" vs. "Paging System" vs. "Page Replacement (Paging)" — are
expected across different extraction calls (different chunks, different
documents, possibly different model runs), and exact-string grouping would
silently treat them as different topics: round-robin coverage would then
look more diverse than it actually is, or double-count what is really one
topic as two round-robin slots. **Before implementing stage 2, verify how
skewed real `topic` values are** (e.g. pull distinct `topic` strings for one
subject from Supabase and eyeball near-duplicates) and, if skewed, add a
normalization or fuzzy-grouping step (embedding-similarity clustering of
topic strings themselves is one option, since `core/features.py`'s embedding
model is already available) before grouping — otherwise stage 2's coverage
guarantee is not real.

### Framing relative to the paper's claims

This extension is a **genuine proposed contribution beyond reproducing
DICL's method**, not part of the replication itself. If a paper implements
and benchmarks it, "MMR" (flat, unmodified DICL method) should be presented
as the DICL-faithful baseline condition, and "MMR + topic-coverage" as a
separate, clearly-labeled extension — both reported side by side if adopted,
so that the paper's claim to faithfully reproduce/reuse DICL's method stays
scoped to the unmodified MMR condition and is not diluted by results from
the extension.

---

## 5. Model substitution note

DICL's own experiments were run with locally-hosted, quantized open models
(per the paper's public abstract/arXiv listing and this repo's own framing
in `bench/README.md`: "different models (Groq-hosted, not
LLaMA3.1-8B/Mistral-7B/Phi3-2.8B)" — exact quantization scheme and inference
stack are not detailed in this repo and should be pulled from the paper
itself before publication, not asserted here). This project instead runs
**`openai/gpt-oss-120b` via Groq's hosted free-tier API** (`llm/client.py:8`;
same model id used by both the live app and `bench/run.py`'s default
invocations).

This is a substitution worth flagging explicitly in a paper, not glossing
over, for three independent reasons:

1. **Different model family and scale.** gpt-oss-120b is a different
   architecture/training lineage and an order of magnitude larger parameter
   count than the paper's ~2.8B–8B local models. Any diversity effect size
   observed here is not evidence about the same effect at the paper's model
   scale, and vice versa — `bench/README.md` says this outright ("Results
   here are not comparable to the numbers in that paper's table").
2. **API-hosted vs. local inference.** The paper's setup is fully local and
   reproducible offline; this project depends on a third-party hosted
   endpoint with its own (undocumented, provider-controlled) serving
   stack, quantization, and versioning that can change without this repo's
   knowledge.
3. **Non-deterministic serving vs. deterministic local setup.** `bench/README.md`'s
   own Determinism section is explicit about this: this harness's *selection*
   (retrieval/MMR) is fully deterministic and reproducible, but "it does not
   guarantee the Groq API itself returns identical completions run-over-run
   — that's outside this harness's control." A local, quantized model run
   with fixed weights and greedy/temperature-0 decoding is a categorically
   more reproducible setup than a hosted API call, even at `temperature=0`
   (`bench/run.py:365`), since batching, hardware, and backend versioning on
   the provider side are not controlled by this project. **Rule:** any
   number reported from a Groq-backed run must be published with an
   explicit run-count (how many independent completions it reflects), never
   presented as if it were the single deterministic output a local,
   fixed-weight model run would produce.

A paper reusing DICL's method on gpt-oss-120b via Groq should present its
own numbers as an independent replication-of-method-not-results, not as a
comparable data point in DICL's original table.

---

## 6. Open questions / gaps to resolve before publication

- **Topic-coverage-augmented example selection (§4.5) is proposed but not
  implemented or benchmarked.** No code exists for the stage-2 round-robin
  selection described in §4.5; `core/mmr.py` and `services/generate.py` are
  unchanged. Before it could be adopted as a default (or even reported as an
  experimental arm), `bench/selection.py` would need a new selection mode
  alongside `zero_shot`/`few_shot`/`mmr_few_shot` (e.g. `mmr_topic_coverage`)
  so it can be measured with the same harness and metrics as the existing
  three settings — and, per §4.5's blocking precondition, `topic` value
  cleanliness needs to be checked/fixed first, since TREC's `label` field is
  the only place this harness currently derives `topic_match_rate` from
  data (`bench/README.md`'s dataset table) and none of SST2/CoLA/RTE/the real
  question bank have been checked for topic-string consistency at all.
  **Rule:** if implemented, must be reported as a separate ablation arm,
  never merged into the DICL-faithful MMR condition.
- **No committed bench results specific to real PYQ data exist.** `REPORT.md`
  measures only the four vendored classification datasets; there is no bench
  run (yet) that applies `core/retrieval.py`/`core/mmr.py` diversity metrics
  to the actual Supabase question bank. Any generation-quality claim about
  the live product is currently unsupported by this repo's own measurements.
- **`alpha=0.7` is a hardcoded default, not an empirically chosen value** —
  it appears in `services/generate.py`'s three `run_generate*` function
  signatures and as `bench/run.py`'s CLI default, but nothing in this repo
  documents *why* 0.7 rather than another value in `(0, 1)`. `REPORT.md`'s
  own "Accuracy vs. alpha" tables currently contain a single alpha value
  per dataset (0.70) — the sweep that would justify 0.7 over other values
  (e.g. sweeping `alpha ∈ {0.3, 0.5, 0.7, 0.9}` per dataset) is supported by
  `sweep.py`'s grid schema but has not been run and committed. **Rule:**
  paper-reported alpha/k must come from a committed `sweep.py` run, not this
  hardcoded default.
- **No ground-truth or proxy "correctness" metric is defined for generated
  PYQ output.** `evaluate.py` exists as a manual, non-automated sanity check
  (MCQ validity, answer substance, pairwise diversity) but is explicitly "not
  part of the automated test suite" (`ONBOARDING.md` §2/§7) and produces no
  committed, reproducible number. A paper claiming generation quality needs
  either a human-rating protocol or a defined automatic proxy — neither
  exists yet. **Rule:** any claim about DICL's method "working" must stay
  scoped to the classification datasets where accuracy is measurable, not
  extended to real PYQ generation, until this gap closes.
- **All `REPORT.md` deltas are single-seed.** The report's own Verdict
  section says every accuracy delta reported "cannot be distinguished from
  seed-to-seed noise" and recommends re-running with `sweep.py`'s `seeds`
  axis set to 2+ before treating any config as a recommended default. This
  applies to any k/alpha recommendation a paper draws from the current
  `REPORT.md`. **Rule:** any reported delta must include 2+ seeds before
  being treated as signal, not noise.
- **Several health metrics are not recorded at all** (per `REPORT.md`'s own
  glossary): API error counts/retries, peak tokens/minute, and per-request
  latency (p50/p95) are all listed as "NOT RECORDED" — a paper citing this
  harness's operational characteristics under Groq's free tier cannot yet
  cite these numbers; they require instrumentation changes to `run.py`/`report.py`
  first.
- **The live app's pool-sizing formula (`max(10*k, 50)`) diverges from
  bench's (`pool_multiplier * k`).** No evidence in this repo connects bench's
  `pool_multiplier` sensitivity (if/when measured) back to a recommended
  live-app pool size, since the two are computed differently.
- **The exact MMR score formula used by the original DICL paper is not
  independently verified against this repo's `core/mmr.py` implementation.**
  This repo's `mmr()` computes `alpha * relevance - (1 - alpha) * diversity`
  greedily; `bench/README.md` describes DICL's method only at the level of
  "top-k retrieval, optionally MMR-reranked from a larger pool." Confirm
  against the paper itself (or its reference implementation, if a copy
  becomes available) that this is the same scoring rule and the same
  greedy selection procedure before presenting them as equivalent.
- **`topic`/`exam_type`/`question_type` as candidate "label" analogues are
  this document's own reasoned conclusion, not something asserted anywhere
  else in the repo.** Confirm with whoever owns the generation product logic
  that no other field (e.g. a difficulty tier, or a future taxonomy field)
  is intended to play a label-like role before a paper asserts "there is no
  label" as settled fact.

### Roadmap

Priority order; each step is tagged with which goal it serves (Skolar /
Paper / Both) and which bullet above it closes.

1. **[Paper]** Run `bench/sweeps/full.yaml` (`--estimate` first) — it
   already defines the multi-seed (`seeds: [0, 1, 2]`), multi-alpha
   (`alpha: [0.3, 0.5, 0.7, 0.9]`), all-four-dataset grid needed, but per
   `REPORT.md`'s own run header (`config_grid` shows only `k: [4, 7]`,
   `alpha: [0.7]`, no `seeds` axis) it has never actually been executed —
   the current `REPORT.md` was produced by a narrower single-seed,
   single-alpha grid. Closes the single-seed bullet and the
   `alpha=0.7`-not-empirical bullet above.
2. **[Paper]** Instrument `run.py`/`report.py` to record API error counts
   (429 vs. other, plus retries), peak tokens/minute, and per-request
   latency (p50/p95) — confirmed still stubbed as `"NOT RECORDED"` in
   `report.py`'s health-check output (`report.py:449-455`). Closes the
   "several health metrics are not recorded" bullet above.
3. **[Both]** Define a generation-quality proxy metric (human-rating
   protocol, or an automatic heuristic building on `evaluate.py`'s existing
   manual checks) and use it to run a bench-style diversity measurement
   against the real Supabase question bank, not just the four vendored
   classification datasets. Skolar needs this to know whether real
   generation quality is actually good; the paper needs it before extending
   any DICL-derived claim past the classification datasets. Closes the
   no-ground-truth-metric bullet and the no-committed-real-PYQ-bench-results
   bullet above.
4. **[Skolar]** Check `topic`-string cleanliness in the real question bank
   (pull distinct `topic` values per subject from Supabase and eyeball
   near-duplicates, per §4.5's blocking precondition) before writing any
   §4.5 stage-2 code. Closes the topic-coverage bullet's precondition above.
5. **[Paper]** Verify the exact MMR scoring formula and greedy selection
   procedure against the DICL paper's text or reference implementation
   (this repo currently infers the match only from `bench/README.md`'s
   prose description, per §2). Closes the MMR-formula-verification bullet
   above.
