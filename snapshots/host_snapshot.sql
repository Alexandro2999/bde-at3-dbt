{% snapshot host_snapshot %}

{{
    config(
        strategy='timestamp',
        unique_key='host_id',
        updated_at='updated_at'
    )
}}

-- SCD2 history of hosts (brief Part 2: decompose listings into entities,
-- timestamp strategy). Input s_host has one row per host; updated_at is
-- the earliest cleaned scraped_date of the host in its latest month.

select
    host_id,
    host_name,
    host_since,
    host_is_superhost,
    host_neighbourhood,
    updated_at::timestamp as updated_at
from {{ ref('s_host') }}

{% endsnapshot %}