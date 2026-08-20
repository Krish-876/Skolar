-- gh-62: Remove dev-leftover RLS policy that grants unauthenticated read access to questions
--
-- baseline.sql line 1485 created:
--   CREATE POLICY "dev read all questions" ON public.questions FOR SELECT USING (true);
--
-- This policy has no TO clause → defaults to PUBLIC (anon + authenticated).
-- USING (true) → no restriction at all.
--
-- Net effect: any anon client can `SELECT * FROM questions` without any
--             auth check — full unauthenticated read of all question data.
--
-- The correctly-scoped `questions_read_all` policy (line 1615) already grants
-- read to authenticated users:
--   CREATE POLICY questions_read_all ON public.questions
--   FOR SELECT USING (auth.role() = 'authenticated'::text);
--
-- So the dev policy is pure superset: it makes the authenticated-only policy
-- meaningless for anon callers and defeats the entire RLS model.
--
-- Fix: DROP the dev policy. No data migration needed — the policy is gone,
-- the table and its rows are untouched.

BEGIN;

DROP POLICY IF EXISTS "dev read all questions" ON public.questions;

-- Safety: verify anon can no longer read questions
-- (run separately, against the target DB)
-- SELECT count(*) FROM questions;  -- as anon → must error or return 0

COMMIT;

-- Rollback (restores the vulnerable state — only for dev rollback testing):
-- CREATE POLICY "dev read all questions" ON public.questions FOR SELECT USING (true);
