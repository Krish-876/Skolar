-- =============================================================================
-- Skolar — Database Schema v2
-- PostgreSQL + pgvector (Supabase)
-- =============================================================================
--
-- Hierarchy:
--   Institution → Campus → Academic Year → Subject
--                                           └── Paper Year → Exam Type → Questions
--
-- Exam type syllabus inclusion:
--   quiz1   ⊂  midsem  ⊂  quiz2  ⊂  compre
--
-- Pipeline compatibility:
--   questions queried by college (campus short_name, text) +
--   subject (text) + optional paper_year range — pipeline.py unchanged.
--
-- No seed data — institution and campus rows are created from the
-- onboarding flow using the authenticated user's email and college field.
--
-- =============================================================================

create extension if not exists vector;


-- -----------------------------------------------------------------------------
-- INSTITUTIONS
-- One row per university. e.g. BITS Pilani = one row covering all campuses.
-- email_patterns: JSON array of regex strings matched in Dart at onboarding.
-- e.g. [".*@.*bits-pilani\\.ac\\.in"]
-- -----------------------------------------------------------------------------
create table institutions (
    id               uuid primary key default gen_random_uuid(),
    name             text not null,           -- 'BITS Pilani'
    short_name       text not null unique,    -- 'BITS'
    email_patterns   jsonb not null default '[]',
    website          text,
    created_at       timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- CAMPUSES
-- A campus belongs to one institution.
-- short_name = 'BPHC' / 'BPGC' / 'BPPC' — must match questions.college exactly.
-- subdomain used to resolve campus from email at onboarding:
--   f20240175@hyderabad.bits-pilani.ac.in → subdomain 'hyderabad' → BPHC
-- -----------------------------------------------------------------------------
create table campuses (
    id               uuid primary key default gen_random_uuid(),
    institution_id   uuid not null references institutions(id) on delete cascade,
    name             text not null,           -- 'Hyderabad Campus'
    short_name       text not null unique,    -- 'BPHC'
    subdomain        text,                    -- 'hyderabad'
    location         text,
    created_at       timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- SUBJECTS
-- UI-level table — drives the subject picker per academic year.
-- name must exactly match free-text questions.subject — naming contract, not FK.
-- Scoped per institution so subjects are shared across all campuses of that
-- institution (a 2nd year AI subject is the same across BPHC, BPGC, BPPC).
-- -----------------------------------------------------------------------------
create table subjects (
    id               uuid primary key default gen_random_uuid(),
    institution_id   uuid not null references institutions(id) on delete cascade,
    name             text not null,           -- 'Artificial Intelligence'
    short_name       text,                    -- 'AI'
    academic_year    smallint not null
                         check (academic_year between 1 and 4),
    created_at       timestamptz not null default now(),
    unique (institution_id, name, academic_year)
);


-- -----------------------------------------------------------------------------
-- USERS
-- Linked to Supabase Auth via auth.users(id).
-- institution_id and campus_id resolved in Dart at onboarding from email.
-- academic_year set by student during onboarding (1–4).
-- college = campus short_name, denormalised here so the pipeline can read it
-- directly from the user without a join.
-- -----------------------------------------------------------------------------
create table users (
    id               uuid primary key references auth.users(id) on delete cascade,
    email            text not null unique,
    full_name        text,
    roll_number      text,                    -- '2024A7PS0175H'
    college          text,                    -- 'BPHC' — denormalised for pipeline
    institution_id   uuid references institutions(id) on delete set null,
    campus_id        uuid references campuses(id) on delete set null,
    academic_year    smallint
                         check (academic_year between 1 and 4),
    avatar_url       text,
    created_at       timestamptz not null default now(),
    updated_at       timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- QUESTIONS
-- Core pipeline table. Free-text college + subject for pipeline compatibility.
--
-- college       = campus short_name ('BPHC')
-- subject       = free text ('Artificial Intelligence')
-- paper_year    = calendar year exam was held (2022, 2025 …)
-- academic_year = year of study this subject belongs to (1–4)
-- exam_type     = quiz1 | midsem | quiz2 | compre | generated
--
-- Syllabus inclusion filter in pipeline.py _EXAM_TYPE_ALLOWED:
--   quiz1   → {quiz1}
--   midsem  → {midsem,  quiz1}
--   quiz2   → {quiz2,   midsem, quiz1}
--   compre  → {compre,  quiz2,  midsem, quiz1}
-- -----------------------------------------------------------------------------
create table questions (
    id               uuid primary key default gen_random_uuid(),

    question_text    text not null,
    marks            integer not null default 0,
    question_type    text not null
                         check (question_type in
                             ('mcq', 'short_answer', 'long_answer', 'numerical')),

    subject          text not null,
    college          text not null,
    paper_year       integer,
    academic_year    smallint
                         check (academic_year between 1 and 4),
    exam_type        text not null
                         check (exam_type in
                             ('quiz1', 'midsem', 'quiz2', 'compre', 'generated')),

    embedding        vector(384),

    published        boolean not null default false,
    published_by     uuid references users(id) on delete set null,
    published_at     timestamptz,

    created_at       timestamptz not null default now()
);


-- -----------------------------------------------------------------------------
-- INDEXES
-- -----------------------------------------------------------------------------

-- Primary pipeline filter
create index idx_questions_college_subject
    on questions (college, subject);

-- With exam_type (most common pipeline query)
create index idx_questions_college_subject_exam
    on questions (college, subject, exam_type);

-- Paper year range filtering
create index idx_questions_paper_year
    on questions (paper_year);

-- Academic year filtering
create index idx_questions_academic_year
    on questions (college, academic_year);

-- Community feed
create index idx_questions_published
    on questions (published)
    where published = true;

-- Vector similarity (cosine) for MMR
create index idx_questions_embedding
    on questions
    using ivfflat (embedding vector_cosine_ops)
    with (lists = 100);

-- Campus subdomain lookup at onboarding
create index idx_campuses_subdomain
    on campuses (subdomain);


-- -----------------------------------------------------------------------------
-- ROW LEVEL SECURITY
-- Flutter  → anon key   → subject to RLS
-- FastAPI  → service key → bypasses RLS
-- -----------------------------------------------------------------------------
alter table questions  enable row level security;
alter table users      enable row level security;

create policy "students read own campus questions"
    on questions for select
    using (
        college = (
            select u.college
            from users u
            where u.id = auth.uid()
        )
    );

create policy "users read own profile"
    on users for select
    using (id = auth.uid());

create policy "users update own profile"
    on users for update
    using (id = auth.uid());