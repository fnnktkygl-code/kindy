-- Schedule the churn-reengage Edge Function daily at 10:15 UTC.
-- Runs 15 minutes after the legacy check-reengage to avoid overlap.
-- Uses CRON_SECRET for authentication (set in Edge Function env).

SELECT cron.schedule(
  'churn-reengage-daily',
  '15 10 * * *',
  $$
  SELECT net.http_post(
    url := 'https://vcnelfgziucsyukahhey.supabase.co/functions/v1/churn-reengage',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.cron_secret'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);

-- Schedule analytics cleanup weekly (Sunday 03:00 UTC).
-- Removes events older than 90 days to control storage costs.
SELECT cron.schedule(
  'analytics-cleanup-weekly',
  '0 3 * * 0',
  $$ SELECT public.cleanup_old_analytics(); $$
);
