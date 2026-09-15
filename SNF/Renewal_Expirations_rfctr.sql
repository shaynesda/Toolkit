/********************************************************************
**  Name: Renewal Expirations 
**  Refactored Date: 7/3/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                    CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**                               PRODUCTS = DIM_PRODUCT
**                                  SITES = OBT_SITE_EXPANDED
**                     E365_TERMS_HISTORY = E365_TERMS_HISTORY (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**                      CONTRACTS_HISTORY = SSF_CONTRACT_LINE_MONTHLY, DIM_CONTRACT 
**                                          (Final Sector - DIM_INFRASTRUCTURE_SECTOR, Revenue Type - DIM_MATERIAL_ORIGINAL)
**   CONTRACTS_CONSUMPTION_ACCRUAL_DWAPPS = SSF_CONTRACT_LINE_MONTHLY, DIM_CONTRACT
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

-----------------------------
--RENEWAL EXPIRATIONS
-----------------------------


--Single CTE           -------------------UPDATE YEAR MONTH
with Contracts_Combined as (
  select a3."Ultimate Name" as ultimate, 
         a1."Brand" as brand,
         a2."Acquisition Source" as acquired_from_id, -- a3."Site Activity Source"?
         a2."Domain" as domain,
         a3."Site Country" as country,
         a3."Country ISO" as country_iso,
         a3."Org Region" as sales_region,  
         a3."Org Unit" as sales_ou,
         ifs."Infrastructure Sector" as final_sector,
         a3."Is DOT" as is_dot,
         to_char(a1."Snapshot Date",'YYYYMM') as calendarmonth,
         a1."Contract Start Date" as header_start_date,
         a1."Contract End Date" as header_end_date,
         dmo."Revenue Type" as revenue_type, 
         a1."ARR Net USD" as ARR
    from MART.SSF_CONTRACT_LINE_MONTHLY a1 
    join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
    join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
left join MART.DIM_INFRASTRUCTURE_SECTOR ifs on a1.fk_infrastructure_sector_key = ifs.sk_infrastructure_sector_key
left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
where 1=1 
  and a1."Source" = 'Workday Accruals'
  and to_char(a1."Snapshot Date",'YYYYMM') > '202501')
select
    ultimate,
    brand,
    acquired_from_id,
    domain,
    country,
    country_iso,
    sales_region,
    sales_OU,
    final_sector,
    is_dot,
    calendarmonth,
    header_start_date,
    header_end_date,
    revenue_type,
    sum(ARR) as ARR
from Contracts_Combined
where 1=1 
--and  ultimate in ('Mississippi DOT') --'Shell Nederland B.V.','ESKOM HOLDINGS SOC LTD','West Virginia DOT','NASA Kennedy Space Center')
and calendarmonth > '202501'
group by all;

--------------update to month before EOQ

-------------------------------------------
--CONSUMPTION TIED TO EXPIRING RENEWALS
-------------------------------------------


----Terms Extended
--select a2.Currency,a1.* from REPORTING_DB.EDW_TABLES.E365_TERMS_EXTENDED a1
--left join REPORTING_DB.EDW.E365_TERMS a2 on a1.UltimateID = a2.UltimateID;

select CURRENCY, ULTIMATE_ID, ULTIMATE_NAME, ANALYST, SIGN_DATE, PRICEBOOK, FLOOR_VALUE, FLOOR_LAST_USAGE_QTR, CEILING_VALUE, CEILING_LAST_USAGE_QTR, YEAR_QUARTER,
GROSS, NET, CONTRACT_VS_USAGE
from EDW_TABLES.E365_TERMS_HISTORY;

select cm."Ultimate ID", s."Ultimate Name", cm."Year Quarter", sum(cm."Normalized Consumption")
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
WHERE cm."Year Quarter" BETWEEN 20242 and 20251 
  AND cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
  AND cm."Ultimate Commercial Program"='E365'
GROUP BY ALL;

--Q2 Expirations          -------------------UPDATE YEAR QUARTERS
select
    cm."Ultimate ID" as ultimateid,
    s."Ultimate Name" as ultimate,
    sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) as "26q1_ltm_consumption", 
    sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end) as "25q1_ltm_consumption", 
    (sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) -
        sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end)) 
    / nullif(sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end),0) as "ltm_pct_difference" 
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
WHERE cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
  AND cm."Ultimate Commercial Program"='E365'
  AND cm."Year Quarter" BETWEEN 20242 and 20261 
  AND cm."Ultimate ID" in (1001381980,1001383421,1001385106,1001387491,1001390531,1002042705,1002049104,1002054668,1002064866,1005880744,1005952746,1006025121,1006630098,1006784390)
group by all
order by cm."Ultimate ID";

--Q3 expirations            -------------------UPDATE YEAR QUARTERS

select
   -- cm."Ultimate ID" as ultimateid,
   -- s."Ultimate Name" as ultimate,
    sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) as "26q1_ltm_consumption", 
    sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end) as "25q1_ltm_consumption", 
    (sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) -
        sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end)) 
    / nullif(sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end),0) as "ltm_pct_difference" 
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
WHERE cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
  AND cm."Ultimate Commercial Program"='E365'
  AND cm."Year Quarter" BETWEEN 20242 and 20261 
  AND cm."Ultimate ID" in (1001382285,
1001385685,
1001385944,
1001386321,
1001387572,
1001389868,
1001390008,
1001698777,
1002047395,
1002050607,
1002120345,
1003085238,
1004982137,
1006376930,
1006429837)
group by all
order by cm."Ultimate ID";


--Q4 expirations             -------------------UPDATE YEAR QUARTERS
select
   -- cm."Ultimate ID" as ultimateid,
   -- s."Ultimate Name" as ultimate,
    sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) as "26q1_ltm_consumption", 
    sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end) as "25q1_ltm_consumption", 
    (sum(case when cm."Year Quarter" between 20252 and 20261 then cm."Normalized Consumption" else 0 end) -
        sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end)) 
    / nullif(sum(case when cm."Year Quarter"  between 20242 and 20251 then cm."Normalized Consumption" else 0 end),0) as "ltm_pct_difference" 
FROM MART.OBT_CONSUMPTION_DAILY cm
LEFT JOIN MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID"
LEFT JOIN MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID"
WHERE cm."In Contracts" = 'Yes'
  AND p."Acquisition Source" NOT IN ('Seequent')
  AND cm."Ultimate Commercial Program"='E365'
  AND cm."Year Quarter" BETWEEN 20242 and 20261 
  AND cm."Ultimate ID" in (1001381496,
1001381641,
1001382151,
1001382704,
1001382933,
1001383089,
1001383619,
1001383661,
1001383832,
1001384859,
1001385387,
1001385616,
1001385880,
1001386107,
1001386573,
1001386812,
1001389456,
1001389583,
1001389595,
1001390746,
1001391255,
1001392556,
1001392596,
1001392643,
1001393041,
1001393122,
1001532714,
1002038534,
1002059397,
1002950459,
1003911794,
1004013854,
1005229829,
1005559240,
1006497506)
group by all
order by cm."Ultimate ID";