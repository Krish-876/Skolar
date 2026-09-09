-- ============================================================
-- Nova conversation proposal/confirm layer — spec §5.
-- Staging table for conversation-proposed facts (standing_flags,
-- situation_flags, nova_history, career_units) that stay inert
-- until the student explicitly confirms them. Confirming writes
-- the real row into the destination table; rejecting just marks
-- this row rejected and touches nothing else.
--
-- turn_id groups everything proposed in one chat turn, so a
-- single confirm/reject action can apply to the whole batch
-- (spec §5's "confirmation happens once per turn, not per field").
-- ============================================================

CREATE TABLE public.nova_unconfirmed_proposals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  turn_id uuid NOT NULL,
  -- Matches the real destination table name exactly for every flag/history
  -- kind (standing_flags/situation_flags/nova_history), so no separate
  -- enum-to-table mapping is ever needed to resolve one from the other.
  -- career_unit is the one exception: it represents the unit itself
  -- (see the CHECK below), not a row destined for a "career_units" table
  -- lookup keyed the same way as the other three.
  proposal_type text NOT NULL CHECK (proposal_type = ANY (ARRAY['standing_flag'::text, 'situation_flag'::text, 'nova_history'::text, 'career_unit'::text])),
  user_subject_id uuid REFERENCES public.user_subjects(id) ON DELETE CASCADE,
  career_unit_id uuid REFERENCES public.career_units(id) ON DELETE CASCADE,
  payload jsonb NOT NULL,
  proposed_summary text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'rejected'::text])),
  resulting_row_id uuid,
  resolved_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT nova_unconfirmed_proposals_pkey PRIMARY KEY (id),
  -- A career_unit proposal represents the unit itself, so it never
  -- attaches to a target unit the way a flag/history proposal does.
  CONSTRAINT nova_unconfirmed_proposals_career_unit_no_target_chk CHECK (
    proposal_type <> 'career_unit'
    OR (user_subject_id IS NULL AND career_unit_id IS NULL)
  ),
  -- status/resolved_at/resulting_row_id must move together, not be set
  -- independently by a stray partial UPDATE:
  --   pending   -> neither set yet
  --   rejected  -> resolved, but nothing was written anywhere
  --   confirmed -> resolved AND a real target-table row exists. Every
  --                confirm path in proposals_service.py sets this,
  --                including career_unit's unpause-existing-row case
  --                (resulting_row_id is that existing row's id, not a
  --                freshly-inserted one) - verified in code, not assumed.
  CONSTRAINT nova_unconfirmed_proposals_status_consistency_chk CHECK (
    (status = 'pending' AND resolved_at IS NULL AND resulting_row_id IS NULL)
    OR (status = 'rejected' AND resolved_at IS NOT NULL AND resulting_row_id IS NULL)
    OR (status = 'confirmed' AND resolved_at IS NOT NULL AND resulting_row_id IS NOT NULL)
  )
);

COMMENT ON TABLE public.nova_unconfirmed_proposals IS
  'Staging area for conversation-proposed writes (spec §5). Unconfirmed rows here have zero effect on facts_service/reasoning — they are not one of the 4 destination tables. Confirming resolves this row into a real write against standing_flags/situation_flags/nova_history/career_units and applies the §2a supersession rule there; rejecting just marks this row rejected.';

CREATE INDEX idx_nova_unconfirmed_proposals_user_status
  ON public.nova_unconfirmed_proposals (user_id, status, created_at);

CREATE INDEX idx_nova_unconfirmed_proposals_turn
  ON public.nova_unconfirmed_proposals (turn_id);

ALTER TABLE public.nova_unconfirmed_proposals ENABLE ROW LEVEL SECURITY;

-- Read-only for the owner, no direct mutation at all for `authenticated`.
-- The real write path (backend/nova) always uses the service-role key,
-- which bypasses RLS regardless - this policy only governs what happens
-- if this table is ever queried directly by a Supabase client. That's a
-- deliberately different (stricter) shape than the four real destination
-- tables this stages for: standing_flags/situation_flags/nova_history/
-- career_units all use a single `FOR ALL USING (user_id = auth.uid())`
-- policy (baseline.sql), which - as a side effect nobody appears to have
-- intended - lets an authenticated student INSERT/UPDATE those tables
-- directly with confirmed_at already set, bypassing the propose/confirm
-- flow entirely. That looks like a latent gap in those four tables, not
-- a pattern worth repeating here; fixing it there is out of scope for
-- this migration, but it's flagged rather than silently matched.
CREATE POLICY "users read own proposals"
  ON public.nova_unconfirmed_proposals
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());
