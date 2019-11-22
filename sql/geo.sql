/*
    ===========
    STATE TABLE
    ===========
*/
DROP TABLE IF EXISTS state;

CREATE TABLE state(
    id    serial        NOT NULL PRIMARY KEY,
    name  varchar(100)  NOT NULL,
    code  char(2)       NOT NULL
);

INSERT INTO state
(
      name
    , code
)
SELECT DISTINCT
      admin_name_1 AS name
    , admin_code_1 AS code
FROM
    all_countries
ORDER BY
    name;


/*
    ============
    COUNTY TABLE
    ============
*/
DROP TABLE IF EXISTS county;
CREATE TABLE county(
    id        serial        NOT NULL PRIMARY KEY,
    state_id  int           NOT NULL REFERENCES state(id),
    name      varchar(100)  NOT NULL,
    code      varchar(20)   NOT NULL
);

INSERT INTO county
(
      state_id
     , name
    , code
)
SELECT DISTINCT ON (admin_code_1 || '_' || admin_name_2)
      S.id AS state_id
    , C.admin_name_2 AS name
    , C.admin_code_2 AS code
FROM
    all_countries AS C
INNER JOIN state S on S.code=C.admin_code_1;


/*
    ==========
    CITY TABLE
    ==========
*/
DROP TABLE IF EXISTS city;
CREATE TABLE city (
    id             serial        NOT NULL PRIMARY KEY,
    state_id       int           NOT NULL REFERENCES state(id),
    county_id      int           NOT NULL REFERENCES county(id),
    name           varchar(180)  NOT NULL
);

INSERT INTO city
(
      state_id
    , county_id
    , name
)
SELECT DISTINCT ON (place_name || '_' || admin_code_1 || '_' || admin_name_2)
      S.id         AS state_id
    , C.id         AS county_id
    , A.place_name AS name
FROM
    all_countries AS A

INNER JOIN state AS S ON S.code=A.admin_code_1
INNER JOIN county AS C ON C.state_id=S.id AND C.name = A.admin_name_2;

/*
    =================
    POSTAL CODE TABLE
    =================
*/
DROP TABLE IF EXISTS postal_code;
CREATE TABLE postal_code (
    id         serial       NOT NULL PRIMARY KEY,
    state_id   int          NOT NULL REFERENCES state(id),
    county_id  int          NOT NULL REFERENCES county(id),
    city_id    int          NOT NULL REFERENCES city(id),
    code       varchar(20)  NOT NULL
);

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
    all_countries AS A
    
INNER JOIN state AS S ON S.code=A.admin_code_1
INNER JOIN county AS CO ON CO.state_id=S.id AND CO.name=A.admin_name_2
INNER JOIN city AS C ON C.state_id=S.id AND C.county_id=CO.id AND C.name=A.place_name
