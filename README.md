# PostalCode

Set up a PostgreSQL database with all cities, states, counties, and postal codes in the United States.

This guide will help set up a database using postal code data from [GeoNames](https://geonames.org).

All data comes courtesy of [GeoNames](https://geonames.org) and is licensed under the Creative Commons Attribution 3.0 License.

## Datafile Setup

Grab a copy of the allCountries.zip file from GeoNames' download page [here](http://download.geonames.org/export/zip/).

1. Unzip the allCountries.zip file
    - Should unzip to all countries.txt
2. Isolate the US postal codes using grep
    - `grep '^US' allCountries.txt > all-countries.csv`
3. Using `sed`, replace the "`\t`" characters with "`~`" for easier import
    - `sed -i 's/\t/~/g' all-countries.csv`
    - If on MacOS, you'll need to insert a literal tab character by using `ctrl+V` and pressing the tab key
    - Using the "`~`" character because some cities have commas in their names

## Database Setup

Create a Postgres database called `geo` (or whatever you like) so we can begin setting up tables

### Create the geonames Table

Create a table called geonames that will be used for the initial import.

```sql
DROP TABLE IF EXISTS geonames;

CREATE TABLE geonames (
    country_code  char(2)       NOT NULL,
    postal_code   varchar(20)   NOT NULL,
    city          varchar(180), -- place_name
    state_name    varchar(100), -- admin_name_1
    state_code    varchar(20),  -- admin_code_1
    county_name   varchar(100), -- admin_name_2
    county_code   varchar(20),  -- admin_code_2
    admin_name_3  varchar(100), -- admin_name_3 (unused in US)
    admin_code_3  varchar(20),  -- admin_code_3 (unused in US)
    lat           numeric,
    lng           numeric,
    accuracy      char(1)
);
```

### Import the `all-countries.csv` File

Important to note that you must use the absolute path to your `all-countries.csv` file from earlier.

```sql
COPY geonames FROM '/path/to/all-countries.csv' DELIMITER '~' CSV;
```