{{
    config(
        unique_key='listing_id',
        alias='listing_latest'
    )
}}

-- Silver listing_latest: one row per listing, input for snapshots/listing_snapshot.
-- (design decisions D2, G2)
-- 1. One row per listing per month: the earliest scraped row of that month.
-- 2. The listing values come from the latest month the listing appears in.
-- 3. updated_at is the first date of the current version, that is the
--    earliest date of the month when the listing values last changed.
--    If nothing changed, updated_at stays the same, so the snapshot
--    does not add a new version.

with

-- one row per listing per month: the earliest scraped row of that month
monthly as (
    select listing_id, listing_month, scraped_date,
           property_type, room_type, accommodates, listing_neighbourhood,
           row_number() over (partition by listing_id, listing_month
                              order by scraped_date) as rn
    from {{ ref('s_listings') }}
    where listing_id is not null
),

one_per_month as (
    select * from monthly where rn = 1
),

-- flag 1 when this is the first month or any attribute differs from the previous month
flagged as (
    select *,
           case when lag(listing_month) over w is null
                  or (property_type, room_type, accommodates, listing_neighbourhood)
                     is distinct from
                     (lag(property_type) over w, lag(room_type) over w,
                      lag(accommodates) over w, lag(listing_neighbourhood) over w)
                then 1 else 0 end as is_change
    from one_per_month
    window w as (partition by listing_id order by listing_month)
),

-- months with the same attributes get the same version number
versioned as (
    select *,
           sum(is_change) over (partition by listing_id order by listing_month
                                rows unbounded preceding) as version_no
    from flagged
),

-- updated_at = first date of the current version; keep the latest month only
dated as (
    select *,
           min(scraped_date) over (partition by listing_id, version_no) as updated_at,
           row_number() over (partition by listing_id order by listing_month desc) as row_num
    from versioned
)

select listing_id, property_type, room_type, accommodates, listing_neighbourhood,
       listing_month, updated_at
from dated
where row_num = 1