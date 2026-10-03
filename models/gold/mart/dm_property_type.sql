{{
    config(
        materialized='view',
        alias='dm_property_type'
    )
}}

-- Datamart dm_property_type: one row per property_type, room_type,
-- accommodates and month/year, ordered by these columns.
-- (brief Part 2 step 2, design decisions G1, G4, D5, Lab 6.3 pattern)
-- 1. property_type, room_type and accommodates come from dim_listing with
--    the SCD2 join (valid_from <= scraped_date < valid_to), so each
--    row uses the listing version that was valid on that date.
--    property_type uses the new names for all months (D5).
-- 2. Superhost status comes from dim_host with the same SCD2 join.
-- 3. Metric definitions are the same as dm_listing_neighbourhood:
--    active listing = has_availability 't' (is_active = 1);
--    active listings rate = active / total * 100;
--    price, review score, stays and revenue use active listings only;
--    superhost rate = distinct superhosts / distinct hosts * 100;
--    stays = 30 - availability_30; revenue = stays * price;
--    total stays is 0 (not NULL) when a group has no active listing;
--    average revenue per active listing = total revenue / active listings;
--    % change = (this month - previous month) / previous month * 100,
--    NULL when the previous row is not exactly one month earlier or the
--    previous value is 0 (NULLIF on every divisor).

with

facts as (
    select
        coalesce(d.property_type, 'Unknown') as property_type,
        coalesce(d.room_type, 'Unknown') as room_type,
        d.accommodates,
        f.listing_month as month_year,
        f.host_id,
        h.host_is_superhost,
        f.is_active,
        f.price,
        f.review_scores_rating,
        case when f.is_active = 1 then 30 - f.availability_30 end as stays
    from {{ ref('g_fact_listings') }} f
    left join {{ ref('g_dim_listing') }} d
        on f.listing_id = d.listing_id
       and f.scraped_date::timestamp >= d.valid_from
       and f.scraped_date::timestamp < coalesce(d.valid_to, '9999-12-31'::timestamp)
    left join {{ ref('g_dim_host') }} h
        on f.host_id = h.host_id
       and f.scraped_date::timestamp >= h.valid_from
       and f.scraped_date::timestamp < coalesce(h.valid_to, '9999-12-31'::timestamp)
),

monthly as (
    select
        property_type,
        room_type,
        accommodates,
        month_year,
        count(*) as total_listings,
        count(*) filter (where is_active = 1) as active_listings,
        count(*) filter (where is_active = 0) as inactive_listings,
        min(price) filter (where is_active = 1) as min_price,
        max(price) filter (where is_active = 1) as max_price,
        percentile_cont(0.5) within group (order by price)
            filter (where is_active = 1) as median_price,
        avg(price) filter (where is_active = 1) as avg_price,
        count(distinct host_id) as distinct_hosts,
        count(distinct host_id) filter (where host_is_superhost) as distinct_superhosts,
        avg(review_scores_rating) filter (where is_active = 1) as avg_review_scores_rating,
        coalesce(sum(stays), 0) as total_stays,
        sum(stays * price) as total_revenue
    from facts
    group by property_type, room_type, accommodates, month_year
),

with_prev as (
    select *,
        case when lag(month_year) over w = month_year - interval '1 month'
             then lag(active_listings) over w end as prev_active_listings,
        case when lag(month_year) over w = month_year - interval '1 month'
             then lag(inactive_listings) over w end as prev_inactive_listings
    from monthly
    window w as (partition by property_type, room_type, accommodates order by month_year)
)

select
    property_type,
    room_type,
    accommodates,
    month_year,
    round(active_listings * 100.0 / nullif(total_listings, 0), 2) as active_listings_rate,
    min_price,
    max_price,
    round(median_price::numeric, 2) as median_price,
    round(avg_price, 2) as avg_price,
    distinct_hosts,
    round(distinct_superhosts * 100.0 / nullif(distinct_hosts, 0), 2) as superhost_rate,
    round(avg_review_scores_rating, 2) as avg_review_scores_rating,
    round((active_listings - prev_active_listings) * 100.0
          / nullif(prev_active_listings, 0), 2) as active_listings_pct_change,
    round((inactive_listings - prev_inactive_listings) * 100.0
          / nullif(prev_inactive_listings, 0), 2) as inactive_listings_pct_change,
    total_stays,
    round(total_revenue / nullif(active_listings, 0), 2) as avg_estimated_revenue_per_active_listing
from with_prev
order by property_type, room_type, accommodates, month_year