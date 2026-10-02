{{
    config(
        unique_key='listing_row_id',
        alias='listings'
    )
}}

-- One row per listing per month, copied from raw_listings.
-- listing_row_id joins listing_id and source_month (same idea as b_facts in Lab 6.3).
select
{{ dbt_utils.generate_surrogate_key(['listing_id', 'source_month']) }} as listing_row_id
, *
from {{ source('raw', 'raw_listings') }}