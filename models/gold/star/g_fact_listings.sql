{{
    config(
        materialized='table',
        unique_key='listing_row_id',
        alias='fact_listings'
    )
}}

-- Gold fact_listings: one row per listing per month, from Silver s_listings.
-- (design decisions G1, G4, D4, Lab 6.3 pattern)
-- 1. Keys to the 4 dimensions (G1):
--    listing_id -> dim_listing, host_id -> dim_host: 0 (unknown) when the
--    key is not in the dimension (Lab 6.3 pattern). Every host is in
--    dim_host (also hosts with always empty values, D3), so host_id 0 is
--    only a safety fallback (check 12a: 0 rows).
--    listing_lga_code -> dim_lga: found from listing_neighbourhood, using the
--    LGA version valid on scraped_date. '0' when there is no match.
--    host_suburb -> dim_suburb: host_neighbourhood when it is a suburb in
--    dim_suburb, otherwise 'UNKNOWN' (NULL and OVERSEAS, check 11c).
-- 2. is_active = 1 when has_availability is true, else 0 (G4; brief:
--    active listing = has_availability 't').
-- 3. Metrics are kept as they are. Stays and revenue are calculated in the
--    datamart views, with the brief definitions.
-- 4. scraped_date is the cleaned date from Silver (D2). It is used to join
--    the fact to the SCD2 dimensions.

with

source as (
    select * from {{ ref('s_listings') }}
),

lga as (
    select lga_code, lga_name_upper, valid_from, valid_to
    from {{ ref('g_dim_lga') }}
    where lga_code <> '0'
)

select
    s.listing_row_id,

    case when s.listing_id in (select distinct listing_id from {{ ref('g_dim_listing') }})
         then s.listing_id else 0 end as listing_id,

    case when s.host_id in (select distinct host_id from {{ ref('g_dim_host') }})
         then s.host_id else 0 end as host_id,

    coalesce(l.lga_code, '0') as listing_lga_code,

    case when s.host_neighbourhood in (select distinct suburb_name from {{ ref('g_dim_suburb') }})
         then s.host_neighbourhood else 'UNKNOWN' end as host_suburb,

    s.scraped_date,
    s.listing_month,

    case when s.has_availability then 1 else 0 end as is_active,

    s.price,
    s.availability_30,
    s.number_of_reviews,
    s.review_scores_rating,
    s.review_scores_accuracy,
    s.review_scores_cleanliness,
    s.review_scores_checkin,
    s.review_scores_communication,
    s.review_scores_value

from source s
left join lga l
    on upper(trim(s.listing_neighbourhood)) = l.lga_name_upper
   and s.scraped_date::timestamp >= l.valid_from
   and s.scraped_date::timestamp < coalesce(l.valid_to, '9999-12-31'::timestamp)