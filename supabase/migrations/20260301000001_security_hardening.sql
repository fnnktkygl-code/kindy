-- Security hardening: add user_id ownership to user_data,
-- accepter_user_id to invites, and RLS deny policies.

-- 1. user_data: add user_id for ownership enforcement
ALTER TABLE public.user_data ADD COLUMN IF NOT EXISTS user_id uuid;
CREATE INDEX IF NOT EXISTS idx_user_data_user_id ON public.user_data(user_id);

-- 2. invites: add accepter_user_id for cleanup on account deletion
ALTER TABLE public.invites ADD COLUMN IF NOT EXISTS accepter_user_id uuid;

-- 3. RLS hardening: explicit deny for DELETE on invites (anon)
DROP POLICY IF EXISTS invites_no_anon_delete ON public.invites;
CREATE POLICY invites_no_anon_delete ON public.invites
  FOR DELETE TO anon USING (false);

-- 4. RLS: explicit deny-all for authenticated role on invites
DROP POLICY IF EXISTS invites_no_auth_all ON public.invites;
CREATE POLICY invites_no_auth_all ON public.invites
  FOR ALL TO authenticated USING (false);

-- 5. RLS: explicit deny-all for authenticated role on user_data
DROP POLICY IF EXISTS user_data_no_auth ON public.user_data;
CREATE POLICY user_data_no_auth ON public.user_data
  FOR ALL TO authenticated USING (false);
