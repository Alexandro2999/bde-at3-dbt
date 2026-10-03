{{
    config(
        unique_key='host_id',
        alias='host'
    )
}}

-- Silver host: one row per host, input for snapshots/host_snapshot.
-- (design decisions D2, D3, G2)
-- 1. Rows where host_name, host_since and host_is_superhost are all empty
--    are removed first, so an empty row does not become a new host
--    version in the snapshot.
-- 2. One row per host per month: the earliest scraped row of that month.
-- 3. The host values come from the latest month the host appears in.
-- 4. updated_at is the first date of the current version, that is the
--    earliest date of the month when the host values last changed.
--    If nothing changed, updated_at stays the same, so the snapshot
--    does not add a new version.

with

rows as (
    select host_id, listing_month, scraped_date, listing_id,
           host_name, host_since, host_is_superhost, host_neighbourhood
    from {{ ref('s_listings') }}
    where host_id is not null
      and not (host_name is null and host_since is null and host_is_superhost is null)
),

-- one row per host per month: the earliest scraped row of that month
monthly as (
    select *,
           row_number() over (partition by host_id, listing_month
                              order by scraped_date, listing_id) as rn
    from rows
),

one_per_month as (
    select host_id, listing_month, scraped_date as month_first_date,
           host_name, host_since, host_is_superhost, host_neighbourhood
    from monthly
    where rn = 1
),

-- flag 1 when this is the first month or any attribute differs from the previous month
flagged as (
    select *,
           case when lag(listing_month) over w is null
                  or (host_name, host_since, host_is_superhost, host_neighbourhood)
                     is distinct from
                     (lag(host_name) over w, lag(host_since) over w,
                      lag(host_is_superhost) over w, lag(host_neighbourhood) over w)
                then 1 else 0 end as is_change
    from one_per_month
    window w as (partition by host_id order by listing_month)
),

-- months with the same attributes get the same version number
versioned as (
    select *,
           sum(is_change) over (partition by host_id order by listing_month
                                rows unbounded preceding) as version_no
    from flagged
),

-- updated_at = first date of the current version; keep the latest month only
dated as (
    select *,
           min(month_first_date) over (partition by host_id, version_no) as updated_at,
           row_number() over (partition by host_id order by listing_month desc) as row_num
    from versioned
)

select host_id, host_name, host_since, host_is_superhost, host_neighbourhood,
       listing_month, updated_at
from dated
where row_num = 1