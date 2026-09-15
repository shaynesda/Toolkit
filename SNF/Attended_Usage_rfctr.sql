/********************************************************************
**  Name: Attended_Usage
**  Refactored Date: 6/8/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**   
**   CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**              PRODUCTS = DIM_PRODUCT
**                 SITES = OBT_SITE_EXPANDED
**    E365_TERMS_HISTORY = E365_TERMS_HISTORY (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**        LOOKUP_COUNTRY = DIM_COUNTRY   *** TABLE AND VIEW TO BE CREATED?***
**
**  Description: 
**
********************************************************************/

USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;

-----------------------------------------
--ATTENDED USAGE (PERSISTED FOR SIGMA)          
-----------------------------------------

--Temp table at user grain w/ lowest dims (to get max country p/ person p/ product p/ quarter)
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.OneUserPerCountryProductQuarter AS
select
    cm."Year Quarter" as year_quarter,
    cm."Ultimate ID" as ultimateid,
    cm."Product ID" as productid,
    cm."Unique User ID" as unique_persona,
    MAX(cm."Usage Country ISO") AS usage_country_iso 
from MART.OBT_CONSUMPTION_DAILY cm
where cm."In Contracts" = 'Yes' 
    --and s.commercial_program='E365'   --open up to all comm programs (add as filter downstream)
    --and cm.e365_category='Category A' --put E365 cat as dim downstream for filtering
    and cm."Year Quarter">=20211
group by all;


--Aggregate user counts by usage_country to join to the same grain as the below join table
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.UsersDedupedByCountry AS
select
    year_quarter,
    ultimateid,
    productid,
    usage_country_iso,
    count(distinct unique_persona) as users_deduped
from SANDBOX.FPANDA.OneUserPerCountryProductQuarter
group by all
order by 1,2;


--Join everything
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.FinalAttendedUsageOutput_26Q1 AS  -- Is this meant to be a table or temp table
with INDUSTRY_DATA 
  as
   (select distinct lm.fk_ultimate_key, lm.fk_product_key, "Infrastructure Sector", du."Industry", du."Industry Segment"
  from MART.DIM_INFRASTRUCTURE_SECTOR ifs
  join MART.SSF_CONTRACT_LINE_MONTHLY lm
    on ifs.sk_infrastructure_sector_key = lm.fk_infrastructure_sector_key
  join MART.DIM_ULTIMATE du
    on lm.fk_ultimate_key = du.sk_ultimate_key),
DaysHours as (
    select
        cm."Year Quarter" as year_quarter,
        cm."Ultimate ID" as ultimateid,
        s."Ultimate Name" as ultimate,
        s."Ultimate With ID" as ultimate_with_id,
        th.category as category,        -------------DERIVE EPS OR NOT IN SIGMA (join on yearquarter & cm.ultimateid)
        th.contract_terms as contractterms, 
        th.contract_vs_usage as contractvsusage, 
        th.floor_value as floorvalue, 
        th.ceiling_value as ceilingvalue, 
        th.net,             ------------DERIVE STATUS FOR THAT QUARTER IN SIGMA (compare to contractnet & terms)
        th.contract_net as contractnet,
        s."Ultimate Commercial Program" as commercial_program,
        s."Ultimate Account Size" as account_size,
        s."Org Region" as sites_sales_region,
        s."Org Unit" as sales_ou,
        s."Country ISO" as usage_country_iso,
        lc."Region" as usage_sales_region,
        id."Infrastructure Sector" as final_sector,
        s."Industry" as industry_sector,
        id."Industry Segment" as industry_segment,
        p."Classification" as industry_classification,  -- Is this now in Product from site?
        s."Sales Regional Executive" as sales_rep_executive_manager,
        s."Is DOT" as is_dot,
        s."Industry Short Code" as short_code,
        p."Acquisition Source" as acquired_from_id,
        p."Brand" as brand,
        cm."E365 Category" as e365_category,
        cm."Product ID" as productid,
        p."Product Name" as product,
        cm."Daily Price" as daily_price,
        SUM(cm."Normalized Application Days") AS normalized_app_days,
        SUM(cm."Normalized Application Days") * cm."Daily Price" AS weighted_days,
        SUM(cm."Total Hours") AS hours,
        SUM(cm."Total Hours") * cm."Daily Price" AS weighted_hours,
        SUM(cm."Normalized Application Days") AS normalized_consumption_validation
    from MART.OBT_CONSUMPTION_DAILY cm
    join MART.OBT_SITE_EXPANDED s ON cm."Ultimate ID" = s."Site ID" 
    join MART.DIM_PRODUCT p ON cm."Product ID" = p."Product ID" 
    left join INDUSTRY_DATA id ON p.sk_product_key = id.fk_product_key
    left join MART.DIM_COUNTRY lc ON cm."Usage Country ISO" = lc."Country ISO"
    left join EDW_TABLES.E365_TERMS_HISTORY th --REPORTING_DB.EDW_TABLES.E365_TERMS_HISTORY th on cm.ultimateid = th.ultimateid
        on th.year_quarter = cm."Year Quarter"
        and th.ultimate_id = cm."Ultimate ID"
    where cm."In Contracts" = 'Yes'
        --and cm.e365_category = 'Category A'
        --and s.commercial_program = 'E365'
      and cm."Year Quarter" >= 20211
    group by all)
select
    dh.*,
    COALESCE(u.users_deduped, 0) as users,
    COALESCE(u.users_deduped, 0) * dh.daily_price as weighted_users
from DaysHours dh
left join SANDBOX.FPANDA.UsersDedupedByCountry u on u.year_quarter=dh.year_quarter
    and u.ultimateid=dh.ultimateid
    and u.productid=dh.productid
    and u.usage_country_iso = dh.usage_country_iso
order by dh.year_quarter;


select * from SANDBOX.FPANDA.FinalAttendedUsageOutput_26Q1 where commercial_program='E365' and e365_category='Category A'; --FOR VALIDATION