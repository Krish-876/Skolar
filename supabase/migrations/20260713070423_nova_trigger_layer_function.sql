-- ============================================================
-- Nova trigger layer function — §3 of the Nova spec.
-- Pure arithmetic, no AI calls. Returns every unit that needs
-- a reasoning pass for this student, since their last pass.
-- ============================================================

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

  -- 1. NEW TEST SCORE — one row per attempt, keyed on user_subjects.id
  SELECT 'subject', us.id, 'new_test_score',
         jsonb_build_object('attempt_id', ta.id, 'completed_at', ta.completed_at)
  FROM test_attempts ta
  JOIN user_subjects us ON us.user_id = p_user_id AND us.subject_id = ta.subject_id
  LEFT JOIN last_reasoned_subject lr ON lr.user_subject_id = us.id
  WHERE ta.user_id = p_user_id
    AND ta.completed_at > COALESCE(lr.last_at, '-infinity'::timestamptz)

  UNION ALL

  -- 2. TIME_LEFT crossed a bucket — single row per exam (most urgent bucket only)
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

  -- 3. ERROR_TYPE shift — current category vs. category as of the last
  --    reasoning pass for this topic. Requires a prior nova_why_log row
  --    (INNER JOIN, deliberate) — a topic with no reasoning history has
  --    nothing to have "shifted" from; its initial error_type is picked
  --    up by whatever full pass first reasons over its parent subject.
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

  -- 4. STALENESS — academic
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

  -- 5. STALENESS — career/industry
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

  -- 6. Confirmed situation_flag
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

  -- 7. Confirmed standing_flag
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

  -- 8. industry_relevance refreshed
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

  -- 9. CAPACITY_TODAY changed
  SELECT 'user_level', p_user_id, 'capacity_changed',
         jsonb_build_object('capacity', ncl.capacity, 'for_date', ncl.logged_for_date)
  FROM nova_capacity_log ncl
  WHERE ncl.user_id = p_user_id
    AND ncl.logged_for_date = CURRENT_DATE
    AND ncl.updated_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log
           WHERE user_id = p_user_id AND entry_type = 'full_pass'
             AND user_subject_id IS NULL AND topic_id IS NULL AND career_unit_id IS NULL),
          '-infinity'::timestamptz);

END;
$$ LANGUAGE plpgsql STABLE;