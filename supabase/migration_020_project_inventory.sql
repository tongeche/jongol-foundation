-- Migration 020: Project products and stock ledger (scalable across projects)

create extension if not exists pgcrypto;

-- Product catalog per project
create table if not exists project_products (
  id uuid primary key default gen_random_uuid(),
  project_id integer not null references iga_projects(id) on delete cascade,
  sku text,
  name text not null,
  category text,
  tracking_mode text not null default 'bulk' check (tracking_mode in ('bulk', 'individual')),
  unit text not null default 'units',
  unit_size numeric(10,3),
  reorder_level numeric(12,2) default 0 check (reorder_level >= 0),
  is_active boolean default true,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_project_products_project_name unique (project_id, name)
);

create unique index if not exists idx_project_products_project_sku
  on project_products(project_id, sku);
create index if not exists idx_project_products_project on project_products(project_id);
create index if not exists idx_project_products_project_category
  on project_products(project_id, category);
create index if not exists idx_project_products_project_active
  on project_products(project_id, is_active);

-- Link sales to product catalog (optional, keeps product_type for legacy)
alter table project_sales
  add column if not exists product_id uuid references project_products(id) on delete set null;
create index if not exists idx_project_sales_project_product
  on project_sales(project_id, product_id);

-- Stock movements ledger (use direction + quantity for balance calculations)
create table if not exists project_stock_movements (
  id uuid primary key default gen_random_uuid(),
  project_id integer not null references iga_projects(id) on delete cascade,
  product_id uuid not null references project_products(id) on delete cascade,
  batch_id uuid,
  movement_date date not null default current_date,
  movement_type text not null check (
    movement_type in (
      'opening',
      'purchase',
      'production',
      'sale',
      'consumption',
      'adjustment',
      'transfer_in',
      'transfer_out',
      'waste',
      'return'
    )
  ),
  direction text not null check (direction in ('in', 'out')),
  quantity numeric(12,2) not null check (quantity >= 0),
  unit_cost numeric(12,2) default 0 check (unit_cost >= 0),
  total_cost numeric(12,2) generated always as (quantity * unit_cost) stored,
  sale_id uuid references project_sales(id) on delete set null,
  expense_id uuid references project_expenses(id) on delete set null,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists idx_project_stock_movements_project_date
  on project_stock_movements(project_id, movement_date);
create index if not exists idx_project_stock_movements_product_date
  on project_stock_movements(product_id, movement_date);
create index if not exists idx_project_stock_movements_project_batch
  on project_stock_movements(project_id, batch_id);
create index if not exists idx_project_stock_movements_sale
  on project_stock_movements(sale_id);
create index if not exists idx_project_stock_movements_expense
  on project_stock_movements(expense_id);

-- Current stock balance per product
create or replace view project_stock_balances as
select
  p.project_id,
  p.id as product_id,
  p.name,
  p.category,
  p.tracking_mode,
  p.unit,
  p.reorder_level,
  p.is_active,
  coalesce(sum(case when m.direction = 'in' then m.quantity else -m.quantity end), 0) as quantity_on_hand,
  max(m.movement_date) as last_movement_date
from project_products p
left join project_stock_movements m on m.product_id = p.id
group by
  p.project_id,
  p.id,
  p.name,
  p.category,
  p.tracking_mode,
  p.unit,
  p.reorder_level,
  p.is_active;

alter table project_products enable row level security;
alter table project_stock_movements enable row level security;

-- Access policies based on membership or leadership (same model as project_sales/expenses)
drop policy if exists "Authenticated can view project products" on project_products;
create policy "Authenticated can view project products"
  on project_products
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
            where icm.project_id = project_products.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_products.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can manage project products" on project_products;
create policy "Authenticated can manage project products"
  on project_products
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
            where icm.project_id = project_products.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_products.project_id
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
            where icm.project_id = project_products.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_products.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can view project stock movements" on project_stock_movements;
create policy "Authenticated can view project stock movements"
  on project_stock_movements
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
            where icm.project_id = project_stock_movements.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_stock_movements.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can manage project stock movements" on project_stock_movements;
create policy "Authenticated can manage project stock movements"
  on project_stock_movements
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
            where icm.project_id = project_stock_movements.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_stock_movements.project_id
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
            where icm.project_id = project_stock_movements.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = project_stock_movements.project_id
              and p.project_leader = m.id
          )
        )
    )
  );
