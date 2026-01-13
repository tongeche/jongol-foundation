
create extension if not exists pgcrypto;

-- 1) BATCH SETUP (one row per batch/pen)
create table if not exists jpp_batches (
  id uuid primary key default gen_random_uuid(),
  batch_code text not null unique,                -- e.g. 'JPP-2026-01-A'
  batch_name text,                                -- e.g. 'Brooder A' / 'Grower Pen 1'
  start_date date not null,
  supplier_name text,
  supplier_contact text,
  bird_type text,                                 -- e.g. 'Broiler', 'Layer', 'Kienyeji'
  breed text,
  starting_count integer not null check (starting_count >= 0),
  avg_start_weight_kg numeric(6,3),               -- optional
  cost_birds numeric(12,2) default 0,
  cost_transport numeric(12,2) default 0,
  cost_initial_meds numeric(12,2) default 0,
  feed_on_hand_kg numeric(10,2) default 0,
  notes text,
  created_at timestamptz not null default now()
);

create index if not exists idx_jpp_batches_start_date on jpp_batches(start_date);


-- 2) DAILY LOG (one row per day per batch)
create table if not exists jpp_daily_log (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references jpp_batches(id) on delete cascade,
  log_date date not null,

  -- tick checklist
  water_clean_full_am boolean default false,
  feed_given_am boolean default false,
  feed_given_pm boolean default false,
  droppings_normal boolean default true,
  temp_vent_ok boolean default true,
  cleaned_drinkers boolean default false,
  cleaned_feeders boolean default false,
  predator_check_done boolean default false,

  -- numbers
  alive_count integer check (alive_count >= 0),
  deaths_today integer default 0 check (deaths_today >= 0),
  death_cause_code text,                          -- U/C/D/P/I/S (optional)
  feed_used_kg numeric(10,2) default 0 check (feed_used_kg >= 0),
  water_refills integer default 0 check (water_refills >= 0),
  eggs_collected integer default 0 check (eggs_collected >= 0),
  money_spent numeric(12,2) default 0 check (money_spent >= 0),
  notes text,

  created_at timestamptz not null default now(),

  constraint uq_jpp_daily_log unique (batch_id, log_date),
  constraint chk_death_cause_code
    check (death_cause_code is null or death_cause_code in ('U','C','D','P','I','S'))
);

create index if not exists idx_jpp_daily_log_batch_date on jpp_daily_log(batch_id, log_date);


-- 3) WEEKLY GROWTH (one row per week per batch)
create table if not exists jpp_weekly_growth (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid not null references jpp_batches(id) on delete cascade,
  week_ending date not null,                      -- pick a consistent day (e.g., Sunday)

  sample_size integer default 0 check (sample_size >= 0),
  avg_weight_kg numeric(6,3),                     -- if you have a scale
  min_weight_kg numeric(6,3),
  max_weight_kg numeric(6,3),

  body_score_avg numeric(4,2),                    -- 1–5 if no scale
  feed_used_week_kg numeric(10,2) default 0 check (feed_used_week_kg >= 0),
  meds_given text,                                -- quick notes
  birds_sold integer default 0 check (birds_sold >= 0),
  birds_culled integer default 0 check (birds_culled >= 0),
  notes text,

  created_at timestamptz not null default now(),

  constraint uq_jpp_weekly_growth unique (batch_id, week_ending)
);

create index if not exists idx_jpp_weekly_growth_batch_week on jpp_weekly_growth(batch_id, week_ending);


-- 4) EXPENSES (every spend is one row)
create table if not exists jpp_expenses (
  id uuid primary key default gen_random_uuid(),
  batch_id uuid references jpp_batches(id) on delete set null,
  expense_date date not null,

  category text not null,                         -- Feed/Meds/Bedding/Labour/Repairs/Transport/Utilities/Other
  amount numeric(12,2) not null check (amount >= 0),
  vendor text,
  description text,
  receipt boolean default false,

  created_at timestamptz not null default now(),

  constraint chk_expense_category
    check (category in ('Feed','Meds','Bedding','Labour','Repairs','Transport','Utilities','Other'))
);

create index if not exists idx_jpp_expenses_date on jpp_expenses(expense_date);
create index if not exists idx_jpp_expenses_batch_date on jpp_expenses(batch_id, expense_date);


-- OPTIONAL: Simple “export views” (nice for Google Sheets)
create or replace view v_jpp_daily_export as
select
  b.batch_code,
  b.batch_name,
  d.log_date,

  d.water_clean_full_am,
  d.feed_given_am,
  d.feed_given_pm,
  d.droppings_normal,
  d.temp_vent_ok,
  d.cleaned_drinkers,
  d.cleaned_feeders,
  d.predator_check_done,

  d.alive_count,
  d.deaths_today,
  d.death_cause_code,
  d.feed_used_kg,
  d.water_refills,
  d.eggs_collected,
  d.money_spent,
  d.notes
from jpp_daily_log d
join jpp_batches b on b.id = d.batch_id
order by b.batch_code, d.log_date;

create or replace view v_jpp_weekly_export as
select
  b.batch_code,
  b.batch_name,
  w.week_ending,
  w.sample_size,
  w.avg_weight_kg,
  w.min_weight_kg,
  w.max_weight_kg,
  w.body_score_avg,
  w.feed_used_week_kg,
  w.meds_given,
  w.birds_sold,
  w.birds_culled,
  w.notes
from jpp_weekly_growth w
join jpp_batches b on b.id = w.batch_id
order by b.batch_code, w.week_ending;

create or replace view v_jpp_expenses_export as
select
  coalesce(b.batch_code, 'UNASSIGNED') as batch_code,
  e.expense_date,
  e.category,
  e.amount,
  e.vendor,
  e.description,
  e.receipt
from jpp_expenses e
left join jpp_batches b on b.id = e.batch_id
order by e.expense_date, batch_code;


-- OPTIONAL: quick KPI rollup per batch (handy)
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
  select batch_id, coalesce(sum(amount),0) as expense_spend
  from jpp_expenses
  group by batch_id
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