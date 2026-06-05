create extension if not exists pgcrypto;

create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  token_hash text not null unique,
  inviter_id text not null,
  contact_id text,
  group_id text,
  channel text not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'expired', 'revoked')),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists invites_status_expires_idx on public.invites(status, expires_at);
create index if not exists invites_inviter_idx on public.invites(inviter_id);

-- Optional: Row Level Security (recommended if accessing from client with anon key).
alter table public.invites enable row level security;

-- Block direct reads/writes from anon clients. Edge Functions should use service role key.
drop policy if exists invites_no_anon_select on public.invites;
create policy invites_no_anon_select on public.invites
for select to anon
using (false);

drop policy if exists invites_no_anon_insert on public.invites;
create policy invites_no_anon_insert on public.invites
for insert to anon
with check (false);

drop policy if exists invites_no_anon_update on public.invites;
create policy invites_no_anon_update on public.invites
for update to anon
using (false)
with check (false);
