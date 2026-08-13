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
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'pairings'
      and policyname = 'Users can view pending pairings'
  ) then
    create policy "Users can view pending pairings" on public.pairings
      for select
      using (status = 'pending');
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'pairings'
      and policyname = 'Users can join pending pairings'
  ) then
    create policy "Users can join pending pairings" on public.pairings
      for update
      using (status = 'pending' and user2_id is null)
      with check (
        user2_id = auth.uid()
        and status = 'active'
      );
  end if;
end
$$;

drop policy if exists "Users can update shared cycle data in pairings" on public.cycle_tracking;
create policy "Users can update shared cycle data in pairings" on public.cycle_tracking
  for update
  using (
    pairing_id in (
      select id
      from public.pairings
      where status = 'active'
        and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  )
  with check (
    pairing_id in (
      select id
      from public.pairings
      where status = 'active'
        and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );

drop policy if exists "Users can delete shared cycle data in pairings" on public.cycle_tracking;
create policy "Users can delete shared cycle data in pairings" on public.cycle_tracking
  for delete
  using (
    pairing_id in (
      select id
      from public.pairings
      where status = 'active'
        and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );
