/********************************************************************
**  Name: Consumption Waterfall for Sigma
**  Refactored Date: 6/4/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**   
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**                 SITES = OBT_SITE_EXPANDED
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


-------------------------------------
--CONSUMPTION WATERFALL FOR SIGMA
-------------------------------------

SELECT * FROM MART.DIM_DATE;

----------------------
--GET PARAMETERS
----------------------
--Dynamically get 2 LTM periods
CREATE OR REPLACE TABLE SANDBOX.FPANDA.WATERFALL_QTR_PARAMS AS
WITH distinct_quarters AS (
    SELECT DISTINCT dd."Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE dd ),
ordered_quarters AS (
    SELECT
        year_quarter_num,
        ROW_NUMBER() OVER (ORDER BY year_quarter_num) AS rn
    FROM distinct_quarters),
today_qtr AS (
    SELECT DISTINCT dd."Year Quarter Num" AS year_quarter_num
    FROM MART.DIM_DATE dd
    WHERE dd."Date" = current_date()),
anchor AS (
    SELECT o_today.rn AS today_rn
    FROM ordered_quarters o_today
    JOIN today_qtr t
      ON o_today.year_quarter_num = t.year_quarter_num)
SELECT
    o_cp_end.year_quarter_num AS cp_end, 
    o_cp_begin.year_quarter_num AS cp_begin, 
    o_pp_end.year_quarter_num AS pp_end,   
    o_pp_begin.year_quarter_num AS pp_begin 
FROM anchor a
JOIN ordered_quarters o_cp_end ON o_cp_end.rn = a.today_rn - 1
JOIN ordered_quarters o_cp_begin ON o_cp_begin.rn = a.today_rn - 4
JOIN ordered_quarters o_pp_end ON o_pp_end.rn = a.today_rn - 5
JOIN ordered_quarters o_pp_begin ON o_pp_begin.rn = a.today_rn - 8;

--Categorize accounts (new, lost, existing)
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.WATERFALL_ACCOUNT_LABELS AS
SELECT
    cm."Ultimate ID" AS ULTIMATEID,
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
             THEN cm."Normalized Consumption" ELSE 0 END) AS Prior_Period_Consumption,
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
             THEN cm."Normalized Consumption" ELSE 0 END) AS Current_Period_Consumption,
    CASE WHEN SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                      THEN cm."Normalized Consumption" ELSE 0 END) = 0
         AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                      THEN cm."Normalized Consumption" ELSE 0 END) > 0
            THEN 'New Account'
        WHEN SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                      THEN cm."Normalized Consumption" ELSE 0 END) = 0
         AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                      THEN cm."Normalized Consumption" ELSE 0 END) > 0
            THEN 'Lost Account'
        ELSE 'Existing Account'
    END AS AccountCategory
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
CROSS JOIN SANDBOX.FPANDA.WATERFALL_QTR_PARAMS qp
WHERE cm."Year Quarter" BETWEEN qp.pp_begin AND qp.cp_end
  AND cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
GROUP BY ALL;


--Final output)
CREATE OR REPLACE TABLE SANDBOX.FPANDA.WATERFALL_PIVOT AS
WITH INDUSTRY_DATA 
  AS
   (select  sk_infrastructure_sector_key, du."Ultimate ID", lm.fk_ultimate_key, "Infrastructure Sector", du."Industry", du."Industry Segment"
     from (select distinct sk_infrastructure_sector_key, "Infrastructure Sector", from MART.DIM_INFRASTRUCTURE_SECTOR) ifs
     join (select distinct fk_ultimate_key, fk_infrastructure_sector_key from MART.SSF_CONTRACT_LINE_MONTHLY) lm   
       on ifs.sk_infrastructure_sector_key = lm.fk_infrastructure_sector_key
     join MART.DIM_ULTIMATE du
       on lm.fk_ultimate_key = du.sk_ultimate_key)
SELECT
    ia.AccountCategory AS "ACCOUNT CATEGORY",
    cm."Ultimate ID" AS ULTIMATEID,
    s."Ultimate Name" AS Ultimate,
    s."Industry Short Code" AS Short_Code,
    s."Org Region" AS Sales_Org,
    s."Org Unit" AS Sales_OU,
    p."Brand" AS Brand,
    p."Product ID" AS ProductID,
    p."Product With ID" AS Product_With_ID,
    p."E365 Category" AS E365_Category,
    s."Ultimate Account Size" AS ACCOUNT_SIZE,
    s."Ultimate Commercial Program" AS COMMERCIAL_PROGRAM,
    s."Industry" AS INDUSTRY_SECTOR, 
    id."Industry Segment" AS INDUSTRY_SEGMENT,
    id."Infrastructure Sector" AS FINAL_SECTOR,  
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
             THEN cm."Normalized Consumption" ELSE 0 END) AS Prior_Period,
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
             THEN cm."Normalized Consumption" ELSE 0 END) AS Current_Period,
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
             THEN cm."Normalized Consumption" ELSE 0 END) -
    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
             THEN cm."Normalized Consumption" ELSE 0 END) AS DELTA,
    CASE
        WHEN ia.AccountCategory = 'New Account'  THEN 'New Account'
        WHEN ia.AccountCategory = 'Lost Account' THEN 'Lost Account'
        WHEN ia.AccountCategory = 'Existing Account' THEN
            CASE WHEN
                    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) <
                    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END)
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) != 0
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) != 0
                    THEN 'Existing – Increase'
                WHEN
                    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) >
                    SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END)
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) != 0
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) != 0
                    THEN 'Existing - Decrease'
                WHEN SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) = 0
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) > 0
                    THEN 'Existing - New'
                WHEN SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.pp_begin AND qp.pp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) > 0
                    AND SUM(CASE WHEN cm."Year Quarter" BETWEEN qp.cp_begin AND qp.cp_end
                             THEN cm."Normalized Consumption" ELSE 0 END) = 0
                    THEN 'Existing - Lost'
                ELSE 'Existing - No Change'
            END
        ELSE 'No Change'
    END AS "WATERFALL CATEGORY"
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
LEFT JOIN INDUSTRY_DATA id ON cm."Ultimate ID" = id."Ultimate ID" and cm.FK_INFRASTRUCTURE_SECTOR_KEY = id.sk_infrastructure_sector_key
JOIN SANDBOX.FPANDA.WATERFALL_ACCOUNT_LABELS ia ON cm."Ultimate ID" = ia.ULTIMATEID
CROSS JOIN SANDBOX.FPANDA.WATERFALL_QTR_PARAMS qp
WHERE cm."Year Quarter" BETWEEN qp.pp_begin AND qp.cp_end
  AND cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
GROUP BY ALL;