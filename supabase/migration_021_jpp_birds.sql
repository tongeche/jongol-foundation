-- Migration 021: JPP birds (individual product tracking)

create extension if not exists pgcrypto;

create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create or replace function trg_jpp_birds_autoname()
returns trigger as $$
begin
  if new.bird_name is null or btrim(new.bird_name) = '' then
    if new.tag_id is not null and btrim(new.tag_id) <> '' then
      new.bird_name := new.tag_id;
    else
      new.bird_name := 'JPP-' || to_char(current_date, 'YYYYMMDD') || '-' ||
        substring(gen_random_uuid()::text, 1, 4);
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

create table if not exists jpp_birds (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references project_products(id) on delete restrict,
  batch_id uuid references jpp_batches(id) on delete set null,
  tag_id text unique,
  sex text not null default 'unknown',
  breed_label text not null default 'unknown',
  hatch_date date,
  acquired_date date not null,
  acquired_source text not null default 'bought',
  status text not null default 'alive',
  status_date date not null default current_date,
  sale_id uuid references project_sales(id) on delete set null,
  photo_url text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  bird_name text,
  description text,
  color_label text,
  pattern_label text,
  age_stage text not null default 'unknown',
  constraint jpp_birds_age_stage_check
    check (age_stage in ('unknown', 'chick', 'pullet', 'cockerel', 'hen', 'rooster')),
  constraint jpp_birds_acquired_source_check
    check (acquired_source in ('bought', 'hatched', 'donated', 'transferred')),
  constraint jpp_birds_sex_check
    check (sex in ('unknown', 'male', 'female')),
  constraint jpp_birds_status_check
    check (status in ('alive', 'sold', 'culled', 'dead', 'missing')),
  constraint chk_dates_jpp_birds
    check (
      (hatch_date is null or hatch_date <= acquired_date)
      and status_date >= acquired_date
    )
);

create index if not exists idx_jpp_birds_product on jpp_birds(product_id);
create index if not exists idx_jpp_birds_batch on jpp_birds(batch_id);
create index if not exists idx_jpp_birds_status on jpp_birds(status);
create index if not exists idx_jpp_birds_sale on jpp_birds(sale_id);
create unique index if not exists uq_jpp_birds_product_bird_name
  on jpp_birds(product_id, bird_name)
  where bird_name is not null;

drop trigger if exists trg_jpp_birds_autoname on jpp_birds;
create trigger trg_jpp_birds_autoname
before insert on jpp_birds
for each row execute function trg_jpp_birds_autoname();

drop trigger if exists trg_jpp_birds_updated_at on jpp_birds;
create trigger trg_jpp_birds_updated_at
before update on jpp_birds
for each row execute function set_updated_at();

alter table jpp_birds enable row level security;

drop policy if exists "Authenticated can view JPP birds" on jpp_birds;
create policy "Authenticated can view JPP birds"
  on jpp_birds
  for select
  to authenticated
  using (
    exists (
      select 1
      from project_products pp
      join members m on m.auth_id = auth.uid()
      where pp.id = jpp_birds.product_id
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = pp.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = pp.project_id
              and p.project_leader = m.id
          )
        )
    )
  );

drop policy if exists "Authenticated can manage JPP birds" on jpp_birds;
create policy "Authenticated can manage JPP birds"
  on jpp_birds
  for all
  to authenticated
  using (
    exists (
      select 1
      from project_products pp
      join members m on m.auth_id = auth.uid()
      where pp.id = jpp_birds.product_id
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = pp.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = pp.project_id
              and p.project_leader = m.id
          )
        )
    )
  )
  with check (
    exists (
      select 1
      from project_products pp
      join members m on m.auth_id = auth.uid()
      where pp.id = jpp_birds.product_id
        and (
          m.role in ('admin', 'superadmin', 'project_manager')
          or exists (
            select 1 from iga_committee_members icm
            where icm.project_id = pp.project_id
              and icm.member_id = m.id
          )
          or exists (
            select 1 from iga_projects p
            where p.id = pp.project_id
              and p.project_leader = m.id
          )
        )
    )
  );
