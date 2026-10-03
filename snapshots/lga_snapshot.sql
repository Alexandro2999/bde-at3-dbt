{% snapshot lga_snapshot %}

{{
    config(
        strategy='check',
        unique_key='lga_code',
        check_cols=['lga_name']
    )
}}

-- SCD2 history of LGAs. The LGA file has no date column, so the check
-- strategy is used (same as Lab 6.3; dbt docs: check is for tables
-- without a reliable updated_at column).

select
    lga_code,
    lga_name,
    lga_name_upper
from {{ ref('s_nsw_lga_code') }}

{% endsnapshot %}