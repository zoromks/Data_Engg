--time travel


--start by creating a new database, followed by the creation of a table that will hold some sample customer data.
CREATE DATABASE C8_R1;
drop table CUSTOMER;

CREATE TABLE CUSTOMER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER
LIMIT 1000;
 
--validate that data has successfully been populated
SELECT * FROM CUSTOMER LIMIT 100;
 
--make note of the current time before running an update on the customer table. We will use this time stamp to see the data as it existed before our update. 
SELECT CURRENT_TIMESTAMP;--2026-02-05 23:50:43.659 -0800
 
--run an UPDATE on the customer table.  We will update the email address column for all rows.
UPDATE CUSTOMER SET C_EMAIL_ADDRESS = 'john.doe@gmail.com';
 
--Validate that the email address column has indeed been updated for the whole table.
SELECT DISTINCT C_EMAIL_ADDRESS FROM CUSTOMER;
 
--use the time travel functionality of Snowflake to view the data as it existed before the update. We will use the timestamp and the AT syntax, to travel back to how the table looked like at or before specific time. Replace the time stamp with the timestamp from the previous step
SELECT DISTINCT C_EMAIL_ADDRESS 
FROM CUSTOMER AT 
(TIMESTAMP => '2026-02-05 23:50:43.659 -0800'::timestamp_tz);
 
--now select all rows from the table and use them in a variety of ways as per your requirements. 
SELECT * 
FROM CUSTOMER AT 
(TIMESTAMP => '2026-02-05 23:50:43.659 -0800'::timestamp_tz);

--if you are not 100% sure of the time when the update was made, you can use the BEFORE syntax and provide an approximate timestamp.
-- replace <time_stamp> with an approximate timestamp of your choosing
SELECT DISTINCT C_EMAIL_ADDRESS 
FROM CUSTOMER BEFORE 
(TIMESTAMP => '2026-02-05 23:50:43.659'::timestamp_tz);




--start by creating a new database
--followed by the creation of a table that will hold some sample customer data
CREATE DATABASE C8_R2;
CREATE TABLE CUSTOMER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER
LIMIT 100000;
 
--validate that data has successfully been populated in the customer table.
SELECT * FROM CUSTOMER LIMIT 100;

--simulate an accidental DELETE
DELETE FROM CUSTOMER;

--Validate that all rows from the table have been deleted. To do so run the following SQL: 
SELECT * FROM CUSTOMER;

--query the query history to identify which query deleted all the rows.
SELECT QUERY_ID, QUERY_TEXT, DATABASE_NAME, SCHEMA_NAME, QUERY_TYPE
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TYPE = 'DELETE' 
AND EXECUTION_STATUS = 'SUCCESS'
AND DATABASE_NAME = 'C8_R1';


--use the timestamp and the BEFORE syntax, to travel back to how the table looked like before the delete was executed.
--replace the query_id with the appropriate query_id from the above statement
SELECT *
FROM CUSTOMER BEFORE
(STATEMENT => '01c23ab5-0001-7b0f-000d-839e00024406');
 
 
--undo the delete by inserting this data back into the table by using time travel. 
INSERT INTO CUSTOMER
SELECT *
FROM CUSTOMER BEFORE
(STATEMENT => '01c23ab5-0001-7b0f-000d-839e00024406');

--Validate that the data has been restored
SELECT * FROM CUSTOMER;





--start by creating a new database, followed by creation of a schema. 
CREATE DATABASE C8_R3;
CREATE SCHEMA SCHEMA1;

 
--create a test table called CUSTOMER in this schema. We will be using sample data provided by Snowflake to populate this table.
CREATE TABLE CUSTOMER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER
LIMIT 100000;

--create another test table call CUSTOMER_ADDRESS in this schema. Again, we will be using sample data provided by Snowflake to populate this table. 
CREATE TABLE CUSTOMER_ADDRESS AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.CUSTOMER_ADDRESS
LIMIT 1000;

--create another schema by the name of SCHEMA2.
USE DATABASE C8_R3;
CREATE SCHEMA SCHEMA2;
 
--create a test table call INVENTORY in this schema. We will be using sample data provided by Snowflake to populate this table.
CREATE TABLE INVENTORY AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.INVENTORY
LIMIT 1000;

--drop the customer table from the CUSTOMER schema.
USE SCHEMA SCHEMA1;
DROP TABLE CUSTOMER;
 
--programmatically find out the tables that may have been dropped
--Tables which have been dropped will have a non-NULL date value in the TABLE_DROPPED column.
USE ROLE ACCOUNTADMIN;
SELECT TABLE_CATALOG, TABLE_SCHEMA,TABLE_NAME,
ID,CLONE_GROUP_ID, TABLE_CREATED, TABLE_DROPPED 
FROM INFORMATION_SCHEMA.TABLE_STORAGE_METRICS WHERE TABLE_CATALOG = 'C8_R1';

--Let us now restore the dropped table.
USE SCHEMA SCHEMA1;
UNDROP TABLE CUSTOMER;
 
--Validate that the table is indeed available now
SELECT COUNT(*) FROM CUSTOMER;

--drop the whole SCHEMA1 schema.
DROP SCHEMA SCHEMA1;
 
--Restore the schema.
UNDROP SCHEMA SCHEMA1;


--cloning

--start by creating a new database called PRODUCTION_DB, which signifies that the database contains production data. We will also create a schema called SRC_DATA, which signifies that it contains raw data from the source systems.
CREATE DATABASE PRODUCTION_DB;
CREATE SCHEMA SRC_DATA;

--create a test table call INVENTORY in this schema. We will be using sample data provided by Snowflake to populate this table.
CREATE TABLE INVENTORY AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.INVENTORY
LIMIT 1000;

--create another test table called ITEM in this schema. Again, we will be using sample data provided by Snowflake to populate this table.
CREATE TABLE ITEM AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.ITEM
LIMIT 1000;

--create another schema by the name of ACCESS_LAYER.
USE DATABASE PRODUCTION_DB;
CREATE SCHEMA ACCESS_LAYER;

--create a test table call STORE_SALES in this schema. We will be using sample data provided by Snowflake to populate this table.
CREATE TABLE STORE_SALES AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.STORE_SALES
LIMIT 1000;

--make note of the current time as we would need that information to clone our production database as it existed at a specific time.
SELECT CURRENT_TIMESTAMP; --2026-02-06 02:48:11.216 -0800
 
--check the count of rows in each table so that when we clone the database in conjunction with time travel, we can demonstrate the database is cloned at a time before additional data was added to the table.
SELECT COUNT(*) FROM PRODUCTION_DB.SRC_DATA.INVENTORY;
SELECT COUNT(*) FROM PRODUCTION_DB.SRC_DATA.ITEM;
SELECT COUNT(*) FROM PRODUCTION_DB.ACCESS_LAYER.STORE_SALES;

--insert more data into all the tables in our PRODUCTION_DB database, simulating how a normal ETL run may execute every day. 
INSERT INTO PRODUCTION_DB.SRC_DATA.INVENTORY
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.INVENTORY
LIMIT 2000;

INSERT INTO PRODUCTION_DB.SRC_DATA.ITEM
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.ITEM
LIMIT 2000;

INSERT INTO PRODUCTION_DB.ACCESS_LAYER.STORE_SALES
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.STORE_SALES
LIMIT 2000;

--clone the PRODUCTION_DB database into DEV_1 database, and while doing so also go back in time when the table only had the initial set of rows.
CREATE DATABASE DEV_1 CLONE PRODUCTION_DB AT(TIMESTAMP => '2026-02-06 02:48:11.216 -0800'::timestamp_tz);

--the DEV_1 database is cloned from PRODUCTION_DB database however it should contain only 100,000 rows that were originally inserted in the tables. Validate that by running count queries on the tables in DEV_1 database.
SELECT COUNT(*) FROM DEV_1.SRC_DATA.INVENTORY;
SELECT COUNT(*) FROM DEV_1.SRC_DATA.ITEM;
SELECT COUNT(*) FROM DEV_1.ACCESS_LAYER.STORE_SALES;





--create a new database called PRD, which signifies that the database contains production data. We will also two  schemas called SRC_DATA, INTEGRATED_DATA & REPORTING_DATA.
CREATE DATABASE PRD;
CREATE SCHEMA SRC_DATA;
CREATE SCHEMA INTEGRATED_DATA;
CREATE SCHEMA REPORTING_DATA;

--create a series of tables in these databases. 
USE SCHEMA SRC_DATA;
CREATE TABLE CUSTOMER AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;

USE SCHEMA SRC_DATA;
CREATE TABLE LINEITEM AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;

USE SCHEMA INTEGRATED_DATA;
CREATE TABLE ORDERS AS 
SELECT * FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;


--create a reporting view to demonstrate that views also get cloned.
USE SCHEMA REPORTING_DATA;
CREATE VIEW REVENUE_REPORT AS 
SELECT
L_RETURNFLAG,
L_LINESTATUS,
SUM(L_QUANTITY) AS SUM_QTY,
SUM(L_EXTENDEDPRICE) AS SUM_BASE_PRICE,
SUM(L_EXTENDEDPRICE * (1-L_DISCOUNT)) AS SUM_DISC_PRICE,
SUM(L_EXTENDEDPRICE * (1-L_DISCOUNT) * (1+L_TAX)) AS SUM_CHARGE,
AVG(L_QUANTITY) AS AVG_QTY,
AVG(L_EXTENDEDPRICE) AS AVG_PRICE,
AVG(L_DISCOUNT) AS AVG_DISC,
COUNT(*) AS COUNT_ORDER
FROM PRD.SRC_DATA.LINEITEM
WHERE L_SHIPDATE <= DATEADD(DAY, -90, TO_DATE('1998-12-01'))
GROUP BY L_RETURNFLAG,L_LINESTATUS;

--create a brand-new development environment for this PRD database, and we will create it with data. 
CREATE DATABASE DEV_DB_1 CLONE PRD;
 
--validate that the new environment has all the required objects. To do so, expand the database tree in the left side of the Snowflake Web UI, you should see the following structure of database, schemas, tables & views.
 
--validate that there is actual data in the cloned tables.
SELECT COUNT(*) FROM DEV_DB_1.SRC_DATA.CUSTOMER;

--validate that there is actual data in the cloned views.
SELECT COUNT(*) FROM DEV_DB_1.REPORTING_DATA.REVENUE_REPORT;
 
--create a testing environment from the production environment.
CREATE DATABASE TEST_1 CLONE PRD;

--create a new development environment from the existing development environment. To do so run the following SQL:
CREATE DATABASE DEV_DB_2 CLONE DEV_DB_1;


--timastamp manage

CREATE DATABASE C9_R1;
CREATE TABLE c9r1_date_test (date_id INTEGER, date_value DATE);
INSERT INTO c9r1_date_test (date_id, date_value)
Values
(1, to_date('2019-12-19','YYYY-MM-DD'));

--The DATE datatype is not limited to take dates only. It can take timestamp values as well. But it will ignore the time component of the input.
INSERT INTO c9r1_date_test (date_id, date_value) 
VALUES
(2, TO_TIMESTAMP('2019.12.21 04:00:00', 'YYYY.MM.DD HH:MI:SS'));

--Another variation is to use the to_date function but pass time only. It can take time values, but it assumes the value of Jan 01, 1970 for the date, completely ignoring the time value.
INSERT INTO c9r1_date_test (date_id, date_value) 
VALUES
(3, TO_DATE ('08:00:00', 'HH:MI:SS'));

--select data in the table.
SELECT * FROM c9r1_date_test; 
 

--create a new table with a timestamp type column to demonstrate how Snowflake manages time zones.
CREATE TABLE c9r1_ts_test (ts_id INTEGER, ts_value TIMESTAMP);

--investigate the session object and how it can be used to manage time zones. Session holds various objects where each object has a default value. To find out values of all objects in the session that are related to time zone, run the following command.
SHOW PARAMETERS LIKE '%TIMEZONE%' IN SESSION;

--set the user defined value for time zone to use with data.
ALTER SESSION SET TIMEZONE='Australia/Sydney';

--re-run the command for session to view the updated value..
SHOW PARAMETERS LIKE '%TIMEZONE%' IN SESSION;

--insert a time stamp value.
INSERT INTO c9r1_ts_test (ts_id, ts_value)
VALUES (1, '2020-11-19 22:00:00.000'); 

--select the data from this table by running the following command.
SELECT * FROM c9r1_ts_test; 

--change another session parameter. We shall change how timestamp data is managed by Snowflake. For that we shall be updating the value of the parameter TIMESTAMP_TYPE_MAPPING. 
ALTER SESSION SET TIMESTAMP_TYPE_MAPPING = 'TIMESTAMP_LTZ';
ALTER SESSION SET TIMEZONE = 'Australia/Sydney';
CREATE OR REPLACE TABLE c9r1_test_ts (ts TIMESTAMP);
INSERT INTO c9r1_test_ts VALUES ('2020-11-19 22:00:00.000');
SELECT ts FROM c9r1_test_ts;

--change how the timestamp value with a different time zone is handled. The timestamp value corresponds to a time zone of Australia/Perth (+0800 w.r.t. UTC)
CREATE OR REPLACE TABLE c9r1_test_ts (ts TIMESTAMP);
INSERT INTO c9r1_test_ts VALUES ('2020-11-19 22:00:00.000 +0800');
SELECT ts FROM c9r1_test_ts;




--use the seq4() function to generate list of numbers from 0 to 364. These numbers will be added to the first date of year 2021. To generate 365 rows, the following code uses GENERATOR() function in Snowflake. 
SELECT (to_date('2020-01-01') + seq4()) cal_dt
FROM TABLE(GENERATOR(ROWCOUNT => 365));

select seq4() from table(generator(rowcount=>10));
 
--start adding functions to extract date parts. In this step we will extract day, month and year from the date using DATE_PART() function.
SELECT (to_date('2020-01-01') + seq4()) cal_dt,
DATE_PART(day, cal_dt) as cal_dom, --day of month
DATE_PART(month, cal_dt) as cal_month, --month of year
DATE_PART(year, cal_dt) as cal_year --year
FROM TABLE(GENERATOR(ROWCOUNT => 365));
 
--enhance it with more fields. We are going to add the first and last day of the month, against each date in our dataset. We add two columns as shown in the code listing.
SELECT 
(to_date('2021-01-01') + seq4()) cal_dt
,DATE_PART(day, cal_dt) as cal_dom --day of month
,DATE_PART(month, cal_dt) as cal_month --month of year
,DATE_PART(year, cal_dt) as cal_year --yearSS
,DATE_TRUNC('month', CAL_DT) as cal_first_dom
,DATEADD('day', -1,
  DATEADD('month', 1,
  DATE_TRUNC('month', CAL_DT))) as cal_last_dom 
FROM TABLE(GENERATOR(ROWCOUNT => 365)); 

 
--add the English name of the month to the above dataset. Use the DECODE function to get to the English name of the month as shown in the following code. 
SELECT (to_date('2021-01-01') + seq4()) cal_dt
,DATE_PART(day, cal_dt) as cal_dom --day of month
,DATE_PART(month, cal_dt) as cal_month --month of year
,DATE_PART(year, cal_dt) as cal_year --yearSS
,DATE_TRUNC('month', CAL_DT) cal_first_dom
,DATEADD('day', -1,
  DATEADD('month', 1,
  DATE_TRUNC('month', CAL_DT))) cal_last_dom
,DECODE(CAL_MONTH,
           1, 'January',
           2, 'February',
           3, 'March',
           4, 'April',
           5, 'May',
           6, 'June',
           7, 'July',
           8, 'August',
           9, 'September',
           10, 'October',
           11, 'November',
           12, 'December') as cal_month_name
FROM TABLE(GENERATOR(ROWCOUNT => 365));
. 
 
--add a column to our dataset that captures the end of the quarter against each date. We would be using the DATE_TRUNC function passed with ‘quarter’ parameter to manage this. The process is similar to the used for arriving at the end of the month for each month. The following code shows the new column CAL_QTR_END_DT which represents the last date of the quarter.

SELECT (to_date('2021-01-01') + seq4()) cal_dt
,DATE_PART(day, cal_dt) as cal_dom --day of month
,DATE_PART(month, cal_dt) as cal_month --month of year
,DATE_PART(year, cal_dt) as cal_year --yearSS
,DATE_TRUNC('month', CAL_DT) cal_first_dom
,DATEADD('day', -1,
  DATEADD('month', 1,
  DATE_TRUNC('month', CAL_DT))) cal_last_dom
,DECODE(CAL_MONTH,
           1, 'January',
           2, 'February',
           3, 'March',
           4, 'April',
           5, 'May',
           6, 'June',
           7, 'July',
           8, 'August',
           9, 'September',
           10, 'October',
           11, 'November',
           12, 'December') as cal_month_name
,DATEADD('day', -1,
  DATEADD('month', 3,
  DATE_TRUNC('quarter', CAL_DT))) as CAL_QTR_END_DT
FROM TABLE(GENERATOR(ROWCOUNT => 365));




--unique counts


-- perform a SELECT query on Orders table available in the database SNOWFLAKE_DEMO_DB, schema TPCH_SF1000. 
select * 
from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS"
sample row (1000 rows);

--execute a count on the O_CUSTKEY column while applying grouping on O_ORDERPRIORITY. 
select 
O_ORDERPRIORITY
,count(O_CUSTKEY)
from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS"
group by 1
order by 1;


--to stop Snowflake from using results from cache , we shall change one setting. We shall alter the session and set USE_CACHED_RESULT to FALSE first
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

--calculate the same count but with a variation this time. We will apply a DISTINCT on the O_CUSTKEY column, so that customers with repeat orders are counted once.
SELECT O_ORDERPRIORITY
,count(DISTINCT O_CUSTKEY)
from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF1000"."ORDERS"
group by 1
order by 1;

 

--try the same thing but this time, we shall use the APPROX_COUNT_DISTINCT function on the O_CUSTKEY column, rather than the COUNT(DISTINCT …) function used in step 3.
select O_ORDERPRIORITY
,APPROX_COUNT_DISTINCT(O_CUSTKEY)
from "SNOWFLAKE_SAMPLE_DATA"."TPCH_SF100"."ORDERS"
group by 1
order by 1;





--managing transactions


--create a database called CHAPTER9.
CREATE DATABASE CHAPTER9;
USE CHAPTER9;
--create two tables to use in this recipe. One table is supposed to store debit in an account and the other one shall store credits. The tables will be updated/inserted in a transaction. 
CREATE TABLE c9r4_credit (
account int
,amount int
,payment_ts timestamp
);

CREATE TABLE c9r4_debit (
account int
,amount int
,payment_ts timestamp
);



-- create a stored procedure that will be used in a transaction. To explain different scenarios, we have introduced a random error in the stored procedure by using a random number. If that error is hit, the query statement is not executed, and the stored procedure executes a roll back. 
create or replace procedure sp_adjust_credit ()
    returns string
    language javascript
    as
    $$
    
    var sql_command = "";
    if ((Math.floor(Math.random() + 0.5) == 0)){
        sql_command = "insert into CHAPTER9.PUBLIC.C9R4_CREDIT select * from CHAPTER9.PUBLIC.C9R4_DEBIT where CHAPTER9.PUBLIC.C9R4_DEBIT.payment_ts > (select IFF(max(payment_ts) IS NULL,to_date('1970-01-01'),max(payment_ts)) from CHAPTER9.PUBLIC.C9R4_CREDIT)";
    }else{
        snowflake.execute (
            {sqlText: "rollback"}
        );
        return "Failed randomly";   // Return a success/error indicator.
    }
        
    try {
        snowflake.execute (
            {sqlText: sql_command}
            );
        return "Succeeded.";   // Return a success/error indicator.
        }
    catch (err)  {
        
        snowflake.execute (
            {sqlText: "rollback"}
        );
        return "Failed: " + err;   // Return a success/error indicator.
        }
    $$;

--use the above stored procedure sp_adjust_credit() within a transaction, preceded by an INSERT into the C9R4_CREDIT.  
begin transaction;
insert into c9r4_debit values (1,100,current_timestamp());
call sp_adjust_credit();
commit;
 

--repeat the above process, but with account column set to 2 this time.
begin transaction;
insert into c9r4_debit values (2,100,current_timestamp());
--call the procedure and follow that by a commit.
call sp_adjust_credit();
commit;

select * from c9r4_debit;

select * from C9R4_CREDIT;



--analytical functions

--create if not exists
create database chapter9; 
use chapter9;

-- The view has the logic to generate 365 records
create or replace view c9r5_vw as 
select
    mod(seq4(),5) as customer_id
    ,(mod(uniform(1,100,random()),5) + 1)*100 as deposit
    ,dateadd(day, '-' || seq4(), current_date()) as deposit_dt
from
  table
    (generator(rowcount => 365));

select * from c9r5_vw;

--use this dataset to run a few window functions available in Snowflake.
SELECT
      customer_id,
      deposit_dt,
deposit,
      deposit > 
      COALESCE(SUM(deposit) OVER (
                 PARTITION BY customer_id 
                 ORDER BY deposit_dt
            	ROWS BETWEEN 2 PRECEDING AND 1 PRECEDING)
       , 0) AS hi_deposit_alert
FROM 
     c9r5_vw
ORDER BY 
      customer_id, deposit_dt desc;

--change the window range and use average rather than sum in this example. 
SELECT
      customer_id,
      deposit_dt,
      deposit,
      COALESCE(AVG(deposit) OVER (
                 PARTITION BY customer_id 
                 ORDER BY deposit_dt
            	ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING)
       , 0) as past_average_deposit,
      deposit >  past_average_deposit AS hi_deposit_alert
FROM 
     c9r5_vw
     
WHERE CUSTOMER_ID = 3
ORDER BY 
      customer_id, deposit_dt desc;


--generating sequence


--create a database where we will create the objects for this recipe. Within the database we will create a basic sequence object as shown below.
CREATE DATABASE C9_R6;
CREATE SEQUENCE SEQ1;

 
--select a value from this newly created sequence.
SELECT SEQ1.NEXTVAL;
 
--if we perform the same SELECT statement again, we will get the next value in the sequence, which in this case will be 2.
SELECT SEQ1.NEXTVAL;

 
--try executing several NEXTVAL in a single statement to validate that the function always returns unique values
SELECT SEQ1.NEXTVAL,SEQ1.NEXTVAL,SEQ1.NEXTVAL;

SELECT SEQ1.NEXTVAL,SEQ1.NEXTVAL;
 
--create a sequence that starts at 777 (rather then 1) and increments by 100 (rather then 1). 
CREATE SEQUENCE SEQ_SPECIAL
START WITH =  777
INCREMENT BY = 100;
 
--test the preceding sequence
SELECT SEQ_SPECIAL.NEXTVAL,SEQ_SPECIAL.NEXTVAL,SEQ_SPECIAL.NEXTVAL;


--create a new table and insert data into one of its columns using a sequence.  
--Let us create the table first. 
CREATE TABLE T1 
(
  CUSTOMER_ID INTEGER,
  CUSTOMER_NAME STRING
);
-- create a sequence that will be used for populating auto-increment values in the CUSTOMER_ID column.
CREATE SEQUENCE T1_SEQ;

-- use the sequence in the INSERT INTO statement to populate data.
INSERT INTO T1
SELECT T1_SEQ.NEXTVAL,
        RANDSTR(10, RANDOM())
FROM
  TABLE
    (generator(rowcount => 50));

SELECT * FROM T1;
 
--define the default value for a table column to be the sequence next value.
CREATE SEQUENCE T2_SEQ;
CREATE TABLE T2 
(
  CUSTOMER_ID INTEGER DEFAULT T2_SEQ.NEXTVAL,
  CUSTOMER_NAME STRING
);

--insert data into this table but omit the CUSTOMER_ID while inserting
INSERT INTO T2 (CUSTOMER_NAME)
SELECT RANDSTR(10, RANDOM())
FROM
  TABLE
    (generator(rowcount => 500));

--check the data in the table
SELECT * FROM T2;




--UDF

--start by creating a database, in which we will create our SQL scalar UDFs. 
CREATE DATABASE C10_R1;

--create a quite simple UDF that squares the value that is provided as the input.
CREATE FUNCTION square(val float)
RETURNS float
AS
$$
  val * val
$$
;

--test this function by calling it in a SELECT statement. 
SELECT square(5);


--create a slightly more complicated function that can apply a tax percentage (10% in this case) and return us the profit after tax deduction. 
CREATE FUNCTION profit_after_tax(cost float, revenue float)
RETURNS float
AS
$$
  (revenue - cost) * (1 - 0.1)
$$
;

--call the function with a simple SELECT statement
SELECT profit_after_tax(100,120);

--call this UDF in the SELECT list as well as the WHERE clause.
SELECT DD.D_DATE, SUM(profit_after_tax(SS_WHOLESALE_COST,SS_SALES_PRICE)) AS real_profit 
FROM SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.STORE_SALES SS 
INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCDS_SF10TCL.DATE_DIM DD
ON SS.SS_SOLD_DATE_SK = DD.D_DATE_SK
WHERE DD.D_DATE BETWEEN '2003-01-01' AND '2003-12-31' 
AND profit_after_tax(SS_WHOLESALE_COST,SS_SALES_PRICE) < -50
GROUP BY DD.D_DATE;




--start by creating a database, in which we will create our SQL tabular UDFs.
CREATE DATABASE C10_R2;
USE DATABASE C10_R2;
USE SCHEMA PUBLIC;

--run an out of the box table function provided by Snowflake to see how to call table functions
SELECT *
FROM TABLE(information_schema.query_history_by_session())
ORDER BY start_time;

 
--create a quite simple table function using SQL. The function will return the name of a location and the time zone that the location has. To keep things simple, we will use hard coded values. 
CREATE FUNCTION LocationTimeZone()
RETURNS TABLE(LocationName String, TimeZoneName String)
as
$$
    SELECT 'Sydney', 'GMT+11'
    UNION
    SELECT 'Auckland', 'GMT+13'
    UNION
    SELECT 'Islamabad', 'GMT+5'
    UNION
    SELECT 'London', 'GMT'
$$;

--call this function.
SELECT * FROM TABLE(LocationTimeZone());

select LocationTimeZone();--error

 --you can treat this output as any other relational table, so you can add where clauses and select only particular columns. To do so run the following SQL:
SELECT TimeZoneName FROM TABLE(LocationTimeZone())
WHERE LocationName = 'Sydney';

--We do not have to hardcode values in a table function but rather we can select from existing tables and even join tables with-in our function definition. Let’s create such a table function which joins data from two table to produce an output.
CREATE FUNCTION CustomerOrders()
RETURNS TABLE(CustomerName String, TotalSpent Number(12,2))
as
$$
    SELECT C.C_NAME AS CustomerName, SUM(O.O_TOTALPRICE) AS TotalSpent
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O 
    INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C
    ON C.C_CUSTKEY = O.O_CUSTKEY
    GROUP BY C.C_NAME
$$;

--call this function to review the output. 
SELECT * FROM TABLE(CustomerOrders());


--alter the function so that it can take customer name as a parameter. 
CREATE FUNCTION CustomerOrders(CustomerName String)
RETURNS TABLE(CustomerName String, TotalSpent Number(12,2))
as
$$
    SELECT C.C_NAME AS CustomerName, SUM(O.O_TOTALPRICE) AS TotalSpent
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS O 
    INNER JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER C
    ON C.C_CUSTKEY = O.O_CUSTKEY
    WHERE C.C_NAME = CustomerName
    GROUP BY C.C_NAME
$$;

--it is important to understand that we have created two functions here. One function called CustomerOrders that does not take any parameter and another with the same name that accepts the name as a parameter. To demonstrate this run the following SQL.
SHOW FUNCTIONS LIKE '%CustomerOrders%';


--Let us now call the new function by passing in a customer name as a paramter.
SELECT * FROM TABLE(CustomerOrders('Customer#000062993'));


--udf with java

--start by creating a database, in which we will create our JavaScript based scalar UDFs.
CREATE DATABASE C10_R3;

--create a very simple UDF that squares the value that is provided as the input. we must capitalize the parameter name when used in the function definition. This can be seen in the code below, where the input parameter val was used in the uppercase and used as VAL.
CREATE FUNCTION square(val float)
RETURNS float
LANGUAGE JAVASCRIPT  
AS
  'return VAL * VAL;'
;

--test this function by calling it in a SELECT statement
SELECT square(5);
--The statement will output the value 25 as expected. 

--create a recursive JavaScript UDF. We will be creating a simple factorial function which will recursively call itself to calculate factorial of the input value.
CREATE FUNCTION factorial(val float)
RETURNS float
LANGUAGE JAVASCRIPT  
AS
$$
    if ( VAL == 1 ){
        return VAL;
    }
    else{
        return VAL * factorial(VAL -1);
    }
$$
;

--try out the factorial function by invoking the function in a select statement, as shown as follows.
SELECT factorial(5);




--start by creating a database, in which we will create our SQL tabular UDFs.
CREATE DATABASE C10_R4;
USE DATABASE C10_R4;
USE SCHEMA PUBLIC;

--run an out of the box table function provided by Snowflake to see how to call table functions and review the results returned by that function. The function that we are going to use is used for generating rows of random data and is a handy function for various scenario. The function is aptly called GENERATOR. Let us call this function to generate 10 rows of data. To do so run the command below.
SELECT seq4() AS incremental_id, mod(random(),5000) AS a_random_number
FROM TABLE(generator(rowcount => 10));

--create a quite simple table function using JavaScript. The function will return the 2 letter ISO code for a country. To keep things simple, we will use hard coded values for this initial example.  Run the following SQL to create this function.
CREATE FUNCTION CountryISO()
RETURNS TABLE(CountryCode String, CountryName String)
LANGUAGE JAVASCRIPT
AS
$$
   {
   processRow: function f(row, rowWriter, context){
       rowWriter.writeRow({COUNTRYCODE: "AU",COUNTRYNAME: "Australia"});
       rowWriter.writeRow({COUNTRYCODE: "NZ",COUNTRYNAME: "New Zealand"});   
       rowWriter.writeRow({COUNTRYCODE: "PK",COUNTRYNAME: "Pakistan"});   
       }
    }    
$$;

--call this function.
SELECT * FROM TABLE(CountryISO());

--you can treat this output as any other relational table, so you can add where clauses and select only particular columns.
SELECT COUNTRYCODE FROM TABLE(CountryISO()) WHERE CountryCode = 'PK';

--We do not have to hardcode values in a table function but rather we can select data from existing table and process on each row. Let’s create such a java script-based table function which processes on values for each row of a table produces the count of character for the input.
CREATE FUNCTION StringSize(input String)
RETURNS TABLE (Size FLOAT)
LANGUAGE JAVASCRIPT
AS 
$$
{
    processRow: function f(row, rowWriter, context) {
      rowWriter.writeRow({SIZE: row.INPUT.length});
    }
}
$$;

--call this function to review the output. Now, we can call this function for a single value but that is not very useful, however, let’s call for a single value to demonstrate the concept.
SELECT * FROM TABLE(StringSize('TEST'));

--you can join this newly created table function with another table and have the table function process multiple rows. 
SELECT * FROM 
SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION, TABLE(StringSize(N_NAME));