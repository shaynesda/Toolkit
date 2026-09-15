/********************************************************************
**  Name: Daily vs. Quarterly
**  Refactored Date: 6/22/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES,
**                                                 PRESENTATION.EDW)
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**                 SITES = DIM_ULTIMATE
**    **
**  Description: 
**
********************************************************************/

--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;


select * FROM SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm LIMIT 200;        -------------------------------USE SNAPSHOT BEFORE NEW TIERING

--------------------------------------------------------------QUARTERLY-----------------------------------------------------------

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 AS
SELECT * FROM MART.OBT_CONSUMPTION_DAILY WHERE "Year Quarter" > 20251;

------------------------------
--SET START & END QUARTERS
------------------------------
SET START_QUARTER = 20201; --how far back to report
SET END_QUARTER = 20254; --reporting quarter


---------------------------------
--QUARTERLY CONSUMPTION GROWTH
---------------------------------

select distinct
    cm."Year Quarter" as year_quarter,
    cm."Unique User" as unique_user
from MART.OBT_CONSUMPTION_DAILY cm
join MART.DIM_PRODUCT p on p."Product ID" = cm."Product ID"
where cm."In Contracts" = 'Yes' 
  and cm."Year Quarter" between 20251 and 20261
  and p."Brand" in ('ProjectWise', 'Connect'); 

desc table SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26;

--STAGING:
--Step 1: Daily PW rollup p/ person p/ quarter p/ Ultimate 
CREATE OR REPLACE TEMP TABLE PWAppDays AS
SELECT 
    cm."Year Quarter" as Year_quarter,
    cm."Ultimate ID" as UltimateID,
    cm."Unique User" as Unique_Persona,
    SUM(CASE WHEN cm."Product ID" = 3379 THEN cm."Application Days" ELSE 0 END) AS App_Days_3379,
    SUM(CASE WHEN cm."Product ID" = 3380 THEN cm."Application Days" ELSE 0 END) AS App_Days_3380,
    SUM(CASE WHEN cm."Product ID" = 3381 THEN cm."Application Days" ELSE 0 END) AS App_Days_3381
--FROM consumption_metrics cm
FROM MART.OBT_CONSUMPTION_DAILY cm --SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm
JOIN MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
WHERE s."Ultimate Commercial Program" = 'E365'
  AND cm."In Contracts" = 'Yes' 
  AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER 
--AND cm."Product ID" in (3379,3380,3381)
GROUP BY ALL
order by cm."Year Quarter", cm."Ultimate ID";

--select * from PWAppDays;


--Step 2: Take highest tier p/ user p/ quarter
CREATE OR REPLACE TEMP TABLE PWAppDaysHighestRanked AS
SELECT 
    UltimateID,
    Year_quarter,
    Unique_Persona,
    CASE 
        WHEN App_Days_3381 > 0 THEN 3381
        WHEN App_Days_3380 > 0 THEN 3380
        WHEN App_Days_3379 > 0 THEN 3379
        ELSE NULL 
    END AS Highest_Ranked_Product
FROM PWAppDays
ORDER BY Year_quarter, UltimateID, Unique_Persona;

--select * from PWAppDaysHighestRanked;


--Step 3: Join to pricebook for quarterly prices
CREATE OR REPLACE TEMP TABLE PWAppDaysHighestRankedWithPrice AS
SELECT 
    pwr.UltimateID,
    pwr.Year_quarter,
    pwr.Unique_Persona,
    pwr.Highest_Ranked_Product,
    ep.E365_GROSS_PRICE AS Quarterly_PW_Consumption
FROM PWAppDaysHighestRanked pwr
JOIN SANDBOX.FPANDA.E365_PRICEBOOK_BIRD ep --  e365_pricebook_all ep 
    ON pwr.Highest_Ranked_Product = ep.PRODUCTID
WHERE 1=1
  AND ep.PRICEBOOK = 'Global'
  AND ep.ITERATION = '7'
 -- AND ep.application_type = 'Visa' -- Where do we get application type for PRICEBOOK?
 -- AND ep.PRODUCTID IN (3379, 3380, 3381)
ORDER BY pwr.Year_quarter, pwr.UltimateID, pwr.Unique_Persona;

--select * from PWAppDaysHighestRankedWithPrice;



--Roll up by quarter for growth (pivot out in Excel)
SELECT 
    Year_quarter,
    SUM(Quarterly_PW_Consumption) AS Total_Quarterly_PW_Consumption
FROM PWAppDaysHighestRankedWithPrice
GROUP BY Year_quarter
ORDER BY Year_quarter;

---------------------------------
--QUARTERLY APP DAY GROWTH
---------------------------------

--STAGING:
--Step 1: Daily PW rollup p/ person p/ quarter p/ Ultimate 
CREATE OR REPLACE TEMP TABLE PWAppDays AS
SELECT 
    cm."Year Quarter" as Year_quarter,
    cm."Ultimate ID" as UltimateID,
    cm."Unique User" as Unique_Persona,
    SUM(CASE WHEN cm."Product ID" = 3379 THEN cm."Application Days" ELSE 0 END) AS App_Days_3379,
    SUM(CASE WHEN cm."Product ID" = 3380 THEN cm."Application Days" ELSE 0 END) AS App_Days_3380,
    SUM(CASE WHEN cm."Product ID" = 3381 THEN cm."Application Days" ELSE 0 END) AS App_Days_3381
--FROM consumption_metrics cm
FROM SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm
JOIN MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
WHERE s."Ultimate Commercial Program" = 'E365'
  AND cm."In Contracts" = 'Yes'
  AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER 
  AND cm."Product ID" in (3379,3380,3381)
GROUP BY ALL
order by cm."Year Quarter", cm."Ultimate ID";

--select * from PWAppDays;


--Step 2: Take highest tier p/ user p/ quarter
CREATE OR REPLACE TEMP TABLE PWAppDaysHighestRanked AS
SELECT 
    UltimateID,
    Year_quarter,
    Unique_Persona,
    CASE 
        WHEN App_Days_3381 > 0 THEN 3381
        WHEN App_Days_3380 > 0 THEN 3380
        WHEN App_Days_3379 > 0 THEN 3379
        ELSE NULL 
    END AS Highest_Ranked_Product
FROM PWAppDays
ORDER BY Year_quarter, UltimateID, Unique_Persona;

--select * from PWAppDaysHighestRanked;


--Step 3: Roll up number of app days by instance p/ unique persona p/ quarter
SELECT 
    Year_quarter,
    Count(Highest_Ranked_Product) AS Total_App_Days
FROM PWAppDaysHighestRanked
GROUP BY Year_quarter
ORDER BY Year_quarter;


-----------------------------
--QUARTERLY USER GROWTH
-----------------------------

SELECT
    Year_Quarter,
    Count(Unique_Persona)
FROM PWAppDaysHighestRanked
GROUP BY ALL
ORDER BY Year_Quarter;




------------------------------------------------------------------DAILY--------------------------------------------------------

-----------------------------
--DAILY CONSUMPTION GROWTH
-----------------------------
--Daily consumption by quarter for all tiers
select 
    cm."Year Quarter" as Year_quarter,
    sum(cm."Normalized Consumption")
--from consumption_metrics cm
FROM  SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm -- MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
where cm."In Contracts" = 'Yes'
  AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER 
  AND s."Ultimate Commercial Program" = 'E365'
group by cm."Year Quarter"
order by cm."Year Quarter";



-----------------------------
--DAILY APP DAY GROWTH
-----------------------------
--Daily App Day by Quarter for All Tiers
select 
    cm."Year Quarter" as Year_quarter,
    sum(cm."Normalized Application Days")
--from consumption_metrics cm
FROM SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm --  MART.OBT_CONSUMPTION_DAILY cm 
JOIN MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
where cm."In Contracts" = 'Yes'
  AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER 
  --AND cm."Product ID" in (3379,3380,3381)
  AND s."Ultimate Commercial Program" = 'E365'
group by cm."Year Quarter"
order by cm."Year Quarter";


-----------------------------
--DAILY USER GROWTH
-----------------------------
select
    cm."Year Quarter" as Year_quarter,
    count(distinct cm."Unique User") AS PW_Users
FROM SANDBOX.FPANDA.CONSUMPTION_METRICS_JAN11_26 cm -- MART.OBT_CONSUMPTION_DAILY cm  
JOIN MART.DIM_ULTIMATE s on cm."Ultimate ID" = s."Ultimate ID"
where cm."In Contracts" = 'Yes'
  AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER 
  --AND cm."Product ID" in (3379,3380,3381)
  AND s."Ultimate Commercial Program" = 'E365'
group by cm."Year Quarter"
order by cm."Year Quarter";
