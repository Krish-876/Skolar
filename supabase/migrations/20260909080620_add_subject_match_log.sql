-- ============================================================
-- AI-assisted subject matching - ambiguous/no-match log.
--
-- subject_matcher.py never guesses and never writes user_subjects/
-- custom_subjects itself when it can't find a confident match (see
-- SUBJECT_MATCH_CONFIDENCE_THRESHOLD). Every time it returns a
-- disambiguation candidate list, or comes back with nothing close at all,
-- the attempt is logged here - queryable evidence of which subject names
-- students are actually typing that the canonical `subjects` catalog is
-- missing, so it can be reviewed and backfilled over time.
--
-- resolved_subject_id/resolved_custom_subject_id are filled in later, once
-- the student explicitly confirms a candidate or creates a new custom
-- subject (see subject_enrollment.resolve_match_log) - NULL until then.
-- ============================================================

CREATE TABLE public.subject_match_log (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  institution_id uuid NOT NULL,
  campus_id uuid,
  query_text text NOT NULL,
  -- 'no_match'       -> candidates is an empty array, genuinely nothing close.
  -- 'disambiguation' -> candidates holds the 1-2 options shown to the student.
  -- 'provider_error' -> the Groq call itself failed (primary and backup, or
  --                      unparseable/empty content) - never a real model
  --                      verdict, kept distinct so it doesn't read as a
  --                      genuine catalog gap.
  status text NOT NULL CHECK (status = ANY (ARRAY['no_match'::text, 'disambiguation'::text, 'provider_error'::text])),
  candidates jsonb NOT NULL DEFAULT '[]'::jsonb,
  resolved_subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
  resolved_custom_subject_id uuid REFERENCES public.custom_subjects(id) ON DELETE SET NULL,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT subject_match_log_pkey PRIMARY KEY (id),
  -- A row is resolved by at most one of the two target tables, never both.
  CONSTRAINT subject_match_log_resolution_chk CHECK (
    resolved_subject_id IS NULL OR resolved_custom_subject_id IS NULL
  )
);

COMMENT ON TABLE public.subject_match_log IS
  'Ambiguous/no-match cases from AI-assisted subject matching (onboarding subject-add flow), for reviewing gaps in the subjects catalog over time.';

CREATE INDEX idx_subject_match_log_institution_status
  ON public.subject_match_log (institution_id, status, created_at);

CREATE INDEX idx_subject_match_log_user
  ON public.subject_match_log (user_id, created_at);

ALTER TABLE public.subject_match_log ENABLE ROW LEVEL SECURITY;

-- Read-only for the owner, no direct mutation for `authenticated` - same
-- shape as nova_unconfirmed_proposals. The real write path (backend/nova)
-- always uses the service-role key, which bypasses RLS regardless; this
-- policy only governs what happens if the table is ever queried directly
-- by a Supabase client.
CREATE POLICY "users read own subject match log"
  ON public.subject_match_log
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
