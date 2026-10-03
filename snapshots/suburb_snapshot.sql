{% snapshot suburb_snapshot %}

{{
    config(
        strategy='check',
        unique_key='suburb_name',
        check_cols=['lga_name']
    )
}}

-- SCD2 history of the suburb -> LGA mapping. No date column, so the
-- check strategy is used (same as lga_snapshot).

select
    suburb_name,
    lga_name
from {{ ref('s_nsw_lga_suburb') }}

{% endsnapshot %}