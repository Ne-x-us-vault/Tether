-- ══════════════════════════════════════════════════════════════════════════════
-- Fix budget_transactions RLS — allow partner-payer entries
-- Problem: INSERT policy required paid_by = auth.uid(), blocking one partner
--          from logging an expense on behalf of the other.
-- Fix:     Allow any active-pairing member to insert. The only requirement is:
--            1. The inserting user (created_by) is in the pairing.
--            2. paid_by is also a member of the SAME pairing (or null).
-- ══════════════════════════════════════════════════════════════════════════════

-- ── Drop the old, restrictive INSERT policy ──────────────────────────────────
drop policy if exists "Users can insert their own budget entries"     on public.budget_transactions;
drop policy if exists "Users can add budget entries to their pairing" on public.budget_transactions;
drop policy if exists "budget_transactions_insert"                    on public.budget_transactions;

-- ── Create the new INSERT policy ─────────────────────────────────────────────
-- The inserting user must be an active member of the target pairing.
-- paid_by can be either member of the pairing (self or partner).
create policy "Pairing members can insert budget entries"
  on public.budget_transactions
  for insert
  with check (
    -- The row creator must be the authenticated user
    created_by = auth.uid()
    and
    -- The pairing must be active and include this user
    pairing_id in (
      select id
      from public.pairings
      where status = 'active'
        and (user1_id = auth.uid() or user2_id = auth.uid())
    )
    and
    -- paid_by must be one of the two pairing members (prevents spoofing)
    (
      paid_by is null
      or paid_by = auth.uid()
      or paid_by in (
        select case
          when user1_id = auth.uid() then user2_id
          else user1_id
        end
        from public.pairings
        where id = pairing_id
          and status = 'active'
          and (user1_id = auth.uid() or user2_id = auth.uid())
      )
    )
  );

-- ── Ensure SELECT, UPDATE, DELETE policies also exist ────────────────────────
-- (These are idempotent — safe to re-run if they already exist)

drop policy if exists "Users can view budget entries in their pairing"   on public.budget_transactions;
create policy "Users can view budget entries in their pairing"
  on public.budget_transactions
  for select
  using (
    pairing_id in (
      select id from public.pairings
      where status = 'active'
        and (user1_id = auth.uid() or user2_id = auth.uid())
    )
  );

drop policy if exists "Users can delete their own budget entries" on public.budget_transactions;
create policy "Users can delete their own budget entries"
  on public.budget_transactions
  for delete
  using (created_by = auth.uid());

drop policy if exists "Users can update their own budget entries" on public.budget_transactions;
create policy "Users can update their own budget entries"
  on public.budget_transactions
  for update
  using (created_by = auth.uid())
  with check (created_by = auth.uid());
