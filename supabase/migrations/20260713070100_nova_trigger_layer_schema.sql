-- ============================================================
-- Nova trigger layer — schema patches
-- ============================================================

-- career_unit_id was missing from these three conversation-fed tables.
ALTER TABLE public.standing_flags
  ADD COLUMN career_unit_id uuid REFERENCES public.career_units(id);

ALTER TABLE public.situation_flags
  ADD COLUMN career_unit_id uuid REFERENCES public.career_units(id);

ALTER TABLE public.nova_history
  ADD COLUMN career_unit_id uuid REFERENCES public.career_units(id);

-- Config table: thresholds live here, not hardcoded in application/query code.
CREATE TABLE public.nova_config (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.users(id),  -- NULL = global default
  key text NOT NULL,
  value jsonb NOT NULL,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT nova_config_pkey PRIMARY KEY (id),
  CONSTRAINT nova_config_user_key_unique UNIQUE (user_id, key)
);

INSERT INTO public.nova_config (user_id, key, value) VALUES
  (NULL, 'staleness_days_academic', '14'),
  (NULL, 'staleness_days_career', '21'),
  (NULL, 'time_left_buckets', '[7,3,1]'),
  (NULL, 'academic_pressure_buckets', '[10,3]');

-- Exclusivity guard on staleness_tracker.
-- If this table already has rows, run this check first and resolve any
-- violations before applying the migration:
--   SELECT * FROM staleness_tracker
--   WHERE (user_subject_id IS NOT NULL)::int + (topic_id IS NOT NULL)::int + (career_unit_id IS NOT NULL)::int != 1;
ALTER TABLE public.staleness_tracker
  ADD CONSTRAINT staleness_tracker_one_target_chk
  CHECK (
    (user_subject_id IS NOT NULL)::int +
    (topic_id IS NOT NULL)::int +
    (career_unit_id IS NOT NULL)::int = 1
  );

-- Indexes for columns the trigger function scans repeatedly, per-user
CREATE INDEX IF NOT EXISTS idx_why_log_user_subject ON nova_why_log(user_id, user_subject_id, created_at);
CREATE INDEX IF NOT EXISTS idx_why_log_topic         ON nova_why_log(user_id, topic_id, created_at);
CREATE INDEX IF NOT EXISTS idx_why_log_career         ON nova_why_log(user_id, career_unit_id, created_at);
CREATE INDEX IF NOT EXISTS idx_staleness_user         ON staleness_tracker(user_id);
CREATE INDEX IF NOT EXISTS idx_question_results_topic ON question_results(topic_id, created_at);