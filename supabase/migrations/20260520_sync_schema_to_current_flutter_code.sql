create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  display_name text,
  avatar_url text,
  bio text,
  battery_level integer,
  battery_last_updated timestamptz,
  location_sharing_enabled boolean not null default false,
  current_latitude double precision,
  current_longitude double precision,
  location_last_updated timestamptz,
  push_token text,
  preferences jsonb not null default '{}'::jsonb,
  is_online boolean not null default false,
  last_seen timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pairings (
  id uuid primary key default gen_random_uuid(),
  user1_id uuid not null references auth.users(id) on delete cascade,
  user2_id uuid references auth.users(id) on delete set null,
  pairing_code text not null unique,
  status text not null default 'pending' check (status in ('pending', 'active', 'inactive')),
  paired_at timestamptz,
  expires_at timestamptz not null default (now() + interval '24 hours'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (user1_id is distinct from user2_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  pairing_id uuid not null references public.pairings(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  message_type text not null default 'text',
  content text,
  media_url text,
  metadata jsonb not null default '{}'::jsonb,
  is_read boolean not null default false,
  read_at timestamptz,
  is_deleted boolean not null default false,
  deleted_at timestamptz,
  reply_to_id uuid references public.messages(id) on delete set null,
  edited_at timestamptz,
  edit_history jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  emoji text not null,
  created_at timestamptz not null default now(),
  unique (message_id, user_id, emoji)
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  pairing_id uuid not null references public.pairings(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  assigned_to uuid references auth.users(id) on delete set null,
  title text not null,
  description text,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high')),
  due_date timestamptz,
  is_completed boolean not null default false,
  completed_at timestamptz,
  completed_by uuid references auth.users(id) on delete set null,
  position integer not null default 0,
  tags text[] not null default '{}'::text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.calendar_events (
  id uuid primary key default gen_random_uuid(),
  pairing_id uuid not null references public.pairings(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  location text,
  start_time timestamptz not null,
  end_time timestamptz not null,
  all_day boolean not null default false,
  color text not null default '#B39DFF',
  reminder_minutes integer[] not null default '{}'::integer[],
  is_recurring boolean not null default false,
  recurrence_rule text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (end_time >= start_time)
);

create table if not exists public.cycle_tracking (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pairing_id uuid references public.pairings(id) on delete set null,
  cycle_start_date date not null,
  cycle_length integer not null default 28,
  period_length integer not null default 5,
  flow_level text,
  symptoms text[],
  mood text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.budget_transactions (
  id uuid primary key default gen_random_uuid(),
  pairing_id uuid not null references public.pairings(id) on delete cascade,
  created_by uuid not null references auth.users(id) on delete cascade,
  paid_by uuid references auth.users(id) on delete set null,
  title text not null,
  amount numeric(12,2) not null,
  category text not null default 'other',
  transaction_date timestamptz not null default now(),
  notes text,
  is_shared boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  pairing_id uuid references public.pairings(id) on delete set null,
  title text not null,
  body text not null,
  notification_type text not null default 'mood',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.profiles add column if not exists username text;
alter table if exists public.profiles add column if not exists display_name text;
alter table if exists public.profiles add column if not exists avatar_url text;
alter table if exists public.profiles add column if not exists bio text;
alter table if exists public.profiles add column if not exists battery_level integer;
alter table if exists public.profiles add column if not exists battery_last_updated timestamptz;
alter table if exists public.profiles add column if not exists location_sharing_enabled boolean not null default false;
alter table if exists public.profiles add column if not exists current_latitude double precision;
alter table if exists public.profiles add column if not exists current_longitude double precision;
alter table if exists public.profiles add column if not exists location_last_updated timestamptz;
alter table if exists public.profiles add column if not exists push_token text;
alter table if exists public.profiles add column if not exists preferences jsonb not null default '{}'::jsonb;
alter table if exists public.profiles add column if not exists is_online boolean not null default false;
alter table if exists public.profiles add column if not exists last_seen timestamptz;
alter table if exists public.profiles add column if not exists created_at timestamptz not null default now();
alter table if exists public.profiles add column if not exists updated_at timestamptz not null default now();

alter table if exists public.pairings add column if not exists paired_at timestamptz;
alter table if exists public.pairings add column if not exists expires_at timestamptz not null default (now() + interval '24 hours');
alter table if exists public.pairings add column if not exists created_at timestamptz not null default now();
alter table if exists public.pairings add column if not exists updated_at timestamptz not null default now();

alter table if exists public.messages add column if not exists message_type text not null default 'text';
alter table if exists public.messages add column if not exists content text;
alter table if exists public.messages add column if not exists media_url text;
alter table if exists public.messages add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table if exists public.messages add column if not exists is_read boolean not null default false;
alter table if exists public.messages add column if not exists read_at timestamptz;
alter table if exists public.messages add column if not exists is_deleted boolean not null default false;
alter table if exists public.messages add column if not exists deleted_at timestamptz;
alter table if exists public.messages add column if not exists reply_to_id uuid references public.messages(id) on delete set null;
alter table if exists public.messages add column if not exists edited_at timestamptz;
alter table if exists public.messages add column if not exists edit_history jsonb;
alter table if exists public.messages add column if not exists created_at timestamptz not null default now();
alter table if exists public.messages add column if not exists updated_at timestamptz not null default now();

alter table if exists public.tasks add column if not exists assigned_to uuid references auth.users(id) on delete set null;
alter table if exists public.tasks add column if not exists description text;
alter table if exists public.tasks add column if not exists priority text not null default 'medium';
alter table if exists public.tasks add column if not exists due_date timestamptz;
alter table if exists public.tasks add column if not exists is_completed boolean not null default false;
alter table if exists public.tasks add column if not exists completed_at timestamptz;
alter table if exists public.tasks add column if not exists completed_by uuid references auth.users(id) on delete set null;
alter table if exists public.tasks add column if not exists position integer not null default 0;
alter table if exists public.tasks add column if not exists tags text[] not null default '{}'::text[];
alter table if exists public.tasks add column if not exists created_at timestamptz not null default now();
alter table if exists public.tasks add column if not exists updated_at timestamptz not null default now();

alter table if exists public.calendar_events add column if not exists description text;
alter table if exists public.calendar_events add column if not exists location text;
alter table if exists public.calendar_events add column if not exists all_day boolean not null default false;
alter table if exists public.calendar_events add column if not exists color text not null default '#B39DFF';
alter table if exists public.calendar_events add column if not exists reminder_minutes integer[] not null default '{}'::integer[];
alter table if exists public.calendar_events add column if not exists is_recurring boolean not null default false;
alter table if exists public.calendar_events add column if not exists recurrence_rule text;
alter table if exists public.calendar_events add column if not exists metadata jsonb not null default '{}'::jsonb;
alter table if exists public.calendar_events add column if not exists created_at timestamptz not null default now();
alter table if exists public.calendar_events add column if not exists updated_at timestamptz not null default now();

alter table if exists public.cycle_tracking add column if not exists pairing_id uuid references public.pairings(id) on delete set null;
alter table if exists public.cycle_tracking add column if not exists cycle_length integer not null default 28;
alter table if exists public.cycle_tracking add column if not exists period_length integer not null default 5;
alter table if exists public.cycle_tracking add column if not exists flow_level text;
alter table if exists public.cycle_tracking add column if not exists symptoms text[];
alter table if exists public.cycle_tracking add column if not exists mood text;
alter table if exists public.cycle_tracking add column if not exists notes text;
alter table if exists public.cycle_tracking add column if not exists created_at timestamptz not null default now();
alter table if exists public.cycle_tracking add column if not exists updated_at timestamptz not null default now();

alter table if exists public.budget_transactions add column if not exists paid_by uuid references auth.users(id) on delete set null;
alter table if exists public.budget_transactions add column if not exists transaction_date timestamptz not null default now();
alter table if exists public.budget_transactions add column if not exists notes text;
alter table if exists public.budget_transactions add column if not exists is_shared boolean not null default true;
alter table if exists public.budget_transactions add column if not exists created_at timestamptz not null default now();
alter table if exists public.budget_transactions add column if not exists updated_at timestamptz not null default now();

alter table if exists public.notifications add column if not exists pairing_id uuid references public.pairings(id) on delete set null;
alter table if exists public.notifications add column if not exists notification_type text not null default 'mood';
alter table if exists public.notifications add column if not exists is_read boolean not null default false;
alter table if exists public.notifications add column if not exists created_at timestamptz not null default now();
alter table if exists public.notifications add column if not exists updated_at timestamptz not null default now();

create index if not exists profiles_username_idx on public.profiles (username);
create index if not exists pairings_code_idx on public.pairings (pairing_code);
create index if not exists pairings_user1_idx on public.pairings (user1_id);
create index if not exists pairings_user2_idx on public.pairings (user2_id);
create index if not exists messages_pairing_created_idx on public.messages (pairing_id, created_at desc);
create index if not exists messages_sender_idx on public.messages (sender_id);
create index if not exists messages_reply_to_idx on public.messages (reply_to_id);
create index if not exists messages_metadata_gin_idx on public.messages using gin (metadata);
create index if not exists message_reactions_message_idx on public.message_reactions (message_id);
create index if not exists message_reactions_user_idx on public.message_reactions (user_id);
create index if not exists tasks_pairing_position_idx on public.tasks (pairing_id, position);
create index if not exists calendar_events_pairing_time_idx on public.calendar_events (pairing_id, start_time, end_time);
create index if not exists cycle_tracking_pairing_idx on public.cycle_tracking (pairing_id, updated_at desc);
create index if not exists cycle_tracking_user_idx on public.cycle_tracking (user_id, updated_at desc);
create index if not exists budget_transactions_pairing_date_idx on public.budget_transactions (pairing_id, transaction_date desc);
create index if not exists budget_transactions_paid_by_idx on public.budget_transactions (paid_by);
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);

update public.budget_transactions
set paid_by = created_by
where paid_by is null;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_pairings_updated_at on public.pairings;
create trigger set_pairings_updated_at
before update on public.pairings
for each row execute function public.set_updated_at();

drop trigger if exists set_messages_updated_at on public.messages;
create trigger set_messages_updated_at
before update on public.messages
for each row execute function public.set_updated_at();

drop trigger if exists set_tasks_updated_at on public.tasks;
create trigger set_tasks_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

drop trigger if exists set_calendar_events_updated_at on public.calendar_events;
create trigger set_calendar_events_updated_at
before update on public.calendar_events
for each row execute function public.set_updated_at();

drop trigger if exists set_cycle_tracking_updated_at on public.cycle_tracking;
create trigger set_cycle_tracking_updated_at
before update on public.cycle_tracking
for each row execute function public.set_updated_at();

drop trigger if exists set_budget_transactions_updated_at on public.budget_transactions;
create trigger set_budget_transactions_updated_at
before update on public.budget_transactions
for each row execute function public.set_updated_at();

drop trigger if exists set_notifications_updated_at on public.notifications;
create trigger set_notifications_updated_at
before update on public.notifications
for each row execute function public.set_updated_at();

create or replace function public.is_pairing_member(p_pairing_id uuid, p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.pairings
    where id = p_pairing_id
      and status = 'active'
      and (user1_id = p_user_id or user2_id = p_user_id)
  );
$$;

grant execute on function public.is_pairing_member(uuid, uuid) to authenticated;

create or replace function public.mark_messages_as_read(
  p_pairing_id uuid,
  p_user_id uuid default auth.uid()
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_user_id is not null and p_user_id <> auth.uid() then
    raise exception 'You can only mark messages as read for yourself';
  end if;

  if not public.is_pairing_member(p_pairing_id, auth.uid()) then
    raise exception 'Not authorized for this pairing';
  end if;

  update public.messages
  set is_read = true,
      read_at = coalesce(read_at, now())
  where pairing_id = p_pairing_id
    and sender_id <> auth.uid()
    and is_read = false;
end;
$$;

grant execute on function public.mark_messages_as_read(uuid, uuid) to authenticated;

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

  if not public.is_pairing_member(p_pairing_id, auth.uid()) then
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

  if not public.is_pairing_member(p_pairing_id, auth.uid()) then
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

alter table public.profiles enable row level security;
alter table public.pairings enable row level security;
alter table public.messages enable row level security;
alter table public.message_reactions enable row level security;
alter table public.tasks enable row level security;
alter table public.calendar_events enable row level security;
alter table public.cycle_tracking enable row level security;
alter table public.budget_transactions enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Users can view their own profile" on public.profiles;
create policy "Users can view their own profile"
on public.profiles
for select
using (id = auth.uid());

drop policy if exists "Users can view paired profiles" on public.profiles;
create policy "Users can view paired profiles"
on public.profiles
for select
using (
  exists (
    select 1
    from public.pairings p
    where p.status = 'active'
      and (
        (p.user1_id = auth.uid() and p.user2_id = profiles.id)
        or
        (p.user2_id = auth.uid() and p.user1_id = profiles.id)
      )
  )
);

drop policy if exists "Users can insert own profile" on public.profiles;
create policy "Users can insert own profile"
on public.profiles
for insert
with check (id = auth.uid());

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile"
on public.profiles
for update
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "Users can delete own profile" on public.profiles;
create policy "Users can delete own profile"
on public.profiles
for delete
using (id = auth.uid());

drop policy if exists "Users can create pairings" on public.pairings;
create policy "Users can create pairings"
on public.pairings
for insert
with check (user1_id = auth.uid());

drop policy if exists "Users can view their pairings" on public.pairings;
create policy "Users can view their pairings"
on public.pairings
for select
using (user1_id = auth.uid() or user2_id = auth.uid());

drop policy if exists "Users can view pending pairings" on public.pairings;
create policy "Users can view pending pairings"
on public.pairings
for select
using (status = 'pending');

drop policy if exists "Users can join pending pairings" on public.pairings;
create policy "Users can join pending pairings"
on public.pairings
for update
using (status = 'pending' and user2_id is null)
with check (
  user2_id = auth.uid()
  and status = 'active'
);

drop policy if exists "Pairing members can view messages" on public.messages;
create policy "Pairing members can view messages"
on public.messages
for select
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can send messages" on public.messages;
create policy "Pairing members can send messages"
on public.messages
for insert
with check (
  sender_id = auth.uid()
  and public.is_pairing_member(pairing_id, auth.uid())
);

drop policy if exists "Pairing members can update messages" on public.messages;
create policy "Pairing members can update messages"
on public.messages
for update
using (public.is_pairing_member(pairing_id, auth.uid()))
with check (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can delete messages" on public.messages;
create policy "Pairing members can delete messages"
on public.messages
for delete
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Users can view reactions on their pairing messages" on public.message_reactions;
create policy "Users can view reactions on their pairing messages"
on public.message_reactions
for select
using (
  exists (
    select 1
    from public.messages m
    where m.id = message_id
      and public.is_pairing_member(m.pairing_id, auth.uid())
  )
);

drop policy if exists "Users can manage their own reactions" on public.message_reactions;
create policy "Users can manage their own reactions"
on public.message_reactions
for insert
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.messages m
    where m.id = message_id
      and public.is_pairing_member(m.pairing_id, auth.uid())
  )
);

drop policy if exists "Users can delete their own reactions" on public.message_reactions;
create policy "Users can delete their own reactions"
on public.message_reactions
for delete
using (user_id = auth.uid());

drop policy if exists "Pairing members can view tasks" on public.tasks;
create policy "Pairing members can view tasks"
on public.tasks
for select
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can insert tasks" on public.tasks;
create policy "Pairing members can insert tasks"
on public.tasks
for insert
with check (
  created_by = auth.uid()
  and public.is_pairing_member(pairing_id, auth.uid())
);

drop policy if exists "Pairing members can update tasks" on public.tasks;
create policy "Pairing members can update tasks"
on public.tasks
for update
using (public.is_pairing_member(pairing_id, auth.uid()))
with check (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can delete tasks" on public.tasks;
create policy "Pairing members can delete tasks"
on public.tasks
for delete
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can view calendar events" on public.calendar_events;
create policy "Pairing members can view calendar events"
on public.calendar_events
for select
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can insert calendar events" on public.calendar_events;
create policy "Pairing members can insert calendar events"
on public.calendar_events
for insert
with check (
  created_by = auth.uid()
  and public.is_pairing_member(pairing_id, auth.uid())
);

drop policy if exists "Pairing members can update calendar events" on public.calendar_events;
create policy "Pairing members can update calendar events"
on public.calendar_events
for update
using (public.is_pairing_member(pairing_id, auth.uid()))
with check (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Pairing members can delete calendar events" on public.calendar_events;
create policy "Pairing members can delete calendar events"
on public.calendar_events
for delete
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Users can view their own cycle data" on public.cycle_tracking;
create policy "Users can view their own cycle data"
on public.cycle_tracking
for select
using (
  user_id = auth.uid()
  or (pairing_id is not null and public.is_pairing_member(pairing_id, auth.uid()))
);

drop policy if exists "Users can insert their own cycle data" on public.cycle_tracking;
create policy "Users can insert their own cycle data"
on public.cycle_tracking
for insert
with check (
  user_id = auth.uid()
  and (
    pairing_id is null
    or public.is_pairing_member(pairing_id, auth.uid())
  )
);

drop policy if exists "Users can update their own cycle data" on public.cycle_tracking;
create policy "Users can update their own cycle data"
on public.cycle_tracking
for update
using (
  user_id = auth.uid()
  or (pairing_id is not null and public.is_pairing_member(pairing_id, auth.uid()))
)
with check (
  user_id = auth.uid()
  or (pairing_id is not null and public.is_pairing_member(pairing_id, auth.uid()))
);

drop policy if exists "Users can delete their own cycle data" on public.cycle_tracking;
create policy "Users can delete their own cycle data"
on public.cycle_tracking
for delete
using (
  user_id = auth.uid()
  or (pairing_id is not null and public.is_pairing_member(pairing_id, auth.uid()))
);

drop policy if exists "Users can update shared cycle data in pairings" on public.cycle_tracking;
drop policy if exists "Users can delete shared cycle data in pairings" on public.cycle_tracking;

drop policy if exists "Users can insert their own budget entries" on public.budget_transactions;
drop policy if exists "Users can add budget entries to their pairing" on public.budget_transactions;
drop policy if exists "budget_transactions_insert" on public.budget_transactions;
drop policy if exists "Pairing members can insert budget entries" on public.budget_transactions;
create policy "Pairing members can insert budget entries"
on public.budget_transactions
for insert
with check (
  created_by = auth.uid()
  and public.is_pairing_member(pairing_id, auth.uid())
  and (
    paid_by is null
    or paid_by = auth.uid()
    or exists (
      select 1
      from public.pairings p
      where p.id = budget_transactions.pairing_id
        and p.status = 'active'
        and (
          (p.user1_id = auth.uid() and p.user2_id = budget_transactions.paid_by)
          or
          (p.user2_id = auth.uid() and p.user1_id = budget_transactions.paid_by)
        )
    )
  )
);

drop policy if exists "Users can view budget entries in their pairing" on public.budget_transactions;
create policy "Users can view budget entries in their pairing"
on public.budget_transactions
for select
using (public.is_pairing_member(pairing_id, auth.uid()));

drop policy if exists "Users can update their own budget entries" on public.budget_transactions;
create policy "Users can update their own budget entries"
on public.budget_transactions
for update
using (created_by = auth.uid())
with check (created_by = auth.uid());

drop policy if exists "Users can delete their own budget entries" on public.budget_transactions;
create policy "Users can delete their own budget entries"
on public.budget_transactions
for delete
using (created_by = auth.uid());

drop policy if exists "Users can view their notifications" on public.notifications;
create policy "Users can view their notifications"
on public.notifications
for select
using (user_id = auth.uid());

drop policy if exists "Users can update their notifications" on public.notifications;
create policy "Users can update their notifications"
on public.notifications
for update
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Users can delete their notifications" on public.notifications;
create policy "Users can delete their notifications"
on public.notifications
for delete
using (user_id = auth.uid());

drop policy if exists "Users can insert their notifications" on public.notifications;
create policy "Users can insert their notifications"
on public.notifications
for insert
with check (user_id = auth.uid());

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'pairings'
  ) then
    alter publication supabase_realtime add table public.pairings;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'message_reactions'
  ) then
    alter publication supabase_realtime add table public.message_reactions;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'tasks'
  ) then
    alter publication supabase_realtime add table public.tasks;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'calendar_events'
  ) then
    alter publication supabase_realtime add table public.calendar_events;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'cycle_tracking'
  ) then
    alter publication supabase_realtime add table public.cycle_tracking;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'budget_transactions'
  ) then
    alter publication supabase_realtime add table public.budget_transactions;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('messages', 'messages', true)
on conflict (id) do update set public = excluded.public;

insert into storage.buckets (id, name, public)
values ('memories', 'memories', true)
on conflict (id) do update set public = excluded.public;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow public read access to avatars'
  ) then
    create policy "Allow public read access to avatars"
    on storage.objects
    for select
    using (bucket_id = 'avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated uploads to avatars'
  ) then
    create policy "Allow authenticated uploads to avatars"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated updates to avatars'
  ) then
    create policy "Allow authenticated updates to avatars"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated deletes to avatars'
  ) then
    create policy "Allow authenticated deletes to avatars"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'avatars');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow public read access to messages'
  ) then
    create policy "Allow public read access to messages"
    on storage.objects
    for select
    using (bucket_id = 'messages');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated uploads to messages'
  ) then
    create policy "Allow authenticated uploads to messages"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'messages');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated updates to messages'
  ) then
    create policy "Allow authenticated updates to messages"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'messages');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated deletes to messages'
  ) then
    create policy "Allow authenticated deletes to messages"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'messages');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow public read access to memories'
  ) then
    create policy "Allow public read access to memories"
    on storage.objects
    for select
    using (bucket_id = 'memories');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated uploads to memories'
  ) then
    create policy "Allow authenticated uploads to memories"
    on storage.objects
    for insert
    to authenticated
    with check (bucket_id = 'memories');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated updates to memories'
  ) then
    create policy "Allow authenticated updates to memories"
    on storage.objects
    for update
    to authenticated
    using (bucket_id = 'memories');
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Allow authenticated deletes to memories'
  ) then
    create policy "Allow authenticated deletes to memories"
    on storage.objects
    for delete
    to authenticated
    using (bucket_id = 'memories');
  end if;
end
$$;
