{{
    config(
        alias='nsw_lga_suburb'
    )
}}

-- Copy of raw_nsw_lga_suburb. SUBURB_NAME is unique (dbt_checks.sql 2a, 2b)
-- and is tested in Silver (s_nsw_lga_suburb, schema.yml).
select * from {{ source('raw', 'raw_nsw_lga_suburb') }}