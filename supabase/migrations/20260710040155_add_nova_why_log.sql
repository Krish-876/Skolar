create table public.nova_why_log (
    id uuid not null default gen_random_uuid(),
    user_id uuid not null references public.users(id) on delete cascade,
    entry_type text not null check (entry_type = any (array['full_pass'::text, 'minor_trigger'::text, 'one_off_override'::text])),
    user_subject_id uuid references public.user_subjects(id),
    topic_id uuid references public.topics(id),
    career_unit_id uuid references public.career_units(id),
    facts_snapshot jsonb,
    plan_output jsonb,
    reasoning_summary text not null,
    superseded_at timestamptz,
    supersedes_id uuid references public.nova_why_log(id),
    created_at timestamptz not null default now(),
    constraint nova_why_log_pkey primary key (id),
    constraint nova_why_log_full_needs_snapshot
        check (entry_type <> 'full_pass'::text or facts_snapshot is not null)
);

comment on table public.nova_why_log is
    'Audit trail for Nova reasoning passes (spec §7). entry_type=full_pass reasons over the whole facts snapshot, so unit-scoped FKs (user_subject_id/topic_id/career_unit_id) are typically null on those rows — full breadth lives in facts_snapshot/plan_output. minor_trigger and one_off_override rows populate the relevant single FK instead. Close-call/flicker flags (§4) are recorded inside plan_output, not as a separate column.';

create index idx_nova_why_log_user_created
    on public.nova_why_log (user_id, created_at desc);

create index idx_nova_why_log_supersedes
    on public.nova_why_log (supersedes_id);

alter table public.nova_why_log enable row level security;

create policy "users read own why-log"
    on public.nova_why_log for select
    using (user_id = auth.uid());