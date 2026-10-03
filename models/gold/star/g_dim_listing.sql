{{
    config(
        materialized='table',
        unique_key='listing_id',
        alias='dim_listing'
    )
}}

-- Gold dim_listing: listing attributes, from snapshots/listing_snapshot (SCD2).
-- (design decisions D1, D5, G3, Lab 6.3 pattern)
-- 1. valid_from of the first version of each listing is set to 1900-01-01,
--    so facts dated before the first snapshot run still find a version.
-- 2. valid_to is dbt_valid_to (NULL = current version).
-- 3. An Unknown row (listing_id 0) is added for facts with no match.
-- The unknown values are cast to the snapshot column types, so the
-- union all works.

with

source as (
    select * from {{ ref('listing_snapshot') }}
),

cleaned as (
    select
        listing_id,
        property_type,
        room_type,
        accommodates,
        listing_neighbourhood,
        case when dbt_valid_from = min(dbt_valid_from) over (partition by listing_id)
             then '1900-01-01'::timestamp
             else dbt_valid_from
        end as valid_from,
        dbt_valid_to as valid_to
    from source
),

unknown as (
    select
        0::bigint as listing_id,
        'Unknown'::text as property_type,
        'Unknown'::text as room_type,
        null::integer as accommodates,
        'Unknown'::text as listing_neighbourhood,
        '1900-01-01'::timestamp as valid_from,
        null::timestamp as valid_to
)

select * from unknown
union all
select * from cleaned