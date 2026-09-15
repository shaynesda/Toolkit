/********************************************************************
**  Name: Floor & Ceiling Performance
**  Refactored Date: 6/1/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES,
**                                                 PRESENTATION.EDW)
**   
**       E365_TERMS_HISTORY = E365_TERMS_HISTORY (DIM_ULTIMATE?)
**               E365_TERMS = E365_TERMS_HISTORY (WHERE YEAR_QUARTER = MAX(YEAR_QUARTER)) TEMP TABLE in SANDBOX FPANDA
**             E365_INVOICE = EDW.E365_INVOICE (**CONSUMPTION ENGINE**)
**     LOOKUP_CURRENCYRATES = LOOKUP_CURRENCYRATES (FCT_FX_RATE_FISCAL_BUDGET?, DIM_CURRENCY?)
**  VW_E365_PARTIAL_QUARTER = VW_E365_PARTIAL_QUARTER (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**
**  Description: 
**
********************************************************************/


--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;





---------------------------------------------------------STEP 1: CONFIGURE---------------------------------------------------------------
--Be in REPORTING_DB.EDW_TABLES Schema w/ Financial_Analyst role

--Set most recent quarter (the reporting quarter)
SET UsageQuarter1 = '20261';        ------------------------------UPDATE

--Set previous quarter (1 quarter behind current)
SET UsageQuarter2 = '20254';        ------------------------------UPDATE

--Adjust which Ultimates to remove (ask Paul Barbour about questionable usage - below is test, Duke, & FM Global)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.UltimateIDsToDelete AS
SELECT 1006427393 AS ULTIMATEID --Test account ---RECENTLY COMMENTED OUT THE 2 BELOW FOR GREG - DO AGAIN?
UNION ALL SELECT 1003752107 --FM Global
UNION ALL SELECT 1005023208; --Duke

SELECT * FROM SWINGACCOUNTSQUARTER1 WHERE FXRATE IS NOT NULL;

-- Create E365_TERMS table in SANDBOX.FPANDA

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.E365_TERMS AS
SELECT *
   FROM PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY
  WHERE YEAR_QUARTER = (select dd."Year Quarter Num" AS year_quarter_num
                          from MART.DIM_DATE dd
                         where dd."Date" = current_date());

-------------------------------------------------STEP 2: STAGE MOST RECENT QUARTER------------------------------------------------------
--Create temp table for most recent usage quarter
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.SwingAccountsQuarter1 AS
SELECT 
    ULTIMATE_ID AS ULTIMATEID, 
    ULTIMATE_NAME AS ULTIMATENAME, 
    CURRENCY, 
    YEAR_QUARTER AS YEARQUARTER,
    CONTRACT_NET AS ContractNetLC, --what customer was actually invoiced
    NET AS NetLC, --what was used by the customer (straight from E365_Invoice)
    CAST(NULL AS NUMERIC(10,6)) AS FXRate, 
    CAST(0 AS NUMERIC(18,2)) AS ARRPostFloorCeilingUSD, ---USD VERSION OF CONTRACTNETLC (what customer was invoiced)
    CAST(0 AS NUMERIC(18,2)) AS ARRUsageUSD, ---USD VERSION OF NETLC (what customer used)
    CAST(NULL AS NUMERIC(10,6)) AS EVD, 
    CAST(0 AS NUMERIC(18,2)) AS CeilingUSD, 
    CAST(0 AS NUMERIC(18,2)) AS FloorUSD
FROM PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY
WHERE YEARQUARTER = $UsageQuarter1;

--select top 10 * from REPORTING_DB.EDW_TABLES.E365_TERMS_HISTORY;

--Calculate ARRPostFloorCeilingUSD and ARRUsageUSD
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter1 
SET ARRPostFloorCeilingUSD = (ContractNetLC / FXRate) * 4, 
    ARRUsageUSD = (NetLC / FXRate) * 4;

--Update NetLC and ContractNetLC
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
SET NetLC = a2.Net, 
    ContractNetLC = a2.Net
FROM (
    SELECT ultimate_id, SUM(net) AS Net 
      FROM EDW.E365_INVOICE 
     WHERE substr(usage_quarter, 1, 5) = $UsageQuarter1
     GROUP BY ultimate_id) AS a2 
WHERE a2.ultimate_id= a1.ULTIMATEID 
  AND (NetLC IS NULL OR ContractNetLC IS NULL);

--Delete partial quarters
DELETE FROM SANDBOX.FPANDA.SwingAccountsQuarter1 tr
USING VW_E365_PARTIAL_QUARTER pq
WHERE tr.ULTIMATEID = pq.ULTIMATEID 
  AND tr.YEARQUARTER = pq.USAGE_QUARTER;

--Delete test account and questionable usage
DELETE FROM SANDBOX.FPANDA.SwingAccountsQuarter1 
WHERE ULTIMATEID IN (SELECT ULTIMATEID FROM UltimateIDsToDelete);

--Update FXRate
/*
UPDATE SwingAccountsQuarter1 AS a1
SET FXRate = a2.Rate
FROM LOOKUP_CURRENCYRATES AS a2
WHERE a2.Currency = a1.CURRENCY 
  AND a2.IsCurrent = 1; 
*/

UPDATE SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
SET FXRate = a2.Rate
FROM (SELECT dc."Currency ISO Code" AS Currency,    -- Ask Mary about the differences in rates (LOOKUP_CURRENCYRATES) and abbrv.
             1/fb."Fiscal Budget Rate Value" AS Rate
        FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
        JOIN MART.DIM_CURRENCY dc
          ON fb.fk_source_currency_key = dc.sk_currency_key
       WHERE "Is Current Rate" = 'TRUE') a2
WHERE a2.Currency = a1.CURRENCY;
  
--Calculate ARRPostFloorCeilingUSD and ARRUsageUSD
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter1
SET ARRPostFloorCeilingUSD = (ContractNetLC / FXRate) * 4, 
    ARRUsageUSD = (NetLC / FXRate) * 4;


--select top 10 * from SwingAccountsQuarter1;
--select * from SwingAccountsQuarter1 where ultimateid=1005435622;



-------------------------------------STEP 3: RUN CHARTS (SLIDES 1 & 2) - COPY/PASTE LAST COLUMN INTO EXCEL----------------------------------
--OVERALL E365/EPS CHART
WITH AggregatedData AS (
    SELECT 
        Type,
        COUNT(ULTIMATEID) AS CountofUltimateID,
        SUM(ARRUsageUSD) AS SumARRUsageUSD,
        SUM(ARRPostFloorCeilingUSD) AS SumARRPostFloorCeilingUSD,
        SUM(Variance) AS SumVariance,
        MIN(SortKey) AS SortKey 
    FROM (
        SELECT 
            a1.ULTIMATEID,
            a1.ULTIMATENAME,
            a2.category AS Category,
            a1.NetLC,
            a1.ContractNetLC,
            a1.FXRate,
            a1.ARRPostFloorCeilingUSD,
            a1.ARRUsageUSD,
            a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD AS Variance,
            CASE
                WHEN a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD < -0.0001 
                    AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 'Above Ceiling'
                WHEN a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD > 0.0001 
                    AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 'Below Floor'
                WHEN ABS(a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) <= 0.0001 
                    AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 'True Consumption'
                WHEN a2.Category IN ('EPS Essentials', 'EPS Premium', 'EPS Standard') THEN 'EPS' 
                ELSE NULL 
            END AS Type,
            CASE
                WHEN a2.Category IN ('EPS Essentials', 'EPS Premium', 'EPS Standard') THEN 1
                WHEN a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD < -0.0001 AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 2
                WHEN a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD > 0.0001 AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 3
            WHEN ABS(a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) <= 0.0001 AND a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') THEN 4
                ELSE 5
            END AS SortKey
        FROM SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
        JOIN SANDBOX.FPANDA.E365_TERMS AS a2 ON a2.ultimate_id = a1.ULTIMATEID) AS subquery
    GROUP BY Type)
SELECT 
    Type,
    CountofUltimateID,
    SumARRUsageUSD,
    SumARRPostFloorCeilingUSD,
    SumVariance,
    ROUND(SumARRPostFloorCeilingUSD / NULLIF(SUM(SumARRPostFloorCeilingUSD) OVER (), 0) * 100, 2) AS PercentOfTotal
FROM AggregatedData
ORDER BY SortKey; 



--EPS - USAGE VS FIXED FEE CHART
WITH AggregatedData AS (
    SELECT 
        UsageAsPercOfActualPaid,
        COUNT(ULTIMATEID) AS CountofUltimateID,
        SUM(ARRUsageUSD) AS SumARRUsageUSD,
        SUM(ARRPostFloorCeilingUSD) AS SumARRPostFloorCeilingUSD,
        SUM(Variance) AS SumVariance,
        MIN(SortKey) AS SortKey
    FROM (
        SELECT 
            a1.ULTIMATEID,
            a1.ULTIMATENAME,
            a2.category AS Category,
            a1.NetLC,
            a1.ContractNetLC,
            a1.FXRate,
            a1.ARRPostFloorCeilingUSD,
            a1.ARRUsageUSD,
            a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD AS Variance,
            (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 AS UsagePercentage,
            CASE
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 < 50.00 THEN 'a) 0-50%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 50.0001 AND 80.00 THEN 'b) 50-80%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 80.0001 AND 90.00 THEN 'c) 80-90%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 90.0001 AND 100.00 THEN 'd) 90-100%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 100.0001 AND 110.00 THEN 'f) 100-110%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 110.0001 AND 120.00 THEN 'g) 110-120%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 120.0001 AND 150.00 THEN 'h) 120-150%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 > 150.0001 THEN 'i) 150% Plus'
                ELSE NULL
            END AS UsageAsPercOfActualPaid,
            CASE
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 < 50.00 THEN 1
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 50.0001 AND 80.00 THEN 2
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 80.0001 AND 90.00 THEN 3
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 90.0001 AND 100.00 THEN 4
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 100.0001 AND 110.00 THEN 5
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 110.0001 AND 120.00 THEN 6
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 120.0001 AND 150.00 THEN 7
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 > 150.0001 THEN 8
                ELSE 9
            END AS SortKey 
        FROM SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
        JOIN SANDBOX.FPANDA.E365_TERMS AS a2 ON a2.ultimate_id = a1.ULTIMATEID
        WHERE a2.Category IN ('EPS Essentials', 'EPS Premium', 'EPS Standard')) AS subquery
    GROUP BY UsageAsPercOfActualPaid)
SELECT 
    UsageAsPercOfActualPaid,
    CountofUltimateID,
    SumARRUsageUSD,
    SumARRPostFloorCeilingUSD,
    SumVariance,
    ROUND(SumARRPostFloorCeilingUSD / NULLIF(SUM(SumARRPostFloorCeilingUSD) OVER (), 0) * 100, 2) AS PercentOfTotal
FROM AggregatedData
ORDER BY SortKey;

-- **  NULL FX Rate is rendering this sql unrunnalbe



--E365 - USAGE VS FLOOR/CEILING CHART
WITH AggregatedData AS (
    SELECT 
        UsageAsPercOfActualPaid,
        COUNT(ULTIMATEID) AS CountofUltimateID,
        SUM(ARRUsageUSD) AS SumARRUsageUSD,
        SUM(ARRPostFloorCeilingUSD) AS SumARRPostFloorCeilingUSD,
        SUM(Variance) AS SumVariance,
        MIN(SortKey) AS SortKey
    FROM (
        SELECT 
            a1.ULTIMATEID,
            a1.ULTIMATENAME,
            a2.category AS Category,
            a1.NetLC,
            a1.ContractNetLC,
            a1.FXRate,
            a1.ARRPostFloorCeilingUSD,
            a1.ARRUsageUSD,
            a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD AS Variance,
            (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 AS UsagePercentage,
            CASE
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 < 50.0000 THEN 'a) 0-50%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 50.0001 AND 80.0000 THEN 'b) 50-80%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 80.0001 AND 90.0000 THEN 'c) 80-90%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 90.0001 AND 99.9999 THEN 'd) 90-100%'
                WHEN ROUND((a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100, 4) = 100.0000 THEN 'e) Usage Billed' 
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 100.0001 AND 110.0000 THEN 'f) 100-110%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 110.0001 AND 120.0000 THEN 'g) 110-120%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 120.0001 AND 150.0000 THEN 'h) 120-150%'
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 > 150.0001 THEN 'i) 150% Plus'
                ELSE NULL
            END AS UsageAsPercOfActualPaid,
            CASE
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 < 50.0000 THEN 1
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 50.0001 AND 80.0000 THEN 2
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 80.0001 AND 90.0000 THEN 3
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 90.0001 AND 99.9999 THEN 4
                WHEN ROUND((a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100, 4) = 100.0000 THEN 5
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 100.0001 AND 110.0000 THEN 6
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 110.0001 AND 120.0000 THEN 7
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 BETWEEN 120.0001 AND 150.0000 THEN 8
                WHEN (a1.ARRUsageUSD / a1.ARRPostFloorCeilingUSD) * 100 > 150.0001 THEN 9
                ELSE 10
        END AS SortKey
        FROM SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
        JOIN SANDBOX.FPANDA.E365_TERMS AS a2 ON a2.ultimate_id = a1.ULTIMATEID
        WHERE a2.Category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard')) AS subquery
    GROUP BY UsageAsPercOfActualPaid)
SELECT 
    UsageAsPercOfActualPaid,
    CountofUltimateID,
    SumARRUsageUSD,
    SumARRPostFloorCeilingUSD,
    SumVariance,
    ROUND(SumARRPostFloorCeilingUSD / NULLIF(SUM(SumARRPostFloorCeilingUSD) OVER (), 0) * 100, 2) AS PercentOfTotal
FROM AggregatedData
ORDER BY SortKey;



--E365 ACCOUNTS - FLOOR/CEILING BREAKDOWN (EXC EPS)
SELECT 
    FloorCeilingType,
    Sum_ARRPostFloorCeilingUSD,
    ROUND(Sum_ARRPostFloorCeilingUSD / NULLIF(SUM(Sum_ARRPostFloorCeilingUSD) OVER (), 0) * 100, 2) AS PercentOfTotal
FROM (
    SELECT 
        CASE
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NOT NULL THEN 'Floor and Ceiling'
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NULL THEN 'Floor Only'
            WHEN eh.floor_value IS NULL AND eh.ceiling_value IS NOT NULL THEN 'Ceiling Only'
            ELSE 'None'
        END AS FloorCeilingType,
        SUM(a1.ARRPostFloorCeilingUSD) AS Sum_ARRPostFloorCeilingUSD,
        SUM(SUM(a1.ARRPostFloorCeilingUSD)) OVER () AS Sum_ARRPostFloorCeilingUSD_Total,
        CASE
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NOT NULL THEN 1
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NULL THEN 2
            ELSE 3
        END AS SortKey
    FROM SANDBOX.FPANDA.SwingAccountsQuarter1 AS a1
    JOIN SANDBOX.FPANDA.E365_TERMS AS a2 ON a2.ultimate_id = a1.ULTIMATEID            
    LEFT JOIN PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY AS eh ON eh.ultimate_id = a1.ULTIMATEID AND eh.year_quarter = eh.year_quarter
    WHERE a2.category IN ('E365 Essentials', 'E365 Premium', 'E365 Standard') 
    GROUP BY 
        CASE
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NOT NULL THEN 'Floor and Ceiling'
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NULL THEN 'Floor Only'
            WHEN eh.floor_value IS NULL AND eh.ceiling_value IS NOT NULL THEN 'Ceiling Only'
            ELSE 'None'
        END,
        CASE
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NOT NULL THEN 1
            WHEN eh.floor_value IS NOT NULL AND eh.ceiling_value IS NULL THEN 2
            ELSE 3
        END) AS subquery
ORDER BY SortKey;




---------------------------------------------------STEP 4: TOTAL ARR CAPTURED (SLIDE 1)----------------------------------------------------
--Total ARR Captured for most recent quarter (refer to Excel sheet for previous ARR totals to include in PPT)
SELECT SUM(ARRPOSTFLOORCEILINGUSD) FROM SANDBOX.FPANDA.SwingAccountsQuarter1;




----------------------------------------------------STEP 5: STAGE PREVIOUS QUARTER-------------------------------------------------------
--Create temp table for previous usage quarter
CREATE OR REPLACE GLOBAL TEMPORARY TABLE SANDBOX.FPANDA.SwingAccountsQuarter2 AS
SELECT 
    ultimate_id AS ULTIMATEID, 
    ULTIMATE_NAME AS ULTIMATENAME, 
    CURRENCY, 
    year_quarter AS YEARQUARTER, 
    NET AS NetLC, 
    CONTRACT_NET AS ContractNetLC, 
    CAST(NULL AS NUMERIC(10,6)) AS FXRate, 
    CAST(0 AS NUMERIC(18,2)) AS ARRPostFloorCeilingUSD, 
    CAST(0 AS NUMERIC(18,2)) AS ARRUsageUSD,
    CAST(NULL AS NUMERIC(10,6)) AS EVD, 
    CAST(0 AS NUMERIC(18,2)) AS CeilingUSD, 
    CAST(0 AS NUMERIC(18,2)) AS FloorUSD
FROM PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY
WHERE YEARQUARTER = $UsageQuarter2;

-- Calculate ARRPostFloorCeilingUSD and ARRUsageUSD
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter2 
SET ARRPostFloorCeilingUSD = (ContractNetLC / FXRate) * 4, 
    ARRUsageUSD = (NetLC / FXRate) * 4;

--Update NetLC and ContractNetLC
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter2 AS a1
SET NetLC = a2.Net, 
    ContractNetLC = a2.Net
FROM (
   SELECT ultimate_id, SUM(net) AS Net 
     FROM E365_INVOICE 
    WHERE substr(usage_quarter, 1, 5) = $UsageQuarter2
    GROUP BY ultimate_id) AS a2 
WHERE a2.ultimate_id = a1.ULTIMATEID 
  AND (NetLC IS NULL OR ContractNetLC IS NULL);

--Delete specific records (partial quarters, test accounts, questionable usage)
DELETE FROM SANDBOX.FPANDA.SwingAccountsQuarter2 tr
USING PRESENTATION.EDW_TABLES.VW_E365_PARTIAL_QUARTER pq
WHERE tr.ULTIMATEID = pq.ULTIMATEID 
  AND tr.YEARQUARTER = pq.USAGE_QUARTER;

--Delete test account and questionable usage
DELETE FROM SANDBOX.FPANDA.SwingAccountsQuarter2
WHERE ULTIMATEID IN (SELECT ULTIMATEID FROM UltimateIDsToDelete);

--Update FXRate
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter2 AS a1
SET FXRate = a2.Rate
FROM LOOKUP_CURRENCYRATES AS a2
WHERE a2.Currency = a1.CURRENCY 
  AND a2.IsCurrent = 1;
  
--Calculate ARRPostFloorCeilingUSD and ARRUsageUSD
UPDATE SANDBOX.FPANDA.SwingAccountsQuarter2
SET ARRPostFloorCeilingUSD = (ContractNetLC / FXRate) * 4, 
    ARRUsageUSD = (NetLC / FXRate) * 4;




----------------------------------------------STEP 6: COMBINE CURRENT AND PREVIOUS USAGE QUARTERS-----------------------------------------
--Combine 2 quarters for Swing Accounts & Terms Changes analyses
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.CombinedSwingTermAnalysis AS
SELECT
    COALESCE(a1.ULTIMATEID, a2.ULTIMATEID) AS ULTIMATEID,
    COALESCE(a1.ULTIMATENAME, a2.ULTIMATENAME) AS ULTIMATENAME,
    a3.Category,
    a1.ARRPostFloorCeilingUSD AS ARRPostFC_Recent,
    a1.ARRUsageUSD AS ARRUsage_Recent,
    (a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) AS Variance_Recent,
    CASE
        WHEN (a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) < 0 THEN 'Above Ceiling'
        WHEN (a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) > 0 THEN 'Below Floor'
        WHEN (a1.ARRPostFloorCeilingUSD - a1.ARRUsageUSD) = 0 THEN 'Usage Billed'
        ELSE NULL
    END AS UsageType_Recent,
    CASE
        WHEN a1.ARRPostFloorCeilingUSD = 0 THEN NULL
        ELSE CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))
    END AS UsagePercentage_Recent,
    CASE
        WHEN a1.ARRPostFloorCeilingUSD = 0 THEN NULL
        ELSE
            CASE
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    < 50.0001 THEN 'a) 0-50%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 50.0001 AND 80.0000 THEN 'b) 50-80%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 80.0001 AND 90.0000 THEN 'c) 80-90%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 90.0001 AND 99.9999 THEN 'd) 90-100%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    = 100.0000 THEN 'e) Usage Billed'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 100.0001 AND 110.0000 THEN 'f) 100-110%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 110.0001 AND 120.0000 THEN 'g) 110-120%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 120.00001 AND 150.0000 THEN 'h) 120-150%'
                WHEN (CAST((CAST(a1.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a1.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    > 150.0001 THEN 'i) 150% Plus'
                ELSE NULL
            END
    END AS UsageBucket_Recent,
    a2.ARRPostFloorCeilingUSD AS ARRPostFC_Previous,
    a2.ARRUsageUSD AS ARRUsage_Previous,
    (a2.ARRPostFloorCeilingUSD - a2.ARRUsageUSD) AS Variance_Previous,
    CASE
        WHEN (a2.ARRPostFloorCeilingUSD - a2.ARRUsageUSD) < 0 THEN 'Above Ceiling'
        WHEN (a2.ARRPostFloorCeilingUSD - a2.ARRUsageUSD) > 0 THEN 'Below Floor'
        WHEN (a2.ARRPostFloorCeilingUSD - a2.ARRUsageUSD) = 0 THEN 'Usage Billed'
        ELSE NULL
    END AS UsageType_Previous,
    CASE
        WHEN a2.ARRPostFloorCeilingUSD = 0 THEN NULL
        ELSE CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))
    END AS UsagePercentage_Previous,
    CASE
        WHEN a2.ARRPostFloorCeilingUSD = 0 THEN NULL
        ELSE
            CASE
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    < 50.0001 THEN 'a) 0-50%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 50.0001 AND 80.0000 THEN 'b) 50-80%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 80.0001 AND 90.0000 THEN 'c) 80-90%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 90.0001 AND 99.9999 THEN 'd) 90-100%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    = 100.00 THEN 'e) Usage Billed'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 100.0001 AND 110.0000 THEN 'f) 100-110%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 110.0001 AND 120.0000 THEN 'g) 110-120%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    BETWEEN 120.0001 AND 150.0000 THEN 'h) 120-150%'
                WHEN (CAST((CAST(a2.ARRUsageUSD AS DECIMAL(18,6)) / CAST(a2.ARRPostFloorCeilingUSD AS DECIMAL(18,6))) * 100 AS DECIMAL(5,1))) 
                    > 150.0001 THEN 'i) 150% Plus'
                ELSE NULL
            END
    END AS UsageBucket_Previous,
    eh1.floor_value AS FloorValue_Recent,
    eh1.ceiling_value AS CeilingValue_Recent,
    CASE
        WHEN eh1.floor_value IS NOT NULL AND eh1.ceiling_value IS NULL THEN 'Floor Only'
        WHEN eh1.floor_value IS NULL AND eh1.ceiling_value IS NOT NULL THEN 'Ceiling Only'
        WHEN eh1.floor_value IS NOT NULL AND eh1.ceiling_value IS NOT NULL THEN 'Floor and Ceiling'
        ELSE 'None'
    END AS FloorCeilingType_Recent,
    eh2.floor_value AS FloorValue_Previous,
    eh2.ceiling_value AS CeilingValue_Previous,
    CASE
        WHEN eh2.floor_value IS NOT NULL AND eh2.ceiling_value IS NULL THEN 'Floor Only'
        WHEN eh2.floor_value IS NULL AND eh2.ceiling_value IS NOT NULL THEN 'Ceiling Only'
        WHEN eh2.floor_value IS NOT NULL AND eh2.ceiling_value IS NOT NULL THEN 'Floor and Ceiling'
        ELSE 'None'
    END AS FloorCeilingType_Previous
FROM SANDBOX.FPANDA.SwingAccountsQuarter1 a1
FULL OUTER JOIN SANDBOX.FPANDA.SwingAccountsQuarter2 a2 ON a1.ULTIMATEID = a2.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.E365_TERMS a3 ON a3.ultimate_id = COALESCE(a1.ULTIMATEID, a2.ULTIMATEID)  
LEFT JOIN PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY eh1 ON eh1.ultimate_id = a1.ULTIMATEID AND eh1.year_quarter = a1.YearQuarter
LEFT JOIN PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY eh2 ON eh2.ultimate_id = a2.ULTIMATEID AND eh2.year_quarter = a2.YearQuarter;

--SELECT * FROM CombinedSwingTermAnalysis;


--Derive compare categories for swing and term analyses 
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.SwingAccountTimePeriodCompares AS
SELECT
    *,
    CASE 
        WHEN UsageBucket_Recent != UsageBucket_Previous THEN 'Yes'
        ELSE 'No'
    END AS ChangedUsageBucket,
    (Variance_Recent - Variance_Previous) AS DiffInVariance,
    (UsagePercentage_Recent - UsagePercentage_Previous) AS DiffInUsagePercent,
    CASE 
        WHEN FloorCeilingType_Recent != FloorCeilingType_Previous AND ARRPostFC_Previous IS NOT NULL THEN 'Yes'
        ELSE 'No'
    END AS ChangedTerms,
    CASE
        WHEN ARRPostFC_Previous IS NULL THEN 'Yes'
        ELSE 'No'
    END AS NetNewAccount,
    CASE
        WHEN ARRPostFC_Recent IS NULL THEN 'Yes'
        ELSE 'No'
    END AS LostAccount
FROM SANDBOX.FPANDA.CombinedSwingTermAnalysis;


select * from SANDBOX.FPANDA.SwingAccountTimePeriodCompares where ultimateid=1001392429; --provide to Jack and Jen C





------------------------------------------------------STEP 7: DERIVE COMMENTARY FOR SLIDE 2-------------------------------------------------
--Overall E365/EPS Chart Explanation (Existing Accounts that Changed)
SELECT
    USAGETYPE_PREVIOUS,
    USAGETYPE_RECENT,    
    ULTIMATENAME,
    CATEGORY,
    ARRPOSTFC_RECENT
FROM SwingAccountTimePeriodCompares
WHERE USAGETYPE_RECENT != USAGETYPE_PREVIOUS
ORDER BY USAGETYPE_PREVIOUS, USAGETYPE_RECENT;


----Overall E365/EPS Chart Explanation (New Accounts)
SELECT
    USAGETYPE_PREVIOUS,
    USAGETYPE_RECENT,    
    ULTIMATENAME,
    ARRPOSTFC_RECENT
FROM SwingAccountTimePeriodCompares
WHERE ARRPOSTFC_PREVIOUS IS NULL
ORDER BY USAGETYPE_PREVIOUS, USAGETYPE_RECENT;




--E365 Accounts w/ Term Changes Chart Explanation (Existing Accounts that Changed)
SELECT
    FLOORCEILINGTYPE_PREVIOUS AS FCTYPE_PREVIOUS,
    FLOORCEILINGTYPE_RECENT AS FCTYPE_RECENT,
    ULTIMATENAME,
    ARRPOSTFC_RECENT,
    USAGETYPE_RECENT,
    USAGEPERCENTAGE_RECENT AS USAGEPERCENT_RECENT,
    DIFFINUSAGEPERCENT
FROM SwingAccountTimePeriodCompares 
WHERE CHANGEDTERMS = 'Yes' 
    AND CATEGORY IN ('E365 Standard','E365 Essentials','E365 Premium')
ORDER BY FLOORCEILINGTYPE_PREVIOUS, FLOORCEILINGTYPE_RECENT;



--E365 Accounts w/ Term Changes Chart Explanation (New Accounts)
SELECT
    FLOORCEILINGTYPE_PREVIOUS AS FCTYPE_PREVIOUS,
    FLOORCEILINGTYPE_RECENT AS FCTYPE_RECENT,
    ULTIMATENAME,
    ARRPOSTFC_RECENT,
    USAGETYPE_RECENT,
    USAGEPERCENTAGE_RECENT AS USAGEPERCENT_RECENT,
    DIFFINUSAGEPERCENT
FROM SwingAccountTimePeriodCompares 
WHERE ARRPOSTFC_PREVIOUS IS NULL 
    AND CATEGORY IN ('E365 Standard','E365 Essentials','E365 Premium')
ORDER BY FLOORCEILINGTYPE_PREVIOUS, FLOORCEILINGTYPE_RECENT;




------------------------------------------------------STEP 8: EPS SWING ACCOUNTS FOR SLIDE 3------------------------------------------------
--EPS Swing Accounts
SELECT * 
FROM SwingAccountTimePeriodCompares
WHERE CHANGEDUSAGEBUCKET = 'Yes'
    AND CATEGORY ILIKE '%EPS%'
    AND NETNEWACCOUNT = 'No'
    AND LOSTACCOUNT = 'No'
ORDER BY ARRPostFC_Recent DESC;


--New and Lost EPS Accounts
SELECT 
    ULTIMATEID,
    ULTIMATENAME,
    CASE 
        WHEN CATEGORY ILIKE '%EPS%' AND NETNEWACCOUNT = 'Yes' THEN 'Net New EPS Account'
        WHEN CATEGORY ILIKE '%EPS%' AND LOSTACCOUNT = 'Yes' THEN 'Lost EPS Account'
        ELSE 'Other'
    END AS AccountStatus,
    ARRPOSTFC_RECENT,
    ARRUSAGE_RECENT,
    USAGEBUCKET_RECENT,
    ARRUSAGE_PREVIOUS,
    USAGEBUCKET_PREVIOUS
FROM SwingAccountTimePeriodCompares
WHERE 
    CATEGORY ILIKE '%EPS%' AND (NETNEWACCOUNT = 'Yes' OR LOSTACCOUNT = 'Yes')
ORDER BY ARRPostFC_Recent DESC;





--------------------STEP 9A: REFER TO EXCEL SHEET FOR PREVIOUS VARIANCES TO INCLUDE
--EPS Implied Premium and Discounts
SELECT
    CASE 
        WHEN USAGETYPE_RECENT = 'Below Floor' THEN 'Implied Premium'
        WHEN USAGETYPE_RECENT = 'Above Ceiling' THEN 'Implied Discount'
        ELSE 'Usage Billed'
    END AS Category,
    SUM(VARIANCE_RECENT) AS Sum_ARRPostFC_Recent
FROM SwingAccountTimePeriodCompares
WHERE CATEGORY ILIKE '%EPS%'
    AND USAGETYPE_RECENT IN ('Below Floor', 'Above Ceiling')
GROUP BY 
    CASE 
        WHEN USAGETYPE_RECENT = 'Below Floor' THEN 'Implied Premium'
        WHEN USAGETYPE_RECENT = 'Above Ceiling' THEN 'Implied Discount'
        ELSE 'Usage Billed'
    END;





------------------------------------------------------STEP 9: E365 SWING ACCOUNTS FOR SLIDE 4-----------------------------------------------
--E365 Swing Accounts
SELECT * 
FROM SwingAccountTimePeriodCompares
WHERE CHANGEDUSAGEBUCKET = 'Yes'
    AND CATEGORY ILIKE '%E365%'
    AND NETNEWACCOUNT = 'No'
    AND LOSTACCOUNT = 'No'
ORDER BY ARRPostFC_Recent DESC;


--New and Lost E365 Accounts
SELECT 
    ULTIMATEID,
    ULTIMATENAME,
    CASE 
        WHEN CATEGORY ILIKE '%E365%' AND NETNEWACCOUNT = 'Yes' THEN 'Net New E365 Account'
        WHEN CATEGORY ILIKE '%E365%' AND LOSTACCOUNT = 'Yes' THEN 'Lost E365 Account'
        ELSE 'Other'
    END AS AccountStatus,
    ARRPOSTFC_RECENT,
    ARRUSAGE_RECENT,
    USAGEBUCKET_RECENT,
    ARRUSAGE_PREVIOUS,
    USAGEBUCKET_PREVIOUS
FROM SwingAccountTimePeriodCompares
WHERE 
    CATEGORY ILIKE '%E365%' AND (NETNEWACCOUNT = 'Yes' OR LOSTACCOUNT = 'Yes')
ORDER BY ARRPostFC_Recent DESC;




--------------------STEP 10A: REFER TO EXCEL SHEET FOR PREVIOUS VARIANCES TO INCLUDE
--E365 Implied Premium and Discounts
SELECT
    CASE 
        WHEN USAGETYPE_RECENT = 'Below Floor' THEN 'Implied Premium'
        WHEN USAGETYPE_RECENT = 'Above Ceiling' THEN 'Implied Discount'
        ELSE 'Usage Billed'
    END AS Category,
    SUM(VARIANCE_RECENT) AS Sum_ARRPostFC_Recent
FROM SwingAccountTimePeriodCompares
WHERE CATEGORY ILIKE '%E365%'
    AND USAGETYPE_RECENT IN ('Below Floor', 'Above Ceiling')
GROUP BY 
    CASE 
        WHEN USAGETYPE_RECENT = 'Below Floor' THEN 'Implied Premium'
        WHEN USAGETYPE_RECENT = 'Above Ceiling' THEN 'Implied Discount'
        ELSE 'Usage Billed'
    END;
	
	
	

-----------------STEP 11: TOTAL DUE TO Discount
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

with currencyrates as (
    select currency, rate
    from presentation.edw_tables.lookup_currencyrates
    where iscurrent = 1),
invoice_by_currency as (
    select
        substr(i.usage_quarter, 1, 5) AS usage_quarter, 
        case
            when t.category ilike '%eps%' then 'eps'
            else 'non-eps'
        end as category,
        i.currency,
        sum(i.gross) as gross_lc,
        sum(i.net_with_renewal_evd) as Net_With_Renewal_EVD_lc
    from edw.e365_invoice i
    join SANDBOX.FPANDA.E365_TERMS t on t.ultimate_id = i.ultimate_id
    where substr(i.usage_quarter, 1, 5) between 20232 and 20261
    group by all)
select
    bc.usage_quarter,
    bc.category,
    bc.gross_lc,
    bc.Net_With_Renewal_EVD_lc,
    bc.gross_lc - bc.Net_With_Renewal_EVD_lc as total_due_to_discount_lc,
    sum(bc.gross_lc / cr.rate) as sum_gross_usd,
    sum(bc.Net_With_Renewal_EVD_lc / cr.rate) as sum_net_usd,
    sum((bc.gross_lc - bc.Net_With_Renewal_EVD_lc) / cr.rate) as total_due_to_discount_usd
from invoice_by_currency bc
left join currencyrates cr on bc.currency = cr.currency
group by all
order by 1,2;