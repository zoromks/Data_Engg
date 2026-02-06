--chapter 1

USE ROLE SYSADMIN;

CREATE WAREHOUSE ETL_WH
WAREHOUSE_SIZE = XSMALL
MAX_CLUSTER_COUNT = 3
MIN_CLUSTER_COUNT = 1
SCALING_POLICY = ECONOMY
AUTO_SUSPEND = 300 -- suspend after 5 minutes (300 seconds) of inactivity
AUTO_RESUME = TRUE
INITIALLY_SUSPENDED = TRUE
COMMENT = 'Virtual Warehouse for ETL workloads. Auto scales between 1 and 3 clusters depending on the workload';


CREATE DATABASE COOKBOOK;

USE DATABASE COOKBOOK;
CREATE TABLE MY_FIRST_TABLE
(
    ID STRING,
    NAME STRING
);

SELECT * FROM MY_FIRST_TABLE;


USE ROLE SECURITYADMIN;

CREATE USER secondary_account_admin 
PASSWORD = 'password123' 
DEFAULT_ROLE = "ACCOUNTADMIN" 
MUST_CHANGE_PASSWORD = TRUE;


GRANT ROLE "ACCOUNTADMIN" TO USER secondary_account_admin;


--chapter 2


USE ROLE SYSADMIN;

CREATE DATABASE our_first_database
COMMENT = 'Our first database';

SHOW DATABASES LIKE 'our_first_database';

CREATE DATABASE production_database 
DATA_RETENTION_TIME_IN_DAYS = 15
COMMENT = 'Critical production database';

SHOW DATABASES LIKE 'production_database';


CREATE TRANSIENT DATABASE temporary_database 
DATA_RETENTION_TIME_IN_DAYS = 0
COMMENT = 'Temporary database for ETL processing';

SHOW DATABASES LIKE 'temporary_database';

ALTER DATABASE temporary_database
SET DATA_RETENTION_TIME_IN_DAYS = 1;

SHOW DATABASES LIKE 'temporary_database';


alter database temporary_database
set data_retention_time_in_days=2; --will get error as it is transient DB it can have max 1 day


CREATE DATABASE testing_schema_creation;

SHOW SCHEMAS IN DATABASE testing_schema_creation;

CREATE SCHEMA a_custom_schema
COMMENT = 'A new custom schema';

SHOW SCHEMAS LIKE 'a_custom_schema' IN DATABASE testing_schema_creation ;

CREATE TRANSIENT SCHEMA temporary_data 
DATA_RETENTION_TIME_IN_DAYS = 0
COMMENT = 'Schema containing temporary data used by ETL processes';

SHOW SCHEMAS LIKE 'temporary_data' IN DATABASE testing_schema_creation ;




-- create a table 
CREATE TABLE customers (
  id              INT NOT NULL,
  last_name       VARCHAR(100) ,
  first_name      VARCHAR(100),
  email           VARCHAR(100),
  company         VARCHAR(100),
  phone           VARCHAR(100),
  address1        VARCHAR(150),
  address2        VARCHAR(150),
  city            VARCHAR(100),
  state           VARCHAR(100),
  postal_code     VARCHAR(15),
  country         VARCHAR(50)
);


-- replace the table
CREATE OR REPLACE TABLE customers (
  id              INT NOT NULL,
  last_name       VARCHAR(100) ,
  first_name      VARCHAR(100),
  email           VARCHAR(100),
  company         VARCHAR(100),
  phone           VARCHAR(100),
  address1        STRING,
  address2        STRING,
  city            VARCHAR(100),
  state           VARCHAR(100),
  postal_code     VARCHAR(15),
  country         VARCHAR(50)
);

-- load sample data
COPY INTO customers
FROM s3://snowflake-cookbook/ch2/r3/customer.csv
FILE_FORMAT = (TYPE = csv SKIP_HEADER = 1 FIELD_OPTIONALLY_ENCLOSED_BY = '"');

select * from customers;


-- replace table selecting all data from the customer table
CREATE OR REPLACE TABLE 
	customers_deep_copy 
AS 
SELECT * 
	FROM customers;


-- replace table selecting without data
CREATE OR REPLACE TABLE 
customers_shallow_copy 
LIKE customers;


SELECT 
COUNT(*) shallow_count 
FROM 
customers_shallow_copy;

-- create a temporary table
CREATE TEMPORARY TABLE customers_temp AS SELECT * FROM customers WHERE TRY_TO_NUMBER(postal_code) IS NOT NULL;

-- create a transient table
CREATE TRANSIENT TABLE customers_trans AS  SELECT * FROM customers WHERE TRY_TO_NUMBER(postal_code) IS NULL;



-- create a stage
create or replace stage sfuser_ext_stage
url='s3://snowflake-cookbook/ch2/r4/';

-- list the files in the stage
list@SFUSER_EXT_STAGE;
	

-- create an external table
create or replace external table ext_tbl_userdata1
with location = @sfuser_ext_stage                                                                      
file_format = (type = parquet);


-- select from the external table
select * from ext_tbl_userdata1;

-- create external table with CSV data
create or replace external table ext_card_data
with location = @sfuser_ext_stage/csv
file_format = (type = csv)
pattern = '.*headless[.]csv';

select * from ext_card_data; 

-- translate JSON data from external table into a relational format
select top 5 value:c3::float as card_sum,
value:c2::string as period 
from ext_card_data;

select top 5 value:c5::string,value:c6 from ext_card_data;

drop table ext_card_data;

drop table ext_tbl_userdata1;


--views

-- create database where we will create views
CREATE DATABASE test_view_creation;

-- create a sample view
CREATE VIEW test_view_creation.public.date_wise_orders
AS
SELECT L_COMMITDATE AS ORDER_DATE,
SUM(L_QUANTITY) AS TOT_QTY,
SUM(L_EXTENDEDPRICE) AS TOT_PRICE
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.LINEITEM
GROUP BY L_COMMITDATE;

-- select from the view to validate view works
SELECT * FROM test_view_creation.public.date_wise_orders; 


-- create the view as materialized
CREATE MATERIALIZED VIEW test_view_creation.public.date_wise_orders_fast
AS
SELECT L_COMMITDATE AS ORDER_DATE,
SUM(L_QUANTITY) AS TOT_QTY,
SUM(L_EXTENDEDPRICE) AS TOT_PRICE
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1000.LINEITEM
GROUP BY L_COMMITDATE;

-- select from materialized view which is much faster
SELECT * FROM test_view_creation.public.date_wise_orders_fast;


--chapter 3

CREATE OR REPLACE STORAGE INTEGRATION azure_int
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = 'AZURE'
ENABLED = TRUE
AZURE_TENANT_ID = 'cbf7a2d6-d787-4216-a290-4a69a6f47d49'
STORAGE_ALLOWED_LOCATIONS = ('azure://storemk1.blob.core.windows.net/mkblob/');



DESC INTEGRATION azure_int;


USE ROLE ACCOUNTADMIN;

GRANT USAGE ON INTEGRATION azure_int TO ROLE SYSADMIN;

USE ROLE SYSADMIN;

CREATE STAGE S3_RESTRICTED_STAGE
  STORAGE_INTEGRATION = azure_int
  URL = 'https://storemk1.blob.core.windows.net/mkblob'; --blob store properties


LIST @S3_RESTRICTED_STAGE;




CREATE DATABASE C3_R2;
USE C3_R2;

-- create the table into which sample data will be loaded
CREATE TABLE CREDIT_CARDS
(
  CUSTOMER_NAME STRING,
  CREDIT_CARD STRING,
  TYPE STRING,
  CCV INTEGER,
  EXP_DATE STRING
);

-- define the CSV file format
CREATE FILE FORMAT GEN_CSV
TYPE = CSV
SKIP_HEADER = 1
FIELD_OPTIONALLY_ENCLOSED_BY = '"';

-- create an external stage using a sample S3 bucket
-- In real world scenario replace the url with your cloud storage URL
CREATE OR REPLACE STAGE C3_R2_STAGE url='s3://snowflake-cookbook/ch3/r2'
FILE_FORMAT = GEN_CSV;

-- list the files in the stage 
LIST @C3_R2_STAGE;

-- copy the data from the stage into the table
COPY INTO CREDIT_CARDS
FROM @C3_R2_STAGE;


-- validate that the data loaded successfully 
USE C3_R2;
SELECT COUNT(*) FROM CREDIT_CARDS;




CREATE DATABASE C4_LD_EX;

-- create the table where the data will be loaded
CREATE TABLE CUSTOMER
(
  FName STRING,
  LName STRING,
  Email STRING,
  Date_Of_Birth DATE,
  City STRING,
  Country STRING
);


-- define the file format which is pipe delimited in case of our sample file
CREATE FILE FORMAT PIPE_DELIM
	TYPE = CSV
	FIELD_DELIMITER = '|'
	FIELD_OPTIONALLY_ENCLOSED_BY = '"'
	SKIP_HEADER = 1
	DATE_FORMAT = 'YYYY-MM-DD';
	
USE C4_LD_EX;
-- Create an internal stage
CREATE STAGE CUSTOMER_STAGE
	FILE_FORMAT = PIPE_DELIM;


--CSV

    USE C4_LD_EX;
    
PUT file://C:/Users/mohankrishna.a/Downloads/customers.csv @CUSTOMER_STAGE;

PUT file://C:/Users/mohankrishna.a/Downloads/customers.csv @CUSTOMER_STAGE;
COPY INTO customers FROM @CUSTOMER_STAGE;



-- validate that the file is successfully loaded
LIST @CUSTOMER_STAGE;



-- copy from internal stage into the table
COPY INTO CUSTOMER
FROM @CUSTOMER_STAGE;

-- validate that the data is successfully loaded
USE C4_LD_EX;
SELECT * FROM CUSTOMER;

-- remove files from internal stage as they are already loaded
REMOVE @CUSTOMER_STAGE;


--PARQUET


CREATE DATABASE C3_R4;

-- create the table in which we will load parquet data
CREATE TABLE TRANSACTIONS 
(
	TRANSACTION_DATE DATE,
	CUSTOMER_ID NUMBER(38,0),
	TRANSACTION_ID NUMBER(38,0),
	AMOUNT NUMBER(38,0)
);

-- define the file format to be Parquet
CREATE FILE FORMAT GEN_PARQ
TYPE = PARQUET
COMPRESSION = AUTO
NULL_IF = ('MISSING','');

-- create external stage over public S3 bucket 
-- where a sample parquet file is already present
CREATE OR REPLACE STAGE C3_R4_STAGE url='s3://snowflake-cookbook/ch3/r4'
FILE_FORMAT = GEN_PARQ;

-- try and list the files in stage
LIST @C3_R4_STAGE;

-- select the data in the stage
SELECT $1 FROM @C3_R4_STAGE;

-- use the special syntax to access fields in the data
-- convert them to the proper data type & insert into target table
INSERT INTO TRANSACTIONS
SELECT 
$1:_COL_0::Date,
$1:_COL_1::NUMBER,
$1:_COL_2::NUMBER,
$1:_COL_3::NUMBER 

FROM @C3_R4_STAGE;

 
-- Validate data is successfully loaded
USE C3_R4;

SELECT * FROM TRANSACTIONS;


--JSON

CREATE DATABASE JSON_EX;

-- create external stage pointing to 
-- the public bucket where we have palced a sample JSON file
CREATE OR REPLACE STAGE JSON_STG url='s3://snowflake-cookbook/ch3/r5'
FILE_FORMAT = (TYPE = JSON);

-- validate that you can access the bucket
LIST @JSON_STG;
 
-- check that you can load and parse the JSON
SELECT  PARSE_JSON($1)
FROM @JSON_STG;
 
-- create a new table in which we will load the JSON data
CREATE TABLE CREDIT_CARD_TEMP
(
    MY_JSON_DATA VARIANT
);

-- copy the JSON data into the table
COPY INTO CREDIT_CARD_TEMP
FROM @JSON_STG;

select * from CREDIT_CARD_TEMP;

-- parse and start making sense of JSON fields
SELECT MY_JSON_DATA:data_set,MY_JSON_DATA:extract_date FROM CREDIT_CARD_TEMP;

-- access the credit_cards array in JSON
SELECT MY_JSON_DATA:credit_cards FROM CREDIT_CARD_TEMP;

-- access specific values in credit_cards array in JSON
SELECT MY_JSON_DATA:credit_cards[0].CreditCardNo,MY_JSON_DATA:credit_cards[0].CreditCardHolder FROM CREDIT_CARD_TEMP;

-- use FLATTEN function to conver JSON into relational format
SELECT
    MY_JSON_DATA:extract_date,
    value:CreditCardNo::String,
    value:CreditCardHolder::String,
    value:CardPin::Integer,
    value:CardCVV::String,
    value:CardExpiry::String
FROM
    CREDIT_CARD_TEMP
    , lateral flatten( input => MY_JSON_DATA:credit_cards );



CREATE DATABASE NDJSON_EX;

-- create a stage pointing to the S3 bucket containing our example file
CREATE OR REPLACE STAGE NDJSON_STG url='s3://snowflake-cookbook/ch3/r6'
FILE_FORMAT = (TYPE = JSON, STRIP_OUTER_ARRAY = TRUE);

-- list & validate that you can see the json file
LIST @NDJSON_STG;

-- parse the JSON
SELECT  PARSE_JSON($1)
FROM @NDJSON_STG;
 
-- parse and convert the JSON into relational format
SELECT  PARSE_JSON($1):CreditCardNo::String AS CreditCardNo
        ,PARSE_JSON($1):CreditCardHolder::String AS CreditCardHolder
        ,PARSE_JSON($1):CardPin::Integer AS CardPin
        ,PARSE_JSON($1):CardExpiry::String AS CardExpiry
        ,PARSE_JSON($1):CardCVV::String AS CardCVV
FROM @NDJSON_STG;
 
-- create a new table with the JSON data
CREATE TABLE CREDIT_CARD_DATA AS
SELECT  PARSE_JSON($1):CreditCardNo::String AS CreditCardNo
        ,PARSE_JSON($1):CreditCardHolder::String AS CreditCardHolder
        ,PARSE_JSON($1):CardPin::Integer AS CardPin
        ,PARSE_JSON($1):CardExpiry::String AS CardExpiry
        ,PARSE_JSON($1):CardCVV::String AS CardCVV
FROM @NDJSON_STG;

-- validate data inserted successfully
SELECT * FROM CREDIT_CARD_DATA;
 
    
--snowpipe

CREATE DATABASE SP_EX;

--create the table where data will be loaded
CREATE TABLE TRANSACTIONS
(
  Transaction_Date DATE,
  Customer_ID NUMBER,
  Transaction_ID NUMBER,
  Amount NUMBER
);

-- create external stage
-- use an S3 integeration object for connecting to the bucket
CREATE OR REPLACE STAGE SP_TRX_STAGE 
url='s3://<bucket>'
STORAGE_INTEGRATION = S3_INTEGRATION;

-- list the stage to validate everything works
LIST @SP_TRX_STAGE;

use role ACCOUNTADMIN;

grant

CREATE OR REPLACE STORAGE INTEGRATION AZURE_INTEGRATION
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = AZURE
ENABLED = TRUE
AZURE_TENANT_ID = 'cbf7a2d6-d787-4216-a290-4a69a6f47d49'
STORAGE_ALLOWED_LOCATIONS = (
  'azure://storemk1.blob.core.windows.net/mkblob/'
);


CREATE OR REPLACE STAGE SP_TRX_STAGE
URL = 'azure://storemk1.blob.core.windows.net/mkblob/'
STORAGE_INTEGRATION = AZURE_INTEGRATION;


list @SP_TRX_STAGE;



DESC STORAGE INTEGRATION AZURE_INTEGRATION;


CREATE OR REPLACE PIPE TX_LD_PIPE 
AUTO_INGEST = true
AS COPY INTO TRANSACTIONS FROM @SP_TRX_STAGE
FILE_FORMAT = (TYPE = CSV SKIP_HEADER = 1);


-- Show pipe to see the notification channel
SHOW PIPES LIKE '%TX_LD_PIPE%';



--export data to internal stage

--create a database
CREATE DATABASE EXPORT_EX;

--Create an internal stage
CREATE OR REPLACE STAGE EXPORT_INTERNAL_STG 
FILE_FORMAT = (TYPE = CSV COMPRESSION=GZIP);

--Extract data from a table into the internal stage
COPY INTO @EXPORT_INTERNAL_STG/customer.csv.gz 
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;

--Validate files are extracted 
LIST @EXPORT_INTERNAL_STG;
 
--Use SnowSQL to download the files to a local directory
GET @EXPORT_INTERNAL_STG 'file://C:/Downloads/';


--export data to external stage

-- Create an External Stage
-- Use the storage integration you would have previously created
CREATE OR REPLACE STAGE EXPORT_EXTERNAL_STG 
url='s3://<bucket>'
STORAGE_INTEGRATION = S3_INTEGRATION
FILE_FORMAT = (TYPE = PARQUET COMPRESSION=AUTO);;

--Extract data from a table into the external stage
COPY INTO @EXPORT_EXTERNAL_STG/customer.parquet 
FROM (SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER SAMPLE (10));
 

--chapter 4

--schduled task

--fictitious query on the sample data
SELECT C.C_NAME,SUM(L_EXTENDEDPRICE),SUM(L_TAX) 
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C 
INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O
ON O.O_CUSTKEY = C.C_CUSTKEY
INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM LI
ON LI.L_ORDERKEY = O.O_ORDERKEY
GROUP BY C.C_NAME;


--create a target table for this query
CREATE DATABASE task_demo;
USE DATABASE task_demo;
CREATE TABLE ordering_customers
(
  Reporting_Time TIMESTAMP,
  Customer_Name STRING,
  Revenue NUMBER(16,2),
  Tax NUMBER(16,2)
);

--create a task using the preceding SQL statement
CREATE TASK refresh_ordering_customers
  WAREHOUSE = COMPUTE_WH
  SCHEDULE = '2 MINUTE'
  COMMENT = 'Update Ordering_Customers Table with latest data'
AS
  INSERT INTO ordering_customers
  SELECT CURRENT_TIMESTAMP, C.C_NAME, 
         SUM(L_EXTENDEDPRICE), SUM(L_TAX)
  FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C 
  INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O
  ON O.O_CUSTKEY = C.C_CUSTKEY
  INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM LI
  ON LI.L_ORDERKEY = O.O_ORDERKEY
  GROUP BY CURRENT_TIMESTAMP, C.C_NAME;

--validate that the Task has been created correctly
DESC TASK refresh_ordering_customers;


-- grant privileges to the SYSADMIN 
USE ROLE ACCOUNTADMIN;
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;
 
--set the task status to Resumed so that it can start executing on schedule.
ALTER TASK refresh_ordering_customers RESUME;
DESC TASK refresh_ordering_customers;

 
--run the followin to keep an eye on the task execution to validate that it runs successfully. 
SELECT name, state,
        completed_time, scheduled_time, 
        error_code, error_message        
FROM TABLE(information_schema.task_history())
WHERE name = 'REFRESH_ORDERING_CUSTOMERS';

--validate that the task has indeed executed successfully by selecting from the ordering_customers table.
SELECT * FROM ordering_customers;
 
drop task refresh_ordering_customers;




--task tree

--We will be using a fictitious query on the sample data
SELECT C.C_NAME,SUM(L_EXTENDEDPRICE),SUM(L_TAX) 
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C 
INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O
ON O.O_CUSTKEY = C.C_CUSTKEY
INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM LI
ON LI.L_ORDERKEY = O.O_ORDERKEY
GROUP BY C.C_NAME;

--create a target table for this query where we will save the results of this query. 
CREATE DATABASE task_demo;
USE DATABASE task_demo;
CREATE TABLE ordering_customers
(
  Customer_Name STRING,
  Revenue NUMBER(16,2),
  Tax NUMBER(16,2)
);

--create an initialization task to clean up the table before we insert new data into the table. 
USE DATABASE task_demo;
CREATE TASK clear_ordering_customers
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Delete from Ordering_Customers'
AS
 DELETE FROM task_demo.public.ordering_customers;
 
	 
--create a task using the SQL statement in step 1 to insert data into the ordering_customers table.
CREATE TASK insert_ordering_customers
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Insert into Ordering_Customers the latest data'
AS
  INSERT INTO ordering_customers
  SELECT C.C_NAME, SUM(L_EXTENDEDPRICE), SUM(L_TAX)
  FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C 
  INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O
  ON O.O_CUSTKEY = C.C_CUSTKEY
  INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM LI
  ON LI.L_ORDERKEY = O.O_ORDERKEY
  GROUP BY C.C_NAME;
 
--We will now make the insert task to run after the clear task.
ALTER TASK insert_ordering_customers 
ADD AFTER clear_ordering_customers; 

--run a describe on the task to validate the tasks have been connected.
DESC TASK insert_ordering_customers; 
 
--schedule our clear_ordering_customers task to execute on a schedule. 
ALTER TASK clear_ordering_customers 
SET SCHEDULE = '10 MINUTE'; 

ALTER TASK clear_ordering_customers SUSPEND;

describe task clear_ordering_customers;


--If you are running your code through a role other than ACCOUNTADMIN you must grant that role the privilege to execute task. 
GRANT EXECUTE TASK ON ACCOUNT TO ROLE SYSADMIN;
 
--set the tasks to Resume since tasks are created as suspended by default and would not work unless we set them to resume. 
ALTER TASK insert_ordering_customers RESUME;
ALTER TASK clear_ordering_customers RESUME;

--keep an eye on the task execution to validate that it runs successfully.
SELECT name, state,
        completed_time, scheduled_time, 
        error_code, error_message        
FROM TABLE(information_schema.task_history())
WHERE name IN ('CLEAR_ORDERING_CUSTOMERS','RELOAD_ORDERING_CUSTOMERS');
 
--After 10 minutes, re-run the preceding query
 
--validate that the tasks have indeed executed successfully by selecting from the ordering_customers table:
SELECT * FROM ordering_customers;

drop task clear_ordering_customers;

drop task INSERT_ORDERING_CUSTOMERS;

show tasks;


--task history

--use the task_history table function which can be used to query the history of task execution. Th
SELECT * FROM TABLE(information_schema.task_history()) 
ORDER BY SCHEDULED_TIME;

 
--query the view to return task history between two timestamps.
SELECT * FROM 
TABLE(information_schema.task_history(
    scheduled_time_range_start=>to_timestamp_ltz('2026-02-02 14:00:00.000 -0700'),
    scheduled_time_range_end=>to_timestamp_ltz('2026-02-05 14:10:00.000 -0700')
)) 
ORDER BY SCHEDULED_TIME;

--use the RESULT_LIMIT parameter.
SELECT * FROM 
TABLE(information_schema.task_history(
       result_limit => 5
)) 
ORDER BY SCHEDULED_TIME;
 
--query the TASK_HISTORY view based on the task name itself. This can be performed by using the TASK_NAME parameter.
SELECT * FROM 
TABLE(information_schema.task_history(
       task_name => 'CLEAR_ORDERING_CUSTOMERS'
)) 
ORDER BY SCHEDULED_TIME;

--combine parameters into a single query as well to narrow down our results
SELECT * FROM 
TABLE(information_schema.task_history(
       task_name => 'CLEAR_ORDERING_CUSTOMERS',
       result_limit => 2
)) 
ORDER BY SCHEDULED_TIME;


--Streams

--create a staging table to simulate data arriving from outside Snowflake and being processed further through a stream object. 
CREATE DATABASE stream_demo;
USE DATABASE stream_demo;
CREATE TABLE customer_staging
(
  ID INTEGER,
  Name STRING,
  State STRING,
  Country STRING
);

-- create a stream 
CREATE STREAM customer_changes ON TABLE customer_staging;
 
--describe the stream to see what has been created:
DESC STREAM customer_changes;
 
--insert some data into the staging table to simulate data arriving into Snowflake:
INSERT INTO customer_staging VALUES (1,'Jane Doe','NSW','AU');
INSERT INTO customer_staging VALUES (2,'Alpha','VIC','AU');
INSERT INTO customer_staging VALUES (3,'mohan','in','AU');
 
--validate that the data is indeed inserted into the staging table
SELECT * FROM customer_staging;
 
--view how the changing data has been captured through the stream.
SELECT * FROM customer_changes;
 
--we can now process the data from the stream into another table.Create a table first in which we will insert the recorded data.
CREATE TABLE customer
(
  ID INTEGER,
  Name STRING,
  State STRING,
  Country STRING
);

 
--Retrieve data from a stream and insert into table
INSERT INTO customer 
SELECT ID,Name,State,Country 
FROM customer_changes 
WHERE metadata$action = 'INSERT';
 

--validate that correct data is inserted
SELECT * FROM customer;

--find out what happens to the stream after data has been processed from it.
SELECT * FROM customer_changes;
 

--update a row in the staging table.
UPDATE customer_staging SET name = 'John Smith' WHERE ID = 1;
 
--Select the data from the stream to see how an UPDATE appears in a stream
SELECT * FROM customer_changes;



--tasks with streams

--create a database and a staging table on which we will create our stream object. We will be creating a staging table to simulate data arriving from outside Snowflake and being processed further through a stream object. 
CREATE DATABASE stream_demo;
USE DATABASE stream_demo;
CREATE TABLE customer_staging
(
  ID INTEGER,
  Name STRING,
  State STRING,
  Country STRING
);

 drop stream customer_changes;
--create a stream on the table that captures only the inserts.
CREATE STREAM customer_changes ON TABLE customer_staging APPEND_ONLY = TRUE;

 --describe the stream to see what has been created. 
DESC STREAM customer_changes;
 
--create the actual table where all the new customer data will be processed into.
CREATE TABLE customer
(
  ID INTEGER,
  Name STRING,
  State STRING,
  Country STRING
);
 
--create a task which we will use to insert any new data that appears in the stream. 
CREATE TASK process_new_customers
  WAREHOUSE = COMPUTE_WH
  COMMENT = 'Process new data into customer'
AS
  INSERT INTO customer 
SELECT ID,Name,State,Country 
FROM customer_changes 
WHERE metadata$action = 'INSERT';
 
--schedule this task to run every 5 minutes.

--Please note that to RESUME a task you will need to run the command as ACCOUTNADMIN or another role with the appropriate privilege. 
ALTER TASK process_new_customers 
SET SCHEDULE = '10 MINUTE'; 
ALTER TASK process_new_customers RESUME;
 
--validate that the target table i.e. customer is empty.
SELECT * FROM customer;
 

--after 5 mins view how the changing data has been captured through the stream.
SELECT * FROM customer_changes;
 
--now insert some data into the staging table 
INSERT INTO customer_staging VALUES (1,'Jane Doe','NSW','AU');
INSERT INTO customer_staging VALUES (2,'Alpha','VIC','AU');

-- retrieve data from a stream and insert into target table. 
--Do note that we have used a where clause on the metadata$action equal to INSERT. This is to ensure that we only process new data.
INSERT INTO customer 
SELECT ID,Name,State,Country 
FROM customer_changes 
WHERE metadata$action = 'INSERT';
 
--select the data from the customer table to validate that correct data appears there.
SELECT * FROM customer;
 
--We will now insert some data into the staging table (effectively simulating data that has arrived into Snowflake from an external source).
INSERT INTO customer_staging VALUES (3,'Mike','ACT','AU');
INSERT INTO customer_staging VALUES (4,'Tango','NT','AU');
 
--wait for our scheduled task to run, which will process this staging data into the target table. 
--keep an eye on the execution and the next scheduled time by running the following query. 
SELECT * FROM 
TABLE(information_schema.task_history(
       task_name => 'PROCESS_NEW_CUSTOMERS'
)) 
ORDER BY SCHEDULED_TIME DESC;

--select the data from the target table to validate that the rows in the staging table have been inserted into the target table. 
SELECT * FROM customer;

show tasks;

alter task PROCESS_NEW_CUSTOMERS suspend;



--data type Conversion

--convert a number stored as a string to a numeric value.
SELECT '100.2' AS input, 
        TO_NUMBER(input),  
        TO_NUMBER(input, 12, 2);
		
--TO_NUMBER function works great, until it encounters a non-numeric value. 
SELECT 'not a number' AS input, 
        TO_NUMBER(input);

 
--use one of the TRY_ function on a non-numeric input, so it fails gracefully
SELECT 'not a number' AS input, 
        TRY_TO_NUMBER(input);

 
--perform the type conversion as per normal when a proper numeric input is provided.
SELECT '100.2' AS input, 
        TRY_TO_NUMBER(input);

 
--conversion of string values into Boolean data type. 
--the following query string values True, true, tRue, T, yes, on and 1 are considered to be boolean value TRUE
SELECT  TO_BOOLEAN('True'),
        TO_BOOLEAN('true'),
        TO_BOOLEAN('tRuE'),
        TO_BOOLEAN('T'),
        TO_BOOLEAN('yes'),
        TO_BOOLEAN('on'),
        TO_BOOLEAN('1');

 
--Conversely string values False, false, FalsE, f, no, off and 0 all convert into FALSE.
SELECT  TO_BOOLEAN('False'),
        TO_BOOLEAN('false'),
        TO_BOOLEAN('FalsE'),
        TO_BOOLEAN('f'),
        TO_BOOLEAN('no'),
        TO_BOOLEAN('off'),
        TO_BOOLEAN('0');
 
--convert a string value that contains a date.
SELECT TO_DATE('2020-08-15'), 
        DATE('2020-08-15'), 
        TO_DATE('15/08/2020','DD/MM/YYYY');

 
--try and convert to a timestamp. 
SELECT TO_TIMESTAMP_NTZ ('2020-08-15'), 
        TO_TIMESTAMP_NTZ ('2020-08-15 14:30:50');


--managing context


--Snowflake provides the function CURRENT_DATE which as the name suggests returns the current date in the default date format. 
SELECT CURRENT_DATE();
 
--combine the output of CURRENT_DATE with other processing logic.
SELECT IFF (  DAYNAME(  CURRENT_DATE() ) IN ( 'Sat', 'Sun'), TRUE, FALSE) as week_end_processing_flag;
 
--Snowflake provides the CURRENT_TIMESTAMP function, which in addition to the date also provides the time component.
SELECT CURRENT_TIMESTAMP();
 
--detect the client that a query is running from, using the CURRENT_CLIENT context function. 
SELECT CURRENT_CLIENT();

 
--find out the region of your snowflake instance.
SELECT CURRENT_REGION();
 
-- use security specific contextual functions, for example the current role function.
SELECT CURRENT_ROLE();
 --combine  CURRENT_ROLE() in your view definitions to provide specific security processing, for example creating views that limit the number of rows based on which role is being used to query.

--Similar to the CURRENT_ROLE() is the CURRENT_USER() function which as the name describes returns the current user.
SELECT CURRENT_USER();
 
--Snowflake provides the current database function which returns the database selected for the session. If there is no database selected the function returns NULL.
USE DATABASE SNOWFLAKE_SAMPLE_DATA;
SELECT CURRENT_DATABASE();
 
--Snowflake provides the current schema function which returns the schema selected for the session. If there is no schema selected the function returns NULL.
USE DATABASE SNOWFLAKE_SAMPLE_DATA;
USE SCHEMA INFORMATION_SCHEMA;
SELECT CURRENT_SCHEMA();

--find out the current warehouse that has been selected to run the query by using the current warehouse function.
SELECT CURRENT_WAREHOUSE();


--Logout from the dev_dba_user1  and log back in as the user used previous steps. We now will create a new role to manage access to the DEV database, hence the name DEV_DBA. 
USE ROLE SECURITYADMIN;
CREATE ROLE DEV_DBA;
 
--a new role has no privileges after creation, which we can validate by the following SQL. 
SHOW GRANTS TO ROLE DEV_DBA;

--provide the new role some privileges on the DEV database. 
GRANT ALL ON DATABASE DEV TO ROLE DEV_DBA;
GRANT ALL ON ALL SCHEMAS IN DATABASE DEV TO ROLE DEV_DBA;
GRANT ALL ON TABLE DEV.PUBLIC.CUSTOMER TO ROLE DEV_DBA;
SHOW GRANTS TO ROLE DEV_DBA;
 
--grant the DEV_DBA role to dev_dba_user1. 
USE ROLE SECURITYADMIN;
GRANT ROLE DEV_DBA TO USER dev_dba_user1;


--query tuning

USE SCHEMA SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL;

SELECT *
FROM store_returns,date_dim
WHERE sr_returned_date_sk = d_date_sk;



--optimized


SELECT 
d_year
,sr_customer_sk as ctr_customer_sk
,sr_store_sk as ctr_store_sk
,SR_RETURN_AMT_INC_TAX
FROM store_returns,date_dim
WHERE sr_returned_date_sk = d_date_sk;


--more optimized
SELECT 
d_year
,sr_customer_sk as ctr_customer_sk
,sr_store_sk as ctr_store_sk
,SR_RETURN_AMT_INC_TAX
FROM store_returns,date_dim
WHERE sr_returned_date_sk = d_date_sk
AND d_year = 1999;


-- list queries ordered by most time taken for execution
USE ROLE ACCOUNTADMIN;
USE SNOWFLAKE;

SELECT QUERY_ID, QUERY_TEXT, EXECUTION_TIME,USER_NAME 
FROM SNOWFLAKE.ACCOUNT_USAGE.query_history 
ORDER BY EXECUTION_TIME DESC;


-- find queries that are alike by grouping on the hash of the query text

USE ROLE ACCOUNTADMIN;
USE SNOWFLAKE;

SELECT QUERY_TEXT, USER_NAME, HASH(QUERY_TEXT) AS PSEUDO_QUERY_ID , 
COUNT(*) AS NUM_OF_QUERIES, SUM(EXECUTION_TIME) AS AGG_EXECUTION_TIME
FROM SNOWFLAKE.ACCOUNT_USAGE.query_history 
GROUP BY QUERY_TEXT, USER_NAME
ORDER BY AGG_EXECUTION_TIME DESC;

-- find the query id
USE ROLE ACCOUNTADMIN;
USE SNOWFLAKE;
SELECT QUERY_ID, QUERY_TEXT, USER_NAME, HASH(QUERY_TEXT) AS PSEUDO_QUERY_ID
FROM SNOWFLAKE.ACCOUNT_USAGE.query_history 
WHERE PSEUDO_QUERY_ID = <PSEUDO query id from previous step>;

-- use the query id to view query profiles
-- Use the Snowflake WebUI



-- create a database and tables which we will load through a fictitious  ETL process
CREATE DATABASE C6_R4;
CREATE TABLE lineitem_interim_processing (
	L_ORDERKEY NUMBER(38,0),
	L_PARTKEY NUMBER(38,0),
	L_SUPPKEY NUMBER(38,0),
	L_LINENUMBER NUMBER(38,0),
	L_QUANTITY NUMBER(12,2),
	L_EXTENDEDPRICE NUMBER(12,2),
	L_DISCOUNT NUMBER(12,2),
	L_TAX NUMBER(12,2),
	L_RETURNFLAG VARCHAR(1),
	L_LINESTATUS VARCHAR(1),
	L_SHIPDATE DATE,
	L_COMMITDATE DATE,
	L_RECEIPTDATE DATE,
	L_SHIPINSTRUCT VARCHAR(25),
	L_SHIPMODE VARCHAR(10),
	L_COMMENT VARCHAR(44)
);

CREATE TABLE order_reporting (
    Order_Ship_Date DATE,
    Quantity NUMBER(38,2),
	Price NUMBER(38,2),
	Discount NUMBER(38,2)
);




-- as part of the ETL process delete from the interim processing table
DELETE FROM lineitem_interim_processing;

-- as part of the ETL process insert data into the interim processing table
INSERT INTO lineitem_interim_processing
SELECT * FROM 
snowflake_sample_data.tpch_sf1.lineitem
WHERE l_shipdate BETWEEN dateadd(day, -365, to_date('1998-12-31')) AND to_date('1998-12-31');


-- delete last 7 days of data from the target table
DELETE FROM order_reporting WHERE Order_Ship_Date >  dateadd(day, -7, to_date('1998-12-01'));

-- insert data into the target table that
-- wasn't already loaded
INSERT INTO order_reporting
SELECT 
    L_SHIPDATE AS Order_Ship_Date,
    SUM(L_QUANTITY) AS Quantity,
    SUM(L_EXTENDEDPRICE) AS Price,
    SUM(L_EXTENDEDPRICE) AS Discount
FROM lineitem_interim_processing
WHERE Order_Ship_Date NOT IN (SELECT Order_Ship_Date FROM order_reporting)
GROUP BY Order_Ship_Date;

-- as we do not need data in the interim table, we will now delete all the data from it.
DELETE FROM lineitem_interim_processing;




-- list the storage metrics and view the active bytes, time travel bytes etc.
USE ROLE ACCOUNTADMIN;
SELECT * FROM C6_R4.INFORMATION_SCHEMA.TABLE_STORAGE_METRICS
WHERE TABLE_CATALOG='C6_R4';

-- recreate the interim processing table by using the TRANSIENT keyword
--which will ensure that the table does not store time travel data or failsafe data
DROP TABLE lineitem_interim_processing;
CREATE TRANSIENT TABLE lineitem_interim_processing (
	L_ORDERKEY NUMBER(38,0),
	L_PARTKEY NUMBER(38,0),
	L_SUPPKEY NUMBER(38,0),
	L_LINENUMBER NUMBER(38,0),
	L_QUANTITY NUMBER(12,2),
	L_EXTENDEDPRICE NUMBER(12,2),
	L_DISCOUNT NUMBER(12,2),
	L_TAX NUMBER(12,2),
	L_RETURNFLAG VARCHAR(1),
	L_LINESTATUS VARCHAR(1),
	L_SHIPDATE DATE,
	L_COMMITDATE DATE,
	L_RECEIPTDATE DATE,
	L_SHIPINSTRUCT VARCHAR(25),
	L_SHIPMODE VARCHAR(10),
	L_COMMENT VARCHAR(44)
);





--create a new database. 
CREATE DATABASE C6_R5;

-- execute a configuration change 
-- so that for the following steps Snowflake does not use caching for the sesion
ALTER SESSION SET USE_CACHED_RESULT=FALSE; 

--create a simple table called SENSOR_DATA to hold demo data
CREATE OR REPLACE TABLE SENSOR_DATA(
   CREATE_TS BIGINT,
   SENSOR_ID BIGINT,
   SENSOR_READING INTEGER
);


--insert demo data into the table.
INSERT INTO SENSOR_DATA
SELECT
    (SEQ8())::BIGINT AS CREATE_TS
    ,UNIFORM(1,99,RANDOM(1111))::BIGINT SENSOR_ID
    ,UNIFORM(1,99,RANDOM(2222))::INTEGER SENSOR_READING
FROM TABLE(GENERATOR(ROWCOUNT => 100))
ORDER BY CREATE_TS;


-- change clustering on create_ts
ALTER TABLE SENSOR_DATA  CLUSTER BY (CREATE_TS);

--run a couple of queries on each of the columns
SELECT 
COUNT(*) CNT
,AVG(SENSOR_READING) MEAN_SENSOR_READING
FROM SENSOR_DATA WHERE CREATE_TS 
BETWEEN 10 AND 100;
 
SELECT 
COUNT(*) CNT, 
AVG(SENSOR_READING)  MEAN_SENSOR_READING 
FROM SENSOR_DATA 
WHERE SENSOR_ID BETWEEN 100 AND 101;
 
--create a materialized view
CREATE OR REPLACE MATERIALIZED VIEW MV_SENSOR_READING(CREATE_TS, SENSOR_ID, SENSOR_READING) 
CLUSTER BY (SENSOR_ID) AS
SELECT CREATE_TS, SENSOR_ID, SENSOR_READING
FROM SENSOR_DATA;


--rerun the second query in step 6 that did not perform well before. 
--we should see a reduction in execution time
SELECT COUNT(*) CNT, AVG(SENSOR_READING)  MEAN_SENSOR_READING 
FROM MV_SENSOR_READING 
WHERE SENSOR_ID BETWEEN 1 AND 101000;




--Create a new database
CREATE DATABASE C6_R6;

-- create table that will hold the transaction data:
CREATE TABLE TRANSACTIONS
(
  TXN_ID STRING,
  TXN_DATE DATE,
  CUSTOMER_ID STRING,
  QUANTITY DECIMAL(20),
  PRICE DECIMAL(30,2),
  COUNTRY_CD STRING
);

--Populate this table with dummy data using the SQL given in the code block that follows. 
--Run this step 8-10 times repeatedly to ensure that a large amount of data is inserted into the TRANSACTIONS table and many micro partitions are created. 
INSERT INTO TRANSACTIONS
SELECT
    UUID_STRING() AS TXN_ID
    ,DATEADD(DAY,UNIFORM(1, 500, RANDOM()) * -1, '2020-10-15') AS TXN_DATE
    ,UUID_STRING() AS CUSTOMER_ID
    ,UNIFORM(1, 10, RANDOM()) AS QUANTITY
    ,UNIFORM(1, 200, RANDOM()) AS PRICE
    ,RANDSTR(2,RANDOM()) AS COUNTRY_CD
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

--run a sample query simulating a report that needs to access the last 30 days of data and check the profile of this query
SELECT * FROM TRANSACTIONS 
WHERE TXN_DATE BETWEEN DATEADD(DAY, -31, '2020-10-15') AND '2020-10-15';

--change the clustering key to TXN_DATE. 
ALTER TABLE TRANSACTIONS CLUSTER BY ( TXN_DATE );

--re-run the same query and investigate if the clustering key has improved performance
SELECT * FROM TRANSACTIONS 
WHERE TXN_DATE BETWEEN DATEADD(DAY, -31, '2020-10-15') AND '2020-10-15';






CREATE DATABASE C7_R1;

-- creation of a table which will hold the transaction data.
CREATE TABLE TRANSACTIONS
(
  TXN_ID STRING,
  TXN_DATE DATE,
  CUSTOMER_ID STRING,
  QUANTITY DECIMAL(20),
  PRICE DECIMAL(30,2),
  COUNTRY_CD STRING
);

--populate this table with thousand rows of dummy data 
INSERT INTO TRANSACTIONS
SELECT
    UUID_STRING() AS TXN_ID
    ,DATEADD(DAY,UNIFORM(1, 500, RANDOM()) * -1, '2020-10-15') AS TXN_DATE
    ,UUID_STRING() AS CUSTOMER_ID
    ,UNIFORM(1, 10, RANDOM()) AS QUANTITY
    ,UNIFORM(1, 200, RANDOM()) AS PRICE
    ,RANDSTR(2,RANDOM()) AS COUNTRY_CD
FROM TABLE(GENERATOR(ROWCOUNT => 1000));




-- You will need to use the ACCOUNTADMIN role to create the share
USE ROLE ACCOUNTADMIN;
CREATE SHARE share_trx_data;

-- grant usage on the database & the schema in which our table is contained
-- this step is necessary to subsequently provide access to the table
GRANT USAGE ON DATABASE C7_R1 TO SHARE share_trx_data;
GRANT USAGE ON SCHEMA C7_R1.public TO SHARE share_trx_data;

-- add the transaction table to the share
-- We have provided SELECT permissions on the shared table so the consumer can 
GRANT SELECT ON TABLE C7_R1.public.transactions TO SHARE share_trx_data;

-- allow consumer account access on the Share
-- to find the consumer_account_number look at the URL of the snowflake
-- instance of the consumer. So if the URL is https://drb98231.us-east-1.snowflakecomputing.com/console#/internal/worksheet
-- the consumer account_number is drb98231
ALTER SHARE share_trx_data ADD ACCOUNT=nx66427;




-- List the inbound and outbound shares that are currently present in the system
USE ROLE ACCOUNTADMIN;
SHOW SHARES;

-- Find the share details by running describe. 
-- Always use provider_account.share_name
DESC SHARE mksnow.SHARE_TRX_DATA;


-- create a database in consumer snowflake instance based on the share.
CREATE DATABASE SHR_TRANSACTIONS FROM SHARE <provider_account_name_here>.SHARE_TRX_DATA;


--validate that the database is attached to the share.
DESC SHARE <provider_account_name_here>.SHARE_TRX_DATA;


-- query the table to confirm you can select data as a consumer
SELECT * FROM SHR_TRANSACTIONS.PUBLIC.TRANSACTIONS;