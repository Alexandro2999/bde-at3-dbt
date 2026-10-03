{{
    config(
        materialized='table',
        unique_key='host_id',
        alias='dim_host'
    )
}}

-- Gold dim_host: host attributes, from snapshots/host_snapshot (SCD2).
-- (design decisions D1, D3, G3, Lab 6.3 pattern)
-- 1. valid_from of the first version of each host is set to 1900-01-01,
--    so facts dated before the first snapshot run still find a version.
-- 2. valid_to is dbt_valid_to (NULL = current version).
-- 3. An Unknown row (host_id 0) is added for facts with no match
--    (Lab 6.3 pattern).
-- The unknown values are cast to the snapshot column types, so the
-- union all works.

with

source as (
    select * from {{ ref('host_snapshot') }}
),

cleaned as (
    select
        host_id,
        host_name,
        host_since,
        host_is_superhost,
        host_neighbourhood,
        case when dbt_valid_from = min(dbt_valid_from) over (partition by host_id)
             then '1900-01-01'::timestamp
             else dbt_valid_from
        end as valid_from,
        dbt_valid_to as valid_to
    from source
),

unknown as (
    select
        0::bigint as host_id,
        'Unknown'::text as host_name,
        null::date as host_since,
        null::boolean as host_is_superhost,
        'UNKNOWN'::text as host_neighbourhood,
        '1900-01-01'::timestamp as valid_from,
        null::timestamp as valid_to
)

select * from unknown
union all
select * from cleaned