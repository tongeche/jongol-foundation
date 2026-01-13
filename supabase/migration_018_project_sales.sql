-- Migration 018: Unified project sales table

create extension if not exists pgcrypto;

create table if not exists project_sales (
  id uuid primary key default gen_random_uuid(),
  project_id integer not null references iga_projects(id) on delete cascade,
  batch_id uuid,
  sale_date date not null default current_date,
  product_type text,
  quantity_units integer default 0 check (quantity_units >= 0),
  quantity_kg numeric(10,2) default 0 check (quantity_kg >= 0),
  unit_price numeric(10,2) default 0 check (unit_price >= 0),
  total_amount numeric(12,2) default 0 check (total_amount >= 0),
  customer_name text,
  customer_contact text,
  customer_type text,
  payment_status text default 'paid' check (payment_status in ('pending', 'partial', 'paid')),
  payment_method text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_project_sales_project_date on project_sales(project_id, sale_date);
create index if not exists idx_project_sales_project_batch on project_sales(project_id, batch_id);

alter table project_sales enable row level security;

-- Access policies based on membership or leadership

drop policy if exists "Authenticated can view project sales" on project_sales;
create policy "Authenticated can view project sales"
  on project_sales
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
            where icm.project_id = project_sales.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_sales.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can manage project sales" on project_sales;
create policy "Authenticated can manage project sales"
  on project_sales
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
            where icm.project_id = project_sales.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_sales.project_id
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
            where icm.project_id = project_sales.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_sales.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

-- Backfill JGF sales
insert into project_sales (
  project_id,
  batch_id,
  sale_date,
  product_type,
  quantity_units,
  quantity_kg,
  unit_price,
  total_amount,
  customer_name,
  customer_contact,
  customer_type,
  payment_status,
  payment_method,
  notes,
  created_by,
  created_at,
  updated_at
)
select
  p.id,
  s.batch_id,
  s.sale_date,
  s.product_type,
  s.quantity_units,
  s.quantity_kg,
  s.unit_price,
  s.total_amount,
  s.customer_name,
  s.customer_contact,
  s.customer_type,
  s.payment_status,
  s.payment_method,
  s.notes,
  s.created_by,
  s.created_at,
  coalesce(s.updated_at, s.created_at, now())
from jgf_sales s
join iga_projects p on p.code = 'JGF';

-- Update JGF KPI view to use project_sales
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
left join (
  select id from iga_projects where code = 'JGF'
) p on true
left join project_sales s on s.batch_id = b.id and s.project_id = p.id
left join project_expenses e on e.batch_id = b.id and e.project_id = p.id
group by b.id, b.batch_code, b.batch_name, b.product_type, b.status, b.start_date, 
         b.end_date, b.raw_groundnuts_kg, b.output_quantity_kg, b.output_units, 
         b.unit_size_grams, b.cost_raw_materials, b.cost_processing, 
         b.cost_packaging, b.cost_labour, b.selling_price_per_unit;
