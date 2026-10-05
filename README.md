# bde-at3-dbt

dbt Cloud project for UTS 94693 Big Data Engineering, Assignment 3:
Airbnb Sydney listings (May 2020 to April 2021) and the 2016 Census in Postgres.
The raw files are loaded into the bronze schema by an Airflow DAG (not in this repo).
The data flows bronze -> silver -> snapshots -> gold star -> gold mart.

## Project structure

```
bde-at3-dbt/
|-- dbt_project.yml          project settings: schema and materialisation per folder
|-- packages.yml             dbt_utils 1.1.1 (used in 3 models and 9 of the 37 tests)
|-- package-lock.yml         exact package version installed by dbt deps
|-- macros/
|   `-- generate_schema_name.sql
|-- models/
|   |-- sources.yml          the 5 raw tables in the bronze schema
|   |-- schema.yml           37 data tests
|   |-- bronze/              5 tables, copies of the raw tables
|   |-- silver/              8 cleaned tables
|   `-- gold/
|       |-- star/            fact table, 4 SCD2 dimensions, 2 census tables
|       `-- mart/            3 datamart views
|-- snapshots/               4 SCD2 snapshots (stored in the silver schema)
`-- analyses/, seeds/, tests/   empty (dbt default folders)
```

## Models

Bronze (schema bronze, tables)
- b_listings, b_census_g01, b_census_g02, b_nsw_lga_code, b_nsw_lga_suburb:
  copies of the raw tables. b_listings adds a row key from listing_id and source_month.

Silver (schema silver, tables)
- s_listings: one row per listing per month; dates fixed, property_type names
  recoded to the new style, host_neighbourhood cleaned
- s_host: one row per host, input for host_snapshot
- s_listing_latest: one row per listing, input for listing_snapshot
- s_nsw_lga_code: LGA code and name
- s_nsw_lga_suburb: suburb to LGA mapping, with the corrections from s_suburb_override
- s_suburb_override: 5 Sydney suburbs that the file maps to a regional LGA
- s_census_g01, s_census_g02: census tables with the LGA code cleaned (no 'LGA' prefix)

Snapshots (schema silver)
- host_snapshot, listing_snapshot: timestamp strategy on updated_at
- lga_snapshot, suburb_snapshot: check strategy (the files have no date column)

Gold star (schema gold, tables)
- g_fact_listings: one row per listing per month, only keys, dates and metrics
- g_dim_host, g_dim_listing, g_dim_lga, g_dim_suburb: SCD2 dimensions from the
  snapshots, with valid_from and valid_to
- g_census_g01, g_census_g02: census reference tables by LGA

Gold mart (schema gold, views)
- dm_listing_neighbourhood: per listing_neighbourhood (LGA) and month
- dm_property_type: per property_type, room_type, accommodates and month
- dm_host_neighbourhood: per host_neighbourhood_lga and month
- Each view joins the fact to the dimension version that was valid on the
  scraped_date (valid_from <= date < valid_to).

## Macro
- generate_schema_name.sql: in prod the schemas are bronze, silver and gold;
  in development they get the dev schema as prefix (for example dbt_wsianipar_silver).

## Run
dbt deps
dbt build

Production job: monthly_build (dbt deps and dbt build), run by hand after each monthly DAG load.
