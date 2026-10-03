{{
    config(
        unique_key='suburb_name',
        alias='nsw_lga_suburb'
    )
}}

-- Silver suburb -> LGA mapping (from NSW_LGA_SUBURB in the brief).
-- 1. Names are cleaned with UPPER and TRIM. The file is uppercase except
--    'Gundagai' (data_exploration_nsw_lga.sql), so UPPER makes all names
--    the same case. SUBURB_NAME is unique before and after cleaning
--    (dbt_checks.sql 2a, 2b).
-- 2. The 4 corrections in s_suburb_override replace the LGA from the file
--    (dbt_checks.sql 3a, 3b). The LGA from the file is kept in
--    lga_name_in_file, and is_corrected shows which rows changed.

with

source as (

    select
        upper(trim(suburb_name)) as suburb_name,
        upper(trim(lga_name))    as lga_name
    from {{ ref('b_nsw_lga_suburb') }}

),

override as (

    select * from {{ ref('s_suburb_override') }}

)

select
    s.suburb_name,
    coalesce(o.lga_name, s.lga_name) as lga_name,
    s.lga_name                       as lga_name_in_file,
    o.suburb_name is not null        as is_corrected
from source s
left join override o
    on s.suburb_name = o.suburb_name