{{
    config(
        materialized='table',
        alias='census_g02'
    )
}}

-- Gold census_g02: 2016 Census G02 by LGA, from Silver s_census_g02.
-- lga_code is already cleaned in Silver (no 'LGA' prefix), so it joins
-- to dim_lga.lga_code. No other change in Gold.

select * from {{ ref('s_census_g02') }}