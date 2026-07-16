-- ============================================================
-- Onboarding seed-context layer: source tracking, career_unit
-- cold-start trigger, auth-scoped RPC, and nova_config RLS fix.
-- ============================================================

-- 1. Source columns
ALTER TABLE public.nova_history
  ADD COLUMN source text NOT NULL DEFAULT 'conversation';

ALTER TABLE public.standing_flags
  ADD COLUMN source text NOT NULL DEFAULT 'conversation';

ALTER TABLE public.career_units
  ADD COLUMN source text NOT NULL DEFAULT 'conversation';

-- 2. Guarded nova_config unique constraint
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'nova_config_user_key_unique'
  ) THEN
    ALTER TABLE public.nova_config
      ADD CONSTRAINT nova_config_user_key_unique UNIQUE (user_id, key);
  END IF;
END $$;

-- 3. nova_config RLS fix (was rowsecurity = false, confirmed via query)
ALTER TABLE public.nova_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY nova_config_select ON public.nova_config
  FOR SELECT
  USING (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY nova_config_insert ON public.nova_config
  FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY nova_config_update ON public.nova_config
  FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- 4. Partial unique index for career_units dedup
CREATE UNIQUE INDEX career_units_user_active_name_uidx
  ON public.career_units (user_id, name)
  WHERE paused_at IS NULL;

-- 5. get_nova_triggers — branches 1–9 unchanged, branch 10 appended
CREATE OR REPLACE FUNCTION public.get_nova_triggers(p_user_id uuid)
RETURNS TABLE (
  unit_type text,
  unit_id uuid,
  trigger_reason text,
  detail jsonb
) AS $$
DECLARE
  v_staleness_academic int := (SELECT (value#>>'{}')::int FROM nova_config WHERE key='staleness_days_academic' AND user_id IS NULL);
  v_staleness_career   int := (SELECT (value#>>'{}')::int FROM nova_config WHERE key='staleness_days_career' AND user_id IS NULL);
BEGIN
  RETURN QUERY

  WITH
  last_reasoned_subject AS (
    SELECT user_subject_id, MAX(created_at) AS last_at
    FROM nova_why_log
    WHERE user_id = p_user_id AND user_subject_id IS NOT NULL
    GROUP BY user_subject_id
  ),
  last_reasoned_topic AS (
    SELECT topic_id, MAX(created_at) AS last_at
    FROM nova_why_log
    WHERE user_id = p_user_id AND topic_id IS NOT NULL
    GROUP BY topic_id
  ),
  time_left_buckets AS (
    SELECT jsonb_array_elements_text(value)::int AS bucket
    FROM nova_config WHERE key = 'time_left_buckets' AND user_id IS NULL
  )

  SELECT 'subject', us.id, 'new_test_score',
         jsonb_build_object('attempt_id', ta.id, 'completed_at', ta.completed_at)
  FROM test_attempts ta
  JOIN user_subjects us ON us.user_id = p_user_id AND us.subject_id = ta.subject_id
  LEFT JOIN last_reasoned_subject lr ON lr.user_subject_id = us.id
  WHERE ta.user_id = p_user_id
    AND ta.completed_at > COALESCE(lr.last_at, '-infinity'::timestamptz)

  UNION ALL

  SELECT 'subject', eb.user_subject_id, 'time_left_threshold',
         jsonb_build_object('exam_type', eb.exam_type, 'exam_date', eb.exam_date,
                             'days_left', eb.days_left, 'bucket', eb.crossed_bucket)
  FROM (
    SELECT ec.user_subject_id, ec.exam_type, ec.exam_date, ec.days_left,
           MIN(b.bucket) AS crossed_bucket
    FROM (
      SELECT us.id AS user_subject_id, use.exam_type, use.exam_date,
             (use.exam_date - CURRENT_DATE) AS days_left
      FROM user_subject_exams use
      JOIN user_subjects us ON us.id = use.user_subject_id
      WHERE us.user_id = p_user_id AND use.exam_date >= CURRENT_DATE
    ) ec
    JOIN time_left_buckets b ON ec.days_left <= b.bucket
    GROUP BY ec.user_subject_id, ec.exam_type, ec.exam_date, ec.days_left
  ) eb
  LEFT JOIN last_reasoned_subject lr ON lr.user_subject_id = eb.user_subject_id
  WHERE COALESCE(lr.last_at, '-infinity'::timestamptz) < (eb.exam_date - eb.crossed_bucket)::timestamptz

  UNION ALL

  SELECT 'topic', tc.topic_id, 'error_type_shift',
         jsonb_build_object('from', tp.prev_category, 'to', tc.current_category, 'at', tc.created_at)
  FROM (
    SELECT DISTINCT ON (qr.topic_id) qr.topic_id, qr.error_category AS current_category, qr.created_at
    FROM question_results qr
    JOIN test_attempts ta ON ta.id = qr.attempt_id
    WHERE ta.user_id = p_user_id AND qr.topic_id IS NOT NULL
    ORDER BY qr.topic_id, qr.created_at DESC, qr.id DESC
  ) tc
  JOIN (
    SELECT DISTINCT ON (qr.topic_id) qr.topic_id, qr.error_category AS prev_category
    FROM question_results qr
    JOIN test_attempts ta ON ta.id = qr.attempt_id
    JOIN last_reasoned_topic lrt ON lrt.topic_id = qr.topic_id
    WHERE ta.user_id = p_user_id AND qr.created_at <= lrt.last_at
    ORDER BY qr.topic_id, qr.created_at DESC, qr.id DESC
  ) tp ON tp.topic_id = tc.topic_id
  WHERE tp.prev_category IS DISTINCT FROM tc.current_category

  UNION ALL

  SELECT
    CASE WHEN st.user_subject_id IS NOT NULL THEN 'subject' ELSE 'topic' END,
    COALESCE(st.user_subject_id, st.topic_id),
    'staleness_academic',
    jsonb_build_object('last_touched', st.last_meaningfully_touched,
                        'days_stale', EXTRACT(DAY FROM now() - st.last_meaningfully_touched))
  FROM staleness_tracker st
  WHERE st.user_id = p_user_id
    AND st.career_unit_id IS NULL
    AND (now() - st.last_meaningfully_touched) > (v_staleness_academic || ' days')::interval
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = p_user_id
        AND (wl.user_subject_id = st.user_subject_id OR wl.topic_id = st.topic_id)
        AND wl.created_at::date = CURRENT_DATE
    )

  UNION ALL

  SELECT 'career_unit', st.career_unit_id, 'staleness_career',
         jsonb_build_object('last_touched', st.last_meaningfully_touched,
                             'days_stale', EXTRACT(DAY FROM now() - st.last_meaningfully_touched))
  FROM staleness_tracker st
  WHERE st.user_id = p_user_id
    AND st.career_unit_id IS NOT NULL
    AND (now() - st.last_meaningfully_touched) > (v_staleness_career || ' days')::interval
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = p_user_id AND wl.career_unit_id = st.career_unit_id
        AND wl.created_at::date = CURRENT_DATE
    )

  UNION ALL

  SELECT
    CASE WHEN sf.career_unit_id IS NOT NULL THEN 'career_unit'
         WHEN sf.user_subject_id IS NOT NULL THEN 'subject'
         ELSE 'user_level' END,
    COALESCE(sf.career_unit_id, sf.user_subject_id, p_user_id),
    'flag_confirmed',
    jsonb_build_object('flag_id', sf.id, 'text', sf.flag_text, 'confirmed_at', sf.confirmed_at)
  FROM situation_flags sf
  WHERE sf.user_id = p_user_id
    AND sf.confirmed_at IS NOT NULL
    AND sf.superseded_at IS NULL
    AND sf.confirmed_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log wl WHERE wl.user_id = p_user_id
             AND wl.user_subject_id IS NOT DISTINCT FROM sf.user_subject_id
             AND wl.career_unit_id IS NOT DISTINCT FROM sf.career_unit_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT
    CASE WHEN stf.career_unit_id IS NOT NULL THEN 'career_unit'
         WHEN stf.user_subject_id IS NOT NULL THEN 'subject'
         ELSE 'user_level' END,
    COALESCE(stf.career_unit_id, stf.user_subject_id, p_user_id),
    'flag_confirmed',
    jsonb_build_object('flag_id', stf.id, 'text', stf.instruction_text, 'confirmed_at', stf.confirmed_at)
  FROM standing_flags stf
  WHERE stf.user_id = p_user_id
    AND stf.confirmed_at IS NOT NULL
    AND stf.superseded_at IS NULL
    AND stf.confirmed_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log wl WHERE wl.user_id = p_user_id
             AND wl.user_subject_id IS NOT DISTINCT FROM stf.user_subject_id
             AND wl.career_unit_id IS NOT DISTINCT FROM stf.career_unit_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'career_unit', cu.id, 'industry_relevance_refreshed',
         jsonb_build_object('score', cu.industry_relevance_score,
                             'refreshed_at', cu.industry_relevance_updated_at)
  FROM career_units cu
  WHERE cu.user_id = p_user_id
    AND cu.confirmed_at IS NOT NULL
    AND cu.paused_at IS NULL
    AND cu.industry_relevance_updated_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log WHERE career_unit_id = cu.id AND user_id = p_user_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'user_level', p_user_id, 'capacity_changed',
         jsonb_build_object('capacity', ncl.capacity, 'for_date', ncl.logged_for_date)
  FROM nova_capacity_log ncl
  WHERE ncl.user_id = p_user_id
    AND ncl.logged_for_date = CURRENT_DATE
    AND ncl.updated_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log
           WHERE user_id = p_user_id AND entry_type = 'full_pass'
             AND user_subject_id IS NULL AND topic_id IS NULL AND career_unit_id IS NULL),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'career_unit', cu.id, 'career_unit_new',
         jsonb_build_object('name', cu.name, 'confirmed_at', cu.confirmed_at, 'source', cu.source)
  FROM career_units cu
  WHERE cu.user_id = p_user_id
    AND cu.confirmed_at IS NOT NULL
    AND cu.paused_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = p_user_id AND wl.career_unit_id = cu.id
    );

END;
$$ LANGUAGE plpgsql STABLE;

-- 6. Onboarding RPC — auth-derived user_id, per-field NULL guards,
--    ON CONFLICT dedup on career_units
CREATE OR REPLACE FUNCTION public.save_onboarding_seed_context(
  p_endgame text,
  p_derailer text,
  p_buffer_pref text,
  p_prep_style text,
  p_career_interests text[],
  p_daily_capacity jsonb
) RETURNS void
SECURITY INVOKER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_endgame IS NOT NULL THEN
    INSERT INTO standing_flags (user_id, instruction_text, confirmed_at, source)
    VALUES (v_user_id, p_endgame, now(), 'onboarding');
  END IF;

  IF p_derailer IS NOT NULL THEN
    INSERT INTO standing_flags (user_id, instruction_text, confirmed_at, source)
    VALUES (v_user_id, p_derailer, now(), 'onboarding');
  END IF;

  IF p_buffer_pref IS NOT NULL THEN
    INSERT INTO standing_flags (user_id, instruction_text, confirmed_at, source)
    VALUES (v_user_id, p_buffer_pref, now(), 'onboarding');
  END IF;

  IF p_prep_style IS NOT NULL THEN
    INSERT INTO nova_history (user_id, content, confirmed_at, source)
    VALUES (v_user_id, p_prep_style, now(), 'onboarding');
  END IF;

  IF p_career_interests IS NOT NULL AND array_length(p_career_interests, 1) > 0 THEN
    INSERT INTO career_units (user_id, name, confirmed_at, source)
    SELECT v_user_id, interest, now(), 'onboarding'
    FROM unnest(p_career_interests) AS interest
    ON CONFLICT (user_id, name) WHERE paused_at IS NULL DO NOTHING;
  END IF;

  IF p_daily_capacity IS NOT NULL THEN
    INSERT INTO nova_config (user_id, key, value)
    VALUES (v_user_id, 'capacity_hour_mapping', p_daily_capacity)
    ON CONFLICT (user_id, key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
  END IF;
END;
$$ LANGUAGE plpgsql;