-- Add notification_prefs column to user_data table
ALTER TABLE public.user_data
  ADD COLUMN IF NOT EXISTS notification_prefs jsonb NOT NULL DEFAULT '{}'::jsonb;
