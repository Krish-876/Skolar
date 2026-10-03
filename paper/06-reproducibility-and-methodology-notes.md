# Reproducibility and methodology notes

What a reviewer or co-author would actually need to reproduce a number from
this project — and, just as important, an honest account of where
reproduction is currently **not** guaranteed to succeed, and why.

## Environment

`backend/requirements.txt` pins the packages `REPORT.md`'s own run header
tracks: `groq==1.6.0`, `sentence-transformers==5.6.1`,
`scikit-learn==1.9.0`, `scipy==1.18.1`, `numpy==2.5.1`. `report.py` reads
these live via `importlib.metadata.version()` at report-generation time and
records whatever is actually installed — this confirms what *was*
installed when a given `REPORT.md` was generated, not a guarantee that a
future `pip install -r requirements.txt` will resolve to the exact same
versions if the pins ever loosen or a transitive dependency changes.

`GROQ_API_KEY` is required in the environment for any `bench/run.py`
invocation that makes a live call (`--estimate`-only invocations need no
key, since they're pure CPU work against the response cache). **No
`.env.example` exists in this repository** — a fresh checkout needs a
hand-created `.env` with at least this variable before anything that calls
the API will run.

## Caching behavior and what it means for reproducibility

- **Embedding cache** — keyed `(dataset, backend[-embedmodel], split)`,
  **not** `--limit`. Re-running the same dataset/backend/split combination
  under a different `--limit` reuses the exact same encoded vectors (good
  for internal consistency), but also means a corrupted or stale cache
  file silently affects every future `--limit` value for that split until
  it's deleted.
- **Response cache** — keyed `sha256(model, reasoning_effort, exact prompt
  string)`. A byte-for-byte-identical prompt served to the same model +
  reasoning effort will, after the first real call, **replay that first
  call's exact completion on every subsequent run, indefinitely**, until
  the specific cache file is deleted by hand. This is a deliberate
  cost-saving design (it's what makes re-running a sweep cheap — see
  `02-our-implementation-audit.md` §4), but it has a direct consequence
  for what "reproducing a result" actually means here: **re-running a
  bench config does not draw an independent new sample from the live
  model — it reproduces exactly the first draw, forever.** There is
  currently no flag or mechanism in `run.py` for "re-roll this exact
  prompt against the live model again"; the only lever is manually
  deleting the relevant cache file(s).

## Determinism — precisely scoped

What **is** guaranteed deterministic by this harness, confirmed by direct
code reading (no RNG call exists anywhere in `core/retrieval.py` or
`core/mmr.py`, and `report.py`'s own determinism health check exercises
this):

1. Test-row ordering — always ascending by id.
2. `--limit` — a deterministic prefix of that ordering (the first N rows
   by id), never a random sample.
3. Retrieval (`retrieve_top_k`) and MMR reranking (`mmr`) — pure functions
   of `(query vector, corpus vectors, k, alpha, pool_multiplier)`, no
   randomness anywhere in either function.
4. `temperature=0` is always passed to the API.
5. `--seed` (default `0`) is currently **inert** — plumbed all the way
   through the CLI and into `sweep.py`'s grid expansion for future use, but
   nothing in the current selection or prompting code reads it for any
   random decision. "Seed" in this harness today is not yet a lever for
   measuring true model output variance — it's scaffolding for the day
   selection (or something else) gains seed-dependent behavior.

What is **not** guaranteed deterministic, and why this is the single
biggest reproducibility gap relative to the source paper: the hosted API
this project calls is a third-party, versioned-without-notice, batched,
provider-controlled serving stack. Even at `temperature=0`, there is no
guarantee that two independent live calls with an identical prompt return
byte-identical completions — batching, hardware, and backend-side
versioning are outside this project's visibility or control. The response
cache (above) *masks* this in day-to-day practice, since a re-run replays
the first draw rather than asking again — but that means this project's
own apparent run-to-run stability is a caching artifact, not evidence the
underlying model itself is deterministic. A cache-cleared re-run, or a
future run after the provider silently updates the model's serving
weights, quantization, or routing, could produce different numbers from
an unchanged prompt with zero code change on this project's side.

**Contrast directly with the source paper's setup:** fully local,
fixed-weight, self-controlled inference (per the paper's own described
setup — see `01-source-paper-summary.md`), with no equivalent
third-party-serving-drift risk. This is a categorical difference in
reproducibility guarantees between the two studies, not a minor detail —
any number this project reports should be published with an explicit note
of how many independent completions it actually reflects (today: exactly
one real draw per distinct prompt, cached and replayed thereafter, never
re-sampled).

## Dataset provenance and splits

- `val.jsonl`/`test.jsonl` are vendored byte-for-byte from a specific
  pinned commit of the source paper's own dataset repository (see
  `backend/bench/README.md` for the exact commit hash and source URL —
  intentionally not duplicated here to avoid a second place this detail
  could drift out of sync).
- `train.jsonl` is **subsampled**, not vendored as-is (see
  `02-our-implementation-audit.md` §6 for the exact method and per-dataset
  before/after counts). Two of the four datasets — SST2 and CoLA — have a
  smaller, differently-composed retrieval/candidate corpus (capped at
  5000 rows, stratified by label) than their original full training
  splits; RTE and TREC were already under the cap and are used
  unsampled. **Any comparison of this project's SST2/CoLA numbers against
  the source paper's own reported numbers is additionally comparing
  against a different-sized retrieval corpus for those two datasets
  specifically**, on top of the model-substitution difference this whole
  paper is about. This repo's own documentation states this as a
  non-comparability caveat for its own single-model results; it applies
  unchanged once additional models are added.

## Current limits on reproducibility — summary

- **Raw per-row output is gitignored.** `results/raw/*.jsonl` (the actual
  predictions/completions) is not committed — only `report.py`'s derived
  `REPORT.md`/`history.jsonl` summaries are. Anyone wanting to check a
  specific prediction (as this audit did for the RTE finding in
  `03-results-so-far.md`) needs the original raw files obtained
  out-of-band; they cannot be recovered from git history alone.
- **Git provenance is weaker than a SHA alone suggests.** Every recorded
  row in `history.jsonl` to date has `git_dirty=True` — the working tree
  had uncommitted local changes at the exact moment every `report.py`
  invocation ran. The recorded SHA identifies the last commit, not
  necessarily the code that actually produced the raw predictions being
  summarized.
- **Hosted-model nondeterminism** (above) means even a from-scratch
  re-run with a cleared response cache is not guaranteed to reproduce
  today's numbers, unlike the source paper's fully local setup — this is
  a structural property of the comparison this paper is making, not a
  bug to fix.
- **No fully pinned environment beyond `requirements.txt`'s version
  numbers.** No container image or hash-pinned lockfile is committed
  alongside a given `REPORT.md` snapshot; matching `requirements.txt`'s
  stated versions is the strongest reproducibility guarantee currently
  available, not a complete one.

## Practical reproduction recipe

For a co-author trying to reproduce a specific number in
`03-results-so-far.md`:

1. Check out the git SHA `history.jsonl` records for the relevant run —
   being aware that `git_dirty=True` for every recorded row means the
   commit alone is **not** sufficient; uncommitted local changes existed
   at run time and are not captured anywhere in this repo.
2. Install exactly the package versions `REPORT.md`'s run header records
   (not just whatever `requirements.txt` currently resolves to, if it has
   since changed).
3. Populate `.env` with `GROQ_API_KEY`.
4. **Do not delete `bench/.cache/`.** Deleting the response cache forces
   live re-calls to the hosted API, which — per the nondeterminism caveat
   above — is not guaranteed to reproduce the original numbers even with
   every other variable held fixed.
5. Obtain the original `results/raw/` output out-of-band (it's gitignored,
   so it must come from whoever ran it, not from git).
6. Re-run `bench/report.py --results-dir <that raw dir> --out-dir <wherever>`
   to regenerate `REPORT.md`/`history.jsonl` from that preserved raw data.

Step 4 is the crux of the whole exercise: this recipe reproduces
*this project's own recorded numbers*, not an independent confirmation
that the underlying hosted model would say the same thing again today.
