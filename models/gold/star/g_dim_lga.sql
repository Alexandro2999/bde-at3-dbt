{{
    config(
        materialized='table',
        unique_key='lga_code',
        alias='dim_lga'
    )
}}

-- Gold dim_lga: LGA code and name, from snapshots/lga_snapshot (SCD2).
-- (design decision G3, Lab 6.3 pattern)
-- 1. valid_from of the first version of each LGA is set to 1900-01-01,
--    so facts dated before the first snapshot run still find a version.
-- 2. valid_to is dbt_valid_to (NULL = current version).
-- 3. An Unknown row (lga_code '0') is added for facts with no match.

with

source as (
    select * from {{ ref('lga_snapshot') }}
),

cleaned as (
    select
        lga_code,
        lga_name,
        lga_name_upper,
        case when dbt_valid_from = min(dbt_valid_from) over (partition by lga_code)
             then '1900-01-01'::timestamp
             else dbt_valid_from
        end as valid_from,
        dbt_valid_to as valid_to
    from source
),

unknown as (
    select
        '0' as lga_code,
        'Unknown' as lga_name,
        'UNKNOWN' as lga_name_upper,
        '1900-01-01'::timestamp as valid_from,
        null::timestamp as valid_to
)

select * from unknown
union all
select * from cleaned