-- Nova Tasks & Timetable: `tasks` table, `activity_log.task_id` link, and the
-- `complete_task` RPC that is the only way a client can mark a task done.
-- See TASKS_PLAN.md (Phase 1 spec) for the full design rationale.

-- 1. tasks
CREATE TABLE public.tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    week_start date NOT NULL,
    planned_for date NOT NULL,
    user_subject_id uuid REFERENCES public.user_subjects(id) ON DELETE SET NULL,
    topic text NOT NULL,
    title text NOT NULL,
    -- Lower bound mirrors the existing global nova_config default
    -- 'focus_min_duration_seconds' = 60 (see 20261003071904); upper bound
    -- mirrors activity_log_duration_check's 86400 (a session can't exceed
    -- 24h). CHECK constraints can't subquery nova_config, so these are
    -- literals kept in sync by hand -- Phase 2 should read the same
    -- nova_config key when Nova assigns timer_seconds so the two limits
    -- don't drift apart in practice.
    timer_seconds integer NOT NULL CHECK (timer_seconds >= 60 AND timer_seconds <= 86400),
    priority integer NOT NULL CHECK (priority >= 1),
    reason text NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'done', 'missed', 'dropped')),
    reschedule_count integer NOT NULL DEFAULT 0 CHECK (reschedule_count >= 0),
    why_log_id uuid REFERENCES public.nova_why_log(id) ON DELETE SET NULL,
    completed_at timestamptz,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT tasks_status_completion_check CHECK (
        (status = 'done' AND completed_at IS NOT NULL) OR
        (status <> 'done' AND completed_at IS NULL)
    )
);

CREATE INDEX idx_tasks_user_week ON public.tasks (user_id, week_start);
CREATE INDEX idx_tasks_user_planned ON public.tasks (user_id, planned_for, status);
CREATE INDEX idx_tasks_why_log ON public.tasks (why_log_id);

CREATE TRIGGER tasks_set_updated_at
    BEFORE UPDATE ON public.tasks
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Belt-and-suspenders: RLS with no INSERT/UPDATE/DELETE policy already
-- blocks those commands for `authenticated`, but we revoke every
-- table-level privilege and grant back only SELECT, so there's no implicit
-- INSERT/UPDATE/DELETE grant left over to rely on RLS alone against. `anon`
-- gets nothing at all, same as every other user table.
REVOKE ALL ON TABLE public.tasks FROM anon;
REVOKE ALL ON TABLE public.tasks FROM authenticated;
GRANT SELECT ON TABLE public.tasks TO authenticated;

CREATE POLICY tasks_select ON public.tasks
    FOR SELECT TO authenticated
    USING (user_id = (select auth.uid()));

-- 2. activity_log.task_id: links a completed session back to its task.
ALTER TABLE public.activity_log
    ADD COLUMN task_id uuid REFERENCES public.tasks(id) ON DELETE SET NULL;

-- A task can be completed at most once.
CREATE UNIQUE INDEX activity_log_task_id_unique
    ON public.activity_log (task_id)
    WHERE task_id IS NOT NULL;

-- Direct client inserts stay allowed for ad-hoc sessions (task_id IS NULL
-- only) -- a task-linked row can only come from complete_task, which runs
-- as SECURITY DEFINER and writes task_id itself.
DROP POLICY IF EXISTS activity_log_insert ON public.activity_log;

CREATE POLICY activity_log_insert ON public.activity_log
    FOR INSERT TO authenticated
    WITH CHECK (
        user_id = (select auth.uid())
        AND task_id IS NULL
    );

-- 3. complete_task RPC
CREATE OR REPLACE FUNCTION public.complete_task(
    p_task_id uuid,
    p_client_id uuid,
    p_duration_seconds integer,
    p_completed_on date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_user_id uuid;
    v_task_user_id uuid;
    v_status text;
    v_timer_seconds integer;
    v_existing_activity_id uuid;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '28000';
    END IF;

    -- Validate duration is in the same absolute range as activity_log's own
    -- CHECK (duration_seconds > 0 AND duration_seconds <= 86400); the insert
    -- below would fail on this anyway, but a dedicated error code here is
    -- more useful to the client than a generic constraint-violation message.
    IF p_duration_seconds <= 0 OR p_duration_seconds > 86400 THEN
        RAISE EXCEPTION 'Invalid duration: %', p_duration_seconds USING ERRCODE = '22003';
    END IF;

    -- p_completed_on is device-local and has no server-side default (unlike
    -- the old CURRENT_DATE behavior) - a null here would otherwise surface
    -- as a confusing NOT NULL constraint violation on the activity_log
    -- insert several steps down, instead of a clear error at the top.
    IF p_completed_on IS NULL THEN
        RAISE EXCEPTION 'p_completed_on is required' USING ERRCODE = '22004';
    END IF;

    -- 1. Idempotent retry: same client_id, same user, same task already
    -- recorded. Scoped to all three (not just id = p_client_id) so a
    -- client_id reused against a different task or user can't be
    -- mistaken for "already done" -- that path falls through to the
    -- ownership/status checks below instead.
    SELECT id INTO v_existing_activity_id
    FROM public.activity_log
    WHERE id = p_client_id
      AND user_id = v_user_id
      AND task_id = p_task_id;

    IF v_existing_activity_id IS NOT NULL THEN
        RETURN jsonb_build_object('success', true, 'status', 'already_completed');
    END IF;

    -- 2. Task existence and ownership. Locked FOR UPDATE: two concurrent
    -- complete_task calls for the same task must not both read status =
    -- 'pending' before either commits - the second call blocks here until
    -- the first's UPDATE (step 5) commits, then re-reads the now-'done'
    -- row and hits the TK001 check below instead of racing past it.
    SELECT user_id, status, timer_seconds
    INTO v_task_user_id, v_status, v_timer_seconds
    FROM public.tasks
    WHERE id = p_task_id
    FOR UPDATE;

    IF v_task_user_id IS NULL OR v_task_user_id <> v_user_id THEN
        RAISE EXCEPTION 'Task not found or unauthorized' USING ERRCODE = '42501';
    END IF;

    -- 3. Only a pending task can be completed. dropped/missed/done are
    -- rejected with distinct codes so the client can tell them apart
    -- (e.g. "this was dropped by Nova" vs "you already did this").
    IF v_status = 'done' THEN
        RAISE EXCEPTION 'Task % is already completed', p_task_id USING ERRCODE = 'TK001';
    ELSIF v_status = 'missed' THEN
        RAISE EXCEPTION 'Task % was missed and can no longer be completed directly', p_task_id USING ERRCODE = 'TK002';
    ELSIF v_status = 'dropped' THEN
        RAISE EXCEPTION 'Task % was dropped and can no longer be completed', p_task_id USING ERRCODE = 'TK003';
    END IF;

    -- 4. The logged focus time must cover the task's own timer. This is a
    -- bug guard, not a malicious-client defense -- a client that wants to
    -- lie about duration can already do so (it controls p_duration_seconds
    -- entirely), so this check cannot and does not try to stop cheating.
    -- Its job is to catch a client-side bug where a task's taskId and a
    -- stale/mismatched timer duration get wired together incorrectly,
    -- which would otherwise silently mark a long task done after a few
    -- seconds.
    IF p_duration_seconds < v_timer_seconds THEN
        RAISE EXCEPTION 'Duration % is shorter than task timer %', p_duration_seconds, v_timer_seconds USING ERRCODE = 'TK004';
    END IF;

    -- 5. Atomic insert + task update.
    INSERT INTO public.activity_log (
        id,
        user_id,
        completed_on,
        duration_seconds,
        task_id
    ) VALUES (
        p_client_id,
        v_user_id,
        p_completed_on,
        p_duration_seconds,
        p_task_id
    );

    UPDATE public.tasks
    SET status = 'done',
        completed_at = now()
    WHERE id = p_task_id;

    RETURN jsonb_build_object('success', true, 'status', 'done');
END;
$$;

REVOKE ALL ON FUNCTION public.complete_task(uuid, uuid, integer, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_task(uuid, uuid, integer, date) TO authenticated;
