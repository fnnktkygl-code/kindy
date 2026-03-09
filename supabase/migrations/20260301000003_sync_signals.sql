-- Realtime sync signals: lightweight table that edge functions INSERT into
-- after data changes. Clients subscribe via Supabase Realtime Postgres Changes
-- filtered by their own user_id, replacing the 45-second polling timer.

CREATE TABLE public.sync_signals (
  id         bigserial    PRIMARY KEY,
  target_user_id uuid     NOT NULL,
  signal_type    text     NOT NULL DEFAULT 'data_changed',
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_sync_signals_target ON public.sync_signals(target_user_id);

ALTER TABLE public.sync_signals ENABLE ROW LEVEL SECURITY;

-- Authenticated users can SELECT only their own signals (required for Realtime)
CREATE POLICY signals_select_own ON public.sync_signals
  FOR SELECT TO authenticated USING (target_user_id = auth.uid());

-- Only service role can INSERT (edge functions)
CREATE POLICY signals_no_auth_insert ON public.sync_signals
  FOR INSERT TO authenticated WITH CHECK (false);

CREATE POLICY signals_no_auth_update ON public.sync_signals
  FOR UPDATE TO authenticated USING (false);

CREATE POLICY signals_no_auth_delete ON public.sync_signals
  FOR DELETE TO authenticated USING (false);

-- Deny anon access entirely
CREATE POLICY signals_no_anon ON public.sync_signals
  FOR ALL TO anon USING (false);

-- Enable Supabase Realtime publication on this table
ALTER PUBLICATION supabase_realtime ADD TABLE public.sync_signals;

-- Periodic cleanup function: delete signals older than 24 hours.
-- Call via pg_cron, Supabase scheduled function, or manual invocation.
CREATE OR REPLACE FUNCTION public.cleanup_old_sync_signals()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.sync_signals
  WHERE created_at < now() - interval '24 hours';
$$;
