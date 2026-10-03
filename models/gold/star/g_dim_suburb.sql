{{
    config(
        materialized='table',
        unique_key='suburb_name',
        alias='dim_suburb'
    )
}}

-- Gold dim_suburb: suburb name and its LGA name, from
-- snapshots/suburb_snapshot (SCD2). Used to find the LGA of the
-- host_neighbourhood (dm_host_neighbourhood).
-- (design decisions D4, G3, Lab 6.3 pattern)
-- 1. valid_from of the first version of each suburb is set to 1900-01-01.
-- 2. valid_to is dbt_valid_to (NULL = current version).
-- 3. An Unknown row (suburb_name 'UNKNOWN') is added for facts with no match.

with

source as (
    select * from {{ ref('suburb_snapshot') }}
),

cleaned as (
    select
        suburb_name,
        lga_name,
        case when dbt_valid_from = min(dbt_valid_from) over (partition by suburb_name)
             then '1900-01-01'::timestamp
             else dbt_valid_from
        end as valid_from,
        dbt_valid_to as valid_to
    from source
),

unknown as (
    select
        'UNKNOWN' as suburb_name,
        'UNKNOWN' as lga_name,
        '1900-01-01'::timestamp as valid_from,
        null::timestamp as valid_to
)

select * from unknown
union all
select * from cleaned