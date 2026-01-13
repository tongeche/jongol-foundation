-- Migration 016: Unified project expenses table

create extension if not exists pgcrypto;

create table if not exists project_expenses (
  id uuid primary key default gen_random_uuid(),
  project_id integer not null references iga_projects(id) on delete cascade,
  batch_id uuid,
  expense_date date not null default current_date,
  category text not null,
  amount numeric(12,2) not null check (amount >= 0),
  vendor text,
  description text,
  receipt boolean default false,
  approved_by uuid references auth.users(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_project_expenses_project_date on project_expenses(project_id, expense_date);
create index if not exists idx_project_expenses_project_batch on project_expenses(project_id, batch_id);

alter table project_expenses enable row level security;

-- Access policies based on membership or leadership

drop policy if exists "Authenticated can view project expenses" on project_expenses;
create policy "Authenticated can view project expenses"
  on project_expenses
  for select
  to authenticated
  using (
    exists (
      select 1
      from members m
      where m.auth_id = auth.uid()
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = project_expenses.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_expenses.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can manage project expenses" on project_expenses;
create policy "Authenticated can manage project expenses"
  on project_expenses
  for all
  to authenticated
  using (
    exists (
      select 1
      from members m
      where m.auth_id = auth.uid()
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = project_expenses.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_expenses.project_id
              and p.project_leader = m.id
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from members m
      where m.auth_id = auth.uid()
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = project_expenses.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_expenses.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

-- Backfill JPP expenses
insert into project_expenses (
  project_id,
  batch_id,
  expense_date,
  category,
  amount,
  vendor,
  description,
  receipt,
  created_at,
  updated_at
)
select
  p.id,
  e.batch_id,
  e.expense_date,
  e.category,
  e.amount,
  e.vendor,
  e.description,
  e.receipt,
  e.created_at,
  coalesce(e.created_at, now())
from jpp_expenses e
join iga_projects p on p.code = 'JPP';

-- Backfill JGF expenses
insert into project_expenses (
  project_id,
  batch_id,
  expense_date,
  category,
  amount,
  vendor,
  description,
  receipt,
  approved_by,
  created_by,
  created_at,
  updated_at
)
select
  p.id,
  e.batch_id,
  e.expense_date,
  e.category,
  e.amount,
  e.vendor,
  e.description,
  e.receipt_available,
  e.approved_by,
  e.created_by,
  e.created_at,
  coalesce(e.updated_at, e.created_at, now())
from jgf_expenses e
join iga_projects p on p.code = 'JGF';

-- Seed default expense items for JGF
insert into project_expense_items (project_id, label, category, display_order)
select p.id, t.label, t.category, t.ord
from iga_projects p
join lateral (
  select *
  from unnest(
    array[
      'Raw materials',
      'Packaging',
      'Labour',
      'Equipment',
      'Transport',
      'Utilities',
      'Marketing',
      'Other'
    ],
    array[
      'Raw Materials',
      'Packaging',
      'Labour',
      'Equipment',
      'Transport',
      'Utilities',
      'Marketing',
      'Other'
    ]
  ) with ordinality as t(label, category, ord)
) t on true
where p.code = 'JGF'
on conflict (project_id, label) do nothing;

-- Update JPP export view to use project_expenses
create or replace view v_jpp_expenses_export as
select
  coalesce(b.batch_code, 'UNASSIGNED') as batch_code,
  e.expense_date,
  e.category,
  e.amount,
  e.vendor,
  e.description,
  e.receipt
from project_expenses e
join iga_projects p on p.id = e.project_id and p.code = 'JPP'
left join jpp_batches b on b.id = e.batch_id
order by e.expense_date, batch_code;

-- Update JPP KPI view to use project_expenses
create or replace view v_jpp_batch_kpis as
with deaths as (
  select batch_id, coalesce(sum(deaths_today),0) as total_deaths
  from jpp_daily_log
  group by batch_id
),
feed as (
  select batch_id, coalesce(sum(feed_used_kg),0) as total_feed_kg
  from jpp_daily_log
  group by batch_id
),
spend_daily as (
  select batch_id, coalesce(sum(money_spent),0) as daily_spend
  from jpp_daily_log
  group by batch_id
),
spend_expenses as (
  select e.batch_id, coalesce(sum(e.amount),0) as expense_spend
  from project_expenses e
  join iga_projects p on p.id = e.project_id and p.code = 'JPP'
  group by e.batch_id
)
select
  b.batch_code,
  b.batch_name,
  b.start_date,
  b.starting_count,
  coalesce(d.total_deaths,0) as total_deaths,
  (b.starting_count - coalesce(d.total_deaths,0)) as estimated_alive_now,
  round(
    case when b.starting_count = 0 then 0
         else (coalesce(d.total_deaths,0)::numeric / b.starting_count::numeric) * 100 end
  , 2) as mortality_pct,
  coalesce(f.total_feed_kg,0) as total_feed_kg,
  (b.cost_birds + b.cost_transport + b.cost_initial_meds
    + coalesce(sd.daily_spend,0) + coalesce(se.expense_spend,0)
  ) as total_spend
from jpp_batches b
left join deaths d on d.batch_id = b.id
left join feed f on f.batch_id = b.id
left join spend_daily sd on sd.batch_id = b.id
left join spend_expenses se on se.batch_id = b.id;

-- Update JGF KPI view to use project_expenses
create or replace view jgf_batch_kpis as
select 
    b.id,
    b.batch_code,
    b.batch_name,
    b.product_type,
    b.status,
    b.start_date,
    b.end_date,
    b.raw_groundnuts_kg,
    b.output_quantity_kg,
    b.output_units,
    b.unit_size_grams,
    coalesce(b.cost_raw_materials, 0) + coalesce(b.cost_processing, 0) +
        coalesce(b.cost_packaging, 0) + coalesce(b.cost_labour, 0) as total_batch_cost,
    b.selling_price_per_unit,
    coalesce(sum(s.total_amount), 0) as total_revenue,
    coalesce(sum(s.quantity_units), 0) as units_sold,
    b.output_units - coalesce(sum(s.quantity_units), 0) as units_remaining,
    case 
        when b.raw_groundnuts_kg > 0 then 
            round((b.output_quantity_kg / b.raw_groundnuts_kg * 100)::numeric, 1)
        else 0 
    end as yield_percentage,
    coalesce(sum(e.amount), 0) as total_expenses
from jgf_batches b
left join jgf_sales s on s.batch_id = b.id
left join (
  select id from iga_projects where code = 'JGF'
) p on true
left join project_expenses e on e.batch_id = b.id and e.project_id = p.id
group by b.id, b.batch_code, b.batch_name, b.product_type, b.status, b.start_date, 
         b.end_date, b.raw_groundnuts_kg, b.output_quantity_kg, b.output_units, 
         b.unit_size_grams, b.cost_raw_materials, b.cost_processing, 
         b.cost_packaging, b.cost_labour, b.selling_price_per_unit;
