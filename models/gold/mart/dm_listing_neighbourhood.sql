{{
    config(
        materialized='view',
        alias='dm_listing_neighbourhood'
    )
}}

-- Datamart dm_listing_neighbourhood: one row per listing_neighbourhood
-- (LGA) and month/year, ordered by listing_neighbourhood and month/year.
-- (brief Part 3, design decisions G1, G4, Lab 6.3 pattern)
-- 1. The fact is joined to dim_lga and dim_host with the SCD2 join
--    (scraped_date between valid_from and valid_to), so each row uses
--    the dimension version that was valid on that date.
-- 2. Metric definitions from the brief:
--    active listing = has_availability 't' (is_active = 1);
--    active listings rate = active / total * 100;
--    price, review score, stays and revenue use active listings only;
--    superhost rate = distinct superhosts / distinct hosts * 100;
--    stays = 30 - availability_30; revenue = stays * price;
--    average revenue per active listing = total revenue / active listings;
--    % change = (this month - previous month) / previous month * 100.
-- 3. % change uses lag() per neighbourhood and is NULL when the previous
--    row is not exactly one month earlier or the previous value is 0
--    (NULLIF on every divisor).

with

facts as (
    select
        coalesce(l.lga_name, 'Unknown') as listing_neighbourhood,
        f.listing_month as month_year,
        f.host_id,
        h.host_is_superhost,
        f.is_active,
        f.price,
        f.review_scores_rating,
        case when f.is_active = 1 then 30 - f.availability_30 end as stays
    from {{ ref('g_fact_listings') }} f
    left join {{ ref('g_dim_lga') }} l
        on f.listing_lga_code = l.lga_code
       and f.scraped_date::timestamp >= l.valid_from
       and f.scraped_date::timestamp < coalesce(l.valid_to, '9999-12-31'::timestamp)
    left join {{ ref('g_dim_host') }} h
        on f.host_id = h.host_id
       and f.scraped_date::timestamp >= h.valid_from
       and f.scraped_date::timestamp < coalesce(h.valid_to, '9999-12-31'::timestamp)
),

monthly as (
    select
        listing_neighbourhood,
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
        sum(stays) as total_stays,
        sum(stays * price) as total_revenue
    from facts
    group by listing_neighbourhood, month_year
),

with_prev as (
    select *,
        case when lag(month_year) over w = month_year - interval '1 month'
             then lag(active_listings) over w end as prev_active_listings,
        case when lag(month_year) over w = month_year - interval '1 month'
             then lag(inactive_listings) over w end as prev_inactive_listings
    from monthly
    window w as (partition by listing_neighbourhood order by month_year)
)

select
    listing_neighbourhood,
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
order by listing_neighbourhood, month_year