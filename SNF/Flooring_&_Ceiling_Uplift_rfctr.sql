/********************************************************************
**  Name: Flooring & Ceiling Uplift
**  Refactored Date: 6/8/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**   
**          E365_INVOICE = E365_INVOICE (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**  LOOKUP_CURRENCYRATES = LOOKUP_CURRENCYRATES (FCT_FX_RATE_FISCAL_BUDGET?, DIM_CURRENCY?)
**    E365_TERMS_HISTORY = EDW_TABLES.E365_TERMS_HISTORY
**   E365_TERMS_EXTENDED = CURATED.STREAMLIT_DB_REFERENCE_DATA.REF_E365_TERMS_EXTENDED
**              CALENDAR = DIM_DATE
**
**
**
**  Description: 
**
********************************************************************/

USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

----------------------------------
--% FLOOR UPLIFT REPORT
----------------------------------

--Custom SQL run in Sigma
WITH --invoice fallback, in case blank (in Paul's original code)
InvoiceNetByUltimateQuarter AS (
    SELECT 
        i.ULTIMATEID AS ULTIMATEID,
        i.USAGEQUARTER AS YEARQUARTER,
        SUM(i.NET) AS InvoiceNetLC
    FROM E365_INVOICE i
    GROUP BY i.ULTIMATEID, i.USAGEQUARTER),
CurrencyFX AS (
      SELECT dc."Currency ISO Code" AS CURRENCY,  
             1/fb."Fiscal Budget Rate Value" AS FXRate
        FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
        JOIN MART.DIM_CURRENCY dc
          ON fb.fk_source_currency_key = dc.sk_currency_key
       WHERE "Is Current Rate" = 'TRUE'),
PartialQuarter AS ( 
 SELECT DISTINCT
        pq.ULTIMATEID,
        pq.USAGE_QUARTER AS YEARQUARTER
    FROM VW_E365_PARTIAL_QUARTER pq),
QuarterSequence AS (SELECT
        q.YEAR_QUARTER_NUM,
        ROW_NUMBER() OVER (ORDER BY q.YEAR_QUARTER_NUM) AS QuarterSeq
    FROM (SELECT DISTINCT YEAR_QUARTER_NUM FROM DIM_CALENDAR) q),
MultiYearStartQuarters AS (
     SELECT DISTINCT
        te.ultimate_id AS ULTIMATEID,
        te.usage_quarter AS USAGE_QUARTER
    FROM CURATED.STREAMLIT_DB_REFERENCE_DATA.REF_E365_TERMS_EXTENDED te     -- E365_TERMS_EXTENDED te
    WHERE te.USAGE_QUARTER IS NOT NULL
      AND te.IS_CURRENT_ROW = 'TRUE'),
MultiYearExpanded AS (
    SELECT DISTINCT
        msq.ULTIMATEID,
        qs2.YEAR_QUARTER_NUM AS YEARQUARTER
    FROM MultiYearStartQuarters msq
    JOIN QuarterSequence qs1 ON qs1.YEAR_QUARTER_NUM = msq.USAGE_QUARTER
    JOIN QuarterSequence qs2 ON qs2.QuarterSeq BETWEEN qs1.QuarterSeq AND qs1.QuarterSeq + 3),
RevisitQuarter AS (
    SELECT DISTINCT
        c."Date" AS DATE_VALUE,
        c."Year Quarter Num" AS YEAR_QUARTER_NUM
    FROM MART.DIM_DATE c),
RenewalQuarterMap AS (
    SELECT
        rq.DATE_VALUE,
        qs_prev.YEAR_QUARTER_NUM AS RenewalQuarter
    FROM RevisitQuarter rq
    JOIN QuarterSequence qs_curr ON qs_curr.YEAR_QUARTER_NUM = rq.YEAR_QUARTER_NUM
    LEFT JOIN QuarterSequence qs_prev ON qs_prev.QuarterSeq = qs_curr.QuarterSeq - 1)
SELECT
    th.ultimate_id AS ULTIMATEID,
    th.ultimate_name AS  ULTIMATENAME,
    th.currency AS CURRENCY,
    th.year_quarter AS YEARQUARTER,
    th.revisit_date AS REVISITDATE,
    rqm.RenewalQuarter,
    th.contract_terms AS CONTRACTTERMS,
    th.contract_vs_usage AS CONTRACTVSUSAGE,
    th.category AS CATEGORY,
    COALESCE(th.contract_net, inv.InvoiceNetLC) AS ContractNetLC, --invoiced
    COALESCE(th.net, inv.InvoiceNetLC) AS NetLC, --used
    th.floor_value AS FloorValueLC,
    th.ceiling_value AS CeilingValueLC,
    fx.FXRate,
    IFF(pq.ULTIMATEID IS NOT NULL, 1, 0) AS IsPartialBillingQuarter,
    IFF(my.ULTIMATEID IS NOT NULL, 1, 0) AS IsMultiYearQuarter
FROM EDW_TABLES.E365_TERMS_HISTORY th
LEFT JOIN InvoiceNetByUltimateQuarter inv ON inv.ULTIMATEID = th.ultimate_id
    AND inv.YEARQUARTER = th.year_quarter
LEFT JOIN CurrencyFX fx ON fx.CURRENCY = th.CURRENCY
LEFT JOIN PartialQuarter pq ON pq.ULTIMATEID = th.ultimate_id
    AND pq.YEARQUARTER = th.year_quarter
LEFT JOIN MultiYearExpanded my ON my.ULTIMATEID = th.ultimate_id
    AND my.YEARQUARTER = th.year_quarter
LEFT JOIN RenewalQuarterMap rqm ON th.revisit_date = rqm.DATE_VALUE
WHERE th.ultimate_id !=1006427393 --test account
ORDER BY th.ultimate_id, th.year_quarter;