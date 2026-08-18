-- ══════════════════════════════════════════════════════════════════════════════
-- Seed 2 development test users — idempotent, split into statements
-- so the exact failure point is visible.
--
--   User 1:  dev1@test.com  /  Test1234!
--   User 2:  dev2@test.com  /  Test1234!
-- ══════════════════════════════════════════════════════════════════════════════

-- ── 0. Clean up any previous run ─────────────────────────────────────────────

delete from public.pairings where id = '00000000-0000-0000-0000-000000000099';
delete from public.profiles where id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
);
delete from auth.identities where user_id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
);
delete from auth.users where id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
);

-- ── 1. Inspect the actual column types so we know what we're working with ────

select column_name, data_type, character_maximum_length
from information_schema.columns
where table_schema = 'auth' and table_name = 'users'
order by ordinal_position;

select column_name, data_type, character_maximum_length
from information_schema.columns
where table_schema = 'auth' and table_name = 'identities'
order by ordinal_position;

-- ── 2. Minimal auth.users insert (let every optional column default) ─────────

insert into auth.users (id, email, encrypted_password, email_confirmed_at)
values (
  '00000000-0000-0000-0000-000000000001',
  'dev1@test.com',
  crypt('Test1234!', gen_salt('bf')),
  now()
);

insert into auth.users (id, email, encrypted_password, email_confirmed_at)
values (
  '00000000-0000-0000-0000-000000000002',
  'dev2@test.com',
  crypt('Test1234!', gen_salt('bf')),
  now()
);

-- ── 3. Minimal auth.identities insert ───────────────────────────────────────

insert into auth.identities (id, user_id, provider_id, identity_data, provider)
values (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'dev1@test.com',
  '{"sub":"00000000-0000-0000-0000-000000000001","email":"dev1@test.com"}',
  'email'
);

insert into auth.identities (id, user_id, provider_id, identity_data, provider)
values (
  '00000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000002',
  'dev2@test.com',
  '{"sub":"00000000-0000-0000-0000-000000000002","email":"dev2@test.com"}',
  'email'
);

-- ── 4. Profiles ─────────────────────────────────────────────────────────────

insert into public.profiles (id, username, display_name)
values
  ('00000000-0000-0000-0000-000000000001', 'dev1', 'Dev User 1');

insert into public.profiles (id, username, display_name)
values
  ('00000000-0000-0000-0000-000000000002', 'dev2', 'Dev User 2');

-- ── 5. Pairing ──────────────────────────────────────────────────────────────

insert into public.pairings (
  id, user1_id, user2_id, pairing_code, status, paired_at, expires_at
) values (
  '00000000-0000-0000-0000-000000000099',
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002',
  'DEV-PAIR-2026',
  'active',
  now(),
  now() + interval '365 days'
);
