-- 1. Enable UPDATE on custom_subjects for authenticated users (required for Supabase .upsert())
CREATE POLICY custom_subjects_update_auth 
ON public.custom_subjects 
FOR UPDATE 
TO authenticated 
USING (true) 
WITH CHECK (true);

-- 2. Update save_onboarding_seed_context function to resolve & persist campus_id and institution_id
CREATE OR REPLACE FUNCTION public.save_onboarding_seed_context(
  p_endgame text,
  p_derailer text,
  p_buffer_pref text,
  p_prep_style text,
  p_career_interests text[],
  p_daily_capacity jsonb,
  -- PROFILE / ACADEMIC FIELDS
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
  v_campus_id uuid;
  v_institution_id uuid;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Fetch user email from auth.users (requires SECURITY DEFINER)
  SELECT email INTO v_user_email FROM auth.users WHERE id = v_user_id;

  -- Resolve campus_id & institution_id from email domain or college name
  IF v_user_email LIKE '%@hyderabad.bits-pilani.ac.in' OR p_college ILIKE '%hyderabad%' THEN
    SELECT id, institution_id INTO v_campus_id, v_institution_id 
    FROM campuses 
    WHERE short_name ILIKE '%hyderabad%' OR name ILIKE '%hyderabad%' OR subdomain ILIKE '%hyderabad%'
    LIMIT 1;
  ELSIF v_user_email LIKE '%@goa.bits-pilani.ac.in' OR p_college ILIKE '%goa%' THEN
    SELECT id, institution_id INTO v_campus_id, v_institution_id 
    FROM campuses 
    WHERE short_name ILIKE '%goa%' OR name ILIKE '%goa%' OR subdomain ILIKE '%goa%'
    LIMIT 1;
  ELSIF v_user_email LIKE '%@pilani.bits-pilani.ac.in' OR p_college ILIKE '%pilani%' THEN
    SELECT id, institution_id INTO v_campus_id, v_institution_id 
    FROM campuses 
    WHERE short_name ILIKE '%pilani%' OR name ILIKE '%pilani%' OR subdomain ILIKE '%pilani%'
    LIMIT 1;
  END IF;

  -- Fallback to any campus/institution if still null
  IF v_campus_id IS NULL THEN
    SELECT id, institution_id INTO v_campus_id, v_institution_id 
    FROM campuses 
    LIMIT 1;
  END IF;

  IF v_institution_id IS NULL THEN
    SELECT id INTO v_institution_id 
    FROM institutions 
    LIMIT 1;
  END IF;

  -- Upsert users table with profile / academic details including campus_id & institution_id
  INSERT INTO public.users (
    id, email, avatar_data, full_name, roll_number, college, branch, dual_branch, 
    academic_year, current_semester, study_capacity, campus_id, institution_id
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
    p_study_capacity,
    v_campus_id,
    v_institution_id
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
    campus_id = COALESCE(v_campus_id, public.users.campus_id),
    institution_id = COALESCE(v_institution_id, public.users.institution_id),
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
