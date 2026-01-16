-- Migration 023: Latest per-bird allocations for cards

create or replace view v_jpp_bird_daily_allocations_latest as
select distinct on (bird_id)
  *
from v_jpp_bird_daily_allocations
order by bird_id, log_date desc;

create or replace view v_jpp_bird_weekly_allocations_latest as
select distinct on (bird_id)
  *
from v_jpp_bird_weekly_allocations
order by bird_id, week_ending desc;

create or replace view v_jpp_bird_cards as
select
  b.*,
  d.log_date as last_log_date,
  d.feed_per_bird_kg,
  d.water_refills_per_bird,
  d.eggs_per_bird,
  d.spend_per_bird,
  d.bird_count as daily_bird_count,
  d.alive_count as daily_alive_count,
  w.week_ending as last_week_ending,
  w.feed_per_bird_week_kg,
  w.birds_sold_per_bird,
  w.birds_culled_per_bird,
  w.bird_count as weekly_bird_count
from jpp_birds b
left join v_jpp_bird_daily_allocations_latest d on d.bird_id = b.id
left join v_jpp_bird_weekly_allocations_latest w on w.bird_id = b.id;
