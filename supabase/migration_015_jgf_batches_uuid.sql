-- Migration 015: Convert JGF batch IDs to UUID

create extension if not exists pgcrypto;

-- Add UUID column to batches and backfill
alter table jgf_batches add column if not exists id_uuid uuid;
update jgf_batches set id_uuid = gen_random_uuid() where id_uuid is null;

-- Add UUID columns to related tables and backfill
alter table jgf_production_logs add column if not exists batch_id_uuid uuid;
update jgf_production_logs l
set batch_id_uuid = b.id_uuid
from jgf_batches b
where l.batch_id = b.id
  and l.batch_id_uuid is null;

alter table jgf_sales add column if not exists batch_id_uuid uuid;
update jgf_sales s
set batch_id_uuid = b.id_uuid
from jgf_batches b
where s.batch_id = b.id
  and s.batch_id_uuid is null;

alter table jgf_expenses add column if not exists batch_id_uuid uuid;
update jgf_expenses e
set batch_id_uuid = b.id_uuid
from jgf_batches b
where e.batch_id = b.id
  and e.batch_id_uuid is null;

-- Drop dependent views before swapping batch_id columns
drop view if exists jgf_batch_kpis;

-- Drop old foreign keys
alter table jgf_production_logs drop constraint if exists jgf_production_logs_batch_id_fkey;
alter table jgf_sales drop constraint if exists jgf_sales_batch_id_fkey;
alter table jgf_expenses drop constraint if exists jgf_expenses_batch_id_fkey;

-- Swap batch id columns to UUID
alter table jgf_production_logs drop column if exists batch_id;
alter table jgf_production_logs rename column batch_id_uuid to batch_id;

alter table jgf_sales drop column if exists batch_id;
alter table jgf_sales rename column batch_id_uuid to batch_id;

alter table jgf_expenses drop column if exists batch_id;
alter table jgf_expenses rename column batch_id_uuid to batch_id;

-- Promote UUID column to primary key on batches
alter table jgf_batches drop constraint if exists jgf_batches_pkey;
alter table jgf_batches rename column id to legacy_id;
alter table jgf_batches rename column id_uuid to id;
alter table jgf_batches alter column id set default gen_random_uuid();
alter table jgf_batches alter column id set not null;
alter table jgf_batches add primary key (id);

-- Restore foreign keys
alter table jgf_production_logs
  add constraint jgf_production_logs_batch_id_fkey
  foreign key (batch_id) references jgf_batches(id) on delete cascade;

alter table jgf_sales
  add constraint jgf_sales_batch_id_fkey
  foreign key (batch_id) references jgf_batches(id) on delete set null;

alter table jgf_expenses
  add constraint jgf_expenses_batch_id_fkey
  foreign key (batch_id) references jgf_batches(id) on delete set null;

-- Recreate indexes on batch_id columns
create index if not exists idx_jgf_production_logs_batch on jgf_production_logs(batch_id);
create index if not exists idx_jgf_sales_batch on jgf_sales(batch_id);
create index if not exists idx_jgf_expenses_batch on jgf_expenses(batch_id);

-- Refresh KPI view to use UUID batch ids
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
left join jgf_expenses e on e.batch_id = b.id
group by b.id, b.batch_code, b.batch_name, b.product_type, b.status, b.start_date, 
         b.end_date, b.raw_groundnuts_kg, b.output_quantity_kg, b.output_units, 
         b.unit_size_grams, b.cost_raw_materials, b.cost_processing, 
         b.cost_packaging, b.cost_labour, b.selling_price_per_unit;
