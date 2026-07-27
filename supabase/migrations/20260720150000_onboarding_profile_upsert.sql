CREATE OR REPLACE FUNCTION public.save_onboarding_seed_context(
  p_endgame text,
  p_derailer text,
  p_buffer_pref text,
  p_prep_style text,
  p_career_interests text[],
  p_daily_capacity jsonb,
  -- NEW FIELDS
  p_avatar_data text DEFAULT NULL,
  p_full_name text DEFAULT NULL,
  p_roll_number text DEFAULT NULL,
  p_college text DEFAULT NULL,
  p_branch text DEFAULT NULL,
  p_dual_branch text DEFAULT NULL,
  p_academic_year smallint DEFAULT NULL,
  p_current_semester smallint DEFAULT NULL,
  p_study_capacity text DEFAULT NULL
) RETURNS void
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_user_email text;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch user email from auth.users (requires SECURITY DEFINER)
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;

  -- Upsert users table with profile / academic details
  INSERT INTO public.users (
    id, email, avatar_data, full_name, roll_number, college, branch, dual_branch, academic_year, current_semester, study_capacity
  )
  VALUES (
    v_user_id,
    COALESCE(v_user_email, 'unknown@domain.com'),
    p_avatar_data,
    p_full_name,
    p_roll_number,
    p_college,
    p_branch,
    p_dual_branch,
    p_academic_year,
    p_current_semester,
    p_study_capacity
  )
  ON CONFLICT (id) DO UPDATE SET 
    avatar_data = COALESCE(EXCLUDED.avatar_data, public.users.avatar_data),
    full_name = COALESCE(EXCLUDED.full_name, public.users.full_name),
    roll_number = COALESCE(EXCLUDED.roll_number, public.users.roll_number),
    college = COALESCE(EXCLUDED.college, public.users.college),
    branch = COALESCE(EXCLUDED.branch, public.users.branch),
    dual_branch = COALESCE(EXCLUDED.dual_branch, public.users.dual_branch),
    academic_year = COALESCE(EXCLUDED.academic_year, public.users.academic_year),
    current_semester = COALESCE(EXCLUDED.current_semester, public.users.current_semester),
    study_capacity = COALESCE(EXCLUDED.study_capacity, public.users.study_capacity),
    updated_at = now();

  -- Existing logic for questionnaire fields
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
