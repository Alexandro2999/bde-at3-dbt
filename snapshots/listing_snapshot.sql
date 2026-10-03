{% snapshot listing_snapshot %}

{{
    config(
        strategy='timestamp',
        unique_key='listing_id',
        updated_at='updated_at'
    )
}}

-- SCD2 history of listing attributes (timestamp strategy).
-- Input s_listing_latest has one row per listing; updated_at is the
-- cleaned scraped_date.

select
    listing_id,
    property_type,
    room_type,
    accommodates,
    listing_neighbourhood,
    updated_at::timestamp as updated_at
from {{ ref('s_listing_latest') }}

{% endsnapshot %}