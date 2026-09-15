/********************************************************************
**  Name: Working Days
**  Refactored Date: 6/5/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES,
**                                                 PRESENTATION.EDW)
**   
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**          E365_INVOICE = EDW.E365_INVOICE (**CONSUMPTION_ENGINE**)
**              CALENDAR = DIM_DATE
**
**
**  Description: 
**
********************************************************************/

--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

-----------------------------------
--WORKING DAYS CTEs FOR SIGMA
-----------------------------------
CREATE OR REPLACE TABLE SANDBOX.FPANDA.WORKING_DAYS_PIVOT AS
WITH distinct_quarters AS (
    SELECT DISTINCT "Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE),
ordered_quarters AS (
    SELECT
        year_quarter_num,
        ROW_NUMBER() OVER (ORDER BY year_quarter_num) AS rn
    FROM distinct_quarters),
today_qtr AS (
    SELECT c."Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE c
    WHERE c."Date" = current_date()),
qtr_params AS (
    SELECT
        o_curr.year_quarter_num  AS rq_curr,
        o_prev.year_quarter_num  AS rq_prev,
        o_4back.year_quarter_num AS rq_4back
    FROM ordered_quarters o_today
    JOIN today_qtr t ON o_today.year_quarter_num = t.year_quarter_num
    JOIN ordered_quarters o_curr ON o_curr.rn = o_today.rn - 1
    JOIN ordered_quarters o_prev ON o_prev.rn = o_today.rn - 2
    JOIN ordered_quarters o_4back ON o_4back.rn = o_today.rn - 5),
TopFiveCountries AS (  
  SELECT
        cm."Usage Country ISO" AS Country,
        SUM(cm."Consumption") AS TotalConsumption
   FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p
      ON cm."Product ID" = p."Product ID"
    CROSS JOIN qtr_params qp
    WHERE cm."Year Quarter" = qp.rq_curr
      AND cm."In Contracts" = 'Yes' 
      AND p."Acquisition Source" NOT IN ('Seequent')
    GROUP BY cm."Usage Country ISO"    
    ORDER BY TotalConsumption DESC LIMIT 5),
DailyMetrics AS (
    SELECT 
        substr(ei.usage_quarter,1,5) AS USAGE_QUARTER,
        ei.country_iso AS COUNTRY,
        ei.usage_date AS USAGE_DATE,
        COUNT(DISTINCT ei.unique_persona) AS DailyUserCount,
        SUM(ei.total_mins) AS DailyTotalMinutes,
        cal."Day of Week" AS DayOfWeek
    FROM EDW.E365_INVOICE ei
    JOIN MART.DIM_DATE cal
      ON ei.usage_date = cal."Date"
    JOIN TopFiveCountries tfc
      ON ei.country_iso = tfc.Country
    CROSS JOIN qtr_params qp
    WHERE
    ei.usage_interval='Daily'
      AND substr(ei.usage_quarter,1,5) IN (qp.rq_curr, qp.rq_prev, qp.rq_4back)
    GROUP BY
        substr(ei.usage_quarter, 1, 5),
        ei.country_iso,
        ei.usage_date,
        cal."Day of Week"),        
QuarterlyAverages AS (
    SELECT 
        USAGE_QUARTER,
        COUNTRY,
        ROUND(AVG(DailyUserCount), 0) AS AvgDailyUserCount,
        ROUND(AVG(DailyTotalMinutes), 0) AS AvgDailyTotalMinutes
    FROM DailyMetrics
    WHERE DayOfWeek NOT IN ('Sat', 'Sun')
    GROUP BY USAGE_QUARTER, COUNTRY),
MetricsWithPercentages AS (
    SELECT 
        dm.USAGE_QUARTER,
        dm.COUNTRY,
        dm.USAGE_DATE,
        dm.DailyUserCount,
        dm.DailyTotalMinutes,
        qa.AvgDailyUserCount,
        qa.AvgDailyTotalMinutes,
        ROUND((dm.DailyUserCount / NULLIF(qa.AvgDailyUserCount, 0)), 6) AS UserPerct,
        ROUND((dm.DailyTotalMinutes / NULLIF(qa.AvgDailyTotalMinutes, 0)), 6) AS MinPerct,
        dm.DayOfWeek,
        CASE 
            WHEN dm.DayOfWeek IN ('Sat', 'Sun') THEN 'Weekend'
            ELSE 'Weekday'
        END AS DayCategory
    FROM DailyMetrics dm
    JOIN QuarterlyAverages qa
      ON dm.USAGE_QUARTER = qa.USAGE_QUARTER
     AND dm.COUNTRY = qa.COUNTRY)
SELECT 
    mwp.USAGE_QUARTER,
    CASE --to pivot in Sigma
        WHEN mwp.USAGE_QUARTER = qp.rq_curr  THEN 'Current Quarter'
        WHEN mwp.USAGE_QUARTER = qp.rq_prev  THEN 'Previous Quarter'
        WHEN mwp.USAGE_QUARTER = qp.rq_4back THEN 'Same Quarter Last Year'
        ELSE 'Other'
    END AS Quarter_Label,
    mwp.COUNTRY,
    mwp.USAGE_DATE,
    mwp.DailyUserCount,
    mwp.AvgDailyUserCount,
    mwp.UserPerct,
    mwp.DailyTotalMinutes,
    mwp.AvgDailyTotalMinutes,
    mwp.MinPerct,
    mwp.DayCategory,
    CASE 
        WHEN mwp.DayCategory = 'Weekend' THEN 'Weekend'
        WHEN mwp.DayCategory = 'Weekday' AND mwp.UserPerct < 0.6 THEN 'Holiday'
        WHEN mwp.DayCategory = 'Weekday' AND mwp.UserPerct BETWEEN 0.6 AND 0.8 THEN 'LowDay'
        WHEN mwp.DayCategory = 'Weekday' THEN 'Workday'
        ELSE NULL 
    END AS FinalDayCategory,
    CASE 
        WHEN mwp.DayCategory = 'Weekday' THEN 1
        ELSE 0
    END AS Is_Weekday
FROM MetricsWithPercentages mwp
CROSS JOIN qtr_params qp
ORDER BY mwp.USAGE_QUARTER, mwp.COUNTRY, mwp.USAGE_DATE;


--Percent of total Cat A being represented by the top 5 countries
CREATE OR REPLACE TABLE SANDBOX.FPANDA.WORKING_DAYS_REPORT_STAT AS
WITH distinct_quarters AS (
    SELECT DISTINCT "Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE),
ordered_quarters AS (
    SELECT
        year_quarter_num,
        ROW_NUMBER() OVER (ORDER BY year_quarter_num) AS rn
    FROM distinct_quarters),
today_qtr AS (
    SELECT c."Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE c
    WHERE c."Date" = current_date()),
reporting_quarter AS (
    SELECT o_prev.year_quarter_num AS reporting_quarter
    FROM ordered_quarters o_today
    JOIN today_qtr t
      ON o_today.year_quarter_num = t.year_quarter_num
    JOIN ordered_quarters o_prev
      ON o_prev.rn = o_today.rn - 1),
TopFiveCountries AS (
     SELECT
        cm."Usage Country ISO" AS Country,
        SUM(cm."Consumption") AS TotalConsumption
   FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p
      ON cm."Product ID" = p."Product ID"
    CROSS JOIN reporting_quarter rq
    WHERE cm."Year Quarter" = rq.reporting_quarter
      AND cm."In Contracts" = 'Yes' 
      AND p."Acquisition Source" NOT IN ('Seequent')
    GROUP BY cm."Usage Country ISO"
    ORDER BY TotalConsumption DESC
    LIMIT 5),
TopFiveMinutes AS (
    SELECT 
        substr(i.usage_quarter, 1, 5) AS USAGE_QUARTER,
        SUM(ei.total_mins) AS TopFiveTotalMinutes
    FROM EDW.E365_INVOICE ei
    JOIN TopFiveCountries tfc
      ON ei.country_iso = tfc.Country
    CROSS JOIN reporting_quarter rq
    WHERE substr(i.usage_quarter, 1, 5) = rq.reporting_quarter
      AND ei.usage_interval = 'Daily'
    GROUP BY ei.usage_quarter),
TotalQuarterMinutes AS (
    SELECT 
        ei.usage_quarter AS USAGE_QUARTER,
        SUM(ei.total_mins) AS TotalMinutes
    FROM EDW.E365_INVOICE ei
    CROSS JOIN reporting_quarter rq
    WHERE substr(i.usage_quarter, 1, 5) = rq.reporting_quarter
      AND ei.usage_interval = 'Daily'
    GROUP BY ei.usage_quarter)
SELECT 
    tfm.USAGE_QUARTER,
    tfm.TopFiveTotalMinutes,
    tqm.TotalMinutes AS TotalQuarterMinutes,
    ROUND((tfm.TopFiveTotalMinutes / NULLIF(tqm.TotalMinutes, 0)) * 100, 2) AS TopFivePercentage
FROM TopFiveMinutes tfm
JOIN TotalQuarterMinutes tqm
  ON tfm.USAGE_QUARTER = tqm.USAGE_QUARTER;