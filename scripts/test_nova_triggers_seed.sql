-- ============================================================
-- Nova trigger-layer seed/test script
-- Exercises all 9 trigger branches (8 distinct trigger_reason
-- values — situation_flags and standing_flags both map to
-- 'flag_confirmed').
--
-- HOW TO RUN:
--   psql "$env:SUPABASE_DB_URL" -v test_user='<real-user-uuid>' -f scripts/test_nova_triggers_seed.sql
--
-- test_user MUST be a real row from `SELECT id FROM users LIMIT 1;`
--
-- Runs inside a transaction and ROLLS BACK at the end — safe to
-- re-run repeatedly. Flip ROLLBACK to COMMIT to keep the data.
--
-- EXPECTED OUTPUT — 8 distinct trigger_reason values, 10 rows total:
--   new_test_score               x2  (one per test_attempts row)
--   time_left_threshold          x1  (bucket=3, exam 2 days out)
--   error_type_shift             x1  (careless as of baseline reasoning
--                                      pass -> concept_gap most recent;
--                                      requires the seeded nova_why_log
--                                      baseline row below)
--   staleness_academic           x1  (topic untouched 20d > 14d threshold)
--   staleness_career             x1  (career unit untouched 25d > 21d threshold)
--   flag_confirmed                x2  (situation_flags + standing_flags)
--   industry_relevance_refreshed x1
--   capacity_changed             x1
-- ============================================================

\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
  v_user   uuid := :'test_user';
  v_inst   uuid;
  v_subj   uuid;
  v_us     uuid;
  v_topic  uuid;
  v_exam   uuid;
  v_ta     uuid;
  v_q1     uuid;
  v_q2     uuid;
  v_career uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = v_user) THEN
    RAISE EXCEPTION 'test_user % does not exist in public.users — pick a real id via SELECT id FROM users LIMIT 1;', v_user;
  END IF;

  SELECT id INTO v_inst FROM institutions LIMIT 1;
  IF v_inst IS NULL THEN
    INSERT INTO institutions (id, name, short_name)
      VALUES (gen_random_uuid(), 'Test Institution', 'TEST') RETURNING id INTO v_inst;
  END IF;

  INSERT INTO subjects (id, institution_id, name, academic_year)
    VALUES (gen_random_uuid(), v_inst, 'Test Subject', 2) RETURNING id INTO v_subj;
  INSERT INTO user_subjects (id, user_id, subject_id, semester)
    VALUES (gen_random_uuid(), v_user, v_subj, 'Sem1') RETURNING id INTO v_us;
  INSERT INTO topics (id, subject_id, name)
    VALUES (gen_random_uuid(), v_subj, 'Test Topic') RETURNING id INTO v_topic;

  -- Branch 2
  INSERT INTO user_subject_exams (id, user_subject_id, exam_type, exam_date)
    VALUES (gen_random_uuid(), v_us, 'quiz1', CURRENT_DATE + 2);

  INSERT INTO published_tests (id, college, subject, exam_type, question_ids)
    VALUES (gen_random_uuid(), 'Test', 'Test Subject', 'quiz1', '{}') RETURNING id INTO v_exam;

  INSERT INTO questions (id, question_text, marks, question_type, subject, college, subject_id, topic_id)
    VALUES (gen_random_uuid(), 'Q1', 5, 'short_answer', 'Test Subject', 'Test', v_subj, v_topic) RETURNING id INTO v_q1;
  INSERT INTO questions (id, question_text, marks, question_type, subject, college, subject_id, topic_id)
    VALUES (gen_random_uuid(), 'Q2', 5, 'short_answer', 'Test Subject', 'Test', v_subj, v_topic) RETURNING id INTO v_q2;

  -- Branch 1: first attempt, category 'careless'
  INSERT INTO test_attempts (id, test_id, user_id, subject_id, completed_at)
    VALUES (gen_random_uuid(), v_exam, v_user, v_subj, now() - interval '2 days') RETURNING id INTO v_ta;
  INSERT INTO question_results (attempt_id, question_id, topic_id, error_category, created_at)
    VALUES (v_ta, v_q1, v_topic, 'careless', now() - interval '2 days');

  -- Baseline reasoning pass — the state branch 3 compares against.
  -- Dated after attempt 1, before attempt 2.
  INSERT INTO nova_why_log (user_id, entry_type, topic_id, reasoning_summary, created_at)
    VALUES (v_user, 'minor_trigger', v_topic, 'seed baseline for error_type_shift test', now() - interval '1 day');

  -- Branch 1 + 3: second attempt, category shifts to 'concept_gap'
  INSERT INTO test_attempts (id, test_id, user_id, subject_id, completed_at)
    VALUES (gen_random_uuid(), v_exam, v_user, v_subj, now()) RETURNING id INTO v_ta;
  INSERT INTO question_results (attempt_id, question_id, topic_id, error_category, created_at)
    VALUES (v_ta, v_q2, v_topic, 'concept_gap', now());

  -- Branch 4
  INSERT INTO staleness_tracker (user_id, topic_id, last_meaningfully_touched)
    VALUES (v_user, v_topic, now() - interval '20 days');

  -- Branch 5
  INSERT INTO career_units (id, user_id, name, confirmed_at)
    VALUES (gen_random_uuid(), v_user, 'Test Skill', now() - interval '30 days') RETURNING id INTO v_career;
  INSERT INTO staleness_tracker (user_id, career_unit_id, last_meaningfully_touched)
    VALUES (v_user, v_career, now() - interval '25 days');

  -- Branch 6
  INSERT INTO situation_flags (user_id, user_subject_id, flag_text, confirmed_at)
    VALUES (v_user, v_us, 'Falling behind in this subject', now());

  -- Branch 7
  INSERT INTO standing_flags (user_id, user_subject_id, instruction_text, confirmed_at)
    VALUES (v_user, v_us, 'Always buffer practicals', now());

  -- Branch 8
  UPDATE career_units
    SET industry_relevance_score = 0.8, industry_relevance_updated_at = now()
    WHERE id = v_career;

  -- Branch 9
  INSERT INTO nova_capacity_log (user_id, capacity, logged_for_date)
    VALUES (v_user, 'packed', CURRENT_DATE);

  RAISE NOTICE 'Seed complete for user %', v_user;
END $$;

SELECT * FROM get_nova_triggers(:'test_user') ORDER BY trigger_reason;

ROLLBACK;