alter table public.budget_transactions
add column if not exists paid_by uuid;

update public.budget_transactions
set paid_by = created_by
where paid_by is null;

create index if not exists budget_transactions_paid_by_idx
on public.budget_transactions (paid_by);
