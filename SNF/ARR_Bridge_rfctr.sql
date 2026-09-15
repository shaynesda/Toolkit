/********************************************************************
**  Name: ARR Bridge
**  Refactored Date: 5/28/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES,
**                                                 PRESENTATION.EDW)
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**    E365_TERMS_HISTORY = E365_TERMS_HISTORY (DIM_ULTIMATE?) 
**    E365_PRICEBOOK_ALL = SANDBOX.FPANDA TEMP TABLE E365_PRICEBOOK_BIRD FROM E365_TERMS_HISTORY & OBT_CONSUMPTION_DAILY
**                         (DIM_PRICEBOOK?, FCT_PRICEBOOK?) 
**          E365_INVOICE = EDW.E365_INVOICE (**CONSUMPTION_ENGINE**)
**  LOOKUP_CURRENCYRATES = LOOKUP_CURRENCYRATES (FCT_FX_RATE_FISCAL_BUDGET?, DIM_CURRENCY?)
**
**  Description: 
**
********************************************************************/


--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;

USE SCHEMA EDW_TABLES;

USE SCHEMA MART;


------------------------------------
--STEP 1: SET PARAMETERS
------------------------------------

--Set current quarter 
SET YEAR_QUARTER = 20261; --what quarter to run this for

--Set next quarter (for invoicing cutoff)
SET MIN_INVOICE_QUARTER = 20262; --what invoice start quarter to kick out (following quarter)

--Ultimates to exclude
SET EXCLUDED_ULTIMATE1 = 1003752107;
SET EXCLUDED_ULTIMATE2 = 1005023208;

--Excluded contract status
SET EXCLUDED_CONTRACT_STATUS = 'Partial Billing Quarter';

------------------------------------
--STEP 2: STORE CONSUMPTION        --------------------RENAME TABLES BEFORE PERSISTING (SEARCH FOR 'SANDBOX' & OLD QUARTER TO SWITCH REFERENCES TOO)
------------------------------------

--Store consumption at product grain for comparison (includes Seequent) Refactored for BIRD_PROD.PRESENTATION.MART

CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_Consumption_20261 AS
WITH MinInvoiceQuarter AS (
    SELECT
        Ultimate_Id AS ULTIMATEID,
        MIN(YEAR_QUARTER) AS MIN_E365_INVOICE_QUARTER
    FROM E365_TERMS_HISTORY  --E365_INVOICE
    GROUP BY ALL)
SELECT
    cm."Ultimate ID" AS ULTIMATEID,
    cm."Year Quarter" AS YEAR_QUARTER,
    cm."E365 Category" AS E365_CATEGORY,
    cm."Product ID" AS PRODUCTID,
    cm."Feature String" AS FEATURE_STRING,
    mi.MIN_E365_INVOICE_QUARTER,
    th."E365 Usage Vs Contract" AS ContractVsUsage,
    SUM(cm."Consumption") AS TOTAL_CONSUMPTION
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MinInvoiceQuarter mi ON cm."Ultimate ID" = mi.ULTIMATEID
LEFT JOIN MART.SSF_E365_USAGE_VS_CONTRACT_QUARTERLY th --used in place of E365_Terms_History
  ON cm."Ultimate ID"||'||'||cm."Year Quarter" = th.BK_E365_USAGE_VS_CONTRACT_KEY -- first 10 bytes of BK_E365_USAGE_VS_CONTRACT_KEY is the Ultimate ID last 5 is the Year Quarter
WHERE cm."Year Quarter" = $YEAR_QUARTER
  AND cm."In Contracts" = 'Yes'  -- Refactored value is Yes vs 1
  AND cm."Ultimate Commercial Program" = 'E365'
GROUP BY ALL;

--select * from SANDBOX.FPANDA.ARR_Bridge_Consumption_20261; -- 8,022

CREATE OR REPLACE TABLE SANDBOX.FPANDA.E365_PRICEBOOK_BIRD AS
WITH TERMS_HISTORY_DATA as
(select distinct
        cd."Product ID" AS PRODUCTID,
        cd."Ultimate ID" AS ULTIMATEID,
        th.unique_e365_terms_history_key,
        th.contract_vs_usage AS CONTRACTVSUSAGE,
        cd."Feature String" AS FEATURE_STRING,
        th.year_quarter AS YEAR_QUARTER, 
        th.pricebook AS PRICEBOOK,
        th.currency AS CURRENCY,
        th.applied_iteration AS ITERATION,
        cd.fk_infrastructure_sector_key
  from PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY th 
   join MART.OBT_CONSUMPTION_DAILY cd
     on th.ultimate_id = cd."Ultimate ID"
    and th.year_quarter = cd."Year Quarter"
where cd."Year Quarter" = $YEAR_QUARTER
  and cd."In Contracts" = 'Yes'  -- Refactored value is Yes vs 1
  and cd."Ultimate Commercial Program" = 'E365')
select distinct 
       dm."Product ID" PRODUCTID,                        -- Required field for reporting
       tha.ULTIMATEID,
       tha.CONTRACTVSUSAGE,
       tha.FEATURE_STRING,
       tha.YEAR_QUARTER,
       tha.CURRENCY,                                     -- Required field for reporting
       pb."Pricebook Description" PRICEBOOK,             -- Required field for reporting
       dpb."Is E365 Pricebook",
       pb."Pricebook Price LC" AS E365_GROSS_PRICE,      -- Required field for reporting
       pb."Pricebook Price USD" AS E365_GROSS_PRICE_USD, -- Required field for reporting
       dpb."Pricebook Iteration Number" AS ITERATION,    -- Required field for reporting
       pb.fk_pricebook_material_key,
       pb.fk_pricebook_product_key,
       pb.fk_pricebook_currency_key,
       dm.sk_product_key
  from MART.FCT_PRICEBOOK pb
  join MART.DIM_PRICEBOOK dpb
    on pb.pk_pricebook_key = dpb.bk_pricebook_key
  join MART.DIM_PRODUCT dm
    on pb.fk_pricebook_product_key = dm.sk_product_key
  join TERMS_HISTORY_DATA tha
    on dm."Product ID" = tha.PRODUCTID
  where dpb."Is E365 Pricebook" = 'Yes';




/*
--select * from SANDBOX.MARY_MAXSON.ARR_Bridge_Consumption_20261;
select sum(consumption) as consumption, sum(normalized_consumption) as normalized_consumption 
from SANDBOX.MARY_MAXSON.CONSUMPTION_METRICS_JAN11_26 c
join sites s on s.siteid=c.ultimateid
where year_quarter=20261 and in_contracts=1 and commercial_program='E365';
*/


-------------------------------------------
--STEP 3: IDENTIFY ULTIMATES TO EXCLUDE
-------------------------------------------

--Excluded Consumption to tie out to Actual Consumption
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_ExcludedConsumption_20261 AS
SELECT
    c.ULTIMATEID,
    c.YEAR_QUARTER,
    SUM(c.TOTAL_CONSUMPTION) AS TOTAL_CONSUMPTION, 
    MAX(c.CONTRACTVSUSAGE) AS CONTRACTVSUSAGE,
    MAX(c.MIN_E365_INVOICE_QUARTER) AS MIN_E365_INVOICE_QUARTER,
    CASE 
        WHEN c.ULTIMATEID IN ($EXCLUDED_ULTIMATE1, $EXCLUDED_ULTIMATE2) THEN 'Questionable Usage'
        WHEN MAX(c.CONTRACTVSUSAGE) = $EXCLUDED_CONTRACT_STATUS THEN $EXCLUDED_CONTRACT_STATUS
        WHEN MAX(c.MIN_E365_INVOICE_QUARTER) = $MIN_INVOICE_QUARTER THEN 'Future Min Invoice Quarter'
        ELSE 'Other'
    END AS EXCLUSION_REASON
FROM SANDBOX.FPANDA.ARR_Bridge_Consumption_20261 c
WHERE c.YEAR_QUARTER = $YEAR_QUARTER 
  AND (c.CONTRACTVSUSAGE = $EXCLUDED_CONTRACT_STATUS
     OR c.MIN_E365_INVOICE_QUARTER = $MIN_INVOICE_QUARTER
     OR c.ULTIMATEID IN ($EXCLUDED_ULTIMATE1, $EXCLUDED_ULTIMATE2))
GROUP BY ALL;


--select * from SANDBOX.FPANDA.ARR_Bridge_ExcludedConsumption_20261; --15


------------------------------------
--STEP 4: IDENTIFY PRODUCTS TO EXCLUDE
------------------------------------

--PRODUCTS IN INVOICE NOT IN CM (FOR TIE OUT)
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_InvoiceNotInConsumption_20261 AS
WITH InvoiceProducts AS (
    SELECT DISTINCT
        i.product_id as PRODUCTID
    FROM EDW.E365_INVOICE i
    WHERE substr(i.usage_quarter, 1, 5) = $YEAR_QUARTER AND i.usage_interval IN ('Daily','Quarterly')),
ConsumptionProducts AS (
    SELECT DISTINCT
        cm."Product ID"
      FROM MART.OBT_CONSUMPTION_DAILY cm
     WHERE cm."Year Quarter" = $YEAR_QUARTER
       AND cm."In Contracts" = 'Yes')
SELECT 
      ip.PRODUCTID
  FROM InvoiceProducts ip
LEFT JOIN ConsumptionProducts cp 
   ON ip.PRODUCTID = cp."Product ID"
WHERE ip.PRODUCTID IS NULL
ORDER BY ip.PRODUCTID;

--select * from SANDBOX.FPANDA.ARR_Bridge_InvoiceNotInConsumption_20261; --0

------------------------------------
--STEP 5: CALC BRIDGE DELTAS
------------------------------------
--Ensure Ultimates defined above get excluded entirely from the below
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_Detailed_FINAL_20261 AS
-------------------------------------------
--Step A: Identify valid ultimates
-------------------------------------------
WITH E365_Ultimates AS (
    SELECT DISTINCT
       cm."Ultimate ID" AS ULTIMATEID,
       cm."Year Quarter" AS YEAR_QUARTER,
    FROM MART.OBT_CONSUMPTION_DAILY cm --CONSUMPTION_METRICS cm 
    WHERE cm."Ultimate Commercial Program" = 'E365'
      AND cm."Year Quarter" = $YEAR_QUARTER),
ValidUltimates AS (
    SELECT 
        e.ULTIMATEID,
        e.YEAR_QUARTER
    FROM E365_Ultimates e
    --exclude any ultimate already staged into ExcludedConsumption
    WHERE NOT EXISTS (
        SELECT 1
        FROM SANDBOX.FPANDA.ARR_Bridge_ExcludedConsumption_20261 ex
        WHERE ex.ULTIMATEID = e.ULTIMATEID
          AND ex.YEAR_QUARTER = e.YEAR_QUARTER)),          
-------------------------------------------
--Step B: Pricing logic
-------------------------------------------
GlobalMaxIteration AS (
  SELECT PRODUCTID,
         pb.FEATURE_STRING, 
         MAX(ITERATION) AS MAX_ITERATION
    FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb
    join MART.OBT_PRODUCT_USAGE_DAILY pud
      on pb.PRODUCTID = pud."Product ID"
    WHERE PRICEBOOK = 'Global'
    GROUP BY PRODUCTID, FEATURE_STRING),
GlobalPricebook AS (
    SELECT 
        pb.PRODUCTID,
        COALESCE(UPPER(gmi.FEATURE_STRING), '') AS FEATURE_STRING,
        pb.E365_GROSS_PRICE_USD
    FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb
    JOIN GlobalMaxIteration gmi 
      ON pb.PRODUCTID = gmi.PRODUCTID
     AND COALESCE(UPPER(pb.FEATURE_STRING), '') = COALESCE(UPPER(gmi.FEATURE_STRING), '')
     AND pb.ITERATION = gmi.MAX_ITERATION
    WHERE pb.PRICEBOOK = 'Global'),
PricebookMaxIteration AS (
SELECT 
         pb.PRICEBOOK,
         pb.CURRENCY,
         PRODUCTID,
         pb.FEATURE_STRING, 
         MAX(ITERATION) AS MAX_ITERATION
    FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb
    join MART.OBT_PRODUCT_USAGE_DAILY pud
      on pb.PRODUCTID = pud."Product ID"
    WHERE PRICEBOOK = 'Global'
    GROUP BY ALL),    
CurrencyPricebook AS (
    SELECT
        pb.PRICEBOOK,
        pb.CURRENCY,
        pb.PRODUCTID,
        COALESCE(UPPER(pb.FEATURE_STRING), '') AS FEATURE_STRING,
        pb.E365_GROSS_PRICE,
        pb.E365_GROSS_PRICE_USD
    FROM SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb --PRESENTATION.EDW_TABLES.E365_PRICEBOOK_ALL pb
    JOIN PricebookMaxIteration mi 
      ON pb.PRICEBOOK = mi.PRICEBOOK
     AND pb.CURRENCY = mi.CURRENCY
     AND pb.PRODUCTID = mi.PRODUCTID
     AND COALESCE(UPPER(pb.FEATURE_STRING), '') = COALESCE(UPPER(mi.FEATURE_STRING), '')
     AND pb.ITERATION = mi.MAX_ITERATION),
UltimateTerms AS (
    SELECT 
        vu.ULTIMATEID,
        vu.YEAR_QUARTER,
        th.PRICEBOOK,
        th.CURRENCY,
        th.applied_iteration AS PRICEBOOK_ITERATION
    FROM ValidUltimates vu
    JOIN PRESENTATION.EDW_TABLES.E365_TERMS_HISTORY th
      ON vu.ULTIMATEID = th.ultimate_id
     AND vu.YEAR_QUARTER = th.year_quarter),
UltimatePricebook AS (
    SELECT DISTINCT
        ut.ULTIMATEID,
        ut.YEAR_QUARTER,
        ut.PRICEBOOK,
        ut.CURRENCY,
        ut.PRICEBOOK_ITERATION,
        pb.PRODUCTID,
        COALESCE(UPPER(pb.FEATURE_STRING), '') AS FEATURE_STRING,
        pb.E365_GROSS_PRICE,
        pb.E365_GROSS_PRICE_USD
    FROM UltimateTerms ut
    JOIN SANDBOX.FPANDA.E365_PRICEBOOK_BIRD pb
      ON ut.PRICEBOOK = pb.PRICEBOOK AND ut.PRICEBOOK_ITERATION = pb.ITERATION),      
-------------------------------------------
--Step C: Price deltas (per unit)
-------------------------------------------
PricebookDeltas AS (
   SELECT 
        up.ULTIMATEID,
        up.YEAR_QUARTER,
        p."E365 Category" AS E365_CATEGORY,
        up.PRODUCTID,
        COALESCE(UPPER(up.FEATURE_STRING), '') AS FEATURE_STRING,
        gp.E365_GROSS_PRICE_USD AS GLOBAL_CURRENT_PRICE_USD,
        up.E365_GROSS_PRICE_USD AS ULTIMATE_ITERATION_USD,
        up.E365_GROSS_PRICE AS ULTIMATE_ITERATION_LC,
        cp.E365_GROSS_PRICE_USD AS CURRENT_ITERATION_USD,
        cp.E365_GROSS_PRICE AS CURRENT_ITERATION_LC,
        up.E365_GROSS_PRICE_USD - gp.E365_GROSS_PRICE_USD AS TOTAL_DELTA,
        up.E365_GROSS_PRICE_USD - cp.E365_GROSS_PRICE_USD AS ITERATION_DELTA,
        cp.E365_GROSS_PRICE_USD - gp.E365_GROSS_PRICE_USD AS PRICEBOOK_DELTA,
        ROW_NUMBER() OVER (
            PARTITION BY up.ULTIMATEID, up.YEAR_QUARTER, up.PRODUCTID, COALESCE(UPPER(up.FEATURE_STRING), '')
            ORDER BY up.YEAR_QUARTER DESC) AS rn
    FROM UltimatePricebook up
    JOIN ValidUltimates vu 
      ON up.ULTIMATEID = vu.ULTIMATEID AND up.YEAR_QUARTER = vu.YEAR_QUARTER
    LEFT JOIN GlobalPricebook gp 
      ON up.PRODUCTID = gp.PRODUCTID AND up.FEATURE_STRING = gp.FEATURE_STRING
    LEFT JOIN CurrencyPricebook cp 
      ON up.PRODUCTID = cp.PRODUCTID 
     AND up.PRICEBOOK = cp.PRICEBOOK 
     AND up.FEATURE_STRING = cp.FEATURE_STRING
    JOIN MART.DIM_PRODUCT p ON p."Product ID" = up.PRODUCTID
    WHERE p."E365 Category" IN ('Category A', 'Category B')),   
 CatAandBPricebookStaging AS (
    SELECT *
    FROM PricebookDeltas
    WHERE rn = 1),
-------------------------------------------
--Step D: Invoice data
-------------------------------------------
CurrencyRates AS (
    SELECT dc."Currency ISO Code" AS CURRENCY,  
             1/fb."Fiscal Budget Rate Value" AS Rate
        FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
        JOIN MART.DIM_CURRENCY dc
          ON fb.fk_source_currency_key = dc.sk_currency_key
       WHERE "Is Current Rate" = 'TRUE'),
AllCategoryInvoice AS (
    SELECT
        i.ultimate_id AS ULTIMATEID, 
        substr(i.usage_quarter, 1, 5) AS YEAR_QUARTER,
        p."E365 Category" AS E365_CATEGORY,
        i.product_id AS PRODUCTID,
        COALESCE(UPPER(i.feature_string), '') AS FEATURE_STRING,
        SUM(i.gross) AS GROSS_INVOICE_LC,
        SUM(i.net) AS NET_INVOICE_LC,
        SUM(i.net_with_renewal_evd) AS NET_RENEWAL_EVD_LC,
        ROUND(SUM(i.gross) / MAX(c.Rate), 2) AS GROSS_INVOICE_USD,
        ROUND(SUM(i.net) / MAX(c.Rate), 2) AS NET_INVOICE_USD,
        ROUND(SUM(i.net_with_renewal_evd) / MAX(c.Rate), 2) AS NET_RENEWAL_EVD_USD,
        COUNT(*) AS APP_DAYS,
        CASE 
            WHEN p."E365 Category" IN ('Category A', 'Category B') AND SUM(i.GROSS) > 0 THEN COUNT(*)
            WHEN SUM(i.GROSS) > 0 THEN 1
            ELSE 0
        END AS APP_DAYS_FOR_INVOICE,
        ROUND(SUM(i.net_with_renewal_evd) / MAX(c.Rate), 2) - ROUND(SUM(i.gross) / MAX(c.Rate), 2) AS EVD_DELTA,
        ROUND(SUM(i.net) / MAX(c.Rate), 2) - ROUND(SUM(i.net_with_renewal_evd) / MAX(c.Rate), 2) AS FLOOR_CEILING_DELTA
    FROM EDW.E365_INVOICE i
    JOIN ValidUltimates vu 
      ON i.ultimate_id = vu.ULTIMATEID AND substr(i.usage_quarter, 1, 5) = vu.YEAR_QUARTER
    LEFT JOIN CurrencyRates c ON i.currency = c.Currency
    JOIN MART.DIM_PRODUCT p ON p."Product ID" = i.product_id 
    WHERE substr(i.usage_quarter, 1, 5) = $YEAR_QUARTER
      AND i.gross > 0
      AND NOT EXISTS (
          SELECT 1
          FROM SANDBOX.FPANDA.ARR_Bridge_InvoiceNotInConsumption_20261 ex
          WHERE ex.PRODUCTID = i.product_id)
    GROUP BY ALL),
-------------------------------------------
--Step E: Final combine - per product/feature
-------------------------------------------
FinalTable AS (
    SELECT
        ci.ULTIMATEID,
        ci.YEAR_QUARTER,
        ci.E365_CATEGORY,
        ci.PRODUCTID,
        ci.FEATURE_STRING,
       -- vu.CONTRACTVSUSAGE,
       -- vu.MIN_E365_INVOICE_QUARTER,
        ci.APP_DAYS_FOR_INVOICE,
        pb.GLOBAL_CURRENT_PRICE_USD,
        pb.ULTIMATE_ITERATION_LC,
        pb.ULTIMATE_ITERATION_USD,
        pb.CURRENT_ITERATION_LC,
        pb.CURRENT_ITERATION_USD,
        pb.ITERATION_DELTA,
        pb.PRICEBOOK_DELTA,
        pb.TOTAL_DELTA,
        (ci.APP_DAYS_FOR_INVOICE * pb.GLOBAL_CURRENT_PRICE_USD) AS INVOICE_CONSUMPTION_PROXY,
        (ci.APP_DAYS_FOR_INVOICE * pb.ULTIMATE_ITERATION_LC) AS AMOUNT_INVOICED_LC,
        (ci.APP_DAYS_FOR_INVOICE * pb.ULTIMATE_ITERATION_USD) AS AMOUNT_INVOICED_USD,
        (ci.APP_DAYS_FOR_INVOICE * pb.CURRENT_ITERATION_USD) AS AMOUNT_INVOICED_IF_CURRENT_USD,
        ci.APP_DAYS_FOR_INVOICE * pb.ITERATION_DELTA AS CAT_AB_ITERATION_DELTA,
        ci.APP_DAYS_FOR_INVOICE * pb.PRICEBOOK_DELTA AS CAT_AB_PRICEBOOK_DELTA,
        ci.APP_DAYS_FOR_INVOICE * pb.TOTAL_DELTA AS CAT_AB_PRICEBOOK_AND_ITERATION_DELTA,
        ci.GROSS_INVOICE_USD,
        ci.NET_INVOICE_USD,
        ci.NET_RENEWAL_EVD_USD,
        ci.EVD_DELTA,
        ci.FLOOR_CEILING_DELTA
    FROM AllCategoryInvoice ci
    LEFT JOIN CatAandBPricebookStaging pb
      ON ci.ULTIMATEID = pb.ULTIMATEID
     AND ci.YEAR_QUARTER = pb.YEAR_QUARTER
     AND ci.PRODUCTID = pb.PRODUCTID
     AND ci.FEATURE_STRING = pb.FEATURE_STRING
    LEFT JOIN ValidUltimates vu
      ON ci.ULTIMATEID = vu.ULTIMATEID
     AND ci.YEAR_QUARTER = vu.YEAR_QUARTER)
SELECT * FROM FinalTable;

--select * from SANDBOX.FPANDA.ARR_Bridge_Detailed_FINAL_20261; --7512

--select ULTIMATEID, YEAR_QUARTER, COUNT(*) from SANDBOX.FPANDA.ARR_Bridge_Detailed_FINAL_20261 GROUP BY ALL; --466

--select * from SANDBOX.FPANDA.ARR_Bridge_Detailed_FINAL_20261 WHERE ULTIMATEID IN (1000075491);

-----------------------
--INVOICE TOTALS 
-----------------------
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_InvoiceActuals_20261 AS
WITH CurrencyRates AS (
SELECT dc."Currency ISO Code" AS Currency,    -- Ask Mary about the differences in rates (LOOKUP_CURRENCYRATES) and abbrv.
       1/fb."Fiscal Budget Rate Value" AS Rate
  FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
  JOIN MART.DIM_CURRENCY dc
    ON fb.fk_source_currency_key = dc.sk_currency_key
 WHERE "Is Current Rate" = 'TRUE'),
AllCategoryInvoice AS (
    SELECT 
        i.usage_interval AS Usage_Interval,
        SUM(i.gross / c.Rate) AS GROSS_USD,
        SUM(i.net / c.Rate) AS NET_USD
    FROM EDW.E365_INVOICE i
    JOIN CurrencyRates c ON i.currency = c.Currency
    WHERE substr(i.usage_quarter, 1, 5) = $YEAR_QUARTER
      GROUP BY ALL) 
SELECT * 
FROM AllCategoryInvoice;

--select * from SANDBOX.FPANDA.ARR_Bridge_InvoiceActuals_20261; --4

------------------------------------
--INVOICE TOTALS, LESS EXCLUSIONS    
------------------------------------
--Invoice totals less the excluded ultimates & products in invoicing not in consumption
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_InvoiceTieout_20261 AS
WITH CurrencyRates AS (
SELECT dc."Currency ISO Code" AS Currency,    -- Ask Mary about the differences in rates (LOOKUP_CURRENCYRATES) and abbrv.
       1/fb."Fiscal Budget Rate Value" AS Rate
  FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
  JOIN MART.DIM_CURRENCY dc
    ON fb.fk_source_currency_key = dc.sk_currency_key
 WHERE "Is Current Rate" = 'TRUE'),
AllCategoryInvoice AS (
    SELECT 
        i.usage_interval AS Usage_Interval,
        i.ultimate_id AS ULTIMATEID,
        substr(i.usage_quarter, 1, 5) AS USAGE_QUARTER,
        SUM(i.gross / c.Rate) AS GROSS_USD,
        SUM(i.net / c.Rate) AS NET_USD
    FROM EDW.E365_INVOICE i
    JOIN CurrencyRates c 
        ON i.currency = c.Currency        
    WHERE substr(i.usage_quarter, 1, 5) = $YEAR_QUARTER
      AND NOT EXISTS (
          SELECT 1
          FROM SANDBOX.FPANDA.ARR_Bridge_InvoiceNotInConsumption_20261 ex --remove products in invoicing, but not in consumption
          WHERE ex.PRODUCTID = i.product_id)
    GROUP BY ALL)
SELECT a.*
FROM AllCategoryInvoice a
WHERE NOT EXISTS (
    SELECT 1
    FROM SANDBOX.FPANDA.ARR_Bridge_ExcludedConsumption_20261 ex --remove kicked out Ultimates from consumption (make apples to apples)
    WHERE ex.ULTIMATEID = a.ULTIMATEID AND ex.YEAR_QUARTER = a.USAGE_QUARTER);

--select * from SANDBOX.FPANDA.ARR_Bridge_InvoiceTieout_20261; --1235


-------------------------------------------
--EXCLUSIONS' INVOICE TOTALS W/ REASONS
-------------------------------------------
CREATE OR REPLACE TABLE SANDBOX.FPANDA.ARR_Bridge_InvoiceExcluded_20261 AS
WITH CurrencyRates AS (
   SELECT dc."Currency ISO Code" AS Currency,    
       1/fb."Fiscal Budget Rate Value" AS Rate
  FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
  JOIN MART.DIM_CURRENCY dc
    ON fb.fk_source_currency_key = dc.sk_currency_key
 WHERE "Is Current Rate" = 'TRUE'),
InvoiceBase AS (
    SELECT
        i.usage_interval AS Usage_Interval,
        i.ultimate_id AS ULTIMATEID,
        substr(i.usage_quarter, 1, 5) AS USAGE_QUARTER,
        i.product_id AS PRODUCTID,
        SUM(i.gross / c.Rate) AS GROSS_USD,
        SUM(i.net / c.Rate) AS NET_USD
    FROM EDW.E365_INVOICE i
    JOIN CurrencyRates c 
      ON i.currency = c.Currency
   WHERE substr(i.usage_quarter, 1, 5) = $YEAR_QUARTER
    GROUP BY ALL),
UltimateExclusions AS (
    SELECT 
        ib.Usage_Interval,
        ib.ULTIMATEID,
        substr(ib.USAGE_QUARTER, 1, 5) AS USAGE_QUARTER,
        ib.PRODUCTID,
        ib.GROSS_USD,
        ib.NET_USD,
        ex.EXCLUSION_REASON
    FROM InvoiceBase ib
    JOIN SANDBOX.FPANDA.ARR_Bridge_ExcludedConsumption_20261 ex
      ON ib.ULTIMATEID = ex.ULTIMATEID AND ib.USAGE_QUARTER = ex.YEAR_QUARTER),
ProductExclusions AS (
    SELECT 
        ib.Usage_Interval,
        ib.ULTIMATEID,
        substr(ib.USAGE_QUARTER, 1, 5) AS USAGE_QUARTER,
        ib.PRODUCTID,
        ib.GROSS_USD,
        ib.NET_USD,
        'Invoiced but not in CM' AS EXCLUSION_REASON
    FROM InvoiceBase ib
    WHERE EXISTS (
        SELECT 1
        FROM SANDBOX.FPANDA.ARR_Bridge_InvoiceNotInConsumption_20261 pex
        WHERE pex.PRODUCTID = ib.PRODUCTID))
SELECT * 
FROM UltimateExclusions
UNION ALL
SELECT * 
FROM ProductExclusions;

--select * from SANDBOX.FPANDA.ARR_Bridge_InvoiceExcluded_20261; --61





