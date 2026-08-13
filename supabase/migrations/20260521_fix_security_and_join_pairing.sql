-- ══════════════════════════════════════════════════════════════════════════════
-- lovit — Security hardening migration
--
-- Fixes from the 4-category audit:
--   SEC-02  Pairing joins move to a SECURITY DEFINER RPC; drop the
--           enumerable "view pending pairings" policy and the vulnerable
--           "join pending pairings" UPDATE policy.
--   SEC-03  Storage object policies scoped to path conventions
--           (avatars/<own-user-id>/, messages+memories/<pairing-id>/).
--   SEC-05  Messages: non-senders may only touch metadata (pins), not
--           content. Cycle data is owner-modifiable only.
--   SEC-06  `create_pairings` insert policy tightened (no pre-made active
--           pairings with arbitrary partners).
--   SEC-07  Opting out of location sharing NULLs stored coordinates.
--
-- Deliberately NOT changed: `push_token` stays SELECT-able because the
-- client realtime SDK (supabase-2.10.6) streams profiles with `select('*')`,
-- so a column-level revoke would break realtime presence. See docs/ERRORS.md.
-- ══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-02: Remove insecure pairing policies
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Users can view pending pairings" on public.pairings;
drop policy if exists "Users can join pending pairings" on public.pairings;

-- SEC-06: A user may only create a pending pairing with themselves as user1.
drop policy if exists "Users can create pairings" on public.pairings;
create policy "Users can create their own pending pairings"
on public.pairings
for insert
with check (
  user1_id = auth.uid()
  and user2_id is null
  and status = 'pending'
);

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-02: Atomic join_pairing RPC
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.join_pairing(p_code text)
returns public.pairings
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pairing public.pairings;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_code is null or btrim(p_code) = '' then
    raise exception 'Pairing code is required';
  end if;

  -- Row lock makes the claim of an open pairing atomic under concurrency.
  select *
  into v_pairing
  from public.pairings
  where upper(pairing_code) = upper(btrim(p_code))
  limit 1
  for update;

  if not found then
    raise exception 'Pairing code not found';
  end if;

  if v_pairing.status <> 'pending' then
    raise exception 'Pairing is no longer pending';
  end if;

  if v_pairing.user2_id is not null then
    raise exception 'Pairing has already been joined';
  end if;

  if v_pairing.user1_id = auth.uid() then
    raise exception 'You cannot join your own pairing';
  end if;

  if v_pairing.expires_at is not null and v_pairing.expires_at < now() then
    raise exception 'Pairing code has expired';
  end if;

  update public.pairings
  set user2_id = auth.uid(),
      status = 'active',
      paired_at = now()
  where id = v_pairing.id
  returning * into v_pairing;

  return v_pairing;
end;
$$;

grant execute on function public.join_pairing(text) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-05: Messages — content is sender-only, metadata is member-accessible
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Pairing members can update messages" on public.messages;
create policy "Messages editable by sender, metadata by members"
on public.messages
for update
using (
  public.is_pairing_member(pairing_id, auth.uid())
  and (
    sender_id = auth.uid()
    or (
      content is not distinct from old.content
      and edited_at is not distinct from old.edited_at
      and edit_history is not distinct from old.edit_history
    )
  )
)
with check (public.is_pairing_member(pairing_id, auth.uid()));

-- Unsend ("delete for everyone") is only offered in the UI for the sender's
-- own messages, so DELETE is sender-only.
drop policy if exists "Pairing members can delete messages" on public.messages;
create policy "Only senders can delete their messages"
on public.messages
for delete
using (sender_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-05: Cycle tracking — owner may modify, partner may view
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "Users can update their own cycle data" on public.cycle_tracking;
create policy "Users can update their own cycle data"
on public.cycle_tracking
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete their own cycle data" on public.cycle_tracking;
create policy "Users can delete their own cycle data"
on public.cycle_tracking
for delete
using (user_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-07: Opting out of location sharing clears stored coordinates
-- ─────────────────────────────────────────────────────────────────────────────

create or replace function public.nullify_location_on_opt_out()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.location_sharing_enabled = false then
    new.current_latitude = null;
    new.current_longitude = null;
    new.location_last_updated = null;
  end if;
  return new;
end;
$$;

drop trigger if exists nullify_location_on_opt_out on public.profiles;
create trigger nullify_location_on_opt_out
before update on public.profiles
for each row execute function public.nullify_location_on_opt_out();

-- ─────────────────────────────────────────────────────────────────────────────
-- SEC-03: Storage policies scoped to path conventions
-- ─────────────────────────────────────────────────────────────────────────────

-- Avatars live under <user_id>/ — only the owner may write to their folder.
drop policy if exists "Allow authenticated uploads to avatars" on storage.objects;
create policy "Allow authenticated uploads to avatars"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Allow authenticated updates to avatars" on storage.objects;
create policy "Allow authenticated updates to avatars"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "Allow authenticated deletes to avatars" on storage.objects;
create policy "Allow authenticated deletes to avatars"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- Message + memory media live under <pairing_id>/ — only pairing members may
-- write to their pairing's folder.
drop policy if exists "Allow authenticated uploads to messages" on storage.objects;
create policy "Allow authenticated uploads to messages"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'messages'
  and exists (
    select 1
    from public.pairings p
    where p.id::text = (storage.foldername(name))[1]
      and public.is_pairing_member(p.id, auth.uid())
  )
);

drop policy if exists "Allow authenticated updates to messages" on storage.objects;
create policy "Allow authenticated updates to messages"
on storage.objects
for update
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

drop policy if exists "Allow authenticated deletes to messages" on storage.objects;
create policy "Allow authenticated deletes to messages"
on storage.objects
for delete
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

drop policy if exists "Allow authenticated uploads to memories" on storage.objects;
create policy "Allow authenticated uploads to memories"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'memories'
  and exists (
    select 1
    from public.pairings p
    where p.id::text = (storage.foldername(name))[1]
      and public.is_pairing_member(p.id, auth.uid())
  )
);

drop policy if exists "Allow authenticated updates to memories" on storage.objects;
create policy "Allow authenticated updates to memories"
on storage.objects
for update
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

drop policy if exists "Allow authenticated deletes to memories" on storage.objects;
create policy "Allow authenticated deletes to memories"
on storage.objects
for delete
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
