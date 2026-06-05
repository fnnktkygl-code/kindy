-- Add gift pots sync column to user_data table
ALTER TABLE public.user_data
  ADD COLUMN IF NOT EXISTS gift_pots_data jsonb NOT NULL DEFAULT '[]'::jsonb;
