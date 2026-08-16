-- ══════════════════════════════════════════════════════════════════════════════
-- SEC-19  Thread deletion guardrails (Low — "Partner can clear/delete a whole
-- thread, by design but affects both users").
--
-- Both partners can still clear a thread (shared soft-delete — hidden but
-- recoverable in the DB). Hard-deleting a thread is what permanently destroys
-- shared history for both users, so it now requires that the thread has already
-- been cleared: every message in it must be soft-deleted first. One partner
-- can no longer nuke live conversation content with a single call.
--
-- UI contract (documented for any future feature work): a "Clear thread"
-- control MUST show a confirmation dialog before calling
-- clear_chat_thread_messages, and a "Delete thread" control MUST warn that it
-- permanently removes the thread for both partners before calling
-- delete_chat_thread_messages.
-- ══════════════════════════════════════════════════════════════════════════════

create or replace function public.delete_chat_thread_messages(
  p_pairing_id uuid,
  p_thread_id text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_live_count bigint;
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

  -- SEC-19: a thread may only be hard-deleted once it has been fully cleared
  -- (every message already soft-deleted). This prevents one partner from
  -- permanently destroying live shared history with a single call.
  select count(*) into v_live_count
  from public.messages
  where pairing_id = p_pairing_id
    and coalesce(metadata ->> 'thread_id', '') = p_thread_id
    and is_deleted = false;

  if v_live_count > 0 then
    raise exception 'Thread must be cleared before it can be deleted';
  end if;

  delete from public.messages
  where pairing_id = p_pairing_id
    and coalesce(metadata ->> 'thread_id', '') = p_thread_id;
end;
$$;

grant execute on function public.delete_chat_thread_messages(uuid, text) to authenticated;

-- clear_chat_thread_messages stays a shared soft-delete (recoverable in the DB).
-- It must always be gated by a confirmation dialog in the UI.
