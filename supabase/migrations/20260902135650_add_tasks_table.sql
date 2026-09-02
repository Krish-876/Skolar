-- ============================================================
-- Dashboard support: `tasks` table.
--
-- One row per Nova weekly_plan task instance, with an attached timer.
-- Completing a focus-session timer for a task is a single UPDATE setting
-- completed_at + actual_duration_seconds; the dashboard's progress ring,
-- streak strip, and weekly bar chart all derive directly from this table
-- (raw completed_at / actual_duration_seconds rows, bucketed client-side
-- in the student's local time) rather than a separate daily-activity table.
-- ============================================================

CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    study_plan_id uuid NOT NULL,
    user_subject_id uuid NOT NULL,
    subject_name text NOT NULL,
    title text NOT NULL,
    planned_duration_seconds integer NOT NULL,
    actual_duration_seconds integer,
    completed_at timestamp with time zone,
    source_week_start date NOT NULL,
    source_task_key text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tasks_planned_duration_check CHECK (planned_duration_seconds > 0),
    CONSTRAINT tasks_actual_duration_check CHECK (actual_duration_seconds IS NULL OR actual_duration_seconds >= 0)
);

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);

-- Idempotency for whatever process materializes rows out of
-- study_plans.weekly_plan: re-syncing the same week's plan upserts on this
-- key instead of duplicating tasks.
ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_unique_source UNIQUE (study_plan_id, source_week_start, source_task_key);

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_study_plan_id_fkey FOREIGN KEY (study_plan_id) REFERENCES public.study_plans(id) ON DELETE CASCADE;

-- TODO: subject_name is denormalized specifically so completed tasks (and
-- the streak/progress history derived from them) keep their label
-- independent of the live user_subjects row. RESTRICT means deleting a
-- user_subjects row with any tasks still pointing at it will fail instead
-- of silently wiping that history -- whatever implements subject deletion
-- needs to handle this explicitly (e.g. reassign/soft-delete tasks first).
ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_user_subject_id_fkey FOREIGN KEY (user_subject_id) REFERENCES public.user_subjects(id) ON DELETE RESTRICT;

-- Progress-ring / remaining-tasks list: fetch a user's incomplete tasks.
CREATE INDEX tasks_user_remaining_idx ON public.tasks USING btree (user_id) WHERE (completed_at IS NULL);

-- Streak / weekly bar chart: range-scan a user's completed tasks by time.
CREATE INDEX tasks_user_completed_idx ON public.tasks USING btree (user_id, completed_at) WHERE (completed_at IS NOT NULL);

CREATE TRIGGER tasks_set_updated_at BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- (select auth.uid()) rather than a bare auth.uid() so Postgres init-plans
-- it once per statement instead of re-evaluating per row (Supabase's
-- documented RLS performance pattern).
CREATE POLICY tasks_own ON public.tasks USING ((user_id = (select auth.uid()))) WITH CHECK ((user_id = (select auth.uid())));
