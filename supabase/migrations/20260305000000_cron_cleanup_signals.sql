-- Schedule daily cleanup of stale sync_signals via pg_cron.
-- Runs at 03:00 UTC every day. Requires pg_cron extension enabled.

-- Enable pg_cron if not already (Supabase has it available but sometimes not enabled)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Schedule the cleanup job
SELECT cron.schedule(
  'cleanup-sync-signals',          -- job name
  '0 3 * * *',                     -- every day at 03:00 UTC
  $$DELETE FROM public.sync_signals WHERE created_at < now() - interval '24 hours'$$
);
