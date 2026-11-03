# Skolar — Database & Supabase

Core Postgres/Supabase schema: academic tables (subjects, questions, tests, study
plans), storage buckets, RLS conventions, and cascade behavior. Nova's own
tables (`standing_flags`, `nova_history`, `career_units`, `nova_config`,
`nova_unconfirmed_proposals`, etc.) are documented in [NOVA.md](NOVA.md#nova-schema-tables)
instead — they're listed here only where a core table references them.

Back to [README](README.md).

---

## Table of Contents

- [Schema Overview](#schema-overview)
- [Core Tables](#core-tables)
- [Cascade Behavior Summary](#cascade-behavior-summary)
- [Model Answer Structure](#model-answer-structure)
- [Supabase Storage](#supabase-storage)
- [RLS Conventions](#rls-conventions)
- [Migrations](#migrations)

---

## Schema Overview

The schema below reflects the live database. Tables with no corresponding
Flutter/Python description yet are marked **(schema only)**.

## Core Tables

#### `institutions` table

```
id                uuid, primary key, default gen_random_uuid()
name              text, not null
short_name        text, not null, unique
email_patterns    jsonb, not null, default '[]'::jsonb
website           text, nullable
created_at        timestamptz, not null, default now()
```

#### `campuses` table

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
name              text, not null
short_name        text, not null, unique
subdomain         text, nullable
location          text, nullable
created_at        timestamptz, not null, default now()
```

#### `subjects` table

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
name              text, not null
short_name        text, nullable
academic_year     smallint, not null, check (1–4)
semester          smallint, nullable
credits           smallint, nullable
campus_id         uuid, nullable, references campuses.id
created_at        timestamptz, not null, default now()
```

#### `users` table

```
id                uuid, primary key, references auth.users(id)
email             text, not null, unique
full_name         text, nullable
roll_number       text, nullable
college           text, nullable
institution_id    uuid, nullable, references institutions.id
campus_id         uuid, nullable, references campuses.id
academic_year     smallint, nullable, check (1–5) — widened from 1–4 to cover dual-degree students
avatar_url        text, nullable
avatar_data       text, nullable — inline avatar payload from the onboarding avatar picker
branch            text, nullable
dual_branch       text, nullable — second branch for dual-degree students
current_semester  smallint, nullable, check (1 or 2)
study_capacity    text, nullable — free-form capacity note captured at onboarding, feeds `nova_config.capacity_hour_mapping`
plan              text, not null, default 'free'
role              text, not null, default 'student', check (student|admin|super_admin)
semester_credits  smallint, nullable
created_at        timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
```

RLS policies: insert, update, select scoped to `auth.uid()`.

`avatar_data`, `dual_branch`, `current_semester`, and `study_capacity` were
added by the redesigned onboarding flow (see
[Onboarding Seed Context](NOVA.md#onboarding-seed-context) in NOVA.md) — they're
written by the same RPC call that seeds `standing_flags`, `nova_history`, and
`career_units`, not through a separate profile-edit path.

#### `custom_subjects` table **(schema only)**

User- or institution-defined subjects that don't exist in the shared `subjects`
catalog yet.

```
id                uuid, primary key, default gen_random_uuid()
institution_id    uuid, not null, references institutions.id ON DELETE CASCADE
course_code       text, not null
name              text, not null
credits           smallint, nullable
created_at        timestamptz, not null, default now()
```

#### `user_subjects` table

```
id                    uuid, primary key, default gen_random_uuid()
user_id               uuid, not null, references users.id ON DELETE CASCADE
subject_id            uuid, nullable, references subjects.id ON DELETE CASCADE
custom_subject_id     uuid, nullable, references custom_subjects.id ON DELETE SET NULL
semester              text, not null
handout_url           text, nullable
handout_filename      text, nullable
handout_uploaded_at   timestamptz, nullable
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set —
enforced via CHECK constraint `user_subjects_subject_check`.

> `topic_schedule` column was present in an earlier version and has been
> dropped. Study plan data lives in `study_plans`.

#### `user_subject_exams` table

Stores exam dates per enrolled subject. Nova uses this for its `time_left`
urgency signal.

```
id                uuid, primary key, default gen_random_uuid()
user_subject_id   uuid, not null, references user_subjects.id ON DELETE CASCADE
exam_type         text, not null, check (quiz1|midsem|quiz2|compre)
exam_date         date, not null
created_at        timestamptz, not null, default now()
unique            (user_subject_id, exam_type)
```

RLS: scoped to student via `user_subject_id` join.

#### `topics` table

Canonical topic list extracted from PYQs and handouts. All free-text `topic`
columns across the schema have a corresponding `topic_id` FK to this table.

```
id                  uuid, primary key, default gen_random_uuid()
subject_id          uuid, nullable, references subjects.id
custom_subject_id   uuid, nullable, references custom_subjects.id
name                text, not null
created_at          timestamptz, not null, default now()
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set.
Case-insensitive unique indexes prevent "Normalization" and "normalization"
from being stored as separate topics.

RLS: read-only for all authenticated users. Write access pending pipeline key
confirmation (service-role vs anon) — see [Tech Debt](#tech-debt) below.

#### `questions` table

```
id                  uuid, primary key, default gen_random_uuid()
question_text       text, not null
marks               integer, not null, default 0
question_type       text, not null — mcq|short_answer|long_answer|numerical
subject             text, not null  — legacy text, kept for pipeline compatibility
college             text, not null  — legacy text, kept for pipeline compatibility
paper_year          integer, nullable
academic_year       smallint, nullable
exam_type           text, nullable — quiz1|midsem|quiz2|compre|generated
embedding           vector(384), nullable — all-MiniLM-L6-v2
published           boolean, not null, default false
published_by        uuid, nullable, references users.id ON DELETE SET NULL
published_at        timestamptz, nullable
created_at          timestamptz, not null, default now()
options             jsonb, nullable — MCQ options array
correct_index       smallint, nullable — correct option index 0–3
subject_id          uuid, nullable, references subjects.id — canonical FK
campus_id           uuid, nullable, references campuses.id
source_pdf_id       uuid, nullable, references uploaded_pdfs.id
doc_type            text, nullable
topic               text, nullable — legacy free text, kept for pipeline compatibility
topic_id            uuid, nullable, references topics.id — canonical FK
has_diagram         boolean, not null, default false
sub_parts           jsonb, nullable
model_answer        text, nullable
answer_source       text, nullable
confidence_score    numeric, nullable
marks_inferred      boolean, not null, default false
```

`subject` and `topic` text columns coexist with their FK replacements
(`subject_id`, `topic_id`) during migration. New code should write both;
future cleanup will drop the text columns once the pipeline is fully
migrated.

#### `published_tests` table

```
id                uuid, primary key, default gen_random_uuid()
published_by      uuid, nullable, references users.id ON DELETE SET NULL
college           text, not null — legacy
subject           text, not null — legacy
subject_id        uuid, nullable — canonical FK
campus_id         uuid, nullable
exam_type         text, not null, check (quiz1|midsem|quiz2|compre|generated)
question_ids      uuid[], not null — plain array, not FK-enforced
upvotes           integer, not null, default 0
downvotes         integer, not null, default 0
attempts          integer, not null, default 0
created_at        timestamptz, not null, default now()
```

`question_ids` is a plain array — deleting a `questions` row will silently
leave a dangling ID here (see [Tech Debt](#tech-debt)).

A row is only inserted here when the generating request sets `persist: true`
— see [BACKEND.md](BACKEND.md#question-generation--upload-mainpy) for the
current (non-default) persist behavior on `/generate-batch` /
`/generate-open-batch`.

#### `post_votes` table

```
user_id           uuid, not null, references users.id ON DELETE CASCADE
post_id           uuid, not null, references published_tests.id ON DELETE CASCADE
vote              smallint, not null, check (1 or -1)
created_at        timestamptz, not null, default now()
primary key       (user_id, post_id)
```

#### `study_plans` table

```
id                uuid, primary key, default gen_random_uuid()
user_subject_id   uuid, not null, references user_subjects.id ON DELETE CASCADE
user_id           uuid, not null, references users.id ON DELETE CASCADE
subject_name      text, not null — denormalized for query convenience
handout_url       text, not null — which handout version this plan was generated from
topics            jsonb, not null — flat list of topic strings
weekly_plan       jsonb, not null — array of {week, topics, study_hours, focus}
raw_handout_data  jsonb, nullable — full extracted handout data, preserves all content
is_active         boolean, not null, default true
generated_at      timestamptz, not null, default now()
updated_at        timestamptz, not null, default now()
```

Only one plan per `user_subject_id` is active at a time. Uploading a new
handout deactivates the previous plan before inserting the new one. See
[FLUTTER.md](FLUTTER.md#subjects-and-handout-upload) for the trigger path and
[BACKEND.md](BACKEND.md#extract-plan-not-a-fastapi-route) for how (and where)
plan generation actually runs today.

#### `uploaded_pdfs` table **(schema only)**

```
id                    uuid, primary key, default gen_random_uuid()
uploaded_by           uuid, nullable, references users.id ON DELETE SET NULL
uploaded_as           text, not null, default 'student', check (student|admin)
storage_path          text, not null
doc_type              text, not null, check (pyq|tutorial|solution|lab|misc)
subject_id            uuid, nullable, references subjects.id
campus_id             uuid, nullable, references campuses.id
exam_type             text, nullable
paper_year            integer, nullable
topic                 text, nullable
topic_id              uuid, nullable, references topics.id
status                text, not null, default 'pending', check (pending|running|succeeded|partial|failed)
questions_extracted   integer, not null, default 0
questions_failed      integer, not null, default 0
created_at            timestamptz, not null, default now()
```

#### `test_attempts` table **(schema only)**

```
id                uuid, primary key, default gen_random_uuid()
test_id           uuid, not null, references published_tests.id ON DELETE CASCADE
user_id           uuid, not null, references users.id ON DELETE CASCADE
subject_id        uuid, nullable, references subjects.id
exam_type         text, nullable, check (quiz1|midsem|quiz2|compre)
attempt_number    smallint, not null, default 1
total_marks       integer, not null, default 0
obtained_marks    integer, not null, default 0
completed_at      timestamptz, not null, default now()
unique            (test_id, user_id, attempt_number)
```

#### `question_results` table **(schema only)**

```
id                  uuid, primary key, default gen_random_uuid()
attempt_id          uuid, not null, references test_attempts.id ON DELETE CASCADE
question_id         uuid, not null, references questions.id
topic               text, nullable — legacy free text
topic_id            uuid, nullable, references topics.id — canonical FK
is_correct          boolean, nullable
marks_available     integer, not null, default 0
marks_obtained      numeric, not null, default 0
self_rating         smallint, nullable, check (1–5)
error_category      text, nullable, check (concept_gap|practice_gap|careless)
ai_evaluation_id    uuid, nullable, references ai_evaluations.id ON DELETE SET NULL
created_at          timestamptz, not null, default now()
```

#### `ai_evaluations` table **(schema only)**

```
id                    uuid, primary key, default gen_random_uuid()
question_result_id    uuid, not null, references question_results.id ON DELETE CASCADE
user_id               uuid, not null, references users.id ON DELETE CASCADE
question_id           uuid, not null, references questions.id
answer_photo_url      text, nullable
extracted_text        text, nullable
model_answer_used     text, nullable
score_awarded         numeric, nullable
max_score             numeric, nullable
feedback_json         jsonb, nullable
evaluated_at          timestamptz, not null, default now()
```

#### `user_topic_weights` table

EMA-style weakness signal per topic per student.

```
id                  uuid, primary key, default gen_random_uuid()
user_id             uuid, not null, references users.id
subject_id          uuid, nullable, references subjects.id — null for custom subjects
custom_subject_id   uuid, nullable, references custom_subjects.id — null for catalog subjects
topic               text, not null — legacy free text
topic_id            uuid, nullable, references topics.id — canonical FK
weight              numeric, not null, default 0.5, check (0–1)
created_at          timestamptz, not null, default now()
updated_at          timestamptz, not null, default now()
unique              (user_id, subject_id, topic)
```

**Constraint:** exactly one of `subject_id` / `custom_subject_id` must be set
— enforced via CHECK constraint `user_topic_weights_subject_check`.

### Test attempt flow (no dedicated code yet)

A `test_attempts` row represents one student's attempt at a `published_tests`
entry. Each question answered within that attempt becomes a `question_results`
row, capturing correctness, marks, error category, and an optional
self-rating. For written/photographed answers, a `question_results` row can
link to an `ai_evaluations` row.

```
published_tests
      ↓ (student attempts)
test_attempts  (total_marks, obtained_marks, exam_type, completed_at)
      ↓ (one row per question)
question_results  (is_correct, marks_obtained, error_category, topic_id, self_rating)
      ↓ (optional, for photographed/handwritten answers)
ai_evaluations  (answer_photo_url → extracted_text → score_awarded, feedback_json)
```

No Flutter or FastAPI code writes to this flow yet — schema is live, UI/API
isn't. Same for `uploaded_pdfs`: it tracks any PDF through ingestion
independent of which feature triggered the upload, and `questions.source_pdf_id`
links extracted questions back to the source upload — see
[BACKEND.md](BACKEND.md#pdf-upload-pipeline) for the one real writer
(`run_upload_pyq`).

## Cascade Behavior Summary

| Parent deleted | Cascades to | Effect |
|---|---|---|
| `users` | `ai_evaluations`, `post_votes`, `study_plans`, `test_attempts`, `user_subjects`, `nova_*` tables | hard delete |
| `institutions` | `campuses`, `custom_subjects`, `subjects` | hard delete |
| `subjects` | `user_subjects` | hard delete — but blocked by `NO ACTION` from `questions`, `test_attempts`, `uploaded_pdfs` |
| `user_subjects` | `study_plans`, `user_subject_exams`, `staleness_tracker` | hard delete |
| `published_tests` | `post_votes`, `test_attempts` | hard delete |
| `test_attempts` | `question_results` | hard delete |
| `question_results` | `ai_evaluations` | hard delete |
| `users` (as `published_by` / `uploaded_by`) | `published_tests`, `questions`, `uploaded_pdfs` | `SET NULL` — content kept, authorship orphaned |
| `custom_subjects` | `user_subjects.custom_subject_id` | `SET NULL` — enrollment kept, link cleared |
| `ai_evaluations` | `question_results.ai_evaluation_id` | `SET NULL` |
| `questions` | `ai_evaluations`, `question_results` | `NO ACTION` — delete blocked while referenced |

## Model Answer Structure

Model answers (on `questions.model_answer`) are structured markdown,
calibrated to marks:

- **1–3 marks**: 2–3 sentences, bold key terms, no headings
- **4–6 marks**: direct answer + `### Steps` (computational) or `### Key points` (conceptual)
- **7+ marks**: full worked answer with `### Working`, `### Result`, or `### Approach / Explanation / Conclusion`

## Supabase Storage

Bucket: `handouts` (public)

RLS policies:
- `INSERT` — authenticated users only, `bucket_id = 'handouts'`
- `SELECT` — authenticated users only, `bucket_id = 'handouts'`

## RLS Conventions

- Student-owned tables are scoped `user_id = auth.uid()` (or a join through
  `user_subject_id` where there's no direct `user_id` column, e.g.
  `user_subject_exams`).
- `topics` is the one read-shared, write-restricted table — read-only for all
  authenticated users, write access still pending a decision on whether the
  pipeline connects via service-role or anon key.
- Cross-student RLS isolation is verified by `backend/tests/test_rls.py` — see
  [BACKEND.md](BACKEND.md#running-rls-isolation-tests) for how to run it and
  what it actually checks.
- Nova's own RLS pattern (`user_id = auth.uid()` on every Nova table, plus a
  stricter read-only policy on `nova_unconfirmed_proposals`) is documented in
  [NOVA.md](NOVA.md#nova-schema-tables).

## Migrations

Migrations live under `supabase/migrations/`, timestamp-prefixed, applied in
order. This audit didn't change any migration or run `supabase db push` —
schema facts above were read directly from the live migration files, not
inferred. If you're adding a new table or column, follow the existing
migration file naming (`YYYYMMDDHHMMSS_description.sql`) and add RLS policies
in the same migration, not a follow-up one.

## Tech Debt

- **`published_tests.question_ids` is not a real foreign key.** Plain
  `uuid[]` array — deleting a `questions` row silently leaves a dangling ID.
  Fix before any question-deletion or moderation tooling is built.
- **`topics` RLS write policy not yet set.** Read-only for authenticated
  users today. Write policy (for pipeline inserts) is pending confirmation of
  whether the FastAPI backend connects via service-role or anon key. Fix
  before wiring the pipeline to write `topic_id` on question extraction.
- **Free-text `topic` columns — migration in progress.** `questions`,
  `question_results`, `uploaded_pdfs`, `user_topic_weights`, and
  `staleness_tracker` all have both a legacy `topic` text column and a new
  `topic_id` FK to `topics`. Old code writes to `topic` text; new code should
  write both. Text columns will be dropped once the pipeline is fully
  migrated.
- **`academic_year` filtering — not wired.** `academic_year` exists on
  `questions` and the Flutter `UserModel` but isn't used as a filter in
  Flutter or the pipeline. Needed before a year-scoped daily question plan
  can ship.
