-- Migration: Secure RPC auth verification
-- Closes Issue #57: Fix RPC/service functions trusting client-supplied user_id

-- 1. Hardened handle_vote: Enforce session auth verification (auth.uid())
CREATE OR REPLACE FUNCTION public.handle_vote(
  p_post_id uuid,
  p_user_id uuid DEFAULT auth.uid(),
  p_vote smallint DEFAULT 1
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_auth_user uuid := auth.uid();
  v_acting_user uuid := COALESCE(p_user_id, v_auth_user);
  existing_vote smallint;
BEGIN
  IF v_auth_user IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  IF p_user_id IS NOT NULL AND p_user_id <> v_auth_user THEN
    RAISE EXCEPTION 'Unauthorized: Cannot vote on behalf of another user';
  END IF;

  -- Check if user already voted on this post
  SELECT vote INTO existing_vote
  FROM post_votes
  WHERE user_id = v_acting_user AND post_id = p_post_id;

  IF NOT FOUND THEN
    -- No existing vote – insert and increment the right counter
    INSERT INTO post_votes (user_id, post_id, vote)
    VALUES (v_acting_user, p_post_id, p_vote);

    IF p_vote = 1 THEN
      UPDATE published_tests SET upvotes = upvotes + 1 WHERE id = p_post_id;
    ELSE
      UPDATE published_tests SET downvotes = downvotes + 1 WHERE id = p_post_id;
    END IF;

  ELSIF existing_vote = p_vote THEN
    -- Same vote again – toggle off (delete and decrement)
    DELETE FROM post_votes
    WHERE user_id = v_acting_user AND post_id = p_post_id;

    IF p_vote = 1 THEN
      UPDATE published_tests SET upvotes = GREATEST(upvotes - 1, 0) WHERE id = p_post_id;
    ELSE
      UPDATE published_tests SET downvotes = GREATEST(downvotes - 1, 0) WHERE id = p_post_id;
    END IF;

  ELSE
    -- Opposite vote – switch and update both counters
    UPDATE post_votes SET vote = p_vote
    WHERE user_id = v_acting_user AND post_id = p_post_id;

    IF p_vote = 1 THEN
      UPDATE published_tests
      SET upvotes   = upvotes + 1,
          downvotes = GREATEST(downvotes - 1, 0)
      WHERE id = p_post_id;
    ELSE
      UPDATE published_tests
      SET downvotes = downvotes + 1,
          upvotes   = GREATEST(upvotes - 1, 0)
      WHERE id = p_post_id;
    END IF;
  END IF;
END;
$$;

-- 2. Hardened get_nova_triggers: Prevent unauthorized cross-user inspection
CREATE OR REPLACE FUNCTION public.get_nova_triggers(p_user_id uuid DEFAULT auth.uid())
RETURNS TABLE (
  unit_type text,
  unit_id uuid,
  trigger_reason text,
  detail jsonb
) AS $$
DECLARE
  v_caller_id uuid := auth.uid();
  v_target_user_id uuid := COALESCE(p_user_id, v_caller_id);
  v_staleness_academic int := (SELECT (value#>>'{}')::int FROM nova_config WHERE key='staleness_days_academic' AND user_id IS NULL);
  v_staleness_career   int := (SELECT (value#>>'{}')::int FROM nova_config WHERE key='staleness_days_career' AND user_id IS NULL);
BEGIN
  IF v_target_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated: user_id is required';
  END IF;

  -- If called with an active auth session, enforce caller can only access own triggers
  IF v_caller_id IS NOT NULL AND v_caller_id <> v_target_user_id THEN
    RAISE EXCEPTION 'Unauthorized: Cannot access triggers for another user';
  END IF;

  RETURN QUERY

  WITH
  last_reasoned_subject AS (
    SELECT user_subject_id, MAX(created_at) AS last_at
    FROM nova_why_log
    WHERE user_id = v_target_user_id AND user_subject_id IS NOT NULL
    GROUP BY user_subject_id
  ),
  last_reasoned_topic AS (
    SELECT topic_id, MAX(created_at) AS last_at
    FROM nova_why_log
    WHERE user_id = v_target_user_id AND topic_id IS NOT NULL
    GROUP BY topic_id
  ),
  time_left_buckets AS (
    SELECT jsonb_array_elements_text(value)::int AS bucket
    FROM nova_config WHERE key = 'time_left_buckets' AND user_id IS NULL
  )

  SELECT 'subject', us.id, 'new_test_score',
         jsonb_build_object('attempt_id', ta.id, 'completed_at', ta.completed_at)
  FROM test_attempts ta
  JOIN user_subjects us ON us.user_id = v_target_user_id AND us.subject_id = ta.subject_id
  LEFT JOIN last_reasoned_subject lr ON lr.user_subject_id = us.id
  WHERE ta.user_id = v_target_user_id
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
      WHERE us.user_id = v_target_user_id AND use.exam_date >= CURRENT_DATE
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
    WHERE ta.user_id = v_target_user_id AND qr.topic_id IS NOT NULL
    ORDER BY qr.topic_id, qr.created_at DESC, qr.id DESC
  ) tc
  JOIN (
    SELECT DISTINCT ON (qr.topic_id) qr.topic_id, qr.error_category AS prev_category
    FROM question_results qr
    JOIN test_attempts ta ON ta.id = qr.attempt_id
    JOIN last_reasoned_topic lrt ON lrt.topic_id = qr.topic_id
    WHERE ta.user_id = v_target_user_id AND qr.created_at <= lrt.last_at
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
  WHERE st.user_id = v_target_user_id
    AND st.career_unit_id IS NULL
    AND (now() - st.last_meaningfully_touched) > (v_staleness_academic || ' days')::interval
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = v_target_user_id
        AND (wl.user_subject_id = st.user_subject_id OR wl.topic_id = st.topic_id)
        AND wl.created_at::date = CURRENT_DATE
    )

  UNION ALL

  SELECT 'career_unit', st.career_unit_id, 'staleness_career',
         jsonb_build_object('last_touched', st.last_meaningfully_touched,
                            'days_stale', EXTRACT(DAY FROM now() - st.last_meaningfully_touched))
  FROM staleness_tracker st
  WHERE st.user_id = v_target_user_id
    AND st.career_unit_id IS NOT NULL
    AND (now() - st.last_meaningfully_touched) > (v_staleness_career || ' days')::interval
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = v_target_user_id AND wl.career_unit_id = st.career_unit_id
        AND wl.created_at::date = CURRENT_DATE
    )

  UNION ALL

  SELECT
    CASE WHEN sf.career_unit_id IS NOT NULL THEN 'career_unit'
         WHEN sf.user_subject_id IS NOT NULL THEN 'subject'
         ELSE 'user_level' END,
    COALESCE(sf.career_unit_id, sf.user_subject_id, v_target_user_id),
    'flag_confirmed',
    jsonb_build_object('flag_id', sf.id, 'text', sf.flag_text, 'confirmed_at', sf.confirmed_at)
  FROM situation_flags sf
  WHERE sf.user_id = v_target_user_id
    AND sf.confirmed_at IS NOT NULL
    AND sf.superseded_at IS NULL
    AND sf.confirmed_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log wl WHERE wl.user_id = v_target_user_id
             AND wl.user_subject_id IS NOT DISTINCT FROM sf.user_subject_id
             AND wl.career_unit_id IS NOT DISTINCT FROM sf.career_unit_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT
    CASE WHEN stf.career_unit_id IS NOT NULL THEN 'career_unit'
         WHEN stf.user_subject_id IS NOT NULL THEN 'subject'
         ELSE 'user_level' END,
    COALESCE(stf.career_unit_id, stf.user_subject_id, v_target_user_id),
    'flag_confirmed',
    jsonb_build_object('flag_id', stf.id, 'text', stf.instruction_text, 'confirmed_at', stf.confirmed_at)
  FROM standing_flags stf
  WHERE stf.user_id = v_target_user_id
    AND stf.confirmed_at IS NOT NULL
    AND stf.superseded_at IS NULL
    AND stf.confirmed_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log wl WHERE wl.user_id = v_target_user_id
             AND wl.user_subject_id IS NOT DISTINCT FROM stf.user_subject_id
             AND wl.career_unit_id IS NOT DISTINCT FROM stf.career_unit_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'career_unit', cu.id, 'industry_relevance_refreshed',
         jsonb_build_object('score', cu.industry_relevance_score,
                            'refreshed_at', cu.industry_relevance_updated_at)
  FROM career_units cu
  WHERE cu.user_id = v_target_user_id
    AND cu.confirmed_at IS NOT NULL
    AND cu.paused_at IS NULL
    AND cu.industry_relevance_updated_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log WHERE career_unit_id = cu.id AND user_id = v_target_user_id),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'user_level', v_target_user_id, 'capacity_changed',
         jsonb_build_object('capacity', ncl.capacity, 'for_date', ncl.logged_for_date)
  FROM nova_capacity_log ncl
  WHERE ncl.user_id = v_target_user_id
    AND ncl.logged_for_date = CURRENT_DATE
    AND ncl.updated_at > COALESCE(
          (SELECT MAX(created_at) FROM nova_why_log
           WHERE user_id = v_target_user_id AND entry_type = 'full_pass'
             AND user_subject_id IS NULL AND topic_id IS NULL AND career_unit_id IS NULL),
          '-infinity'::timestamptz)

  UNION ALL

  SELECT 'career_unit', cu.id, 'career_unit_new',
         jsonb_build_object('name', cu.name, 'confirmed_at', cu.confirmed_at, 'source', cu.source)
  FROM career_units cu
  WHERE cu.user_id = v_target_user_id
    AND cu.confirmed_at IS NOT NULL
    AND cu.paused_at IS NULL
    AND NOT EXISTS (
      SELECT 1 FROM nova_why_log wl
      WHERE wl.user_id = v_target_user_id AND wl.career_unit_id = cu.id
    );

END;
$$ LANGUAGE plpgsql STABLE;