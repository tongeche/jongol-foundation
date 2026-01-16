-- Migration 022: Allocate batch daily/weekly logs down to individual birds

create or replace view v_jpp_bird_daily_allocations as
with eligible_birds as (
  select
    d.id as log_id,
    d.batch_id,
    d.log_date,
    d.feed_used_kg,
    d.water_refills,
    d.eggs_collected,
    d.money_spent,
    d.alive_count,
    b.id as bird_id
  from jpp_daily_log d
  join jpp_birds b
    on b.batch_id = d.batch_id
  where b.acquired_date <= d.log_date
    and (
      b.status not in ('sold', 'dead', 'culled', 'missing')
      or b.status_date > d.log_date
    )
),
counts as (
  select log_id, count(*) as bird_count
  from eligible_birds
  group by log_id
)
select
  e.log_id,
  e.batch_id,
  e.log_date,
  e.bird_id,
  coalesce(e.alive_count, c.bird_count) as alive_count,
  c.bird_count,
  case
    when coalesce(e.alive_count, c.bird_count, 0) > 0
      then e.feed_used_kg / coalesce(nullif(e.alive_count, 0), c.bird_count)
    else 0
  end as feed_per_bird_kg,
  case
    when coalesce(e.alive_count, c.bird_count, 0) > 0
      then e.water_refills::numeric / coalesce(nullif(e.alive_count, 0), c.bird_count)
    else 0
  end as water_refills_per_bird,
  case
    when coalesce(e.alive_count, c.bird_count, 0) > 0
      then e.eggs_collected::numeric / coalesce(nullif(e.alive_count, 0), c.bird_count)
    else 0
  end as eggs_per_bird,
  case
    when coalesce(e.alive_count, c.bird_count, 0) > 0
      then e.money_spent / coalesce(nullif(e.alive_count, 0), c.bird_count)
    else 0
  end as spend_per_bird
from eligible_birds e
join counts c on c.log_id = e.log_id;

create or replace view v_jpp_bird_weekly_allocations as
with weekly as (
  select
    w.id as weekly_id,
    w.batch_id,
    w.week_ending,
    w.feed_used_week_kg,
    w.birds_sold,
    w.birds_culled
  from jpp_weekly_growth w
),
eligible_birds as (
  select
    w.weekly_id,
    w.batch_id,
    w.week_ending,
    w.feed_used_week_kg,
    w.birds_sold,
    w.birds_culled,
    b.id as bird_id
  from weekly w
  join jpp_birds b
    on b.batch_id = w.batch_id
  where b.acquired_date <= w.week_ending
    and (
      b.status not in ('sold', 'dead', 'culled', 'missing')
      or b.status_date > w.week_ending
    )
),
counts as (
  select weekly_id, count(*) as bird_count
  from eligible_birds
  group by weekly_id
)
select
  e.weekly_id,
  e.batch_id,
  e.week_ending,
  e.bird_id,
  c.bird_count,
  case when c.bird_count > 0 then e.feed_used_week_kg / c.bird_count else 0 end
    as feed_per_bird_week_kg,
  case when c.bird_count > 0 then e.birds_sold::numeric / c.bird_count else 0 end
    as birds_sold_per_bird,
  case when c.bird_count > 0 then e.birds_culled::numeric / c.bird_count else 0 end
    as birds_culled_per_bird
from eligible_birds e
join counts c on c.weekly_id = e.weekly_id;
