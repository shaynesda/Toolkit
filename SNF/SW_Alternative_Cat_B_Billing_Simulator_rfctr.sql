/********************************************************************
**  Name: SW_Alternative_Cat_B_Billing_Simulator
**  Refactored Date: 7/28/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                    CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**                               PRODUCTS = DIM_PRODUCT
**                                  SITES = OBT_SITE_EXPANDED
**                     E365_TERMS_HISTORY = E365_TERMS_HISTORY (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**                      
**
**
**  Description: 
**
********************************************************************/

--------------------------------------
--E365 ALTERNATIVE CAT B PRICING
--------------------------------------
--Bring 2 persisted tables in Sigma workbook, do simulations downstream (3 part process/3 persisted tables)


--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

---------------------------------------------------STEP 1) STAGE BREAK-EVEN PRICING OVER LAST LTM PERIOD-----------------------------------------------

-----------------------
--SET PARAMETERS
-----------------------
--LTM window (25Q2 LTM)
SET START_QUARTER = 20261;
SET END_QUARTER = 20262;


-----------------------
--BASE USAGE
-----------------------
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.BaseUsage AS
SELECT
    cm."Ultimate ID" as ULTIMATEID,
    cm."E365 Category" as E365_CATEGORY,
    cm."Product ID" as PRODUCTID,
    cm."Feature String" as FEATURE_STRING,
    cm."Daily Price" as DAILY_PRICE,
    cm."Unique User" as UNIQUE_PERSONA,
    cm."Usage Date" as USAGE_DATE,
    cm."Application Days" as APPLICATION_DAYS,
    cm."Year Quarter" as YEAR_QUARTER,
    c."Year Month Num" as USAGE_MONTH,
    cm."Consumption" as ACTUAL_CONSUMPTION
FROM MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.DIM_PRODUCT p ON p."Product ID" = cm."Product ID"
JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = cm."Ultimate ID"
JOIN MART.DIM_DATE c ON c."Date"=cm."Usage Date"
WHERE s."Ultimate Commercial Program" = 'E365'
    AND cm."In Contracts" = 'Yes'
    AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER
    AND p."Acquisition Source" NOT IN ('Seequent')
    AND cm."E365 Category" = 'Category A';

---------------------------------
--MONTHLY & QUARTERLY TOTALS
---------------------------------
--Per Ultimate × Product × Month
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Actuals_Monthly AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    USAGE_MONTH,
    SUM(ACTUAL_CONSUMPTION) AS ACTUAL_CONSUMPTION_MONTH
FROM SANDBOX.FPANDA.BaseUsage
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;


--Per Ultimate × Product × Quarter
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Actuals_Quarterly AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    YEAR_QUARTER,
    SUM(ACTUAL_CONSUMPTION) AS ACTUAL_CONSUMPTION_QTR
FROM SANDBOX.FPANDA.BaseUsage
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;


--Per Ultimate × Product over the LTM window
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Actuals_LTM AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(ACTUAL_CONSUMPTION) AS ACTUAL_CONSUMPTION_LTM,
    COUNT(DISTINCT USAGE_MONTH) AS ACTIVE_MONTHS,
    COUNT(DISTINCT YEAR_QUARTER) AS ACTIVE_QUARTERS
FROM SANDBOX.FPANDA.BaseUsage
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--------------------------
--BILLING UNITS
--------------------------

--Daily billing units: 1 per unique_persona per product per day (feature_string already handled in curation)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.DailyUnits AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(APPLICATION_DAYS) AS DAILY_BILLING_UNITS
FROM SANDBOX.FPANDA.BaseUsage
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--Monthly billing units: 1 per unique_persona per product per (highest) feature_string per month 
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.MonthlyUnits AS
WITH RankedMonthly AS (
    SELECT
        ULTIMATEID,
        PRODUCTID,
        FEATURE_STRING,
        USAGE_MONTH,
        UNIQUE_PERSONA,
        MAX(DAILY_PRICE) AS MAX_DAILY_PRICE,  --highest daily price that user hit for that feature_string in the month
        ROW_NUMBER() OVER (
            PARTITION BY ULTIMATEID, PRODUCTID, UNIQUE_PERSONA, USAGE_MONTH
            ORDER BY MAX(DAILY_PRICE) DESC, FEATURE_STRING ASC) AS rn
    FROM SANDBOX.FPANDA.BaseUsage
    GROUP BY ALL)
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    USAGE_MONTH,
    COUNT(DISTINCT UNIQUE_PERSONA) AS MONTHLY_BILLING_UNITS
FROM RankedMonthly
WHERE rn = 1 --only keep highest daily_price feature_string for each user per month
GROUP BY ALL
ORDER BY ULTIMATEID, PRODUCTID, FEATURE_STRING, USAGE_MONTH;



--Roll monthly units up to the Ultimate level (sum all monthly units)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.MonthlyUnits_LTM AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(MONTHLY_BILLING_UNITS) AS TOTAL_MONTHLY_BILLING_UNITS, --total across all months (in LTM view)
    COUNT(DISTINCT USAGE_MONTH) AS DISTINCT_ACTIVE_MONTHS  --count of active months
FROM SANDBOX.FPANDA.MonthlyUnits
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--Quarterly billing units: 1 per unique_persona per product per (highest) feature_string per quarter
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.QuarterlyUnits AS
WITH RankedQuarterly AS (
    SELECT
        ULTIMATEID,
        PRODUCTID,
        FEATURE_STRING,
        YEAR_QUARTER,
        UNIQUE_PERSONA,
        MAX(DAILY_PRICE) AS MAX_DAILY_PRICE,  --highest daily price that user hit for that feature_string in the quarter
        ROW_NUMBER() OVER (
            PARTITION BY ULTIMATEID, PRODUCTID, UNIQUE_PERSONA, YEAR_QUARTER
            ORDER BY MAX(DAILY_PRICE) DESC, FEATURE_STRING ASC) AS rn
    FROM SANDBOX.FPANDA.BaseUsage
    GROUP BY ALL)
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    YEAR_QUARTER,
    COUNT(DISTINCT UNIQUE_PERSONA) AS QUARTERLY_BILLING_UNITS
FROM RankedQuarterly
WHERE rn = 1 --only keep highest daily_price feature_string for each user per quarter
GROUP BY ALL
ORDER BY ULTIMATEID, PRODUCTID, FEATURE_STRING, YEAR_QUARTER;



--Roll quarterly units up to the Ultimate level (sum all quarterly units)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.QuarterlyUnits_LTM AS
SELECT
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(QUARTERLY_BILLING_UNITS) AS TOTAL_QUARTERLY_BILLING_UNITS, --total across all quarters
    COUNT(DISTINCT YEAR_QUARTER) AS DISTINCT_ACTIVE_QUARTERS  --count of active quarters
FROM SANDBOX.FPANDA.QuarterlyUnits
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--LTM totals of billing units per Ultimate × Product (daily, monthly, & quarterly)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Units_LTM AS
SELECT
    u.ULTIMATEID,
    u.PRODUCTID,
    COALESCE(u.FEATURE_STRING, 'NO_FEATURE') AS FEATURE_STRING,
    --Daily Units
    COALESCE(d.DAILY_BILLING_UNITS, 0) AS DAILY_UNITS_LTM,
    --Monthly Units
    COALESCE(m.TOTAL_MONTHLY_BILLING_UNITS, 0) AS MONTHLY_UNITS_LTM,
    COALESCE(m.DISTINCT_ACTIVE_MONTHS, 0) AS DISTINCT_ACTIVE_MONTHS,
    --Quarterly Units
    COALESCE(q.TOTAL_QUARTERLY_BILLING_UNITS, 0) AS QUARTERLY_UNITS_LTM,
    COALESCE(q.DISTINCT_ACTIVE_QUARTERS, 0) AS DISTINCT_ACTIVE_QUARTERS
FROM ( --distinct list of all Ultimate × Product × Feature_String combos
    SELECT DISTINCT 
        ULTIMATEID, 
        PRODUCTID, 
        FEATURE_STRING
    FROM SANDBOX.FPANDA.BaseUsage) u
LEFT JOIN SANDBOX.FPANDA.DailyUnits d
    ON d.ULTIMATEID = u.ULTIMATEID AND d.PRODUCTID = u.PRODUCTID
    AND COALESCE(d.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
LEFT JOIN SANDBOX.FPANDA.MonthlyUnits_LTM m
    ON m.ULTIMATEID = u.ULTIMATEID AND m.PRODUCTID = u.PRODUCTID
    AND COALESCE(m.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
LEFT JOIN SANDBOX.FPANDA.QuarterlyUnits_LTM q
    ON q.ULTIMATEID = u.ULTIMATEID AND q.PRODUCTID = u.PRODUCTID
    AND COALESCE(q.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
ORDER BY u.ULTIMATEID, u.PRODUCTID, u.FEATURE_STRING;



-------------------------------
--GLOBAL BREAK EVEN PRICES
-------------------------------

--Total actuals per product across LTM (numerator)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Product_Actuals_LTM AS
SELECT
    PRODUCTID,
    FEATURE_STRING,
    SUM(ACTUAL_CONSUMPTION_LTM) AS PRODUCT_ACTUALS_LTM
FROM SANDBOX.FPANDA.Actuals_LTM
GROUP BY ALL ORDER BY PRODUCTID;


--Total billing units per product across LTM (denominator)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Product_Units_LTM AS
SELECT
    PRODUCTID,
    FEATURE_STRING,
    SUM(DAILY_UNITS_LTM) AS PRODUCT_DAILY_UNITS_LTM,
    SUM(MONTHLY_UNITS_LTM) AS PRODUCT_MONTHLY_UNITS_LTM,
    SUM(QUARTERLY_UNITS_LTM) AS PRODUCT_QUARTERLY_UNITS_LTM
FROM SANDBOX.FPANDA.Units_LTM
GROUP BY ALL ORDER BY PRODUCTID;


--Store a current price p/ product > feature_string
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.DailyPrice_ByProductFeature AS
SELECT
    cm."Product ID" as PRODUCTID,
    cm."Feature String" as FEATURE_STRING,
    MAX(cm."Daily Price") AS DAILY_PRICE
FROM MART.OBT_CONSUMPTION_DAILY cm
GROUP BY ALL ORDER BY cm."Product ID";


--Break-even prices per Product (global, Cat A only)

-- Was orginally created as a Table and not a Temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.BreakEvenPrices_Product AS
SELECT
    p."Product Name" as PRODUCT,
    a.PRODUCTID,
    COALESCE(a.FEATURE_STRING, 'NO_FEATURE') AS FEATURE_STRING,
    a.PRODUCT_ACTUALS_LTM,
    dp.DAILY_PRICE,
    CASE 
        WHEN u.PRODUCT_MONTHLY_UNITS_LTM > 0 
        THEN a.PRODUCT_ACTUALS_LTM / u.PRODUCT_MONTHLY_UNITS_LTM
        ELSE NULL 
    END AS BREAK_EVEN_MONTHLY_PRICE,
    CASE 
        WHEN u.PRODUCT_QUARTERLY_UNITS_LTM > 0 
        THEN a.PRODUCT_ACTUALS_LTM / u.PRODUCT_QUARTERLY_UNITS_LTM
        ELSE NULL 
    END AS BREAK_EVEN_QUARTERLY_PRICE,
    u.PRODUCT_DAILY_UNITS_LTM,
    u.PRODUCT_MONTHLY_UNITS_LTM,
    u.PRODUCT_QUARTERLY_UNITS_LTM
FROM Product_Actuals_LTM a
JOIN Product_Units_LTM u  ON a.PRODUCTID = u.PRODUCTID
    AND COALESCE(a.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
JOIN SANDBOX.FPANDA.DailyPrice_ByProductFeature dp  ON a.PRODUCTID = dp.PRODUCTID
    AND COALESCE(a.FEATURE_STRING, 'NO_FEATURE') = COALESCE(dp.FEATURE_STRING, 'NO_FEATURE')
JOIN MART.DIM_PRODUCT p ON p."Product ID" = a.PRODUCTID
ORDER BY a.PRODUCTID, FEATURE_STRING;




---------------------------------------------------STEP 2) STAGE BILLABLE UNITS P/ ULTIMATE BY QUARTER-------------------------------------------------

----------------------
--SET PARAMETERS
----------------------

--LTM window (25Q2 LTM)
SET START_QUARTER = 20201;  -----------------------------------UPDATED THIS TO PULL IN MORE DATA
SET END_QUARTER = 20252;

--Set as range to bring more quarters in the future
SET SIM_START_QTR = 20201;  -----------------------------------UPDATED THIS TO PULL IN MORE DATA
SET SIM_END_QTR = 20252;  


-----------------------
--BASE CAT A USAGE
-----------------------
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.BaseUsage AS
SELECT
    cm."Ultimate ID" as ULTIMATEID,
    cm."E365 Category" as E365_CATEGORY,
    cm."Product ID" as PRODUCTID,
    cm."Feature String" as FEATURE_STRING,
    cm."Daily Price" as DAILY_PRICE,
    cm."Unique User" as UNIQUE_PERSONA,
    cm."Usage Date" as USAGE_DATE,
    cm."Application Days" as APPLICATION_DAYS,
    cm."Year Quarter" as YEAR_QUARTER,
    c."Year Month Num" as USAGE_MONTH,
    cm."Consumption" as ACTUAL_CONSUMPTION
FROM MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.DIM_PRODUCT p ON p."Product ID" = cm."Product ID"
JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = cm."Ultimate ID"
JOIN MART.DIM_DATE c ON c."Date"=cm."Usage Date"
WHERE s."Ultimate Commercial Program" = 'E365'
    AND cm."In Contracts" = 'Yes'
    AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER
    AND p."Acquisition Source" NOT IN ('Seequent')
    AND cm."E365 Category" = 'Category A';

--Store just the above timeframe's consumption from base
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_Base AS
SELECT *
FROM SANDBOX.FPANDA.BaseUsage
WHERE YEAR_QUARTER BETWEEN $SIM_START_QTR AND $SIM_END_QTR;


--Store actuals (i.e., actual consumption under daily model)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_Actuals AS
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(ACTUAL_CONSUMPTION) AS ACTUAL_CONSUMPTION_QTR
FROM SANDBOX.FPANDA.Simulation_Base
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



----------------------------------
--BILLING UNITS FOR SIMULATION
----------------------------------

--Daily billing units for simulation
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_DailyUnits AS
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(APPLICATION_DAYS) AS DAILY_BILLING_UNITS_QRT
FROM SANDBOX.FPANDA.Simulation_Base
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--Monthly billing units in the simulation timeframe 
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_MonthlyUnits AS
WITH RankedMonthly AS (
    SELECT
        YEAR_QUARTER,
        USAGE_MONTH,
        ULTIMATEID,
        PRODUCTID,
        FEATURE_STRING,
        UNIQUE_PERSONA,
        MAX(DAILY_PRICE) AS MAX_DAILY_PRICE,
        ROW_NUMBER() OVER (
            PARTITION BY YEAR_QUARTER, USAGE_MONTH, ULTIMATEID, PRODUCTID, UNIQUE_PERSONA
            ORDER BY MAX(DAILY_PRICE) DESC, FEATURE_STRING ASC) AS rn
    FROM SANDBOX.FPANDA.Simulation_Base
    GROUP BY ALL)
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    USAGE_MONTH,
    COUNT(DISTINCT UNIQUE_PERSONA) AS MONTHLY_BILLING_UNITS
FROM RankedMonthly
WHERE rn = 1
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--Roll up the monthly units to the quarter 
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_MonthlyUnits_Qtr AS
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    SUM(MONTHLY_BILLING_UNITS) AS TOTAL_MONTHLY_UNITS_QTR
FROM SANDBOX.FPANDA.Simulation_MonthlyUnits
GROUP BY ALL ORDER BY ULTIMATEID, PRODUCTID;



--Total quarterly billing units (no need to roll up for this sim being at quarter level)
-- Was orginally created as a Table and not a Temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_QuarterlyUnits_Qtr AS
WITH RankedQuarterly AS (
    SELECT
        YEAR_QUARTER,
        ULTIMATEID,
        PRODUCTID,
        FEATURE_STRING,
        UNIQUE_PERSONA,
        MAX(DAILY_PRICE) AS MAX_DAILY_PRICE,
        ROW_NUMBER() OVER (
            PARTITION BY YEAR_QUARTER, ULTIMATEID, PRODUCTID, UNIQUE_PERSONA
            ORDER BY MAX(DAILY_PRICE) DESC, FEATURE_STRING ASC) AS rn
    FROM SANDBOX.FPANDA.Simulation_Base
    GROUP BY ALL)
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    FEATURE_STRING,
    COUNT(DISTINCT UNIQUE_PERSONA) AS TOTAL_QUARTERLY_UNITS_QTR
FROM RankedQuarterly
WHERE rn = 1
GROUP BY YEAR_QUARTER, ULTIMATEID, PRODUCTID, FEATURE_STRING
ORDER BY ULTIMATEID, PRODUCTID;

--select distinct productid, feature_string, daily_price from consumption_metrics where productid=3173;


---------------------------
--COMBINED CLEAN TABLE
---------------------------

--Combine actual billing units, actual consumption, & monthly & quarterly units
-- Was orginally created as a Table and not a Temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Simulation_BillingUnits_All_CatA_4YearsData AS
SELECT
    u.YEAR_QUARTER,
    u.ULTIMATEID,
    u.PRODUCTID,
    COALESCE(u.FEATURE_STRING, 'NO_FEATURE') AS FEATURE_STRING,
    COALESCE(d.DAILY_BILLING_UNITS_QRT, 0) AS DAILY_BILLING_UNITS_QRT,
    COALESCE(m.TOTAL_MONTHLY_UNITS_QTR, 0) AS TOTAL_MONTHLY_UNITS_QTR,
    COALESCE(q.TOTAL_QUARTERLY_UNITS_QTR, 0) AS TOTAL_QUARTERLY_UNITS_QTR
    FROM (--distinct list of all combinations
    SELECT DISTINCT
        YEAR_QUARTER,
        ULTIMATEID,
        PRODUCTID,
        FEATURE_STRING
    FROM SANDBOX.FPANDA.Simulation_Base) u
LEFT JOIN SANDBOX.FPANDA.Simulation_DailyUnits d
    ON d.YEAR_QUARTER = u.YEAR_QUARTER AND d.ULTIMATEID = u.ULTIMATEID
    AND d.PRODUCTID = u.PRODUCTID
    AND COALESCE(d.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
LEFT JOIN SANDBOX.FPANDA.Simulation_MonthlyUnits_Qtr m
    ON m.YEAR_QUARTER = u.YEAR_QUARTER 
    AND m.ULTIMATEID = u.ULTIMATEID
    AND m.PRODUCTID = u.PRODUCTID
    AND COALESCE(m.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
LEFT JOIN SANDBOX.FPANDA.Simulation_QuarterlyUnits_Qtr q
    ON q.YEAR_QUARTER = u.YEAR_QUARTER AND q.ULTIMATEID = u.ULTIMATEID
    AND q.PRODUCTID = u.PRODUCTID
    AND COALESCE(q.FEATURE_STRING, 'NO_FEATURE') = COALESCE(u.FEATURE_STRING, 'NO_FEATURE')
ORDER BY u.YEAR_QUARTER, u.ULTIMATEID, u.PRODUCTID, u.FEATURE_STRING;





--------------------------------------------------------------STEP 3) STAGE CAT B CONSUMPTION----------------------------------------------------------

-----------------------
--STORE CAT B USAGE
-----------------------
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatBBaseUsage AS
SELECT
    cm."Ultimate ID" as ULTIMATEID,
    cm."E365 Category" as E365_CATEGORY,
    cm."Product ID" as PRODUCTID,
    cm."Feature String" as FEATURE_STRING,
    cm."Daily Price" as DAILY_PRICE,
    cm."Unique User" as UNIQUE_PERSONA,
    cm."Usage Date" as USAGE_DATE,
    cm."Application Days" as APPLICATION_DAYS,
    cm."Year Quarter" as YEAR_QUARTER,
    c."Year Month Num" as USAGE_MONTH,
    cm."Consumption" as ACTUAL_CONSUMPTION
FROM MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.DIM_PRODUCT p ON p."Product ID" = cm."Product ID"
JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = cm."Ultimate ID"
JOIN MART.DIM_DATE c ON c."Date"=cm."Usage Date"
WHERE s."Ultimate Commercial Program" = 'E365'
    AND cm."In Contracts" = 'Yes'
    AND cm."Year Quarter" BETWEEN $START_QUARTER AND $END_QUARTER
    AND p."Acquisition Source" NOT IN ('Seequent')
    AND cm."E365 Category" = 'Category B';


--Stage E365 pricebook USD global prices for all Cat B, down to feature_string
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatBPricebookPrices AS
SELECT
    "Pricebook Section" as PRICEBOOK_SECTION,
    PRODUCTID,
    FEATURE_STRING,
    E365_GROSS_PRICE
FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD 
WHERE PRICEBOOK = 'Global' AND ITERATION = 7 AND "Pricebook Section"  = 'Category B';



--Stage PW & Synchro IDs
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatBProductGroups AS
SELECT 
    PRODUCTID,
    CASE 
        WHEN PRODUCTID IN (3379, 3380, 3381) THEN 'PW'
        WHEN PRODUCTID IN (6144, 6331, 6332, 6143, 6142) THEN 'SYNCHRO'
        ELSE 'OTHER'
    END AS PRODUCT_GROUP
FROM SANDBOX.FPANDA.CatBPricebookPrices;

--Stage quarterly units for Cat B (1 per user per quarter per product - w/ highest feature_string)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatBQuarterlyUnits AS
WITH RankedQuarterly AS (
    SELECT
        cb.YEAR_QUARTER,
        cb.ULTIMATEID,
        cb.PRODUCTID,
        cb.UNIQUE_PERSONA,
        pg.PRODUCT_GROUP,
        --rank products by price for PW/Synchro groups per user per quarter (other will just behave normally)
        ROW_NUMBER() OVER (
            PARTITION BY cb.YEAR_QUARTER, cb.ULTIMATEID, cb.UNIQUE_PERSONA, pg.PRODUCT_GROUP
            ORDER BY MAX(cb.DAILY_PRICE) DESC, cb.PRODUCTID ASC) AS group_rank
    FROM SANDBOX.FPANDA.CatBBaseUsage cb
    LEFT JOIN SANDBOX.FPANDA.CatBProductGroups pg
        ON cb.PRODUCTID = pg.PRODUCTID
    GROUP BY ALL)
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    PRODUCTID,
    COUNT(DISTINCT UNIQUE_PERSONA) AS TOTAL_QUARTERLY_UNITS
FROM RankedQuarterly
WHERE group_rank = 1 --keep only the top-priced PW or Synchro product per group (others only have '1')
GROUP BY ALL
ORDER BY YEAR_QUARTER, ULTIMATEID, PRODUCTID;



--Roll up grain and persist to Sandbox to pull into Sigma
--Was orginally created as a Table and not a Temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.SimulationActualCatBConsumptionv2_4YearsData AS
SELECT
    cb.YEAR_QUARTER,
    cb.ULTIMATEID,
    cb.E365_CATEGORY,
    cb.PRODUCTID,
    COALESCE(cb.FEATURE_STRING, 'NO_FEATURE') AS FEATURE_STRING,
    cb.DAILY_PRICE,
    COALESCE(pb.E365_GROSS_PRICE, 0) AS BREAK_EVEN_QUARTERLY_PRICE,
    SUM(cb.APPLICATION_DAYS) AS DAILY_UNITS,
    COALESCE(qu.TOTAL_QUARTERLY_UNITS, 0) AS QUARTERLY_UNITS, 
    SUM(cb.ACTUAL_CONSUMPTION) AS DAILYL_CONSUMPTION, 
    (COALESCE(qu.TOTAL_QUARTERLY_UNITS, 0) * COALESCE(pb.E365_GROSS_PRICE, 0)) AS QUARTERLY_CONSUMPTION
FROM SANDBOX.FPANDA.CatBBaseUsage cb
LEFT JOIN SANDBOX.FPANDA.CatBQuarterlyUnits qu
    ON cb.YEAR_QUARTER = qu.YEAR_QUARTER
    AND cb.ULTIMATEID = qu.ULTIMATEID
    AND cb.PRODUCTID = qu.PRODUCTID
    --AND COALESCE(cb.FEATURE_STRING, 'NO_FEATURE') = COALESCE(qu.FEATURE_STRING, 'NO_FEATURE') --no Cat B feature_strings anyway, can join on productid alone
LEFT JOIN SANDBOX.FPANDA.CatBPricebookPrices pb
    ON cb.PRODUCTID = pb.PRODUCTID
    AND COALESCE(cb.FEATURE_STRING, 'NO_FEATURE') = COALESCE(pb.FEATURE_STRING, 'NO_FEATURE')
GROUP BY ALL 
ORDER BY cb.YEAR_QUARTER, cb.ULTIMATEID, cb.PRODUCTID;