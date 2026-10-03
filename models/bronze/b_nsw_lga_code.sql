{{
    config(
        unique_key='lga_code',
        alias='nsw_lga_code'
    )
}}

select * from {{ source('raw', 'raw_nsw_lga_code') }}