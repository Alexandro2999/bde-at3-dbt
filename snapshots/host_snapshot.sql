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
-- the first date of the host's current version (the month when its
-- values last changed, D2/G2), so a new version is added only when the
-- host values really change (dbt_checks.sql 10).

select
    host_id,
    host_name,
    host_since,
    host_is_superhost,
    host_neighbourhood,
    updated_at::timestamp as updated_at
from {{ ref('s_host') }}

{% endsnapshot %}