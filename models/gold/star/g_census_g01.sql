{{
    config(
        materialized='table',
        alias='census_g01'
    )
}}

-- Gold census_g01: 2016 Census G01 by LGA, from Silver s_census_g01.
-- lga_code is already cleaned in Silver (no 'LGA' prefix), so it joins
-- to dim_lga.lga_code. No other change in Gold.

select * from {{ ref('s_census_g01') }}