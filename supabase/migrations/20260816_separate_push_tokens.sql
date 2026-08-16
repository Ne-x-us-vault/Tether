-- ══════════════════════════════════════════════════════════════════════════════
-- SEC-17  Push tokens are device-specific secrets.
--
-- Previously `profiles.push_token` was SELECT-able by the pairing partner
-- (the realtime presence stream selects profiles with select('*')), leaking
-- the recipient's FCM token to anyone in an active pairing.
--
-- This migration moves the token into a private `push_tokens` table where:
--   • the owner can insert/update/select/delete only their own row, and
--   • only the service role (edge function) can read any token.
-- The realtime `select('*')` on profiles keeps working because the column is
-- simply gone from that table.
-- ══════════════════════════════════════════════════════════════════════════════

create table if not exists public.push_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  token text not null,
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;

-- Owner-only: one policy covers select / insert / update / delete.
create policy "Users manage their own push token"
  on public.push_tokens
  for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Explicit grants (Supabase default grants can be missing in some setups).
grant select, insert, update, delete on public.push_tokens to authenticated;
grant all on public.push_tokens to service_role;

-- ── Carry over existing tokens, then retire the profiles column ─────────────
insert into public.push_tokens (user_id, token, updated_at)
select id, push_token, coalesce(updated_at, now())
from public.profiles
where push_token is not null
on conflict (user_id) do update set token = excluded.token;

alter table public.profiles drop column if exists push_token;
