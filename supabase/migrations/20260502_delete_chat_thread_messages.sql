create or replace function public.delete_chat_thread_messages(
  p_pairing_id uuid,
  p_thread_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_thread_id is null or btrim(p_thread_id) = '' then
    raise exception 'Thread id is required';
  end if;

  if p_thread_id = 'primary-thread' then
    raise exception 'Primary chat cannot be deleted';
  end if;

  if not exists (
    select 1
    from public.pairings
    where id = p_pairing_id
      and status = 'active'
      and (user1_id = auth.uid() or user2_id = auth.uid())
  ) then
    raise exception 'Not authorized to delete this thread';
  end if;

  delete from public.messages
  where pairing_id = p_pairing_id
    and coalesce(metadata ->> 'thread_id', '') = p_thread_id;
end;
$$;

grant execute on function public.delete_chat_thread_messages(uuid, text) to authenticated;

create or replace function public.clear_chat_thread_messages(
  p_pairing_id uuid,
  p_thread_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_thread_id is null or btrim(p_thread_id) = '' then
    raise exception 'Thread id is required';
  end if;

  if p_thread_id = 'primary-thread' then
    raise exception 'Primary chat cannot be cleared this way';
  end if;

  if not exists (
    select 1
    from public.pairings
    where id = p_pairing_id
      and status = 'active'
      and (user1_id = auth.uid() or user2_id = auth.uid())
  ) then
    raise exception 'Not authorized to clear this thread';
  end if;

  update public.messages
  set is_deleted = true,
      deleted_at = now()
  where pairing_id = p_pairing_id
    and coalesce(metadata ->> 'thread_id', '') = p_thread_id;
end;
$$;

grant execute on function public.clear_chat_thread_messages(uuid, text) to authenticated;
