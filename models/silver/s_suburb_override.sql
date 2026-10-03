{{
    config(
        unique_key='suburb_name',
        alias='suburb_override'
    )
}}

-- Corrections for NSW_LGA_SUBURB (the mapping file given in the brief).
-- These Sydney suburbs are mapped in the file to a regional LGA with the
-- same suburb name (dbt_checks.sql 3a), but the hosts with these
-- host_neighbourhood values list their properties in Sydney LGAs
-- (dbt_checks.sql 3b and 3d). Only these 5 names are changed; every
-- other suburb keeps the LGA from the file.
-- WAVERLY is not here: it is fixed to WAVERLEY in s_listings, and
-- WAVERLEY is already mapped to WAVERLEY LGA in the file (3a).
-- RICHMOND is not here: RICHMOND -> HAWKESBURY is a real Greater Sydney
-- mapping and its hosts have no main listing LGA (3d).
-- Names are uppercase, the same as the suburb file.

select
    suburb_name,
    lga_name,
    lga_name_in_file
from (
    values
        ('DARLINGTON',  'SYDNEY',     'SINGLETON'),
        ('THE ROCKS',   'SYDNEY',     'BATHURST REGIONAL'),
        ('SUMMER HILL', 'INNER WEST', 'DUNGOG'),
        ('ENMORE',      'INNER WEST', 'ARMIDALE REGIONAL'),
        ('BALMORAL',    'MOSMAN',     'LAKE MACQUARIE')
) as override (suburb_name, lga_name, lga_name_in_file)