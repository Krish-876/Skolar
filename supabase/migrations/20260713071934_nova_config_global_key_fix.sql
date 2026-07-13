-- ============================================================
-- Fix: NULL user_id rows in nova_config aren't caught by the
-- existing UNIQUE(user_id, key) constraint, since Postgres treats
-- NULL <> NULL for uniqueness. This guards the global-default rows
-- specifically, so get_nova_triggers() can't hit a
-- "subquery returned more than one row" crash.
-- ============================================================
CREATE UNIQUE INDEX nova_config_global_key_uidx
  ON public.nova_config (key)
  WHERE user_id IS NULL;