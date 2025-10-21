
#	build_synthea_omop_postgres_database

The intention of this was to test in addition to the Eunomia database
but its kinda diverged away from AI and more with OHDSI

Download new data

https://github.com/OHDSI/ETL-Synthea

We are loading a version 5.4 CDM into a local PostgreSQL database called "synthea10".
The ETLSyntheaBuilder package leverages the OHDSI/CommonDataModel package for CDM creation.
Valid CDM versions are determined by executing CommonDataModel::listSupportedVersions().
The strings representing supported CDM versions are currently "5.3" and "5.4". 
The Synthea version we use in this example is 2.7.0.
However, at this time we also support 3.0.0, 3.1.0, 3.2.0 and 3.3.0.
Please note that Synthea's MASTER branch is always active and this package will be updated to support
future versions as possible.
The schema to load the Synthea tables is called "native".
The schema to load the Vocabulary and CDM tables is "cdm_synthea10".  
The username and pw are "postgres" and "lollipop".
The Synthea and Vocabulary CSV files are located in /tmp/synthea/output/csv and /tmp/Vocabulary_20181119, respectively.


For those interested in seeing the CDM changes from 5.3 to 5.4, please see: http://ohdsi.github.io/CommonDataModel/cdm54Changes.html



Download the data. This includes json, xml and csv. Just using the csv here.
https://synthea.mitre.org/downloads
SyntheticMass Data, Version 2 (24 May, 2017): 21GB. FHIR 3.0.1, CSV, C-CDA
https://mitre.box.com/shared/static/3bo45m48ocpzp8fc0tp005vax7l93xji.gz

```bash
#	Extract the internal 12 output_*.tar.gz files ...
tar xvfz synthea_1m_fhir_3_0_May_24.tar.gz

#	Extract just the csv data ...
for f in output_*; do echo $f; tar xvfz $f \*/csv/ ; done

#	Make a couple corrections ...
for d in output_*/csv; do
  echo $d
  #	Need to change DATE to START and STOP in the header of encounters.csv and procedures.csv
  mv ${d}/procedures.csv ${d}/procedures.original ; awk 'BEGIN{FS=OFS=","}{print $1,$1,$2,$3,$4,$5,$6,$7}' ${d}/procedures.original > ${d}/procedures.csv
  sed -i '' '1s/DATE,DATE/START,STOP/' ${d}/procedures.csv
  mv ${d}/encounters.csv ${d}/encounters.original ; awk 'BEGIN{FS=OFS=","}{print $1,$2,$2,$3,$4,$5,$6,$7}' ${d}/encounters.original > ${d}/encounters.csv
  sed -i '' '1s/DATE,DATE/START,STOP/' ${d}/encounters.csv
  #	patients.csv files are all "corrupt" need to select only those records with 17 fields.
  mv ${d}/patients.csv ${d}/patients.original ; awk -F, '(NF==17){print}' ${d}/patients.original > ${d}/patients.csv 
done
```



Download vocab files.
Where to get vocab Files?
Need to create a user 
https://athena.ohdsi.org/vocabulary/download-history
There are many different sets of data.
Its not clear how many or which are actually needed.

```bash
#	Unzip the downloaded file ...
unzip vocabulary_download_v5_{4cb70d34-c931-4018-9198-99afa4d0bace}_1760570025269.zip
#	Rename and/or move the folder to whereever it is needed
```







Prepare the receiving postgres database ...

```bash
/opt/local/lib/postgresql17/bin/psql -U postgres
```

```postgres
CREATE DATABASE synthea10;
\c synthea10;
CREATE SCHEMA cdm_synthea10;
CREATE SCHEMA native;
```




```R

library('DatabaseConnector')
DatabaseConnector::downloadJdbcDrivers("postgresql",pathToDriver="~/Downloads/")

```


```bash

build_synthea_omop_postgres_database.R

```






Move this to a different server

IF VERSIONS ARE SYNCHRONIZED OR THE TARGET IS NEWER 


SHOULD use -Fc option. This creates a .backup file
which is compressed, binary, and can be used with pgAdmin -> Restore

```bash
sudo port load postgresql17-server

pg_dump -U postgres -d synthea -Fc -C -f synthea10.backup

sudo port unload postgresql17-server

ls -l synthea10.sql synthea10.backup
#	Much smaller
#	-r--r--r--   1 jake  staff  30244418805 Oct 16 16:38 synthea10.sql
#	-rw-r--r--   1 jake  staff   4048907542 Oct 16 20:32 synthea10.backup
```


This only works if the versions are close to synchronized. Going from 17.6 to 15.2 won't work.
Need to stick the SQL style dump.

```bash
docker cp synthea10.backup broadsea-atlasdb:/synthea10.backup

docker ps -a | cut -w -f1,2 | grep broadsea-atlasdb
#	97daf8a059da   ohdsi/broadsea-atlasdb:2.1.0-secret

docker exec -it 97daf8a059da /bin/sh

#	pg_restore -U postgres -d synthea -f /synthea10.backup

pg_restore -U postgres --clean --create -d synthea /synthea10.backup

```



OTHERWISE IF TARGET IS OLDER, DUMP TO SQL

```bash
/opt/local/lib/postgresql17/bin/pg_dump -U postgres -d synthea10 -f synthea10.sql

ls -l synthea10.sql

#	-rw-r--r--  1 jake  staff  30244418799 Oct 16 07:40 synthea10.sql
```


```bash
docker cp synthea10.sql broadsea-atlasdb:/synthea10.sql

docker ps -a | cut -w -f1,2 | grep broadsea-atlasdb
#	97daf8a059da   ohdsi/broadsea-atlasdb:2.1.0-secret

docker exec -it 97daf8a059da /bin/sh
psql -U postgres -d synthea -f /synthea10.sql
```









NOTE pgadmin is run on one container, but postgres is actually being run on the atlasdb container

Make it visible to atlas

there also may be some version differences here

From pgadmin / postgres Tools > Query Tool

```postgres
INSERT INTO webapi.source (source_id, source_name, source_key, source_connection, source_dialect)
VALUES (
	    2,
	    'Synthea CDM',
	    'SYNTHEA',
	    'jdbc:postgresql://broadsea-atlasdb:5432/synthea?user=postgres&password=mypass',
	    'postgresql'
);

INSERT INTO webapi.source_daimon (source_daimon_id, source_id, daimon_type, table_qualifier, priority)
VALUES
	    (4, 2, 0, 'cdm_synthea10', 1),   -- CDM schema
	    (5, 2, 1, 'cdm_synthea10', 1),   -- Vocabulary schema (same for Synthea)
	    (6, 2, 2, 'results_synthea10', 1); -- Results schema (create this if missing)

DROP SCHEMA results_synthea10 CASCADE;
-- CREATE SCHEMA results_synthea10;
CREATE SCHEMA results_synthea10 AUTHORIZATION postgres;

CREATE TABLE IF NOT EXISTS results_synthea10.achilles_results_dist
(
    analysis_id integer,
    stratum_1 character varying COLLATE pg_catalog."default",
    stratum_2 character varying COLLATE pg_catalog."default",
    stratum_3 character varying COLLATE pg_catalog."default",
    stratum_4 character varying COLLATE pg_catalog."default",
    stratum_5 character varying COLLATE pg_catalog."default",
    count_value bigint,
    min_value numeric,
    max_value numeric,
    avg_value numeric,
    stdev_value numeric,
    median_value numeric,
    p10_value numeric,
    p25_value numeric,
    p75_value numeric,
    p90_value numeric
)

TABLESPACE pg_default;

ALTER TABLE IF EXISTS results_synthea10.achilles_results_dist
    OWNER to postgres;

CREATE TABLE IF NOT EXISTS results_synthea10.achilles_results
(
	analysis_id integer,
	stratum_1 character varying COLLATE pg_catalog."default",
	stratum_2 character varying COLLATE pg_catalog."default",
	stratum_3 character varying COLLATE pg_catalog."default",
	stratum_4 character varying COLLATE pg_catalog."default",
	stratum_5 character varying COLLATE pg_catalog."default",
	count_value bigint
)

```
	

Clear the cache

DELETE FROM webapi.achilles_cache;







The first couple reports work. The others do not.
Working on it.









CREATE TABLE results_synthea10.concept_hierarchy (
    concept_id INT PRIMARY KEY,
    concept_name TEXT,
    level1_concept_name TEXT,
    level2_concept_name TEXT,
    level3_concept_name TEXT,
    level4_concept_name TEXT,
    treemap TEXT
);


CREATE TABLE results_synthea10.concept_ancestor (
    ancestor_concept_id INT,
    descendant_concept_id INT,
    min_levels_of_separation INT
);


INSERT INTO results_synthea10.concept_hierarchy VALUES (0,0,0);
INSERT INTO results_synthea10.concept_ancestor VALUES (0,0,0);




SELECT
concept_hierarchy.concept_id,
CONCAT(
COALESCE(concept_hierarchy.level4_concept_name,'NA'), '||',
COALESCE(concept_hierarchy.level3_concept_name,'NA'), '||',
COALESCE(concept_hierarchy.level2_concept_name,'NA'), '||',
COALESCE(concept_hierarchy.level2_concept_name,'NA'), '||',
COALESCE(concept_hierarchy.concept_name,'NA')
) AS concept_path,
ar1.count_value                                     AS num_persons,
ROUND(CAST(1.0 * ar1.count_value / denom.count_value AS NUMERIC),5) AS percent_persons,
ROUND(CAST(1.0 * ar2.count_value / ar1.count_value AS NUMERIC),5)   AS records_per_person
FROM (SELECT *
FROM results_synthea10.achilles_results WHERE analysis_id = 400) ar1
INNER JOIN
(SELECT *
FROM results_synthea10.achilles_results WHERE analysis_id = 401) ar2
ON ar1.stratum_1 = ar2.stratum_1
INNER JOIN
results_synthea10.concept_hierarchy concept_hierarchy
ON CAST(CASE WHEN ar1.analysis_id = 400 THEN ar1.stratum_1 ELSE null END AS INT) = concept_hierarchy.concept_id
AND concept_hierarchy.treemap='Condition'
,
(SELECT count_value
FROM results_synthea10.achilles_results WHERE analysis_id = 1) denom
ORDER BY ar1.count_value DESC





SELECT DISTINCT att.attname as name, att.attnum as OID, pg_catalog.format_type(ty.oid,NULL) AS datatype,
att.attnotnull as not_null, att.atthasdef as has_default_val, des.description, seq.seqtypid
FROM pg_catalog.pg_attribute att
JOIN pg_catalog.pg_type ty ON ty.oid=atttypid
JOIN pg_catalog.pg_namespace tn ON tn.oid=ty.typnamespace
JOIN pg_catalog.pg_class cl ON cl.oid=att.attrelid
JOIN pg_catalog.pg_namespace na ON na.oid=cl.relnamespace
LEFT OUTER JOIN pg_catalog.pg_type et ON et.oid=ty.typelem
LEFT OUTER JOIN pg_catalog.pg_attrdef def ON adrelid=att.attrelid AND adnum=att.attnum
LEFT OUTER JOIN (pg_catalog.pg_depend JOIN pg_catalog.pg_class cs ON classid='pg_class'::regclass AND objid=cs.oid AND cs.relkind='S') ON refobjid=att.attrelid AND refobjsubid=att.attnum
LEFT OUTER JOIN pg_catalog.pg_namespace ns ON ns.oid=cs.relnamespace
LEFT OUTER JOIN pg_catalog.pg_index pi ON pi.indrelid=att.attrelid AND indisprimary
LEFT OUTER JOIN pg_catalog.pg_description des ON (des.objoid=att.attrelid AND des.objsubid=att.attnum AND des.classoid='pg_class'::regclass)
LEFT OUTER JOIN pg_catalog.pg_sequence seq ON cs.oid=seq.seqrelid
WHERE
att.attrelid = 18641::oid
AND att.attnum > 0
AND att.attisdropped IS FALSE
ORDER BY att.attnum
2025-10-21 04:12:11.663 UTC [301] LOG:  statement: SELECT n.nspname, r.relname
FROM pg_catalog.pg_class r
LEFT JOIN pg_catalog.pg_namespace n ON (r.relnamespace = n.oid)
WHERE r.oid = 18641;
















#	for whatever reason achilles doesn't create the tables. It expects them to be there.







org.postgresql.util.PSQLException: ERROR: relation "results_synthea10.achilles_results_dist" does not exist











#	Now seeing that there are no achilles reports

#	HADES (Rstudio)

#	R doesn't install these to persist

```R
install.packages("remotes")  # if not already installed
remotes::install_github("OHDSI/Achilles")
#remotes::install_github("OHDSI/Achilles@v1.7.2")
#remotes::install_github("OHDSI/Andromeda",force=TRUE)
#remotes::install_github("OHDSI/Achilles",force=TRUE)



library('DatabaseConnector')
library('Achilles')


connectionDetails <- DatabaseConnector::createConnectionDetails(
	  dbms = "postgresql",
	  server = "broadsea-atlasdb/synthea",
	  user = "postgres",
	  password = "mypass",
	  port = 5432
)




#
#	analysisDetails <- getAnalysisDetails()
#	> dim(analysisDetails)
#	[1] 294  11
#	> max(analysisDetails$analysis_id)
#	[1] 2201
#
#	#	create all of the reports

achilles(
	connectionDetails,
	cdmDatabaseSchema = "cdm_synthea10",
	resultsDatabaseSchema = "results_synthea10",
	vocabDatabaseSchema = "cdm_synthea10",
	numThreads = 1,
	sourceName = "Synthea CDM",
	cdmVersion = "5.4",
	createTable = TRUE, 
  dropScratchTables = TRUE,
  createIndices = TRUE,
)

#	That worked. Not sure what exactly changed, but numThreads=1 is primarily
#	select count(1) from results_synthea10.achilles_results;
#	While this table is not populated, I still don't get plots in Atlas -> Data Sources

#	Don't multithread
#	analysisIds = c(0,1,2,3,4,5,6,7,8,9,10,11,12),
#	analysisIds = c(101, 102, 103) # Replace with your desired analysis IDs
```




Cleanup

```postgres
DO $$
DECLARE
	r RECORD;
BEGIN
	FOR r IN (SELECT tablename FROM pg_tables WHERE schemaname = 'results_synthea10' AND tablename LIKE 'tmp%') LOOP
		EXECUTE 'DROP TABLE IF EXISTS ' || quote_ident('results_synthea10') || '.' || quote_ident(r.tablename) || ' CASCADE';
	END LOOP;
END $$;
```








#	may be able to run R directly rather than use Rstudio

#	docker ps | grep broadsea-hades | cut -w -f1,2
#	bcd76eb4c608   ohdsi/broadsea-hades:4.2.1
#	
#	docker exec -it bcd76eb4c608 /bin/sh
#
#	R
#	...


