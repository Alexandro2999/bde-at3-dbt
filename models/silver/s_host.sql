{{
    config(
        unique_key='host_id',
        alias='host'
    )
}}

-- Silver host: one row per host, input for snapshots/host_snapshot.
-- (design decisions D2, D3)
-- 1. Rows where host_name, host_since and host_is_superhost are all empty
--    are removed first, so an empty row does not become a new host
--    version in the snapshot.
-- 2. The host values come from the latest month the host appears in.
-- 3. updated_at is the earliest scraped_date of the host in that month.
--    A host can appear on several dates in one month; using the earliest
--    date means every fact row of that month joins this version.

with

rows as (

    select
        host_id,
        listing_month,
        scraped_date,
        host_name,
        host_since,
        host_is_superhost,
        host_neighbourhood
    from {{ ref('s_listings') }}
    where host_id is not null
      and not (host_name is null
               and host_since is null
               and host_is_superhost is null)

),

ranked as (

    select
        *,
        min(scraped_date) over (partition by host_id, listing_month) as updated_at,
        row_number() over (partition by host_id
                           order by listing_month desc, scraped_date desc) as row_num
    from rows

)

select
    host_id,
    host_name,
    host_since,
    host_is_superhost,
    host_neighbourhood,
    listing_month,
    updated_at
from ranked
where row_num = 1