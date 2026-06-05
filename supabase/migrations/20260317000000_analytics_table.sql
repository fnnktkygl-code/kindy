-- Analytics events table for growth tracking.
-- Receives events from the Flutter client via Supabase insert.
-- Used to compute D1/D7/D30 retention cohorts and activation funnels.

CREATE TABLE public.analytics (
  id         bigint       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    uuid         REFERENCES auth.users(id) ON DELETE SET NULL,
  event      text         NOT NULL,
  properties jsonb        DEFAULT '{}'::jsonb,
  created_at timestamptz  NOT NULL DEFAULT now()
);

-- Index for cohort queries: "which users did X within N days of install?"
CREATE INDEX idx_analytics_user_event ON public.analytics(user_id, event);
CREATE INDEX idx_analytics_created    ON public.analytics(created_at DESC);
CREATE INDEX idx_analytics_event      ON public.analytics(event);

-- Row Level Security: users can only insert their own events
ALTER TABLE public.analytics ENABLE ROW LEVEL SECURITY;

-- Authenticated users can INSERT their own events
CREATE POLICY analytics_insert_own ON public.analytics
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- Users can SELECT their own events (optional: for client-side debugging)
CREATE POLICY analytics_select_own ON public.analytics
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- No update or delete from clients
CREATE POLICY analytics_no_update ON public.analytics
  FOR UPDATE TO authenticated USING (false);
CREATE POLICY analytics_no_delete ON public.analytics
  FOR DELETE TO authenticated USING (false);

-- Anon cannot access analytics
CREATE POLICY analytics_no_anon ON public.analytics
  FOR ALL TO anon USING (false);

-- Periodic cleanup: remove events older than 90 days to control storage.
-- Can be called via pg_cron or manually.
CREATE OR REPLACE FUNCTION public.cleanup_old_analytics()
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  DELETE FROM public.analytics
  WHERE created_at < now() - interval '90 days';
$$;
