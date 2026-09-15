/********************************************************************
**  Name: SW E365 ARR Forecast
**  Refactored Date: 7/28/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                    CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**                               PRODUCTS = DIM_PRODUCT
**                                  SITES = OBT_SITE_EXPANDED
**                     E365_TERMS_HISTORY = E365_TERMS_HISTORY (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**                      CONTRACTS_HISTORY = SSF_CONTRACT_LINE_MONTHLY, DIM_CONTRACT 
**
**
**  Description: 
**
********************************************************************/

--Revised to include plugs for 26Q4 (added placeholder row of 20271 and brought in more multi-year terms for floor uplifts)

--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

-------------------------
--SET PARAMETERS
-------------------------
SET PREDICTION_DATE = '2026-01-21';

SET HIST_START_YQ = 20262;
SET HIST_END_YQ = 20264;

SET FCST_START_YQ = 20261;
SET FCST_END_YQ = 20264;


------------------------
--BUILD TIME SPINE
------------------------

--Which intervals each ultimate in invoice had in 2025 (assume used all each quarter)       -----------FINAL OUTPUT BUILT OFF ULTIMATES WHO EXIST IN INVOICING IN 2025
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.InvoiceIntervals_2025_ByUltimate AS
SELECT DISTINCT
    i.ultimateid as ULTIMATEID,
    i.usageinterval as USAGE_INTERVAL
FROM E365_INVOICE i
JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = i.ULTIMATEID   ---------------------IS THIS THE RIGHT JOIN?
WHERE i.usagequarter BETWEEN 20251 AND $HIST_END_YQ 
AND i.gross > 0
    AND s."Ultimate Commercial Program"='E365'; --still on E365 today


--Build 2026 placeholders (plus 20271 for 26Q4 plugs)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ForecastQuarters_2026 AS
SELECT COLUMN1::NUMBER AS YEAR_QUARTER
--FROM VALUES ($FCST_START_YQ), (20262), (20263), ($FCST_END_YQ);
FROM VALUES ($FCST_START_YQ), (20262), (20263), ($FCST_END_YQ), (20271);        ----------------ADDED 20271


--Cross join to build the spine (p/ ultimate > year_quarter > interval)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ForecastedUsage_2026_Spine AS
SELECT
    i.ULTIMATEID,
    q.YEAR_QUARTER,
    i.USAGE_INTERVAL,
    NULL::NUMBER AS TOTAL_GROSS --fill in as we get each downstream
FROM SANDBOX.FPANDA.InvoiceIntervals_2025_ByUltimate i
CROSS JOIN SANDBOX.FPANDA.ForecastQuarters_2026 q
ORDER BY 1,2,3;

/*
select distinct f.ultimateid, min(i.usage_quarter) from ForecastedUsage_2026_Spine f join sites s on s.siteid=f.ultimateid join e365_invoice i on i.ultimateid=f.ultimateid where commercial_program='E365' group by all having max(i.usage_quarter) > 20252;
--553 (down to 540 when saying 'only on E365 today)

select distinct i.ultimateid, min(i.usage_quarter) as min_invoice_quarter from e365_invoice i join sites s on s.siteid=i.ultimateid where commercial_program='E365' group by all having max(i.usage_quarter) > 20252 order by min(i.usage_quarter);
*/


--------------------------
--CONSUMPTION FORECAST
--------------------------


-- **** Created a dummy DS_FPA_CONSUMPTION_FORCAST_AGGREGATED_QA table as 
--      a place holder until we can get the source of truth ****
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.DS_FPA_CONSUMPTION_FORECAST_AGGREGATED_QA AS
    SELECT "Ultimate ID" AS ULTIMATEID, 
        cd."E365 Category" AS E365_PRODUCT_CATEGORY,
        to_char(cd."Usage Date", 'YYYY') CALENDAR_YEAR, 
        cd."Year Quarter" CALENDAR_QUARTER,
        to_date(cd."Max Update Date") PREDICTION_DATE,
        "Normalized Consumption" CONSUMPTION_PREDICTION 
  FROM MART.OBT_CONSUMPTION_DAILY cd
 WHERE cd."Usage Date" > '2026-01-01'
  limit 50000;
--*********************************************************************

--Persist to bring into Sigma
--Was created as a table and not temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ConsumptionForecast_2026 AS
SELECT
    CONCAT(f.CALENDAR_YEAR, f.CALENDAR_QUARTER) AS YEAR_QUARTER,
    f.ULTIMATEID,
    UPPER(E365_PRODUCT_CATEGORY) AS E365_CATEGORY,
    SUM(f.CONSUMPTION_PREDICTION) AS CONSUMPTION
FROM SANDBOX.FPANDA.DS_FPA_CONSUMPTION_FORECAST_AGGREGATED_QA f  --REPORTING_DB.DATA_SCIENCE.DS_FPA_CONSUMPTION_FORECAST_AGGREGATED_QA f
JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = f.ULTIMATEID
WHERE s."Ultimate Commercial Program" = 'E365' -- s.COMMERCIAL_PROGRAM
  AND f.CALENDAR_YEAR = 2026
  AND f.PREDICTION_DATE = $PREDICTION_DATE
GROUP BY ALL
ORDER BY 1,2;


--------------------------------------------------------------------------------------------------------------------------------------------------------------                                                                                           --CAT A--
--------------------------------------------------------------------------------------------------------------------------------------------------------------


------------------------------
--STAGE CAT A CONSUMPTION
------------------------------
--Store Ultimates currently in consumption_metrics on E365 (in case any from ML are no longer in)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.LiveE365Ultimates_FromCM AS
SELECT DISTINCT cm."Ultimate ID" as ULTIMATEID
FROM MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
WHERE s."Ultimate Commercial Program" = 'E365' 
    AND cm."In Contracts" = 'Yes'
    AND p."Acquisition Source" NOT IN ('Seequent');

--select * from LiveE365Ultimates_FromCM;
--541


--Cat A forecast for 2026, by Ultimate 
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_ConsumptionForecast2026_ByUltimate AS
SELECT
    CONCAT(f.CALENDAR_YEAR, f.CALENDAR_QUARTER) AS YEAR_QUARTER,
    f.ULTIMATEID,
    UPPER(E365_PRODUCT_CATEGORY) AS E365_CATEGORY,
    SUM(f.CONSUMPTION_PREDICTION) AS CONSUMPTION
FROM SANDBOX.FPANDA.DS_FPA_CONSUMPTION_FORECAST_AGGREGATED_QA f  --REPORTING_DB.DATA_SCIENCE.DS_FPA_CONSUMPTION_FORECAST_AGGREGATED_QA f
JOIN MART.OBT_SITE_EXPANDED s ON f.ULTIMATEID = s."Site ID" --s.SITEID = f.ULTIMATEID
WHERE s."Ultimate Commercial Program" = 'E365'
  AND f.CALENDAR_YEAR = 2026
  AND f.PREDICTION_DATE = $PREDICTION_DATE
  AND E365_PRODUCT_CATEGORY='Category A'
GROUP BY ALL
ORDER BY 1,2;


--Store Ultimates from ML forecast (to bring in their history) - to calc QoQ % growth
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ForecastUltimates_CatA_2026 AS
SELECT DISTINCT ULTIMATEID
FROM SANDBOX.FPANDA.CatA_ConsumptionForecast2026_ByUltimate;


--Stage those Ultimates' actual Cat A consumption from 2025 (from old tiering snapshot - aligns w/ ML)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_ConsumptionActuals2025_ByUltimate AS
SELECT
    cm."Year Quarter" as YEAR_QUARTER,
    cm."Ultimate ID" as ULTIMATEID,
    cm."E365 Category" as E365_CATEGORY,
    SUM(cm."Normalized Consumption") AS CONSUMPTION 
FROM MART.OBT_CONSUMPTION_DAILY cm --snapshot from before PW tiering 
JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
JOIN SANDBOX.FPANDA.ForecastUltimates_CatA_2026 fu ON fu.ULTIMATEID = cm."Ultimate ID"
WHERE s."Ultimate Commercial Program" = 'E365' 
  AND cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
  AND cm."E365 Category" = 'CATEGORY A'
  AND cm."Year Quarter" BETWEEN $HIST_START_YQ AND $HIST_END_YQ
GROUP BY ALL
ORDER BY 1,2;


--select year_quarter, sum(consumption) from CatA_ConsumptionActuals2025_ByUltimate group by all order by 1;


--Combine Cat A actuals and forecast -- will be missing Ultimates not in ML (pick up later)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_Consumption_2025Actuals_2026Forecast AS
SELECT
    a.YEAR_QUARTER,
    a.ULTIMATEID,
    a.E365_CATEGORY,
    a.CONSUMPTION,
    'ACTUAL' AS DATA_SOURCE
FROM SANDBOX.FPANDA.CatA_ConsumptionActuals2025_ByUltimate a
UNION ALL
SELECT
    f.YEAR_QUARTER,
    f.ULTIMATEID,
    f.E365_CATEGORY,
    f.CONSUMPTION,
    'FORECAST' AS DATA_SOURCE
FROM SANDBOX.FPANDA.CatA_ConsumptionForecast2026_ByUltimate f;



--Calc QoQ % per Ultimate for Cat A consumption
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_QoQ_Growth_AllPeriods AS
SELECT
    YEAR_QUARTER,
    ULTIMATEID,
    E365_CATEGORY,
    CONSUMPTION AS CURRENT_QTR_CONSUMPTION,
    LAG(CONSUMPTION) OVER (PARTITION BY ULTIMATEID ORDER BY YEAR_QUARTER) AS PREV_QTR_CONSUMPTION,
    CASE
        WHEN LAG(CONSUMPTION) OVER (PARTITION BY ULTIMATEID ORDER BY YEAR_QUARTER) IS NULL
          OR LAG(CONSUMPTION) OVER (PARTITION BY ULTIMATEID ORDER BY YEAR_QUARTER) = 0
        THEN NULL
        ELSE (CONSUMPTION - LAG(CONSUMPTION) OVER (PARTITION BY ULTIMATEID ORDER BY YEAR_QUARTER))
             / LAG(CONSUMPTION) OVER (PARTITION BY ULTIMATEID ORDER BY YEAR_QUARTER)
    END AS QOQ_GROWTH_PCT
FROM SANDBOX.FPANDA.CatA_Consumption_2025Actuals_2026Forecast;

--select * from CatA_QoQ_Growth_AllPeriods where ultimateid=1000009736 order by year_quarter;


--Store 2026 QoQ consumption growth rows (this is Ultimates in the ML forecast & currently present in CM)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_QoQ_Growth_2026 AS
SELECT g.*
FROM SANDBOX.FPANDA.CatA_QoQ_Growth_AllPeriods g
JOIN SANDBOX.FPANDA.LiveE365Ultimates_FromCM le ON le.ULTIMATEID = g.ULTIMATEID
WHERE g.YEAR_QUARTER BETWEEN $FCST_START_YQ AND $FCST_END_YQ
ORDER BY g.ULTIMATEID, g.YEAR_QUARTER;

--select count(distinct ultimateid) from CatA_QoQ_Growth_2026;
--531
--9 ultimates in CM, not in forecast (picked up in New_CatA_Ultimates_NotInForecast below)

------------------------------
--PICK UP MISSING ULTIMATES   
-------------------------------

--Pick up Ultimates in live CM, but not in ML forecast (New)             
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.New_CatA_Ultimates_NotInForecast AS
SELECT
    cm."Ultimate ID" as ULTIMATEID,
    MIN(cm."Year Quarter") AS FIRST_USAGE_QTR,
    MAX( cm."Year Quarter") AS LAST_USAGE_QTR,
    COUNT(DISTINCT  cm."Year Quarter") AS NUM_QUARTERS_WITH_USAGE,
    SUM(cm."Normalized Consumption") AS TOTAL_CONSUMPTION
FROM MART.OBT_CONSUMPTION_DAILY cm
JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN SANDBOX.FPANDA.ForecastUltimates_CatA_2026 f ON f.ULTIMATEID = cm."Ultimate ID"
WHERE s."Ultimate Commercial Program" = 'E365' AND cm."In Contracts" = 'Yes'
    AND f.ULTIMATEID IS NULL AND p."Acquisition Source" NOT IN ('Seequent')
GROUP BY ALL
ORDER BY FIRST_USAGE_QTR DESC;


--Store Ultimates in e365_invoice (w/ recent cat a usage), but not in live CM (if we don't catch their usage)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatAUltimatesInInvoice_NotInCM AS
SELECT top 50
    COALESCE(s."Ultimate ID", e.ULTIMATEID) AS ULTIMATEID, --account for consolidations
    e.usagequarter AS YEAR_QUARTER,
    SUM(e.gross) AS TOTAL_DAILY_GROSS
FROM E365_INVOICE e
LEFT JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = e.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.LiveE365Ultimates_FromCM le ON le.ULTIMATEID = COALESCE(s."Ultimate ID", e.ULTIMATEID)
WHERE e.usageinterval = 'Daily'
  AND TO_NUMBER(e.usagequarter) = $HIST_END_YQ
  AND le.ULTIMATEID IS NULL --not in live CM tbale
GROUP BY 1,2;

------------------------------
--STAGE CAT A % TO INVOICE
------------------------------

--Baseline (25Q4) Cat A gross for the ultimates that exist in CatA_QoQ_Growth_2026 (in ML & live CM)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_DailyGrossBaseline_MaxAvail AS
WITH invoice_daily AS (
    SELECT
        COALESCE(s."Ultimate ID", e.ULTIMATEID) AS ULTIMATEID, --for Ultimates that have consolidated
        e.usagequarter AS USAGE_QUARTER,
        SUM(e.gross) AS DAILY_GROSS
    FROM E365_INVOICE e
    LEFT JOIN MART.OBT_SITE_EXPANDED s ON e.ULTIMATEID = s."Site ID"
    WHERE e.usageinterval = 'Daily'
    GROUP BY ALL),
max_qtr AS (
    SELECT --for each ultimate, find latest daily invoice quarter up to HIST_END_YQ
        i.ULTIMATEID,
        MAX(i.USAGE_QUARTER) AS MAX_USAGE_QUARTER
    FROM invoice_daily i
    WHERE i.USAGE_QUARTER <= $HIST_END_YQ
    GROUP BY ALL)
SELECT
    g.ULTIMATEID,
    mq.MAX_USAGE_QUARTER AS BASELINE_YEAR_QUARTER,
    id.DAILY_GROSS AS BASELINE_DAILY_GROSS
FROM (SELECT DISTINCT ULTIMATEID FROM SANDBOX.FPANDA.CatA_QoQ_Growth_2026) g
LEFT JOIN max_qtr mq ON mq.ULTIMATEID = g.ULTIMATEID
LEFT JOIN invoice_daily id ON id.ULTIMATEID = g.ULTIMATEID
   AND id.USAGE_QUARTER = mq.MAX_USAGE_QUARTER
WHERE BASELINE_YEAR_QUARTER IS NOT NULL --likely consolidated (no longer exists in consumption)
ORDER BY BASELINE_YEAR_QUARTER DESC NULLS LAST, g.ULTIMATEID;

--select count(distinct ultimateid) from CatA_DailyGrossBaseline_MaxAvail;
--523 (takes out where baseline_year_quarter = null - so they don't exist in e365_invoice)          ----------------------INVESTIGATE WHO THESE ARE

--select count(distinct ultimateid) from e365_invoice where usage_interval='Daily' and usage_quarter=20254 having sum(gross) > 0;
--517 (511 in my dataset) - 6 in CM, not in invoice


--Store those w/ the right 'baseline' quarter (i.e. have daily usage in 20254)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_DailyBaseline_Ready AS
SELECT
    ULTIMATEID,
    BASELINE_YEAR_QUARTER,
    BASELINE_DAILY_GROSS
FROM SANDBOX.FPANDA.CatA_DailyGrossBaseline_MaxAvail
WHERE BASELINE_YEAR_QUARTER = $HIST_END_YQ AND BASELINE_DAILY_GROSS > 0;

--select distinct ultimateid from CatA_DailyBaseline_Ready;
--511


--Store who has usage in the forecast start quarter (20261) to check they're still active
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.InvoiceDailyGross_FCST_START_QTR AS
SELECT
    ULTIMATEID,
    e.usagequarter AS YEAR_QUARTER,
    SUM(e.gross) AS DAILY_GROSS
FROM E365_INVOICE e
WHERE e.usageinterval = 'Daily' AND e.usagequarter = $FCST_START_YQ
GROUP BY ALL
HAVING SUM(e.gross) > 0;


--Set aside Ultimates w/out 20254 daily usage, but had past and have usage in 20261 (likely still active & should be included - use avgs)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_DailyBaseline_NeedsHandled AS
SELECT
    b.ULTIMATEID,
    BASELINE_YEAR_QUARTER,
    BASELINE_DAILY_GROSS,
    f.DAILY_GROSS AS FCST_START_DAILY_GROSS
FROM SANDBOX.FPANDA.CatA_DailyGrossBaseline_MaxAvail b
JOIN SANDBOX.FPANDA.InvoiceDailyGross_FCST_START_QTR f ON f.ULTIMATEID = b.ULTIMATEID
WHERE BASELINE_YEAR_QUARTER < $HIST_END_YQ AND BASELINE_DAILY_GROSS > 0;

--5 ultimates (w/ 20253 usage and 20261 - will use avgs so they don't drop out completely)



------------------------------
--STORE ULTIMATES TO HANDLE             
------------------------------

--Store all 'missing' ultimates to take avg from all available invoice quarters & apply        
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_Ultimates_Unhandled AS
SELECT DISTINCT
    ULTIMATEID,
    'LIVE_IN_CM_NOT_IN_ML_FORECAST' AS REASON
FROM SANDBOX.FPANDA.New_CatA_Ultimates_NotInForecast
UNION ALL
SELECT DISTINCT
    ULTIMATEID,
    'IN_INVOICE_ONLY_NOT_IN_LIVE_CM' AS REASON
FROM SANDBOX.FPANDA.CatAUltimatesInInvoice_NotInCM
UNION ALL
SELECT DISTINCT
    ULTIMATEID,
    'NO_BASELINE_INVOICE_QTR_USAGE_BUT_LIVE' AS REASON
FROM SANDBOX.FPANDA.CatA_DailyBaseline_NeedsHandled;



------------------------------
--APPLY CAT A % TO INVOICE
------------------------------

--Combine 20254 baseline gross for daily usage & QoQ consumption growth
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_DailyGrossForecastStaging_2026 AS
SELECT
    q.ULTIMATEID,
    q.YEAR_QUARTER,
    q.QOQ_GROWTH_PCT,
    b.BASELINE_DAILY_GROSS AS BASELINE_DAILY_GROSS_20254,
    TO_NUMBER(RIGHT(TO_VARCHAR(q.YEAR_QUARTER), 1)) AS QTR_NUM
FROM SANDBOX.FPANDA.CatA_QoQ_Growth_2026 q
JOIN SANDBOX.FPANDA.CatA_DailyBaseline_Ready b ON b.ULTIMATEID = q.ULTIMATEID
WHERE q.YEAR_QUARTER BETWEEN $FCST_START_YQ AND $FCST_END_YQ
QUALIFY ROW_NUMBER() OVER (PARTITION BY q.ULTIMATEID, q.YEAR_QUARTER ORDER BY q.ULTIMATEID) = 1
ORDER BY 1,2;


--select distinct ultimateid from CatA_DailyGrossForecastStaging_2026; --511 Ultimates (matches above)
--select * from CatA_QoQ_Growth_2026 where ultimateid=1000009736;
--select * from CatA_DailyBaseline_Ready where ultimateid=1000009736;
--select sum(gross) from e365_invoice where ultimateid=1000009736 and usage_interval='Daily' and usage_quarter=20254;



--Calculate 2026 daily values
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_DailyGrossForecast_2026 AS
WITH RECURSIVE step AS (
    SELECT
        d.ULTIMATEID,
        d.YEAR_QUARTER,
        d.QTR_NUM,
        d.QOQ_GROWTH_PCT,
        d.BASELINE_DAILY_GROSS_20254,
        d.BASELINE_DAILY_GROSS_20254 * (1 + COALESCE(d.QOQ_GROWTH_PCT, 0)) AS FORECASTED_DAILY_GROSS
    FROM SANDBOX.FPANDA.CatA_DailyGrossForecastStaging_2026 d
    WHERE d.QTR_NUM = 1
    UNION ALL
    SELECT
        d.ULTIMATEID,
        d.YEAR_QUARTER,
        d.QTR_NUM,
        d.QOQ_GROWTH_PCT,
        s.BASELINE_DAILY_GROSS_20254,
        s.FORECASTED_DAILY_GROSS * (1 + COALESCE(d.QOQ_GROWTH_PCT, 0)) AS FORECASTED_DAILY_GROSS
    FROM step s
    JOIN SANDBOX.FPANDA.CatA_DailyGrossForecastStaging_2026 d ON d.ULTIMATEID = s.ULTIMATEID
     AND d.QTR_NUM = s.QTR_NUM + 1)
SELECT
    ULTIMATEID,
    YEAR_QUARTER,
    'Daily' AS USAGE_INTERVAL,
    FORECASTED_DAILY_GROSS AS TOTAL_GROSS
FROM step
ORDER BY ULTIMATEID, YEAR_QUARTER;

--select distinct ultimateid from CatA_DailyGrossForecast_2026; --511 ultimates
--SELECT * FROM CatA_DailyGrossForecast_2026 where ultimateid=1000009736 order by year_quarter;



------------------------------
--UPDATE SPINE W/ CAT A
------------------------------

--Populate w/ Ultimates that had an invoice baseline (majority of Ultimates)
UPDATE SANDBOX.FPANDA.ForecastedUsage_2026_Spine f
SET TOTAL_GROSS = d.TOTAL_GROSS
FROM SANDBOX.FPANDA.CatA_DailyGrossForecast_2026 d
WHERE f.ULTIMATEID = d.ULTIMATEID
    AND f.YEAR_QUARTER = d.YEAR_QUARTER
    AND f.USAGE_INTERVAL = 'Daily'
    AND f.TOTAL_GROSS IS NULL;


--Populate w/ (new) Ultimates where we're using avgs (vs ML)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_Unhandled_DailyInvoiceHistory AS
SELECT
    COALESCE(s."Ultimate ID", e.ULTIMATEID) AS ULTIMATEID,
    e.usagequarter AS YEAR_QUARTER,
    SUM(e.gross) AS TOTAL_DAILY_GROSS
FROM E365_INVOICE e
LEFT JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = e.ULTIMATEID
JOIN SANDBOX.FPANDA.CatA_Ultimates_Unhandled u ON u.ULTIMATEID = COALESCE(s."Ultimate ID", e.ULTIMATEID) --15 'missing' Ultimates
WHERE e.usageinterval = 'Daily'
    AND usagequarter BETWEEN $HIST_START_YQ AND $HIST_END_YQ
GROUP BY ALL;

--Calc avg across available quarters (9 Ultimates dropped out exist in invoice)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_Unhandled_DailyAvgGross AS
SELECT
    h.ULTIMATEID,
    AVG(h.TOTAL_DAILY_GROSS) AS AVG_DAILY_GROSS,
    COUNT(DISTINCT h.YEAR_QUARTER) AS NUM_QTRS_USED --proves they're all new (4 or fewer qtrs)
FROM SANDBOX.FPANDA.CatA_Unhandled_DailyInvoiceHistory h
GROUP BY ALL;


--Update spine w/ avgs for those Ultimates
UPDATE SANDBOX.FPANDA.ForecastedUsage_2026_Spine f
SET TOTAL_GROSS = a.AVG_DAILY_GROSS
FROM SANDBOX.FPANDA.CatA_Unhandled_DailyAvgGross a
WHERE f.ULTIMATEID = a.ULTIMATEID
    AND f.USAGE_INTERVAL = 'Daily'
    AND f.YEAR_QUARTER BETWEEN $FCST_START_YQ AND $FCST_END_YQ
    AND f.TOTAL_GROSS IS NULL;
--32 rows were updated (likely 8 ultimates)



/*
--------------------TROUBLESHOOT THESE 23 ULTIMATES (MUST HAVE HAD 2025 DAILY INVOICE, BUT NOT IN ML OR UNHANDLED)
SELECT
    f.ULTIMATEID,
    IFF(c.ULTIMATEID IS NOT NULL, 1, 0) AS IN_CATA_DAILY_FORECAST,
    IFF(a.ULTIMATEID IS NOT NULL, 1, 0) AS IN_UNHANDLED_AVG
FROM (
    SELECT ULTIMATEID
    FROM ForecastedUsage_2026_Spine
    WHERE USAGE_INTERVAL='Daily'
    GROUP BY ULTIMATEID
    HAVING MAX(COALESCE(TOTAL_GROSS,0)) = 0) f
LEFT JOIN (SELECT DISTINCT ULTIMATEID FROM CatA_DailyGrossForecast_2026) c
    ON c.ULTIMATEID = f.ULTIMATEID
LEFT JOIN (SELECT DISTINCT ULTIMATEID FROM CatA_Unhandled_DailyAvgGross) a
    ON a.ULTIMATEID = f.ULTIMATEID
ORDER BY f.ULTIMATEID;
*/


--Missing ultimates (10)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatA_MissingDailyInSpine AS
SELECT
    ULTIMATEID
FROM SANDBOX.FPANDA.ForecastedUsage_2026_Spine
WHERE USAGE_INTERVAL = 'Daily'
GROUP BY ULTIMATEID
HAVING MAX(COALESCE(TOTAL_GROSS, 0)) = 0;


/*
--Did these 10 accounts actually have invoice data for daily in 2025?   ----------Sparse 2025 data and none in 20254 (less acquistions - still decide how to handle)
SELECT
    e.ULTIMATEID,
    e.ACCOUNT_NAME,
    COUNT(DISTINCT TO_NUMBER(e.USAGE_QUARTER)) AS NUM_2025_QTRS_WITH_DAILY,
    SUM(e.GROSS) AS TOTAL_2025_DAILY_GROSS,
    MIN(TO_NUMBER(e.USAGE_QUARTER)) AS FIRST_2025_DAILY_QTR,
    MAX(TO_NUMBER(e.USAGE_QUARTER)) AS LAST_2025_DAILY_QTR
FROM E365_INVOICE e
JOIN CatA_MissingDailyInSpine m ON m.ULTIMATEID = e.ULTIMATEID
WHERE e.USAGE_INTERVAL = 'Daily'
  AND TO_NUMBER(e.USAGE_QUARTER) BETWEEN 20251 AND $HIST_END_YQ
GROUP BY ALL
ORDER BY TOTAL_2025_DAILY_GROSS ASC;



--Do they have a baseline quarter < or = baseline (20254)  
SELECT
    e.ULTIMATEID,
    MAX(TO_NUMBER(e.USAGE_QUARTER)) AS MAX_DAILY_QTR_LE_HIST_END,
    SUM(CASE WHEN TO_NUMBER(e.USAGE_QUARTER) = $HIST_END_YQ THEN e.GROSS ELSE 0 END) AS GROSS_IN_HIST_END,
    SUM(CASE WHEN TO_NUMBER(e.USAGE_QUARTER) = ($HIST_END_YQ - 1) THEN e.GROSS ELSE 0 END) AS GROSS_IN_HIST_END_MINUS1
FROM E365_INVOICE e
JOIN CatA_MissingDailyInSpine m ON m.ULTIMATEID = e.ULTIMATEID
WHERE e.USAGE_INTERVAL = 'Daily'
  AND TO_NUMBER(e.USAGE_QUARTER) <= $HIST_END_YQ
GROUP BY 1
ORDER BY MAX_DAILY_QTR_LE_HIST_END NULLS FIRST;
*/


--------------------------------------------------------------------------------------------------------------------------------------------------
                                                                        --CAT B--
---------------------------------------------------------------------------------------------------------------------------------------------------            

-------------------------------
--CAT B INVOICE REGRESSION
-------------------------------

--Global Current Prices (to try tying to Mirko's Cat B consumption forecast)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Forecast_GlobalUSD_LatestIteration_Prices AS
SELECT Usage_Fee_Interval, ProductID, Global_Current_Price
    FROM (SELECT DISTINCT
    e.usageinterval as Usage_Fee_Interval,
    e.productid as ProductID,
    E365_GROSS_PRICE AS Global_Current_Price,
    ROW_NUMBER() OVER (PARTITION BY e.productid ORDER BY Iteration DESC) AS rn
FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb
LEFT JOIN E365_INVOICE e ON pb.productid = e.productid  -- JOINED ON E365_INVOICE TO GET THE USAGE INTERVAL
WHERE Pricebook = 'Global' AND e.usageinterval in ('Quarterly'))
WHERE rn = 1;


--What each customer actually pays
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Forecast_Customer_Actual_Prices AS
SELECT
    UltimateID,
    usageinterval as Usage_Interval,
    ProductID,
    Max(Gross) as Actual_Gross,
    Max(Net) as Actual_Net
FROM e365_invoice
WHERE usageinterval in ('Quarterly')
    AND usagequarter BETWEEN 20251 AND 20254
GROUP BY ALL;


--Cat B invoice by ultimate (regression for users by product)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Forecast_CatB_Users_ByUltimate AS
WITH
params AS (
  SELECT
    20234::NUMBER AS hist_start_qtr,       -----for ultimate labels
    20254::NUMBER AS hist_end_qtr,
    8::NUMBER AS reg_max_quarters_back),   -----changed from 12 to 8 for more recent data (didn't really change the numbers)
--quarterly historic users
catb_quarterly_users AS (
  SELECT
      ei.ULTIMATEID as UltimateID,
      ei.productid as ProductID,
      ei.usagequarter as Year_Quarter,
      COUNT(DISTINCT ei.uniquepersona) AS QuarterlyUsers
  FROM E365_INVOICE ei
  JOIN MART.OBT_SITE_EXPANDED s
    ON s."Site ID" = ei.ULTIMATEID
  JOIN params p ON TRUE
  WHERE s."Ultimate Commercial Program" = 'E365'
    AND ei.usageinterval = 'Quarterly'
    AND ei.usagequarter BETWEEN p.hist_start_qtr AND p.hist_end_qtr
  GROUP BY ALL),
quarter_dim AS (
  SELECT
    Year_Quarter,
    DENSE_RANK() OVER (ORDER BY Year_Quarter) AS QuarterIndex
  FROM (SELECT DISTINCT Year_Quarter FROM catb_quarterly_users)),
quarter_meta AS (
  SELECT
    MAX(Year_Quarter)  AS MaxYear_Quarter,
    MAX(QuarterIndex) AS MaxQuarterIndex
  FROM quarter_dim),
ultimate_stats AS (
  SELECT
    UltimateID,
    MIN(Year_Quarter) AS FirstQtr,
    MAX(Year_Quarter) AS LastQtr,
    COUNT(DISTINCT Year_Quarter) AS NumQuarters
  FROM catb_quarterly_users
  GROUP BY 1),
ultimate_stats_w_idx AS (
  SELECT
    a.*,
    qf.QuarterIndex AS FirstIdx,
    ql.QuarterIndex AS LastIdx
  FROM ultimate_stats a
  JOIN quarter_dim qf ON qf.Year_Quarter = a.FirstQtr
  JOIN quarter_dim ql ON ql.Year_Quarter = a.LastQtr),
account_labels AS (
  SELECT
    s.UltimateID,
    s.FirstQtr,
    s.LastQtr,
    s.NumQuarters,
    m.MaxQuarterIndex,
    s.FirstIdx,
    s.LastIdx,
    (m.MaxQuarterIndex - s.LastIdx) AS QuartersSinceLast,
    CASE
      WHEN (m.MaxQuarterIndex - s.LastIdx) >= 3 THEN 'Lost'     ----changed from 2 to 3 to grab those w/ 20252 usage
      WHEN s.NumQuarters < 5 THEN 'New'
      ELSE 'Mature'
    END AS AccountLabel
  FROM ultimate_stats_w_idx s
  CROSS JOIN quarter_meta m),
reg_training AS (
  SELECT
    c.UltimateID,
    c.ProductID,
    c.Year_Quarter,
    c.QuarterlyUsers,
    q.QuarterIndex::FLOAT AS TimeIndex
  FROM catb_quarterly_users c
  JOIN quarter_dim q
    ON q.Year_Quarter = c.Year_Quarter
  JOIN account_labels al
    ON al.UltimateID = c.UltimateID
  JOIN params p ON TRUE
  JOIN quarter_meta m ON TRUE
  WHERE al.AccountLabel = 'Mature'
    AND q.QuarterIndex >= m.MaxQuarterIndex - p.reg_max_quarters_back + 1),
reg_coeff AS (
  SELECT
    UltimateID,
    ProductID,
    REGR_SLOPE(QuarterlyUsers, TimeIndex) AS Slope,
    REGR_INTERCEPT(QuarterlyUsers, TimeIndex) AS Intercept,
    COUNT(*) AS NumPoints
  FROM reg_training
  GROUP BY 1,2
  HAVING COUNT(*) >= 4),
--placeholders for next 4 quarters
cal_quarter_index AS (
  SELECT
    year_quarter_num AS Year_Quarter,
    ROW_NUMBER() OVER (ORDER BY year_quarter_num) AS QuarterIndex
  FROM (SELECT DISTINCT "Year Quarter Num" AS year_quarter_num FROM MART.DIM_DATE)),
end_idx AS (
  SELECT cqi.QuarterIndex
  FROM cal_quarter_index cqi
  JOIN params p ON TRUE
  WHERE cqi.Year_Quarter = p.hist_end_qtr),
future_quarters AS (
  SELECT
    cqi.Year_Quarter,
    cqi.QuarterIndex - e.QuarterIndex AS QuarterStepsFromEnd
  FROM cal_quarter_index cqi
  CROSS JOIN end_idx e
  WHERE cqi.QuarterIndex > e.QuarterIndex
  QUALIFY ROW_NUMBER() OVER (ORDER BY cqi.QuarterIndex) <= 4),
mature_forecast AS (
  SELECT
    rc.UltimateID,
    rc.ProductID,
    fq.Year_Quarter,
    GREATEST(
      rc.Slope * (m.MaxQuarterIndex + fq.QuarterStepsFromEnd)::FLOAT + rc.Intercept,
      0)::NUMBER(18,4) AS ForecastedUsers
  FROM reg_coeff rc
  CROSS JOIN quarter_meta m
  JOIN future_quarters fq ON TRUE),
new_avg AS (
  SELECT
    c.UltimateID,
    c.ProductID,
    AVG(c.QuarterlyUsers) AS AvgUsersAllQuarters
  FROM catb_quarterly_users c
  JOIN account_labels al
    ON al.UltimateID = c.UltimateID
  WHERE al.AccountLabel = 'New'
  GROUP BY 1,2),
new_forecast AS (
  SELECT
    n.UltimateID,
    n.ProductID,
    fq.Year_Quarter,
    n.AvgUsersAllQuarters::NUMBER(18,4) AS ForecastedUsers
  FROM new_avg n
  JOIN future_quarters fq ON TRUE),
combined_forecast AS (
  SELECT * FROM mature_forecast
  UNION ALL
  SELECT * FROM new_forecast)
SELECT
  UltimateID,
  Year_Quarter,
  ProductID,
  SUM(ForecastedUsers) AS TotalForecastedUsers
FROM combined_forecast
GROUP BY 1,2,3
ORDER BY 1,2,3;



--Compute Cat B gross                       ----------------------------------CHECK IN ON PW NEW TIERING AND IMPACT?-------------------------------
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Forecast_CatB_Amounts_ByUltimateProductQtr AS
SELECT
    f.UltimateID,
    f.Year_Quarter,
    f.ProductID,
    f.TotalForecastedUsers AS Forecasted_Quarterly_Users,
    gp.Global_Current_Price AS GlobalUSD_Quarterly_Price,
    ap.Actual_Gross AS Actual_Quarterly_Gross_Price,
    ap.Actual_Net AS Actual_Quarterly_Net_Price,
    f.TotalForecastedUsers * gp.Global_Current_Price AS Forecast_GlobalUSD_Gross,
    f.TotalForecastedUsers * ap.Actual_Gross AS Forecast_Actual_Gross,
    f.TotalForecastedUsers * ap.Actual_Net AS Forecast_Actual_Net
FROM SANDBOX.FPANDA.Forecast_CatB_Users_ByUltimate f
LEFT JOIN SANDBOX.FPANDA.Forecast_GlobalUSD_LatestIteration_Prices gp ON gp.ProductID = f.ProductID 
    AND gp.Usage_Fee_Interval = 'Quarterly'
LEFT JOIN SANDBOX.FPANDA.Forecast_Customer_Actual_Prices ap ON ap.UltimateID = f.UltimateID 
    AND ap.ProductID = f.ProductID AND ap.Usage_Interval = 'Quarterly';

--select top 10 * from Forecast_CatB_Amounts_ByUltimateProductQtr;




----------------------------
--POPULATE SPINE W/ CAT B
----------------------------

--Roll up to the grain of the spine
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CatB_QuarterlyGrossForecast_2026 AS
SELECT
    UltimateID,
    Year_Quarter,
    'Quarterly' AS Usage_Interval,
    SUM(Forecast_Actual_Gross) AS Total_Gross
FROM SANDBOX.FPANDA.Forecast_CatB_Amounts_ByUltimateProductQtr
GROUP BY ALL
ORDER BY 1,2;


--select distinct ultimateid from CatB_QuarterlyGrossForecast_2026;
--select usage_quarter, sum(gross) from e365_invoice where usage_interval='Quarterly' and usage_quarter between 20231 and 20254 group by all order by 1;
--SELECT Year_Quarter, SUM(Total_Gross) AS Total_Gross FROM CatB_QuarterlyGrossForecast_2026 GROUP BY ALL ORDER BY 1;


--Pipe into spine
UPDATE SANDBOX.FPANDA.ForecastedUsage_2026_Spine s
SET Total_Gross = b.Total_Gross
FROM SANDBOX.FPANDA.CatB_QuarterlyGrossForecast_2026 b
WHERE s.UltimateID = b.UltimateID
  AND s.Year_Quarter = b.Year_Quarter
  AND s.Usage_Interval = 'Quarterly';
--1,780 rows updated (445 ultimates w/ 4 qtrs each)



/*
-----VALIDATIONS
--how many quarterly spine rows remain null/zero?
SELECT COUNT(*) AS MissingQuarterlyRows
FROM ForecastedUsage_2026_Spine
WHERE Usage_Interval = 'Quarterly'
  AND Year_Quarter BETWEEN $FCST_START_YQ AND $FCST_END_YQ
  AND COALESCE(Total_Gross, 0) = 0;
--93 (down to 71)


--which ultimates are still missing quarterly? --the 21 missing Ultimates have very small dollars for quarterly & most end in 20251 or 20252
SELECT UltimateID
FROM ForecastedUsage_2026_Spine
WHERE Usage_Interval = 'Quarterly'
  AND Year_Quarter BETWEEN $FCST_START_YQ AND $FCST_END_YQ
GROUP BY UltimateID
HAVING MAX(COALESCE(Total_Gross,0)) = 0
ORDER BY UltimateID;
--21 (down to 13 when adjusting timeframe)

--select usage_quarter, usage_interval, sum(gross) from e365_invoice where ultimateid=1001384238 group by all order by 1,2;
*/



----------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                    --ALL OTHER CATEGORIES--
----------------------------------------------------------------------------------------------------------------------------------------------------------------                                                       

----------------------------
--ALL OTHER CATEGORIES
----------------------------

--Get baseline to carry over 2025 Cat B, C, & D values
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.OtherIntervals_Baseline_2025 AS
SELECT
    ULTIMATEID,
    e.usagequarter AS YEAR_QUARTER,
    e.usageinterval AS USAGE_INTERVAL,
    SUM(e.gross) AS BASELINE_GROSS
FROM E365_INVOICE e
WHERE e.usagequarter BETWEEN 20251 AND $HIST_END_YQ
  AND e.usageinterval NOT IN ('Daily','Quarterly')
GROUP BY 1,2,3
HAVING SUM(e.gross) > 0;


--Put 25Q1 in 26Q1, 25Q2 in 26Q2...etc.
UPDATE SANDBOX.FPANDA.ForecastedUsage_2026_Spine f
SET Total_Gross = b.BASELINE_GROSS
FROM SANDBOX.FPANDA.OtherIntervals_Baseline_2025 b
WHERE f.ULTIMATEID = b.ULTIMATEID
    AND f.USAGE_INTERVAL = b.USAGE_INTERVAL
    AND f.YEAR_QUARTER BETWEEN $FCST_START_YQ AND $FCST_END_YQ      
    AND b.YEAR_QUARTER BETWEEN 20251 AND $HIST_END_YQ   
    AND RIGHT(TO_VARCHAR(f.YEAR_QUARTER), 1) = RIGHT(TO_VARCHAR(b.YEAR_QUARTER), 1)
    AND COALESCE(f.Total_Gross, 0) = 0;
--1,678


--Persist to Sigma
-- Was originally created as a temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.GrossForecast2026 AS
select * from SANDBOX.FPANDA.ForecastedUsage_2026_Spine order by ultimateid, year_quarter, usage_interval;


/*
--what's missing from these (troubleshoot)  
SELECT
  USAGE_INTERVAL,
  COUNT(*) AS count,
  COUNT_IF(COALESCE(TOTAL_GROSS,0)=0) AS MISSING
FROM ForecastedUsage_2026_Spine
WHERE YEAR_QUARTER BETWEEN $FCST_START_YQ AND $FCST_END_YQ
  AND USAGE_INTERVAL NOT IN ('Daily','Quarterly')
GROUP BY 1
ORDER BY 1;


select * from ForecastedUsage_2026_Spine order by ultimateid, year_quarter, usage_interval;
select usage_quarter, usage_interval, sum(gross) from e365_invoice where usage_quarter between 20221 and 20254 group by all order by 1,2;
*/



-----------------------------------------------------------------------------------------------------------------------------------------------------------
                                                              --BRING IN DIMENSIONS--
------------------------------------------------------------------------------------------------------------------------------------------------------------

-----------------------
--CONTRACT DETAILS
-----------------------
--Stage Calendar join (to simplify downstream)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Calendar_Lookup AS
SELECT
    "Date" as date_value,
    "Year Quarter Num" as year_quarter_num
FROM MART.DIM_DATE
GROUP BY ALL;

--Bring in renewal date (use proxy if blank)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ContractsActive_Base AS
SELECT
    s."Ultimate ID" as UltimateID,
    COALESCE(s."Ultimate Best Renewal Date", TO_VARCHAR(ca."Contract End Date", 'YYYYMMDD')) AS Ultimate_Renewal_Date_Raw
FROM MART.SSF_CONTRACT_LINE_MONTHLY ca
JOIN MART.OBT_SITE_EXPANDED s ON ca."FK_SITE_SHIP_TO_KEY" = s.sk_site_key   
WHERE ca."ARR Net USD" IS NOT NULL AND ca."ARR Net USD" <> 0;

/*
select count(distinct ultimateid) from ContractsActive_Base;
--35046

select ultimatebestrenewaldate from REPORTING_DB.EDW_TABLES.SITES_DWH where siteid=1001389362; --this ultimate is no longer active on contracts_history
select s.ultimate from Contracts_Active C join sites s on s.siteid=c.ship_toid where s.siteid=1001389362;

select ultimatebestrenewaldate from REPORTING_DB.EDW_TABLES.SITES_DWH where siteid=1001389897;
select max(usage_quarter) from e365_invoice where ultimateid=1001389362;
select * from contracts_active where Ship_ToID=1001389897;
*/


--Grab usage status of history_end_quarter (or most recent quarter)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.CurrentTermsContractStatus AS
SELECT
    ULTIMATE_ID as ultimateid,
    UPPER(TRIM(CONTRACT_VS_USAGE)) AS contract_vs_usage,
    YEAR_QUARTER AS quarter_of_usage_status
FROM E365_TERMS_HISTORY
QUALIFY ROW_NUMBER() OVER 
    (PARTITION BY ULTIMATE_ID ORDER BY CASE WHEN YEAR_QUARTER = $HIST_END_YQ THEN 1 ELSE 2 END, YEAR_QUARTER DESC) = 1;


--Join all dimensions together
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ContractsActive_Renewal_And_Status_Staging AS
SELECT
    cb.UltimateID,
    s."Ultimate Name" AS Ultimate,
    TO_CHAR(cb.Ultimate_Renewal_Date_Raw, 'YYYYMMDD') AS renewal_date,
    LPAD(cl.year_quarter_num::VARCHAR, 5, '0') AS renewal_quarter,
    c.contract_vs_usage,
    c.quarter_of_usage_status
FROM SANDBOX.FPANDA.ContractsActive_Base cb
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cb.UltimateID = s."Site ID"
LEFT JOIN SANDBOX.FPANDA.CurrentTermsContractStatus c ON cb.UltimateID = c.UltimateID
LEFT JOIN SANDBOX.FPANDA.Calendar_Lookup cl ON cl.date_value = TO_CHAR(cb.Ultimate_Renewal_Date_Raw, 'YYYYMMDD')
WHERE s."Ultimate Commercial Program"='E365'
QUALIFY ROW_NUMBER() OVER 
    (PARTITION BY cb.UltimateID ORDER BY TO_CHAR(cb.Ultimate_Renewal_Date_Raw, 'YYYYMMDD') DESC) = 1;

--select count(distinct ultimateid) from ContractsActive_Renewal_And_Status_Staging;
--550


--Final/clean output
--Was originally created as a table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Ultimate_Renewal_Contract_Metadata AS
SELECT
    UltimateID,
    Ultimate,
    renewal_date,
    renewal_quarter,
    contract_vs_usage,
    quarter_of_usage_status
FROM SANDBOX.FPANDA.ContractsActive_Renewal_And_Status_Staging;


--select * from SANDBOX.MARY_MAXSON.Ultimate_Renewal_Contract_Metadata where ultimateid in (1001382680,1001388852,1001389362);
--select * from e365_invoice where ultimateid in (1001382680,1001388852) and usage_quarter=20254;

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.E365_TERMS AS
SELECT *
   FROM PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY
  WHERE YEAR_QUARTER = (select dd."Year Quarter Num" AS year_quarter_num
                          from MART.DIM_DATE dd
                         where dd."Date" = current_date());


----------------------------
--DISCOUNT & F&C DETAILS
----------------------------

--Get base stats                                        
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.UltimateTerms_Base AS
SELECT
    e.ULTIMATE_ID AS UltimateID,
    e.ULTIMATE_NAME AS Ultimate_Name,
    e.currency as Currency,
    CAST(COALESCE(e.target_disc, 0) AS NUMBER(18,4)) AS Discount,
    NULLIF(e.floor_value, 0) AS Original_Floor_Value,
    NULLIF(e.ceiling_value, 0) AS Original_Ceiling_Value
FROM SANDBOX.FPANDA.E365_TERMS e
JOIN MART.OBT_SITE_EXPANDED s ON e.ULTIMATE_ID = s."Site ID"
WHERE s."Ultimate Commercial Program" = 'E365'; --where Ultimate still active

--select * from REPORTING_DB.EDW_TABLES.E365_TERMS_HISTORY where ultimateid=1006703946 order by yearquarter;
--select * from REPORTING_DB.EDW_TABLES.E365_TERMS_HISTORY where ultimateid=1000075491 order by yearquarter;


--Prior year uplift % (capped at 6% and 15%) - for non-known terms (end up capping in Sigma for flex)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Ultimate_PriorYearUplift AS
WITH th AS (
    SELECT
        th.ULTIMATE_ID as UltimateID,
        MAX(CASE WHEN th.year_quarter = 20251 THEN th.FLOOR_VALUE END) AS FloorValue20251,
        MAX(CASE WHEN th.year_quarter = 20261 THEN th.FLOOR_VALUE END) AS FloorValue20261
    FROM E365_TERMS_HISTORY th
    JOIN MART.OBT_SITE_EXPANDED s ON th.ULTIMATE_ID = s."Site ID"
        AND s."Ultimate Commercial Program" = 'E365'
    WHERE th.year_quarter IN (20251, 20261) --check 4 quarters apart (from the most current)
    GROUP BY th.ULTIMATE_ID),
calc AS (
    SELECT
        UltimateID,
        FloorValue20251,
        FloorValue20261,
        CASE
            WHEN FloorValue20251 IS NULL OR FloorValue20261 IS NULL OR FloorValue20251 = 0 THEN NULL
            ELSE (FloorValue20261 - FloorValue20251) / FloorValue20251
        END AS PercIncrease
    FROM th)
SELECT
    UltimateID,
    FloorValue20251,
    FloorValue20261,
    PercIncrease,
    CASE    --cap to 6%–15% if we have a value; otherwise NULL --actually, do in Sigma
        WHEN PercIncrease IS NULL THEN NULL
        WHEN PercIncrease < 0.06 THEN 0.06
        WHEN PercIncrease > 0.15 THEN 0.15
        ELSE PercIncrease
    END AS Uplift_Pct_Capped
FROM calc;

--select * from REPORTING_DB.EDW_TABLES.E365_TERMS_HISTORY where ultimateid=1006394376 order by yearquarter;



--------------------------
--KNOWN UPLIFTS
--------------------------

--Get all valid floor records p/ Ultimate (add deal_iteration here if needed later)
create or replace temp table SANDBOX.FPANDA.rankedfloors_v2 as
select
    ultimateid,
    usage_quarter,
    floor_value,
    row_number() over (partition by ultimateid order by usage_quarter) as rn
from e365_terms_extended
where floor_value is not null
  and floor_value > 0;

--select * from rankedfloors_v2 where ultimateid=1001381496;


--Pair sequential floors
create or replace temp table SANDBOX.FPANDA.pairedfloors_v2 as
select
    cur.ultimateid,
    cur.usage_quarter as current_terms_quarter,
    nxt.usage_quarter as next_terms_quarter,
    cur.floor_value as current_floor,
    nxt.floor_value as next_floor
from SANDBOX.FPANDA.rankedfloors_v2 cur
join SANDBOX.FPANDA.rankedfloors_v2 nxt on cur.ultimateid = nxt.ultimateid
    and nxt.rn = cur.rn + 1
order by cur.ultimateid, cur.usage_quarter;

--select * from pairedfloors_v2 where ultimateid=1001381496;


--Calc uplift %
create or replace temp table SANDBOX.FPANDA.KnownContractUplifts_allperiods as
select
    p.ultimateid,
    p.current_terms_quarter,
    p.next_terms_quarter,
    floor(p.next_terms_quarter / 10) as renewal_year, 
    p.current_floor,
    p.next_floor,
    case when p.current_floor > 0
         then (p.next_floor - p.current_floor) / p.current_floor
         else null
    end as known_contract_uplift_pct
from SANDBOX.FPANDA.pairedfloors_v2 p;

--select * from KnownContractUplifts_allperiods where ultimateid=1001381496;


--small calendar temp table
create or replace temp table SANDBOX.FPANDA.QuarterIndex as
select
    year_quarter_num,
    row_number() over (order by year_quarter_num) as qtr_rn
from (
    select distinct "Year Quarter Num" as year_quarter_num
    from MART.DIM_DATE
    where year_quarter_num > 20201);


--Store final uplift and backdate the year_quarter      
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.KnownContractUplifts_Effective AS
WITH base AS (
    SELECT
        ultimateid,
        current_terms_quarter,
        next_terms_quarter,
        renewal_year,
        current_floor,
        next_floor,
        known_contract_uplift_pct,
        LEAD(next_terms_quarter) OVER (
            PARTITION BY ultimateid
            ORDER BY next_terms_quarter
        ) AS next_next_terms_quarter
    FROM SANDBOX.FPANDA.KnownContractUplifts_allperiods
    WHERE known_contract_uplift_pct IS NOT NULL),
q AS (
    SELECT
        b.*,
        qi_next.qtr_rn AS next_rn,
        qi_nextnext.qtr_rn AS nextnext_rn
    FROM base b
    LEFT JOIN SANDBOX.FPANDA.QuarterIndex qi_next
      ON qi_next.year_quarter_num = b.next_terms_quarter
    LEFT JOIN SANDBOX.FPANDA.QuarterIndex qi_nextnext ON qi_nextnext.year_quarter_num = b.next_next_terms_quarter),
start_end AS (
    SELECT
        q.*,
        qi_start.year_quarter_num AS apply_start_quarter,
        qi_start.qtr_rn AS start_rn,
        qi_end.year_quarter_num AS apply_end_quarter_raw
    FROM q
    LEFT JOIN SANDBOX.FPANDA.QuarterIndex qi_start ON qi_start.qtr_rn = q.next_rn - 1
    LEFT JOIN SANDBOX.FPANDA.QuarterIndex qi_end ON qi_end.qtr_rn = q.nextnext_rn - 2) 
SELECT
    ultimateid,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    known_contract_uplift_pct,
    apply_start_quarter,
    COALESCE(apply_end_quarter_raw, qi_cap.year_quarter_num) AS apply_end_quarter,
    TO_NUMBER(apply_start_quarter) AS apply_start_quarter_num,
    TO_NUMBER(COALESCE(apply_end_quarter_raw, qi_cap.year_quarter_num)) AS apply_end_quarter_num
FROM start_end se
LEFT JOIN SANDBOX.FPANDA.QuarterIndex qi_cap
  ON qi_cap.qtr_rn = se.start_rn + 3; --force an end quarter, avoids nulls     

--select * from KnownContractUplifts_Effective where ultimateid=1001381746;
--select * from KnownContractUplifts_Effective where ultimateid=1001381496;


--Expand known uplifts/multi-years to Ultimate > Quarter grain (to get 2 renewals for 26Q2 plugs)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.KnownUplift_ByUltimateQuarter AS
SELECT
    ku.ultimateid,
    qi.year_quarter_num AS year_quarter,  
    ku.current_terms_quarter,
    ku.next_terms_quarter,
    ku.renewal_year,
    ku.current_floor,
    ku.next_floor,
    ku.known_contract_uplift_pct,
    ku.apply_start_quarter_num,
    ku.apply_end_quarter_num
FROM SANDBOX.FPANDA.KnownContractUplifts_Effective ku
JOIN SANDBOX.FPANDA.QuarterIndex qi
  ON qi.year_quarter_num BETWEEN ku.apply_start_quarter_num AND ku.apply_end_quarter_num
WHERE qi.year_quarter_num IN ($FCST_START_YQ, 20262, 20263, $FCST_END_YQ, 20271); --include all quarters from spine

--select * from KnownUplift_ByUltimateQuarter where ultimateid=1001381746;


--Get FX rate per currency (to join in downstream)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.Currency_FX AS
SELECT dc."Currency ISO Code" AS Currency,   
             1/fb."Fiscal Budget Rate Value" AS FXRate
        FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
        JOIN MART.DIM_CURRENCY dc
          ON fb.fk_source_currency_key = dc.sk_currency_key
       WHERE "Is Current Rate" = 'TRUE';




--Final table joining all dimensions (now at the quarter grain for 26Q4 plugs)
-- Was originally created as a temp table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.E365Forecast_Ultimate_Terms_v2 AS
WITH ForecastQuarters AS (
    SELECT COLUMN1::NUMBER AS year_quarter
    FROM VALUES ($FCST_START_YQ), (20262), (20263), ($FCST_END_YQ), (20271)),
BaseByQuarter AS (
    SELECT
        b.UltimateID,
        b.Ultimate_Name,
        b.Currency,
        b.Discount,
        b.Original_Floor_Value,
        b.Original_Ceiling_Value,
        q.year_quarter
    FROM SANDBOX.FPANDA.UltimateTerms_Base b
    CROSS JOIN ForecastQuarters q)
SELECT
    bq.UltimateID,
    bq.Ultimate_Name AS Ultimate,
    bq.Currency,
    fx.FXRate,
    bq.Discount,
    bq.Original_Floor_Value AS Current_Floor,
    bq.Original_Ceiling_Value AS Current_Ceiling,
    CASE WHEN bq.Original_Floor_Value = bq.Original_Ceiling_Value THEN 1 ELSE 0 END AS Is_EPS,
    bq.year_quarter,
    py.FloorValue20251,
    py.FloorValue20261,
    py.PercIncrease,
    py.Uplift_Pct_Capped,
    kq.known_contract_uplift_pct,
    kq.current_terms_quarter,
    kq.next_terms_quarter,
    kq.renewal_year,
    kq.apply_start_quarter_num AS apply_start_quarter,
    kq.apply_end_quarter_num   AS apply_end_quarter,
    CASE
        WHEN kq.ultimateid IS NOT NULL THEN 'Known Multi-Year'
        WHEN py.UltimateID IS NOT NULL THEN 'Prior-Year Fallback'
        ELSE 'No Uplift'
    END AS Uplift_Type
FROM BaseByQuarter bq
LEFT JOIN SANDBOX.FPANDA.KnownUplift_ByUltimateQuarter kq ON bq.UltimateID = kq.ultimateid
    AND bq.year_quarter = kq.year_quarter
LEFT JOIN SANDBOX.FPANDA.Ultimate_PriorYearUplift py ON bq.UltimateID = py.UltimateID
LEFT JOIN SANDBOX.FPANDA.Currency_FX fx ON bq.Currency = fx.Currency;



--Small helper table to just bring in new FX rates (only refresh)               -------------------------ONLY NEED AFTER FX RATES CHANGE
-- Was originally created as a Table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.E365Forecast_2026FXRatesPerUltimate AS
SELECT
    e.ULTIMATE_ID as UltimateID,
    e.Ultimate_Name AS Ultimate,
    e.Currency,
    lcr.FXRate AS FXRate
FROM SANDBOX.FPANDA.E365_TERMS e
JOIN MART.OBT_SITE_EXPANDED s ON e.ULTIMATE_ID = s."Site ID" 
LEFT JOIN SANDBOX.FPANDA.Currency_FX lcr ON e.Currency = lcr.Currency
WHERE s."Ultimate Commercial Program"='E365';



--Small helper table just bringing in consumption comparisons
-- Was originally created as a Table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.E365Forecast_ConsumptionYoY AS
WITH consumption_yoy AS (
    SELECT
        cm."Ultimate ID" as ultimateid,
        SUM(CASE WHEN cm."Year Quarter" BETWEEN 20241 AND 20244 THEN cm."Normalized Consumption" ELSE 0 END) AS normalized_consumption_2024,
        SUM(CASE WHEN cm."Year Quarter" BETWEEN 20251 AND 20254 THEN cm."Normalized Consumption" ELSE 0 END) AS normalized_consumption_2025
    FROM MART.OBT_CONSUMPTION_DAILY cm
    GROUP BY 1)
SELECT
    cy.ultimateid,
    s."Ultimate Name" as ultimate,
    cy.normalized_consumption_2024,
    cy.normalized_consumption_2025,
    cy.normalized_consumption_2025 - cy.normalized_consumption_2024 AS yoy_delta,
    (cy.normalized_consumption_2025 - cy.normalized_consumption_2024) / NULLIF(cy.normalized_consumption_2024, 0) AS yoy_pct_change
FROM consumption_yoy cy
LEFT JOIN MART.OBT_SITE_EXPANDED s ON s."Site ID" = cy.ultimateid
WHERE s."Ultimate Commercial Program"='E365';
