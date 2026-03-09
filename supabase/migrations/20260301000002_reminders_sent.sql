-- Add reminders_sent JSONB column to user_data
-- Used by the birthday-reminder edge function to track which pushes
-- have already been sent, preventing duplicates across invocations.
ALTER TABLE user_data
  ADD COLUMN IF NOT EXISTS reminders_sent JSONB DEFAULT '{}'::jsonb;
