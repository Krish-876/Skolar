-- Update foreign keys referencing public.users(id) to ON DELETE CASCADE

-- 1. career_units
ALTER TABLE public.career_units
  DROP CONSTRAINT IF EXISTS career_units_user_id_fkey,
  ADD CONSTRAINT career_units_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 2. nova_capacity_log
ALTER TABLE public.nova_capacity_log
  DROP CONSTRAINT IF EXISTS nova_capacity_log_user_id_fkey,
  ADD CONSTRAINT nova_capacity_log_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 3. nova_config (drops auto-generated constraint and re-creates with ON DELETE CASCADE)
ALTER TABLE public.nova_config
  DROP CONSTRAINT IF EXISTS nova_config_user_id_fkey,
  ADD CONSTRAINT nova_config_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 4. nova_history
ALTER TABLE public.nova_history
  DROP CONSTRAINT IF EXISTS nova_history_user_id_fkey,
  ADD CONSTRAINT nova_history_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 5. situation_flags
ALTER TABLE public.situation_flags
  DROP CONSTRAINT IF EXISTS situation_flags_user_id_fkey,
  ADD CONSTRAINT situation_flags_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 6. staleness_tracker
ALTER TABLE public.staleness_tracker
  DROP CONSTRAINT IF EXISTS staleness_tracker_user_id_fkey,
  ADD CONSTRAINT staleness_tracker_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 7. standing_flags
ALTER TABLE public.standing_flags
  DROP CONSTRAINT IF EXISTS standing_flags_user_id_fkey,
  ADD CONSTRAINT standing_flags_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- 8. published_tests (previously ON DELETE SET NULL)
ALTER TABLE public.published_tests
  DROP CONSTRAINT IF EXISTS published_tests_published_by_fkey,
  ADD CONSTRAINT published_tests_published_by_fkey
    FOREIGN KEY (published_by) REFERENCES public.users(id) ON DELETE CASCADE;

-- 9. questions (previously ON DELETE SET NULL)
ALTER TABLE public.questions
  DROP CONSTRAINT IF EXISTS questions_published_by_fkey,
  ADD CONSTRAINT questions_published_by_fkey
    FOREIGN KEY (published_by) REFERENCES public.users(id) ON DELETE CASCADE;

-- 10. uploaded_pdfs (previously ON DELETE SET NULL)
ALTER TABLE public.uploaded_pdfs
  DROP CONSTRAINT IF EXISTS uploaded_pdfs_uploaded_by_fkey,
  ADD CONSTRAINT uploaded_pdfs_uploaded_by_fkey
    FOREIGN KEY (uploaded_by) REFERENCES public.users(id) ON DELETE CASCADE;
