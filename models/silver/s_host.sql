{{
    config(
        unique_key='host_id',
        alias='host'
    )
}}

-- Silver host: one row per host, input for snapshots/host_snapshot.
-- (design decisions D2, D3, G2)
-- 1. A row where host_name, host_since and host_is_superhost are all empty
--    is a scrape gap (D3). It is ignored when the host has a non-empty row
--    in any loaded month, so a gap does not become a new host version.
--    A host that is empty in every row is kept with empty values, so it
--    keeps its own host_id in the fact (not the unknown host 0).
-- 2. One row per host per month, with the values of the earliest kept row.
--    month_first_date is the earliest date of the host in that month,
--    counted over all its rows (also the empty ones), so every fact row of
--    that month finds this version.
-- 3. The host values come from the latest month the host appears in.
-- 4. updated_at is the first date of the current version, that is the
--    month_first_date of the month when the host values last changed.
--    If nothing changed, updated_at stays the same, so the snapshot
--    does not add a new version.

with

host_rows as (
    select host_id, listing_month, scraped_date, listing_id,
           host_name, host_since, host_is_superhost, host_neighbourhood,
           (host_name is null and host_since is null
            and host_is_superhost is null) as is_empty
    from {{ ref('s_listings') }}
    where host_id is not null
),

-- true when every row of the host is empty
host_flag as (
    select host_id, bool_and(is_empty) as always_empty
    from host_rows
    group by host_id
),

-- earliest date of the host in each month, over all its rows
month_dates as (
    select host_id, listing_month, min(scraped_date) as month_first_date
    from host_rows
    group by host_id, listing_month
),

-- keep non-empty rows, and the rows of hosts that are always empty
kept_rows as (
    select r.*
    from host_rows r
    join host_flag f on f.host_id = r.host_id
    where not r.is_empty or f.always_empty
),

-- one row per host per month: the earliest kept row of that month
monthly as (
    select *,
           row_number() over (partition by host_id, listing_month
                              order by scraped_date, listing_id) as rn
    from kept_rows
),

one_per_month as (
    select m.host_id, m.listing_month, d.month_first_date,
           m.host_name, m.host_since, m.host_is_superhost, m.host_neighbourhood
    from monthly m
    join month_dates d
      on d.host_id = m.host_id and d.listing_month = m.listing_month
    where m.rn = 1
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