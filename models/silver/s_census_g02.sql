{{
    config(
        unique_key='lga_code',
        alias='census_g02'
    )
}}

-- Silver census G02 (Selected Medians and Averages, 2016, NSW LGAs).
-- Same cleaning as s_census_g01: the 'LGA' prefix is removed from
-- LGA_CODE_2016 so the census can be joined to the LGA table
-- (data_exploration_census.sql query 3, data_exploration_nsw_lga.sql
-- query 3). The original code is kept. All other columns are copied.
-- LGA19499 and LGA19799 have 0 in many columns (census query 5). They are
-- kept here and handled where the census is used.

select
    regexp_replace(lga_code_2016, '^LGA', '') as lga_code,
    lga_code_2016,
    {{ dbt_utils.star(from=ref('b_census_g02'), except=['lga_code_2016']) }}
from {{ ref('b_census_g02') }}