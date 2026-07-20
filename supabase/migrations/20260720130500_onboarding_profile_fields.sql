-- Add onboarding fields to users table

-- 1. Relax academic_year check to allow up to 5 for dual degree students
ALTER TABLE public.users DROP CONSTRAINT IF EXISTS users_academic_year_check;
ALTER TABLE public.users ADD CONSTRAINT users_academic_year_check CHECK (((academic_year >= 1) AND (academic_year <= 5)));

-- 2. Add new columns
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_data text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS dual_branch text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS current_semester smallint;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS study_capacity text;

-- 3. Update the RPC to accept all fields and update the user record
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
SECURITY INVOKER
AS $$
DECLARE
  v_user_id uuid := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Update users table with profile / academic details
  UPDATE public.users 
  SET 
    avatar_data = COALESCE(p_avatar_data, avatar_data),
    full_name = COALESCE(p_full_name, full_name),
    roll_number = COALESCE(p_roll_number, roll_number),
    college = COALESCE(p_college, college),
    branch = COALESCE(p_branch, branch),
    dual_branch = COALESCE(p_dual_branch, dual_branch),
    academic_year = COALESCE(p_academic_year, academic_year),
    current_semester = COALESCE(p_current_semester, current_semester),
    study_capacity = COALESCE(p_study_capacity, study_capacity),
    updated_at = now()
  WHERE id = v_user_id;

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
