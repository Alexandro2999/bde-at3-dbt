{{
    config(
        unique_key='lga_code',
        alias='census_g01'
    )
}}

-- Silver census G01 (Selected Person Characteristics, 2016, NSW LGAs).
-- LGA_CODE_2016 has an 'LGA' prefix (e.g. LGA10050), but NSW_LGA_CODE has
-- no prefix (e.g. 10050) (data_exploration_census.sql query 2,
-- data_exploration_nsw_lga.sql query 3). The prefix is removed so the
-- census can be joined to the LGA table. The original code is kept.
-- All other columns are copied as they are (dbt_utils.star).
-- LGA19499 and LGA19799 are not real LGAs (census query 5). They are kept
-- here and handled where the census is used.

select
    regexp_replace(lga_code_2016, '^LGA', '') as lga_code,
    lga_code_2016,
    {{ dbt_utils.star(from=ref('b_census_g01'), except=['lga_code_2016']) }}
from {{ ref('b_census_g01') }}