create table public._integration_test (
    id uuid primary key default gen_random_uuid(),
    created_at timestamptz not null default now()
);