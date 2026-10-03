{{
    config(
        unique_key='listing_row_id',
        alias='listings'
    )
}}

-- Silver listings: one row per listing per month (same grain as Bronze).
-- Evidence: data_exploration_listings.sql (query N) and dbt_checks.sql (3x).
-- 1. Dates become DATE. scraped_date is YYYY-MM-DD (query 8); host_since
--    is day first, DD/MM/YYYY (query 10, check 3c).
--    07_2020 has 4,780 rows dated 2020-09-05 (query 9), later than every
--    08_2020 date (query 18). A scraped_date after the end of its file
--    month is set to the last day of that month. The raw date and a flag
--    are kept.
-- 2. property_type: the naming style changed between May and August 2020
--    (queries 17, 19). Rows scraped before 2020-08-01 are recoded to the
--    new style with a rule based on room_type. The raw value is kept.
--    The rule will be checked again in dbt_checks.sql after all months
--    are loaded (Part 3).
-- 3. host_neighbourhood: UPPER and TRIM (the suburb file is uppercase),
--    WAVERLY -> WAVERLEY (checks 3a, 3b), empty -> NULL.
-- 4. t/f flags become boolean (queries 3, 4, 5). scrape_id is dropped
--    (one value per file, queries 2, 17).

with

source as (

    select * from {{ ref('b_listings') }}

),

dates as (

    select
        *,
        to_date(source_month, 'MM_YYYY') as month_start,
        (to_date(source_month, 'MM_YYYY') + interval '1 month - 1 day')::date as month_end,
        to_date(scraped_date, 'YYYY-MM-DD') as scraped_date_raw
    from source

),

renamed as (

    select
        listing_row_id,
        listing_id,
        host_id,
        source_month,
        month_start as listing_month,

        -- dates
        least(scraped_date_raw, month_end) as scraped_date,
        scraped_date_raw,
        scraped_date_raw > month_end as is_scraped_date_fixed,

        -- host attributes
        nullif(trim(host_name), '') as host_name,
        to_date(host_since, 'DD/MM/YYYY') as host_since,
        case host_is_superhost when 't' then true when 'f' then false end as host_is_superhost,
        case
            when upper(trim(host_neighbourhood)) = 'WAVERLY' then 'WAVERLEY'
            else nullif(upper(trim(host_neighbourhood)), '')
        end as host_neighbourhood,

        -- listing attributes
        trim(listing_neighbourhood) as listing_neighbourhood,
        case
            when scraped_date_raw >= date '2020-08-01' then property_type
            when property_type in ('Boutique hotel', 'Hotel', 'Aparthotel')
                then 'Room in ' || lower(property_type)
            when room_type = 'Entire home/apt' then
                case
                    when property_type in ('Barn', 'Boat', 'Bus', 'Camper/RV', 'Castle',
                                           'Cave', 'Dome house', 'Earth house', 'Farm stay',
                                           'Island', 'Tent', 'Tiny house', 'Train',
                                           'Treehouse', 'Yurt')
                        then property_type
                    when property_type = 'Other' then 'Entire place'
                    when property_type = 'Casa particular (Cuba)' then 'Casa particular'
                    else 'Entire ' || lower(property_type)
                end
            when property_type = 'Other' then room_type
            when room_type = 'Private room' then 'Private room in ' || lower(property_type)
            when room_type = 'Shared room' then 'Shared room in ' || lower(property_type)
            when room_type = 'Hotel room' then 'Room in ' || lower(property_type)
            else property_type
        end as property_type,
        property_type as property_type_raw,
        room_type,
        accommodates,

        -- metrics
        price,
        case has_availability when 't' then true when 'f' then false end as has_availability,
        availability_30,
        number_of_reviews,
        review_scores_rating,
        review_scores_accuracy,
        review_scores_cleanliness,
        review_scores_checkin,
        review_scores_communication,
        review_scores_value

    from dates

)

select * from renamed