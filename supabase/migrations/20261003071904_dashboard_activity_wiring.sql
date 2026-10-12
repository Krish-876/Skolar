-- Dashboard activity log + daily aggregation RPC

-- 1. activity_log
CREATE TABLE IF NOT EXISTS public.activity_log (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    completed_on date NOT NULL,
    duration_seconds integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activity_log_pkey PRIMARY KEY (id),
    -- upper bound: a single session cannot exceed 24h
    CONSTRAINT activity_log_duration_check
        CHECK (duration_seconds > 0 AND duration_seconds <= 86400),
    CONSTRAINT activity_log_user_id_fkey FOREIGN KEY (user_id)
        REFERENCES public.users(id) ON DELETE CASCADE
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'activity_log_completed_on_sane'
          AND conrelid = 'public.activity_log'::regclass
    ) THEN
        -- device-local date may be up to 1 day ahead of the server date (UTC+14)
        ALTER TABLE public.activity_log
            ADD CONSTRAINT activity_log_completed_on_sane
            CHECK (completed_on <= CURRENT_DATE + 1);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS activity_log_user_date_idx
    ON public.activity_log USING btree (user_id, completed_on)
    INCLUDE (duration_seconds);

ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.activity_log FROM anon;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'activity_log'
          AND policyname = 'activity_log_select'
    ) THEN
        CREATE POLICY activity_log_select ON public.activity_log
            FOR SELECT TO authenticated
            USING (user_id = (select auth.uid()));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'activity_log'
          AND policyname = 'activity_log_insert'
    ) THEN
        CREATE POLICY activity_log_insert ON public.activity_log
            FOR INSERT TO authenticated
            WITH CHECK (user_id = (select auth.uid()));
    END IF;
END $$;

-- 2. nova_config: global defaults (RLS + select policy already exist)
CREATE UNIQUE INDEX IF NOT EXISTS nova_config_global_key_uidx
    ON public.nova_config (key) WHERE user_id IS NULL;

INSERT INTO public.nova_config (user_id, key, value)
VALUES (NULL, 'week_start_day', '7'::jsonb)
ON CONFLICT (key) WHERE user_id IS NULL DO NOTHING;

INSERT INTO public.nova_config (user_id, key, value)
VALUES (NULL, 'focus_min_duration_seconds', '60'::jsonb)
ON CONFLICT (key) WHERE user_id IS NULL DO NOTHING;

-- May and August belong to their semesters; the holiday gap is derived in code
INSERT INTO public.nova_config (user_id, key, value)
VALUES (NULL, 'academic_terms',
        '{"even": {"start": 1, "end": 5}, "odd": {"start": 8, "end": 12}}'::jsonb)
ON CONFLICT (key) WHERE user_id IS NULL DO NOTHING;

-- 3. Daily aggregation RPC
CREATE OR REPLACE FUNCTION public.get_activity_daily(p_from date, p_to date)
RETURNS TABLE (day date, sessions bigint, counted_focus_seconds bigint)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_min_seconds integer;
BEGIN
    SELECT CASE WHEN (value #>> '{}') ~ '^[0-9]{1,9}$'
                THEN (value #>> '{}')::integer END
    INTO v_min_seconds
    FROM public.nova_config
    WHERE key = 'focus_min_duration_seconds'
      AND (user_id = (select auth.uid()) OR user_id IS NULL)
    ORDER BY user_id DESC NULLS LAST   -- per-user override beats global
    LIMIT 1;

    v_min_seconds := COALESCE(v_min_seconds, 0);

    RETURN QUERY
    SELECT al.completed_on,
           COUNT(*)::bigint,
           COALESCE(SUM(al.duration_seconds), 0)::bigint
    FROM public.activity_log al
    WHERE al.user_id = (select auth.uid())
      AND al.completed_on >= p_from
      AND al.completed_on <= p_to
      AND al.duration_seconds >= v_min_seconds
    GROUP BY al.completed_on
    ORDER BY al.completed_on;
END;
$$;

REVOKE ALL ON FUNCTION public.get_activity_daily(date, date) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_activity_daily(date, date) TO authenticated;