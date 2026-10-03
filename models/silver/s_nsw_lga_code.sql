{{
    config(
        unique_key='lga_code',
        alias='nsw_lga_code'
    )
}}

-- Silver LGA code table (from NSW_LGA_CODE in the brief).
-- LGA_CODE is unique, 5 characters, no 'LGA' prefix
-- (data_exploration_nsw_lga.sql queries 2, 3).
-- lga_name keeps the case from the file (e.g. 'Inner West'), which is the
-- case used by listing_neighbourhood. lga_name_upper is added for the
-- join with the suburb mapping, which is uppercase (dbt_checks.sql 5c).

select
    trim(lga_code)          as lga_code,
    trim(lga_name)          as lga_name,
    upper(trim(lga_name))   as lga_name_upper
from {{ ref('b_nsw_lga_code') }}