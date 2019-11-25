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
    - Using the "`~`" character because some cities have commas in their names
    - If on MacOS, you'll need to insert a literal tab character by using `ctrl+V` and pressing the tab key
      - Also on Mac, if using bsd style sed with the `-i` flag, include an additional empty extension or provide an extension to create a backup of the original file `sed -i '' 's/    /~/g' all-countries.csv`

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

### Clean Up Records

The datafile contains quite a few postal codes without a state or county, most of which seem to be military. Since we are going to rely on each postal code having a state an county it is recommended that you delete these records.

```sql
DELETE FROM geonames WHERE state_name IS NULL OR county_name IS NULL;
```

### Create State, County, City, and Postal Code Tables

Next we're going to create the state, county, city and postal code tables so that we can normalize the data we've copied into the geonames table.

```sql
DROP TABLE IF EXISTS state;
CREATE TABLE state(
    id    serial        NOT NULL PRIMARY KEY,
    name  varchar(100)  NOT NULL,
    code  char(2)       NOT NULL
);

DROP TABLE IF EXISTS county;
CREATE TABLE county(
    id        serial        NOT NULL PRIMARY KEY,
    state_id  int           NOT NULL REFERENCES state(id),
    name      varchar(100)  NOT NULL,
    code      varchar(20)   NOT NULL
);

DROP TABLE IF EXISTS city;
CREATE TABLE city (
    id             serial        NOT NULL PRIMARY KEY,
    state_id       int           NOT NULL REFERENCES state(id),
    county_id      int           NOT NULL REFERENCES county(id),
    name           varchar(180)  NOT NULL
);

DROP TABLE IF EXISTS postal_code;
CREATE TABLE postal_code (
    id         serial       NOT NULL PRIMARY KEY,
    state_id   int          NOT NULL REFERENCES state(id),
    county_id  int          NOT NULL REFERENCES county(id),
    city_id    int          NOT NULL REFERENCES city(id),
    code       varchar(20)  NOT NULL
);
```

---

## Populating the Database

Now that we've imported the datafile and set up our tables, we can start to populate them. We'll start with the state tables and work our way down to county, city, and finally postal code.

### State

All we need to do populate the state table is to select distinct state names from the geonames table for the insert statement.

```sql
INSERT INTO state
(
      name
    , code
)
SELECT DISTINCT
      state_name AS name
    , state_code AS code
FROM
    geonames
ORDER BY
    name;
```

### County

For the county table, we want to avoid missing any counties that may appear in multiple states, so it is not enough to simply select distinct county names. In order to get a distinct county name per state, we're going to use Postgres' `DISTINCT ON` feature and provide it with the result of concatenating the state code and county name. This should give a distinct county name per state that we can use to populate the counties table. 

We'll also join the state table we just populated on the state's code so that we can insert the state ID that each county belongs to.

```sql
INSERT INTO county
(
      state_id
    , name
    , code
)
SELECT DISTINCT ON (state_name || '_' || county_name)
      S.id          AS state_id
    , C.county_name AS name
    , C.county_code AS code
FROM
    geonames AS C
INNER JOIN state S on S.code=C.state_code;
```

### City

For the city table, we're going to use the same `DISTINCT ON` feature to get a unique city per county and state. We'll also join the state and county tables to insert their IDs in the city table.

```sql
INSERT INTO city
(
      state_id
    , county_id
    , name
)
SELECT DISTINCT ON (city || '_' || state_code || '_' || county_name)
      S.id   AS state_id
    , C.id   AS county_id
    , A.city AS name
FROM
    geonames AS A

INNER JOIN state AS S ON S.code=A.state_code
INNER JOIN county AS C ON C.state_id=S.id AND C.name = A.county_name;
```

### Postal Code

The postal code table is the final one to be populated, we'll have 1 record for each row in the geonames table and foreign keys into each of the previous tables that we've populated.

```sql
INSERT INTO postal_code
(
      state_id
    , county_id
    , city_id
    , code
)
SELECT
      S.id          AS state_id
    , CO.id         AS county_id
    , C.id          AS city_id
    , A.postal_code AS code
FROM
    geonames AS A
    
INNER JOIN state AS S ON S.code=A.state_code
INNER JOIN county AS CO ON CO.state_id=S.id AND CO.name=county_name
INNER JOIN city AS C ON C.state_id=S.id AND C.county_id=CO.id AND C.name=A.city
```

---

## Wrapping Up

### Dropping the geonames Table

Now that the postal code data has been normalized, we can drop the geonames table that we started with. 

```sql
DROP TABLE geonames;
```

### Query Samples

Get all postal codes with state, county, and city names

```sql
SELECT
	  P.code  AS postal_code
	, S.name  AS state
	, CO.name AS county
	, C.name  AS city
FROM
	postal_code AS P

INNER JOIN state AS S ON S.id=P.state_id
INNER JOIN county AS CO on CO.id=P.county_id
INNER JOIN city AS C ON C.id=P.city_id
```

Get all postal codes as a JSON array by city, county, and state

```sql
SELECT
	  C.name           AS city
	, CO.name          AS county
	, S.name           AS state
	, json_agg(P.code) AS postal_codes

FROM
	postal_code AS P

INNER JOIN state AS S ON S.id=P.state_id
INNER JOIN county AS CO on CO.id=P.county_id
INNER JOIN city AS C ON C.id=P.city_id

GROUP BY
	  C.name
	, CO.name
	, S.name
```

Get all postal codes as a JSON array for cities matching a search

```sql
SELECT
	  C.name           AS city
	, CO.name          AS county
	, S.name           AS state
	, json_agg(P.code) AS postal_codes

FROM
	postal_code AS P

INNER JOIN state AS S ON S.id=P.state_id
INNER JOIN county AS CO on CO.id=P.county_id
INNER JOIN city AS C ON C.id=P.city_id

WHERE LOWER(C.name) LIKE '%ridge%'

GROUP BY
	  C.name
	, CO.name
	, S.name
```