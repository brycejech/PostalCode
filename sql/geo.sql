/*
    ===========
    TABLE SETUP
    ===========
*/
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


/*
    ==============
    INITIAL IMPORT
    ==============
*/
COPY geonames FROM '/path/to/all-countries.csv' DELIMITER '~' CSV;

DELETE FROM geonames WHERE state_name IS NULL OR county_name IS NULL;


/*
    ==================
    DATA NORMALIZATION
    ==================
*/

-- STATE TABLE
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


-- COUNTY TABLE
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


-- CITY TABLE
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


-- POSTAL CODE TABLE
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
INNER JOIN city AS C ON C.state_id=S.id AND C.county_id=CO.id AND C.name=A.city;


/*
    =======
    WRAP-UP
    =======
*/
DROP TABLE geonames;