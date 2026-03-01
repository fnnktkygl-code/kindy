-- Profile exchange: store sender/accepter profile in invites
ALTER TABLE public.invites ADD COLUMN IF NOT EXISTS inviter_profile jsonb;
ALTER TABLE public.invites ADD COLUMN IF NOT EXISTS accepter_profile jsonb;

-- Cross-device sync table
CREATE TABLE IF NOT EXISTS public.user_data (
  sync_key       text PRIMARY KEY,
  contacts_data  jsonb NOT NULL DEFAULT '[]'::jsonb,
  circles_data   jsonb NOT NULL DEFAULT '[]'::jsonb,
  pending_invites_data jsonb NOT NULL DEFAULT '[]'::jsonb,
  profile_data   jsonb NOT NULL DEFAULT '{}'::jsonb,
  wishes_data    jsonb NOT NULL DEFAULT '[]'::jsonb,
  events_data    jsonb NOT NULL DEFAULT '[]'::jsonb,
  sizes_data     jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_data ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_data_no_anon ON public.user_data;
CREATE POLICY user_data_no_anon ON public.user_data
  FOR ALL TO anon USING (false);
