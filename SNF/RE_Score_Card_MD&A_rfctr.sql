
/********************************************************************
**  Name: RE Score Card MD&A
**  Refactored Date: 6/2/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**   
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**                 SITES = OBT_SITE_EXPANDED
**    E365_TERMS_HISTORY = SSF_E365_USAGE_VS_CONTRACT_QUARTERLY, E365_TERMS_HISTORY
**        LOOKUP_COUNTRY = DIM_COUNTRY   *** TABLE AND VIEW TO BE CREATED?***
**              CALENDAR = DIM_DATE
**
**  Description: 
**
********************************************************************/

--------------------------SET CURRENT QUARTER BEFORE RUNNING------------------------------

--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

--------------------------
--STAGE ALL PARAMETERS
--------------------------

--Set current reporting quarter
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.ReportingQuarterInput AS   
SELECT 20261 AS current_quarter;                                        --------------SET CURRENT REPORTING QUARTER HERE (MAKE DYNAMIC BASED ON LAST REPORTING QTR)

--Store all quarters from Calendar table w/ index
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.CalendarRanked AS
SELECT 
    YEAR_QUARTER_NUM,
    ROW_NUMBER() OVER (ORDER BY YEAR_QUARTER_NUM) AS quarter_index
FROM (
    SELECT DISTINCT dd."Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE dd
    WHERE dd."Year Quarter Num" >= 20201) deduped;


--Store all periods needed for this quarter's analysis
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.ReportingQuarterParams AS
WITH current_quarter_cte AS (
    SELECT 
        cr.quarter_index AS current_index,
        cr.YEAR_QUARTER_NUM AS current_reporting_quarter
    FROM SANDBOX.FPANDA.ReportingQuarterInput rqi
    JOIN SANDBOX.FPANDA.CalendarRanked cr ON cr.YEAR_QUARTER_NUM = rqi.current_quarter),
params AS (
    SELECT
        cq.current_reporting_quarter,
        cr1.YEAR_QUARTER_NUM AS prior_year_quarter,
        cr2.YEAR_QUARTER_NUM AS current_q1,
        cr3.YEAR_QUARTER_NUM AS current_q2,
        cr4.YEAR_QUARTER_NUM AS current_q3,
        cr5.YEAR_QUARTER_NUM AS current_q4,
        cr6.YEAR_QUARTER_NUM AS prior_q1,
        cr7.YEAR_QUARTER_NUM AS prior_q2,
        cr8.YEAR_QUARTER_NUM AS prior_q3,
        cr9.YEAR_QUARTER_NUM AS prior_q4
    FROM current_quarter_cte cq
    JOIN SANDBOX.FPANDA.CalendarRanked cr1 ON cr1.quarter_index = cq.current_index - 4
    JOIN SANDBOX.FPANDA.CalendarRanked cr2 ON cr2.quarter_index = cq.current_index
    JOIN SANDBOX.FPANDA.CalendarRanked cr3 ON cr3.quarter_index = cq.current_index - 1
    JOIN SANDBOX.FPANDA.CalendarRanked cr4 ON cr4.quarter_index = cq.current_index - 2
    JOIN SANDBOX.FPANDA.CalendarRanked cr5 ON cr5.quarter_index = cq.current_index - 3
    JOIN SANDBOX.FPANDA.CalendarRanked cr6 ON cr6.quarter_index = cq.current_index - 4
    JOIN SANDBOX.FPANDA.CalendarRanked cr7 ON cr7.quarter_index = cq.current_index - 5
    JOIN SANDBOX.FPANDA.CalendarRanked cr8 ON cr8.quarter_index = cq.current_index - 6
    JOIN SANDBOX.FPANDA.CalendarRanked cr9 ON cr9.quarter_index = cq.current_index - 7)
SELECT * FROM params;

---------------------------
--ACCOUNT METADATA
---------------------------
--Account consumption totals for quarterly YoY and quarterly LTM
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.UltimateMetrics_Base AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
UltimateHistory AS (
    SELECT 
        cm."Ultimate ID" AS ULTIMATEID,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption,
        SUM(cm."Normalized Application Days") AS App_Days
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
    WHERE cm."Year Quarter" IN (
          SELECT current_reporting_quarter FROM Periods UNION
          SELECT prior_year_quarter FROM Periods UNION
          SELECT current_q1 FROM Periods UNION
          SELECT current_q2 FROM Periods UNION
          SELECT current_q3 FROM Periods UNION
          SELECT current_q4 FROM Periods UNION
          SELECT prior_q1 FROM Periods UNION
          SELECT prior_q2 FROM Periods UNION
          SELECT prior_q3 FROM Periods UNION
          SELECT prior_q4 FROM Periods    )
      AND  cm."In Contracts" = 'Yes'
      AND  p."Acquisition Source"  NOT IN ('Seequent')
    GROUP BY ALL),
Aggregated AS (
    SELECT 
        uh.ULTIMATEID,
        SUM(CASE WHEN uh.YEAR_QUARTER IN (p.current_q1, p.current_q2, p.current_q3, p.current_q4)
                 THEN uh.Consumption ELSE 0 END) AS Current_LTM_Consumption,
        SUM(CASE WHEN uh.YEAR_QUARTER IN (p.prior_q1, p.prior_q2, p.prior_q3, p.prior_q4)
                 THEN uh.Consumption ELSE 0 END) AS Prior_LTM_Consumption,
        SUM(CASE WHEN uh.YEAR_QUARTER = p.current_reporting_quarter
                 THEN uh.Consumption ELSE 0 END) AS Current_Qtr_Consumption,
        SUM(CASE WHEN uh.YEAR_QUARTER = p.prior_year_quarter
                 THEN uh.Consumption ELSE 0 END) AS Prior_Year_Qtr_Consumption,
        SUM(CASE WHEN uh.YEAR_QUARTER IN (p.current_q1, p.current_q2, p.current_q3, p.current_q4)
                 THEN uh.App_Days ELSE 0 END) AS Current_LTM_AppDays,
        SUM(CASE WHEN uh.YEAR_QUARTER IN (p.prior_q1, p.prior_q2, p.prior_q3, p.prior_q4)
                 THEN uh.App_Days ELSE 0 END) AS Prior_LTM_AppDays,
        SUM(CASE WHEN uh.YEAR_QUARTER = p.current_reporting_quarter
                 THEN uh.App_Days ELSE 0 END) AS Current_Qtr_AppDays,
        SUM(CASE WHEN uh.YEAR_QUARTER = p.prior_year_quarter
                 THEN uh.App_Days ELSE 0 END) AS Prior_Year_Qtr_AppDays
    FROM UltimateHistory uh
    JOIN Periods p ON 1=1
    GROUP BY ALL)
SELECT 
    a.ULTIMATEID,
    s."Ultimate Name" AS "Ultimate",
    s."Ultimate Commercial Program" AS "Commercial Program",
    ROUND(a.Current_Qtr_Consumption, 2) AS "Current Quarter Consumption",
    ROUND(a.Current_LTM_Consumption, 2) AS "Current LTM Consumption",
    ROUND(a.Current_Qtr_Consumption - a.Prior_Year_Qtr_Consumption, 2) AS "Quarterly YoY Delta",
    ROUND(a.Current_LTM_Consumption - a.Prior_LTM_Consumption, 2) AS "LTM Delta",
    CASE 
        WHEN a.Prior_Year_Qtr_Consumption = 0 THEN NULL
        ELSE ROUND((a.Current_Qtr_Consumption - a.Prior_Year_Qtr_Consumption) / a.Prior_Year_Qtr_Consumption, 4)
    END AS "Quarterly YoY %",
    CASE 
        WHEN a.Prior_LTM_Consumption = 0 THEN NULL
        ELSE ROUND((a.Current_LTM_Consumption - a.Prior_LTM_Consumption) / a.Prior_LTM_Consumption, 4)
    END AS "LTM YoY %",
    CASE 
        WHEN a.Prior_Year_Qtr_AppDays = 0 THEN NULL
        ELSE ROUND((a.Current_Qtr_AppDays - a.Prior_Year_Qtr_AppDays) / a.Prior_Year_Qtr_AppDays, 4)
    END AS "App Days - Quarterly YoY",
    CASE 
        WHEN a.Prior_LTM_AppDays = 0 THEN NULL
        ELSE ROUND((a.Current_LTM_AppDays - a.Prior_LTM_AppDays) / a.Prior_LTM_AppDays, 4)
    END AS "App Days - LTM YoY"
FROM Aggregated a
LEFT JOIN MART.OBT_SITE_EXPANDED s ON a.ULTIMATEID = s."Site ID";


---------------------
--LTM TOP DRIVERS
---------------------
--Top 3 Brand Deltas p/ Account (LTM)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3BrandLTMDeltasPerUltimate AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
BrandHistory AS (
    SELECT 
        cm."Ultimate ID" AS ULTIMATEID,
        p."Brand" AS BRAND,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
   WHERE cm."In Contracts" = 'Yes'
     AND p."Acquisition Source"  NOT IN ('Seequent')
     AND cm."Year Quarter" IN (
          SELECT current_q1 FROM Periods UNION
          SELECT current_q2 FROM Periods UNION
          SELECT current_q3 FROM Periods UNION
          SELECT current_q4 FROM Periods UNION
          SELECT prior_q1 FROM Periods UNION
          SELECT prior_q2 FROM Periods UNION
          SELECT prior_q3 FROM Periods UNION
          SELECT prior_q4 FROM Periods)
    GROUP BY ALL),
Aggregated AS (
    SELECT 
        bh.ULTIMATEID,
        bh.BRAND,
        SUM(CASE WHEN bh.YEAR_QUARTER IN (p.current_q1, p.current_q2, p.current_q3, p.current_q4) THEN bh.Consumption ELSE 0 END) AS Current_LTM,
        SUM(CASE WHEN bh.YEAR_QUARTER IN (p.prior_q1, p.prior_q2, p.prior_q3, p.prior_q4) THEN bh.Consumption ELSE 0 END) AS Prior_LTM
    FROM BrandHistory bh
    JOIN Periods p ON 1=1
    GROUP BY bh.ULTIMATEID, bh.BRAND),
Ranked AS (
    SELECT *,
        ROUND(Current_LTM - Prior_LTM, 2) AS Brand_LTM_Delta,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY ABS(Current_LTM - Prior_LTM) DESC, BRAND) AS Brand_Rank
    FROM Aggregated)
SELECT *
FROM Ranked
WHERE Brand_Rank <= 3;

--Top 3 Region Deltas p/ Account (based on Country_Country_ISO in CM, rolled up to sales region) (LTM)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.UltimateRegion_LTM_Drivers AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
RegionHistory AS (
    SELECT
        cm."Ultimate ID" AS ULTIMATEID,
        lc."Org Region" AS SALES_REGION,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
    LEFT JOIN MART.DIM_COUNTRY lc ON cm."Usage Country ISO" = lc."Country ISO"
    WHERE cm."In Contracts" = 'Yes'
      AND p."Acquisition Source"  NOT IN ('Seequent')
      AND cm."Year Quarter" IN (
          SELECT current_q1 FROM Periods UNION
          SELECT current_q2 FROM Periods UNION
          SELECT current_q3 FROM Periods UNION
          SELECT current_q4 FROM Periods UNION
          SELECT prior_q1 FROM Periods UNION
          SELECT prior_q2 FROM Periods UNION
          SELECT prior_q3 FROM Periods UNION
          SELECT prior_q4 FROM Periods      )
    GROUP BY ALL),
Aggregated AS (
    SELECT
        rh.ULTIMATEID,
        rh.SALES_REGION,
        SUM(CASE WHEN rh.YEAR_QUARTER IN (p.current_q1, p.current_q2, p.current_q3, p.current_q4) THEN rh.Consumption ELSE 0 END) AS Current_LTM,
        SUM(CASE WHEN rh.YEAR_QUARTER IN (p.prior_q1, p.prior_q2, p.prior_q3, p.prior_q4) THEN rh.Consumption ELSE 0 END) AS Prior_LTM
    FROM RegionHistory rh
    JOIN Periods p ON 1=1
    GROUP BY ALL)
SELECT
    a.*,
    ROUND(a.Current_LTM - a.Prior_LTM, 2) AS Region_LTM_Delta
FROM Aggregated a;


--Rank & store top 3 regions p/ Ultimate (2 steps b/c of complexity from sales region rollup) (LTM)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3RegionLTMDeltasPerUltimate AS
SELECT *
FROM (SELECT
        ULTIMATEID,
        SALES_REGION,
        Current_LTM,
        Prior_LTM,
        Region_LTM_Delta,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY ABS(Region_LTM_Delta) DESC, SALES_REGION) AS Region_Rank
    FROM SANDBOX.FPANDA.UltimateRegion_LTM_Drivers)
WHERE Region_Rank <= 3
ORDER BY ULTIMATEID;


--Store each account's primary usage region (for extra context) (LTM)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.PrimaryUsageRegionPerUltimate_LTM AS
SELECT
    ULTIMATEID,
    SALES_REGION AS Primary_Usage_Region
FROM (SELECT
        ULTIMATEID,
        SALES_REGION,
        Current_LTM,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY Current_LTM DESC, SALES_REGION) AS rn
    FROM SANDBOX.FPANDA.UltimateRegion_LTM_Drivers)
WHERE rn = 1;



---------------------------
--LTM PIVOT TOP DRIVERS 
---------------------------

--Pivot top 3 brands to 1 row per Ultimate (to join up 1 row p/ Ultimte downstream)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3BrandsPivot_LTM_PerUltimate AS
SELECT
    ULTIMATEID,
    MAX(CASE WHEN Brand_Rank = 1 THEN BRAND END) AS Brand_1,
    MAX(CASE WHEN Brand_Rank = 1 THEN Brand_LTM_Delta END) AS Brand_1_LTM_Delta,
    MAX(CASE WHEN Brand_Rank = 2 THEN BRAND END) AS Brand_2,
    MAX(CASE WHEN Brand_Rank = 2 THEN Brand_LTM_Delta END) AS Brand_2_LTM_Delta,
    MAX(CASE WHEN Brand_Rank = 3 THEN BRAND END) AS Brand_3,
    MAX(CASE WHEN Brand_Rank = 3 THEN Brand_LTM_Delta END) AS Brand_3_LTM_Delta
FROM SANDBOX.FPANDA.Top3BrandLTMDeltasPerUltimate
GROUP BY ULTIMATEID;


--Pivot top 3 regions to 1 row per Ultimate (to join up 1 row p/ Ultimte downstream)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3RegionsPivot_LTM_PerUltimate AS
SELECT
    ULTIMATEID,
    MAX(CASE WHEN Region_Rank = 1 THEN SALES_REGION END) AS Region_1,
    MAX(CASE WHEN Region_Rank = 1 THEN Region_LTM_Delta END) AS Region_1_LTM_Delta,
    MAX(CASE WHEN Region_Rank = 2 THEN SALES_REGION END) AS Region_2,
    MAX(CASE WHEN Region_Rank = 2 THEN Region_LTM_Delta END) AS Region_2_LTM_Delta,
    MAX(CASE WHEN Region_Rank = 3 THEN SALES_REGION END) AS Region_3,
    MAX(CASE WHEN Region_Rank = 3 THEN Region_LTM_Delta END) AS Region_3_LTM_Delta
FROM SANDBOX.FPANDA.Top3RegionLTMDeltasPerUltimate
GROUP BY ULTIMATEID;


---------------------
--TOP YoY DRIVERS
---------------------
--Top 3 Brand Deltas p/ Account (YoY)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3BrandYoYDeltasPerUltimate AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
BrandHistory AS (
    SELECT 
        cm."Ultimate ID" AS ULTIMATEID,
         p."Brand" AS BRAND,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
    WHERE cm."In Contracts" = 'Yes'
      AND p."Acquisition Source"  NOT IN ('Seequent')
      AND cm."Year Quarter" IN (
          SELECT current_reporting_quarter FROM Periods
          UNION
          SELECT prior_year_quarter FROM Periods)
    GROUP BY ALL),
Aggregated AS (
    SELECT
        bh.ULTIMATEID,
        bh.BRAND,
        SUM(CASE WHEN bh.YEAR_QUARTER = p.current_reporting_quarter THEN bh.Consumption ELSE 0 END) AS Current_Qtr,
        SUM(CASE WHEN bh.YEAR_QUARTER = p.prior_year_quarter THEN bh.Consumption ELSE 0 END) AS Prior_Year_Qtr
    FROM BrandHistory bh
    JOIN Periods p ON 1=1
    GROUP BY bh.ULTIMATEID, bh.BRAND),
Ranked AS (
    SELECT
        *,
        ROUND(Current_Qtr - Prior_Year_Qtr, 2) AS Brand_YoY_Delta,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY ABS(Current_Qtr - Prior_Year_Qtr) DESC, BRAND) AS Brand_Rank
    FROM Aggregated)
SELECT *
FROM Ranked
WHERE Brand_Rank <= 3;

 

--Region drivers base (YoY) - using country_ISO but linked to sales region
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.UltimateRegion_YoY_Drivers AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
RegionHistory AS (
    SELECT
        cm."Ultimate ID" AS ULTIMATEID,
        lc."Org Region" AS SALES_REGION,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
    LEFT JOIN MART.DIM_COUNTRY lc ON cm."Usage Country ISO" = lc."Country ISO"
    WHERE cm."In Contracts" = 'Yes'
      AND p."Acquisition Source"  NOT IN ('Seequent')
      AND cm."Year Quarter" IN (
          SELECT current_reporting_quarter FROM Periods
          UNION
          SELECT prior_year_quarter FROM Periods      )
    GROUP BY ALL),
Aggregated AS (
    SELECT
        rh.ULTIMATEID,
        rh.SALES_REGION,
        SUM(CASE WHEN rh.YEAR_QUARTER = p.current_reporting_quarter THEN rh.Consumption ELSE 0 END) AS Current_Qtr,
        SUM(CASE WHEN rh.YEAR_QUARTER = p.prior_year_quarter THEN rh.Consumption ELSE 0 END) AS Prior_Year_Qtr
    FROM RegionHistory rh
    JOIN Periods p ON 1=1
    GROUP BY ALL)
SELECT
    a.*,
    ROUND(a.Current_Qtr - a.Prior_Year_Qtr, 2) AS Region_YoY_Delta
FROM Aggregated a;


--Top 3 Region Deltas p/ Ultimate (YoY)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3RegionYoYDeltasPerUltimate AS
SELECT *
FROM (SELECT
        ULTIMATEID,
        SALES_REGION,
        Current_Qtr,
        Prior_Year_Qtr,
        Region_YoY_Delta,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY ABS(Region_YoY_Delta) DESC, SALES_REGION) AS Region_Rank
    FROM SANDBOX.FPANDA.UltimateRegion_YoY_Drivers)
WHERE Region_Rank <= 3
ORDER BY ULTIMATEID;


--Primary usage region (YoY context; based on Current_Qtr)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.PrimaryUsageRegionPerUltimate_YoY AS
SELECT
    ULTIMATEID,
    SALES_REGION AS Primary_Usage_Region
FROM (SELECT
        ULTIMATEID,
        SALES_REGION,
        Current_Qtr,
        ROW_NUMBER() OVER (PARTITION BY ULTIMATEID ORDER BY Current_Qtr DESC, SALES_REGION) AS rn
    FROM SANDBOX.FPANDA.UltimateRegion_YoY_Drivers)
WHERE rn = 1;



---------------------
--TOP YoY PIVOTS
---------------------
--Pivot top 3 brands to 1 row per Ultimate (YoY)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3BrandsPivot_YoY_PerUltimate AS
SELECT
    ULTIMATEID,
    MAX(CASE WHEN Brand_Rank = 1 THEN BRAND END) AS Brand_1,
    MAX(CASE WHEN Brand_Rank = 1 THEN Brand_YoY_Delta END) AS Brand_1_YoY_Delta,
    MAX(CASE WHEN Brand_Rank = 2 THEN BRAND END) AS Brand_2,
    MAX(CASE WHEN Brand_Rank = 2 THEN Brand_YoY_Delta END) AS Brand_2_YoY_Delta,
    MAX(CASE WHEN Brand_Rank = 3 THEN BRAND END) AS Brand_3,
    MAX(CASE WHEN Brand_Rank = 3 THEN Brand_YoY_Delta END) AS Brand_3_YoY_Delta
FROM SANDBOX.FPANDA.Top3BrandYoYDeltasPerUltimate
GROUP BY ULTIMATEID;


--Pivot top 3 regions to 1 row per Ultimate (YoY)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.Top3RegionsPivot_YoY_PerUltimate AS
SELECT
    ULTIMATEID,
    MAX(CASE WHEN Region_Rank = 1 THEN SALES_REGION END) AS Region_1,
    MAX(CASE WHEN Region_Rank = 1 THEN Region_YoY_Delta END) AS Region_1_YoY_Delta,
    MAX(CASE WHEN Region_Rank = 2 THEN SALES_REGION END) AS Region_2,
    MAX(CASE WHEN Region_Rank = 2 THEN Region_YoY_Delta END) AS Region_2_YoY_Delta,
    MAX(CASE WHEN Region_Rank = 3 THEN SALES_REGION END) AS Region_3,
    MAX(CASE WHEN Region_Rank = 3 THEN Region_YoY_Delta END) AS Region_3_YoY_Delta
FROM SANDBOX.FPANDA.Top3RegionYoYDeltasPerUltimate
GROUP BY ULTIMATEID;



------------------------------------------------------3 TABLES TO PERSIST TO SIGMA (RUN STAGING ABOVE)-----------------------------------------------------------

----------------------
--FINAL OUTPUTS             
----------------------
--LTM - by Ultimate output (i.e. scorecard - 1 row p/ Ultimate)
CREATE OR REPLACE TABLE SANDBOX.FPANDA.UltimateScorecard_LTM AS
SELECT
    b.ULTIMATEID,
    b."Ultimate",
    b."Commercial Program",
    s."Sales Regional Executive" AS RE,
    th."E365 Usage Vs Contract" AS CURRENT_QTR_STATUS,
    b."Current LTM Consumption",
    b."LTM Delta",
    b."LTM YoY %",
    b."App Days - LTM YoY",
    tb.Brand_1,
    tb.Brand_1_LTM_Delta,
    tb.Brand_2,
    tb.Brand_2_LTM_Delta,
    tb.Brand_3,
    tb.Brand_3_LTM_Delta,
    pr.Primary_Usage_Region,
    tr.Region_1,
    tr.Region_1_LTM_Delta,
    tr.Region_2,
    tr.Region_2_LTM_Delta,
    tr.Region_3,
    tr.Region_3_LTM_Delta
FROM SANDBOX.FPANDA.UltimateMetrics_Base b
LEFT JOIN MART.OBT_SITE_EXPANDED s ON b.ULTIMATEID = s."Site ID"
LEFT JOIN MART.SSF_E365_USAGE_VS_CONTRACT_QUARTERLY th --used in place of E365_Terms_History
  ON b.ULTIMATEID = substr(BK_E365_USAGE_VS_CONTRACT_KEY, 1, 10)
 AND substr(th.BK_E365_USAGE_VS_CONTRACT_KEY, -5, 5) = (SELECT current_quarter FROM SANDBOX.FPANDA.ReportingQuarterInput) -- last 5 of the BK_E365_USAGE_VS_CONTRACT_KEY is the Year Quarter
LEFT JOIN SANDBOX.FPANDA.PrimaryUsageRegionPerUltimate_LTM pr ON b.ULTIMATEID = pr.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.Top3BrandsPivot_LTM_PerUltimate tb ON b.ULTIMATEID = tb.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.Top3RegionsPivot_LTM_PerUltimate tr ON b.ULTIMATEID = tr.ULTIMATEID;
--WHERE COMMERCIAL_PROGRAM='E365';

--select count(*) from SANDBOX.FPANDA.UltimateScorecard_LTM; --32,717

--YoY - by Ultimate output (i.e. scorecard - 1 row p/ Ultimate)
CREATE OR REPLACE TABLE SANDBOX.FPANDA.UltimateScorecard_YOY AS
SELECT
    b.ULTIMATEID,
    b."Ultimate",
    b."Commercial Program",
    s."Sales Regional Executive" AS RE,
    th."E365 Usage Vs Contract" AS CURRENT_QTR_STATUS,
    b."Current Quarter Consumption",
    b."Quarterly YoY Delta",
    b."Quarterly YoY %",
    b."App Days - Quarterly YoY",
    tb.Brand_1,
    tb.Brand_1_YoY_Delta,
    tb.Brand_2,
    tb.Brand_2_YoY_Delta,
    tb.Brand_3,
    tb.Brand_3_YoY_Delta,
    pr.Primary_Usage_Region,
    tr.Region_1,
    tr.Region_1_YoY_Delta,
    tr.Region_2,
    tr.Region_2_YoY_Delta,
    tr.Region_3,
    tr.Region_3_YoY_Delta
FROM SANDBOX.FPANDA.UltimateMetrics_Base b
LEFT JOIN MART.OBT_SITE_EXPANDED s ON b.ULTIMATEID = s."Site ID"
LEFT JOIN MART.SSF_E365_USAGE_VS_CONTRACT_QUARTERLY th --used in place of E365_Terms_History
  ON b.ULTIMATEID = substr(BK_E365_USAGE_VS_CONTRACT_KEY, 1, 10) -- first 10 bytes of BK_E365_USAGE_VS_CONTRACT_KEY is the Ultimate_id
 AND substr(th.BK_E365_USAGE_VS_CONTRACT_KEY, -5, 5) = (SELECT current_quarter FROM SANDBOX.FPANDA.ReportingQuarterInput) -- last 5 of the BK_E365_USAGE_VS_CONTRACT_KEY is the Year Quarter
LEFT JOIN SANDBOX.FPANDA.PrimaryUsageRegionPerUltimate_YoY pr ON b.ULTIMATEID = pr.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.Top3BrandsPivot_YoY_PerUltimate tb ON b.ULTIMATEID = tb.ULTIMATEID
LEFT JOIN SANDBOX.FPANDA.Top3RegionsPivot_YoY_PerUltimate tr ON b.ULTIMATEID = tr.ULTIMATEID;
--WHERE COMMERCIAL_PROGRAM='E365';

--select count(*) from SANDBOX.FPANDA.UltimateScorecard_YOY; -- 33634 

--Final, low grain table to roll up for top brands...etc.
CREATE OR REPLACE TABLE SANDBOX.FPANDA.RE_FullGrain_Table AS
WITH Periods AS (
    SELECT * FROM SANDBOX.FPANDA.ReportingQuarterParams),
Quarterly AS (
    SELECT 
        cm."Ultimate ID" AS ULTIMATEID,
        p."Brand" AS BRAND,
        lc."Org Region" AS SALES_REGION,
        cm."Year Quarter" AS YEAR_QUARTER,
        SUM(cm."Normalized Consumption") AS Consumption,
        SUM(cm."Normalized Application Days") AS App_Days
    FROM MART.OBT_CONSUMPTION_DAILY cm
    JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
    LEFT JOIN MART.DIM_COUNTRY lc ON cm."Usage Country ISO" = lc."Country ISO"
    JOIN Periods per ON 1=1
    WHERE cm."In Contracts" = 'Yes'
      AND p."Acquisition Source"  NOT IN ('Seequent')
      AND cm."Year Quarter" IN (
          per.current_q1, per.current_q2, per.current_q3, per.current_q4,
          per.prior_q1, per.prior_q2,   per.prior_q3,   per.prior_q4,
          per.current_reporting_quarter,
          per.prior_year_quarter)
    GROUP BY ALL),
Periodized AS (
    SELECT
        q.ULTIMATEID,
        q.BRAND,
        q.SALES_REGION,
        'Current_LTM' AS Period_Type,
        SUM(q.Consumption) AS Consumption_Value,
        SUM(q.App_Days) AS AppDays_Value
    FROM Quarterly q
    JOIN Periods per ON 1=1
    WHERE q.YEAR_QUARTER IN (per.current_q1, per.current_q2, per.current_q3, per.current_q4)
    GROUP BY q.ULTIMATEID, q.BRAND, q.SALES_REGION
    UNION ALL
    SELECT
        q.ULTIMATEID,
        q.BRAND,
        q.SALES_REGION,
        'Prior_LTM' AS Period_Type,
        SUM(q.Consumption) AS Consumption_Value,
        SUM(q.App_Days) AS AppDays_Value
    FROM Quarterly q
    JOIN Periods per ON 1=1
    WHERE q.YEAR_QUARTER IN (per.prior_q1, per.prior_q2, per.prior_q3, per.prior_q4)
    GROUP BY q.ULTIMATEID, q.BRAND, q.SALES_REGION
    UNION ALL
    SELECT
        q.ULTIMATEID,
        q.BRAND,
        q.SALES_REGION,
        'Current_Qtr' AS Period_Type,
        SUM(q.Consumption) AS Consumption_Value,
        SUM(q.App_Days) AS AppDays_Value
    FROM Quarterly q
    JOIN Periods per ON 1=1
    WHERE q.YEAR_QUARTER = per.current_reporting_quarter
    GROUP BY q.ULTIMATEID, q.BRAND, q.SALES_REGION
    UNION ALL
    SELECT
        q.ULTIMATEID,
        q.BRAND,
        q.SALES_REGION,
        'Prior_Year_Qtr' AS Period_Type,
        SUM(q.Consumption) AS Consumption_Value,
        SUM(q.App_Days) AS AppDays_Value
    FROM Quarterly q
    JOIN Periods per ON 1=1
    WHERE q.YEAR_QUARTER = per.prior_year_quarter
    GROUP BY q.ULTIMATEID, q.BRAND, q.SALES_REGION)
SELECT
    p.ULTIMATEID,
    p.BRAND,
    p.SALES_REGION,
    p.Period_Type, 
    s."Ultimate Name" AS "Ultimate",
    s."Ultimate Commercial Program" AS "Commercial Program",
    s."Sales Regional Executive" AS RE,
    th.contract_vs_usage AS STATUS,
    ROUND(p.Consumption_Value, 2) AS Consumption_Value,
    ROUND(p.AppDays_Value, 2) AS AppDays_Value
FROM Periodized p
LEFT JOIN MART.OBT_SITE_EXPANDED s ON p.ULTIMATEID = s."Site ID"
LEFT JOIN EDW_TABLES.E365_TERMS_HISTORY th on p.ULTIMATEID = th.ultimate_id
    AND th.year_quarter = (SELECT current_quarter FROM SANDBOX.FPANDA.ReportingQuarterInput);

--select count(*) from SANDBOX.FPANDA.RE_FullGrain_Table; --195,011

------------------------------------
--FOR ACCOUNT PAGES IN MD&A DECK
------------------------------------
--LTM Top & Bottom Output For MDA Deck 
SELECT
    ULTIMATEID,
    "Ultimate" as "Account",
    --"Commercial Program",
    RE,
    CURRENT_QTR_STATUS as "Current Status",
    ROW_NUMBER() OVER (ORDER BY "Current LTM Consumption" DESC) AS "Consumption Rank",
    --"Current LTM Consumption",
    "LTM Delta",
    "LTM YoY %" as "Consumption TTM %",
    "App Days - LTM YoY" as "App Days TTM %",
    Brand_1 as "Top Brand Driver",
    Brand_1_LTM_Delta as "Top Brand Change",
    Region_1 as "Top Region Driver",
    Region_1_LTM_Delta as "Top Region Change"
FROM SANDBOX.FPANDA.UltimateScorecard_LTM
WHERE "Commercial Program"='E365'
ORDER BY "LTM Delta" DESC;

--YoY Top & Bottom Output For MDA Deck  
SELECT
    ULTIMATEID,
    "Ultimate" as "Account",
    --"Commercial Program",
    RE,
    CURRENT_QTR_STATUS as "Current Status",
    ROW_NUMBER() OVER (ORDER BY "Current Quarter Consumption" DESC) AS "Consumption Rank",
    --"Current Quarter Consumption",
    "Quarterly YoY Delta",
    "Quarterly YoY %" as "Consumption YoY %",
    "App Days - Quarterly YoY" as "App Days YoY %",
    Brand_1 as "Top Brand Driver",
    Brand_1_YoY_Delta as "Top Brand Change",
    Region_1 as "Top Region Driver",
    Region_1_YoY_Delta as "Top Region Change"
FROM SANDBOX.FPANDA.UltimateScorecard_YOY
WHERE "Commercial Program"='E365'
ORDER BY "Quarterly YoY Delta" DESC;