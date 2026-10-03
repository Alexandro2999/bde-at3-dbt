{{
    config(
        unique_key='listing_id',
        alias='listing_latest'
    )
}}

-- Silver listing_latest: one row per listing (its latest month), input for
-- snapshots/listing_snapshot. Not the same as s_listings, which keeps one
-- row per listing per month. (design decisions D1, D2, D3)
-- 1. Only listing attributes are kept: property_type, room_type,
--    accommodates, listing_neighbourhood. host_id, price and the other
--    metrics belong to the fact table.
-- 2. The values come from the latest month the listing appears in.
-- 3. updated_at is the cleaned scraped_date. A listing appears once per
--    file (data_exploration_listings.sql query 14), so there is one date
--    per listing per month.

with

ranked as (

    select
        listing_id,
        property_type,
        room_type,
        accommodates,
        listing_neighbourhood,
        listing_month,
        scraped_date as updated_at,
        row_number() over (partition by listing_id
                           order by listing_month desc, scraped_date desc) as row_num
    from {{ ref('s_listings') }}
    where listing_id is not null

)

select
    listing_id,
    property_type,
    room_type,
    accommodates,
    listing_neighbourhood,
    listing_month,
    updated_at
from ranked
where row_num = 1