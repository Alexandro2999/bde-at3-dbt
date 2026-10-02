{{
    config(
        alias='nsw_lga_suburb'
    )
}}

-- No unique_key: SUBURB_NAME uniqueness is not proven yet (see part_1.sql section 6).
select * from {{ source('raw', 'raw_nsw_lga_suburb') }}