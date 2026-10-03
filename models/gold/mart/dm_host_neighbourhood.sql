{{
    config(
        materialized='view',
        alias='dm_host_neighbourhood'
    )
}}

-- Datamart dm_host_neighbourhood: one row per host_neighbourhood_lga and
-- month/year, ordered by host_neighbourhood_lga and month/year.
-- (brief Part 3, design decisions G1, D4, Lab 6.3 pattern)
-- 1. host_neighbourhood_lga: the fact key host_suburb is joined to
--    dim_suburb (suburb -> LGA name), then to dim_lga for the LGA name
--    as written in NSW_LGA_CODE. Both joins use the SCD2 join
--    (scraped_date between valid_from and valid_to).
-- 2. The UNKNOWN suburb (NULL and OVERSEAS host_neighbourhood, D4)
--    matches the Unknown row of dim_lga, so it is shown as 'Unknown'.
-- 3. Metric definitions from the brief:
--    number of distinct hosts;
--    estimated revenue per active listing = stays * price,
--    stays = 30 - availability_30 (active listings only);
--    average estimated revenue per active listing
--      = total estimated revenue / number of active listings;
--    estimated revenue per host
--      = total estimated revenue / distinct hosts;
--    total_estimated_revenue is also shown, as the numerator of both.
--    NULLIF on every divisor.

with

facts as (
    select
        coalesce(l.lga_name, 'Unknown') as host_neighbourhood_lga,
        f.listing_month as month_year,
        f.host_id,
        f.is_active,
        case when f.is_active = 1
             then (30 - f.availability_30) * f.price end as revenue
    from {{ ref('g_fact_listings') }} f
    left join {{ ref('g_dim_suburb') }} s
        on f.host_suburb = s.suburb_name
       and f.scraped_date::timestamp >= s.valid_from
       and f.scraped_date::timestamp < coalesce(s.valid_to, '9999-12-31'::timestamp)
    left join {{ ref('g_dim_lga') }} l
        on s.lga_name = l.lga_name_upper
       and f.scraped_date::timestamp >= l.valid_from
       and f.scraped_date::timestamp < coalesce(l.valid_to, '9999-12-31'::timestamp)
)

select
    host_neighbourhood_lga,
    month_year,
    count(distinct host_id) as distinct_hosts,
    round(sum(revenue) / nullif(count(*) filter (where is_active = 1), 0), 2)
        as avg_estimated_revenue_per_active_listing,
    round(sum(revenue) / nullif(count(distinct host_id), 0), 2)
        as estimated_revenue_per_host,
    sum(revenue) as total_estimated_revenue
from facts
group by host_neighbourhood_lga, month_year
order by host_neighbourhood_lga, month_year