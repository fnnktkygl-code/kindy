-- CRIT-04 / RGPD remediation
-- Remove IP address and User-Agent storage of invite recipients.
-- These columns had no documented legal basis and violated GDPR minimisation principle.
ALTER TABLE public.invites DROP COLUMN IF EXISTS consumed_ip;
ALTER TABLE public.invites DROP COLUMN IF EXISTS consumed_ua;
