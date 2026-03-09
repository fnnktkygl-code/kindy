-- Enable pg_net and pg_cron for server-side re-engagement push notifications
CREATE EXTENSION IF NOT EXISTS pg_net SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron SCHEMA cron;

-- Schedule daily re-engagement push at 10:00 UTC
-- Calls the check-reengage edge function which queries inactive users
-- and sends FCM push notifications to bring them back.
SELECT cron.schedule(
  'reengage-daily',
  '0 10 * * *',
  $$
  SELECT net.http_post(
    url := 'https://rlghoamehiqlqzjdyxcg.supabase.co/functions/v1/check-reengage',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
