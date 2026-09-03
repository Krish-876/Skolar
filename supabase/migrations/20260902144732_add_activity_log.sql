-- ============================================================
-- Dashboard support: `activity_log` table.
--
-- Replaces the abandoned per-task/per-timer design (the `tasks` table on
-- feat/dashboard-tasks-schema, not built upon here) with a single
-- lightweight event log: one row per completion event, decoupled from
-- Nova's plan data entirely. The dashboard's semester total time, weekly
-- bar chart, and streak/heatmap all read straight off this table at query
-- time -- no stored rollup counters.
-- ============================================================

CREATE TABLE public.activity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    completed_on date NOT NULL,
    duration_seconds integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activity_log_pkey PRIMARY KEY (id),
    CONSTRAINT activity_log_duration_check CHECK (duration_seconds > 0),
    CONSTRAINT activity_log_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE
);

-- Only FK is to users, and it's the only CASCADE that should ever fire here:
-- deleting a user removes their history; nothing else (plan regeneration,
-- subject deletion, task edits) should ever touch this table.

CREATE INDEX activity_log_user_date_idx ON public.activity_log
    USING btree (user_id, completed_on) INCLUDE (duration_seconds);
-- Backs: semester total time (SUM(duration_seconds) over a date range),
-- tasks-completed-per-week (COUNT(*) grouped by week), and the
-- login/work heatmap (DISTINCT completed_on per user) — all computed at
-- query time, no stored rollup counters.

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- (select auth.uid()) rather than a bare auth.uid() so Postgres init-plans
-- it once per statement instead of re-evaluating per row (Supabase's
-- documented RLS performance pattern).
CREATE POLICY activity_log_select ON public.activity_log
    FOR SELECT
    USING ((user_id = (select auth.uid())));

CREATE POLICY activity_log_insert ON public.activity_log
    FOR INSERT
    WITH CHECK ((user_id = (select auth.uid())));
