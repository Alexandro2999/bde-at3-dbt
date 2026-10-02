{{
    config(
        unique_key='lga_code_2016',
        alias='census_g01'
    )
}}

select * from {{ source('raw', 'raw_census_g01') }}