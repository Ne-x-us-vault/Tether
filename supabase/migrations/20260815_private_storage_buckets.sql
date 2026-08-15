-- ══════════════════════════════════════════════════════════════════════════════
-- lovit — Make media storage private (SEC-14)
--
-- Fixes the public-bucket leak: avatars, messages, and memories buckets were
-- created `public = true` with `Allow public read access` policies, so anyone
-- with an object URL could read any user's photos/videos/memories with no auth.
--
--   SEC-14a  Buckets flipped to private (public = false).
--   SEC-14b  Public-read policies dropped; replaced with authenticated,
--            pairing/owner-scoped read policies.
--   SEC-14c  `storage.create_signed_url` execute granted to `authenticated`
--            (default in stock Supabase; made explicit so the app's
--            signed-URL flow can never be blocked by a missing grant).
--
-- The Flutter client now stores the storage *path* (e.g. `messages/<pairing>/x`)
-- and resolves a short-lived signed URL at display time. Legacy public URLs
-- already written to the DB keep working: the client re-signs them from the
-- bucket/path embedded in the old URL.
-- ══════════════════════════════════════════════════════════════════════════════

-- ── SEC-14a: flip buckets to private ──────────────────────────────────────────
update storage.buckets
set public = false
where id in ('avatars', 'messages', 'memories');

-- ── SEC-14b: remove public reads, add authenticated scoped reads ──────────────
drop policy if exists "Allow public read access to avatars" on storage.objects;
drop policy if exists "Allow public read access to messages" on storage.objects;
drop policy if exists "Allow public read access to memories" on storage.objects;

drop policy if exists "Authenticated read access to avatars" on storage.objects;
create policy "Authenticated read access to avatars"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (
    -- owner
    (storage.foldername(name))[1] = auth.uid()::text
    or exists (
      select 1
      from public.pairings p
      where p.status = 'active'
        and (
          (p.user1_id = auth.uid() and p.user2_id::text = (storage.foldername(name))[1])
          or (p.user2_id = auth.uid() and p.user1_id::text = (storage.foldername(name))[1])
        )
    )
  )
);

drop policy if exists "Authenticated read access to messages" on storage.objects;
create policy "Authenticated read access to messages"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'messages'
  and exists (
    select 1
    from public.pairings p
    where p.id::text = (storage.foldername(name))[1]
      and public.is_pairing_member(p.id, auth.uid())
  )
);

drop policy if exists "Authenticated read access to memories" on storage.objects;
create policy "Authenticated read access to memories"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'memories'
  and exists (
    select 1
    from public.pairings p
    where p.id::text = (storage.foldername(name))[1]
      and public.is_pairing_member(p.id, auth.uid())
  )
);

-- ── SEC-14c: explicit grant for signed-URL creation ───────────────────────────
do $$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'storage' and p.proname = 'create_signed_url' and p.pronargs = 3
  ) then
    execute 'grant execute on function storage.create_signed_url(text, text, integer) to authenticated';
  end if;

  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'storage' and p.proname = 'create_signed_url' and p.pronargs = 4
  ) then
    execute 'grant execute on function storage.create_signed_url(text, text, integer, jsonb) to authenticated';
  end if;
end
$$;
