/********************************************************************
**  Name: SW Pricing Escalation Simulator
**  Refactored Date: 7/28/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                    CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**                               PRODUCTS = DIM_PRODUCT
**                                  SITES = OBT_SITE_EXPANDED
**                     E365_TERMS_HISTORY = E365_TERMS_HISTORY (**REPORTING_DB_SOURCE_SHARE_PROD share**)
**                      CONTRACTS_HISTORY = SSF_CONTRACT_LINE_MONTHLY
**                      LOOKUP_CURRENCYRATES = LOOKUP_CURRENCYRATES (FCT_FX_RATE_FISCAL_BUDGET?, DIM_CURRENCY?)
**
**
**  Description: 
**
********************************************************************/


-------------------------
--WORKSHEET PURPOSE
-------------------------
--Stage persisted tables for Sigma to simulate pricing escalations (CPI) and per product updates across commercial programs (impact to ARR)


-------------------------
--INSTRUCTIONS
-------------------------
--1. If retaining old versions, rename each persisted table below with an '_YearQuarter'
    --Note that all tables below are persisted to Mary Maxson's sandbox. Update the schema to land them elsewhere
--2. Update Effective Dates (in case statement of the SANDBOX.MARY_MAXSON.effective_dates table generation)
--3. Build escalation permutations in section below and populate in Snowflake or Excel & load into Sigma via CSV
    --Current years' escalations can be loaded via CSV (should be static - can be found in 2026 Sigma Escalation workbook)
--4. Run all scripts below (remembering to rename tables first if we want to save old data)
--5. Make a copy of final 2026 Sigma Escalation workbook and:
    --Upload escalation CSV(s)
    --If updated persisted table names below, replace all 'source' tables in Sigma to new names (may take 1 day/refresh to appear)

--Note: Applying escalations (taking multi-years as priority), and applying plugs both happen inside Sigma workbook


--------------------------
--DATABASE SETTINGS
--------------------------
USE DATABASE PRESENTATION;
USE SCHEMA EDW_TABLES;


-----------------------
--YEAR SETTINGS               ------------------------------------------------------------------------------UPDATE                   
-----------------------
create or replace temp table SANDBOX.FPANDA.forecast_years as  
SELECT
    2025::NUMBER AS current_year,
    2026::NUMBER AS future_year;


---------------------------------
--DYNAMIC QUARTER PARAMETERS                   
---------------------------------
--Will dynamically pull the last complete quarter and then predict 6 quarters out
-- Was created as a table and not temp table
create or replace temp table SANDBOX.FPANDA.forecast_parameters as   
with distinct_quarters as (
    select distinct "Year Quarter Num" as year_quarter_num
    from MART.DIM_DATE),
ordered_quarters as (
    select
        year_quarter_num,
        row_number() over (order by year_quarter_num) as rn
    from distinct_quarters),
today_qtr as (
    select c."Year Quarter Num" as year_quarter_num
    from MART.DIM_DATE c
    where c."Date" = current_date()),
baseline_quarter as (
    select 
        o_prev.year_quarter_num as forecast_start_qtr
    from ordered_quarters o_today
    join today_qtr t on o_today.year_quarter_num = t.year_quarter_num
    join ordered_quarters o_prev on o_prev.rn = o_today.rn - 1),
last_complete_qtr as (
    select 
        o_prev.year_quarter_num as last_complete_quarter
    from ordered_quarters o_today
    join today_qtr t on o_today.year_quarter_num = t.year_quarter_num
    join ordered_quarters o_prev on o_prev.rn = o_today.rn - 1),
qtr_params as (
    select
        b.forecast_start_qtr,
        o_plus6.year_quarter_num as forecast_end_qtr,
        o_minus4.year_quarter_num as uplift_start_qtr,
        l.last_complete_quarter
    from baseline_quarter b
    join ordered_quarters o_start on o_start.year_quarter_num = b.forecast_start_qtr
    join ordered_quarters o_plus6 on o_plus6.rn = o_start.rn + 6
    join ordered_quarters o_minus4 on o_minus4.rn = o_start.rn - 4
    join last_complete_qtr l on 1=1)
select
    forecast_start_qtr,
    forecast_end_qtr,
    uplift_start_qtr,
    forecast_end_qtr as uplift_end_qtr,
    last_complete_quarter
from qtr_params;

-------------------------
--EFFECTIVE DATES               ------------------------------------------------------------------------------UPDATE
-------------------------
--Set the rules for when each type of escalation should go into effect
-- Was created as a table and not temp table
create or replace temp table SANDBOX.FPANDA.effective_dates as      
with product_revtype as (select distinct --grab brand & revenue_type combos
        p."Brand" as Brand,
        m."Revenue Type" as Revenue_Type
    from MART.SSF_CONTRACT_LINE_MONTHLY ca 
    join MART.DIM_PRODUCT p on ca.fk_product_key = p.sk_product_key
    join MART.DIM_MATERIAL_ORIGINAL m on ca.fk_material_original_key = m.sk_material_original_key  
     where ca."ARR Net USD" is not null and ca."ARR Net USD" <> 0),
escalation_effective_dates as (
    select
        Brand,
        Revenue_Type,
        case
            when Brand = 'PLS' then date '2026-01-01'
            when Revenue_Type = 'E365' then date '2026-04-01'
            else date '2026-06-27'
        end as escalation_effective_date_2026,
        date '2025-01-01' as escalation_effective_date_2025, --somewhat arbitrary, just grab before
        case
            when Brand = 'PLS' then 'PLS Rule'
            when Revenue_Type = 'E365' then 'E365 Rule'
            else 'Non-E365 / Non-PLS Rule'
        end as escalation_rule
    from product_revtype)
select *
from escalation_effective_dates;



-------------------------
--TIMELINE FRAMEWORK         
-------------------------
--generate a sequential list of quarters within timeframe (list all 6 identified above)
create or replace temp table SANDBOX.FPANDA.forecast_quarters as
select distinct 
    c."Year Quarter Num" as year_quarter
from MART.DIM_DATE c
join SANDBOX.FPANDA.forecast_parameters fp on c."Year Quarter Num"
    between fp.forecast_start_qtr and fp.forecast_end_qtr
order by c."Year Quarter Num";

-------------------------
--BASELINE ARR                       
-------------------------
--Get current ARR by product by Ultimate (use header end date as proxy for those missing renewal date)
create or replace temp table SANDBOX.FPANDA.ContractsActive_Base as 
select
    s."Ultimate ID" as UltimateID,
    COALESCE(s."Ultimate Best Renewal Date", TO_VARCHAR(ca."Contract Start Date", 'YYYYMMDD')) AS Ultimate_Renewal_Date_Raw, --use proxy renewal date if missing
    ca."Brand" as Brand,
    p."Domain",
    p."E365 Category",
    p."Advancement Unit" as AU,
    p."Product Name" as Product,
    p."Product ID" as ProductID,
    m2."Material Description" as Material,
    m1."Original Material Description" as Original_Material,
    ca."ARR Gross USD" as ARR_Gross_USD,
    ca."ARR Net USD" as ARR_Net_USD,
    m1."Revenue Type" as Revenue_Type  
from MART.SSF_CONTRACT_LINE_MONTHLY ca 
join MART.OBT_SITE_EXPANDED s ON ca."FK_SITE_SHIP_TO_KEY" = s.sk_site_key 
join MART.DIM_PRODUCT p on ca.fk_product_key = p.sk_product_key
left join MART.DIM_MATERIAL_ORIGINAL m1 on fk_material_original_key = m1.sk_material_original_key --how to bring in rev_type, per Paul
left join MART.DIM_MATERIAL m2 on ca.fk_material_key = m2.sk_material_key
where ca."ARR Net USD" is not null and ca."ARR Net USD" <> 0;


--Store each Ultimate's latest usage status (& list which quarter that was) 
create or replace temp table SANDBOX.FPANDA.CurrentTermsContractStatus as          
with fp as (select * from SANDBOX.FPANDA.forecast_parameters)
select
    et.ULTIMATE_ID as ultimateid,
    upper(trim(et.contract_vs_usage)) AS contract_vs_usage,
    et.year_quarter as quarter_of_usage_status
from E365_TERMS_HISTORY et
qualify row_number() over (partition by et.ULTIMATE_ID order by 
    (case when et.year_quarter = (select last_complete_quarter from fp) then 1 else 2 end), et.year_quarter desc) = 1;  --take latest available if null 



--Bring in Rev Type (from materials, per Paul Barbour's recommendation)) 
create or replace temp table SANDBOX.FPANDA.CONTRACTSACTIVE_BASELINE_ARR_STAGING as 
with Calendar_Dedup as (
    select
        "Date" date_value,
        "Year Quarter Num" as year_quarter_num,
        "Year Month Num" as year_month_num
    from MART.DIM_DATE
    group by 1,2,3)
select
    cb.UltimateID,
    s."Ultimate Name" as Ultimate,
    s."Country ISO" as Country_ISO,
    s."Country ISO" as Country,
    s."Org Region" as Sales_Region,
    s."Ultimate Commercial Program" as Commercial_Program,
    cb.AU,
    cb."Domain" as Domain,
    cb.Brand,
    sum(cb.ARR_Gross_USD) as ARR_Gross_USD,
    sum(cb.ARR_Net_USD) as ARR_Net_USD,
    TO_CHAR(cb.Ultimate_Renewal_Date_Raw, 'YYYYMMDD') AS ultimate_renewal_date,
    --to_date(to_varchar(cb.Ultimate_Renewal_Date_Raw),'yyyymmdd') as ultimate_renewal_date,
    --CAST(ca.year_quarter_num AS NUMBER(6,0)) AS original_renewal_quarter,
    LPAD(ca.year_quarter_num::varchar , 5, '0') AS original_renewal_quarter, --text version for Sigma (to do RIGHT function)
    CAST(ca.year_quarter_num AS NUMBER(6,0))   AS original_renewal_quarter_num, --numeric version for joining & calcs
    ca.year_month_num as original_renewal_month,
    cb.Revenue_Type,
    c.contract_vs_usage,
    c.quarter_of_usage_status
from SANDBOX.FPANDA.ContractsActive_Base cb
left join MART.OBT_SITE_EXPANDED s on cb.UltimateID = s."Site ID"
left join SANDBOX.FPANDA.CurrentTermsContractStatus c on cb.UltimateID = c.ultimateid
left join Calendar_Dedup ca ON ca.date_value = to_char(cb.Ultimate_Renewal_Date_Raw, 'YYYYMMDD')
group by all;

 select *
    from MART.DIM_DATE;

    select * from ContractsActive_Baseline_ARR;
    
--Bring in baseline ARR
CREATE OR REPLACE TEMP TABLE SANDBOX.FPANDA.ContractsActive_Baseline_ARR AS
WITH fp AS (
    SELECT forecast_start_qtr FROM SANDBOX.FPANDA.forecast_parameters),
calendar_quarter AS (
    SELECT
         "Year Quarter Num" as year_quarter_num,
         MIN("Year Month Num") AS first_month_in_qtr,
         MIN("First Day of Quarter") AS quarter_start
     FROM MART.DIM_DATE
    WHERE "Last Day of Month" = current_date()
    GROUP BY "Year Quarter Num"),
base_with_flag AS (   --Note from Jack/Paul: maybe future enhancement for non-E365 accounts to move all renewal dates back 30 days
    SELECT
        b.*,
        CASE --is ultimate eligible for plug? (pure consumption in last complete quarter)
            WHEN b.quarter_of_usage_status = fp.forecast_start_qtr
             AND b.contract_vs_usage IN ('USAGE ABOVE FLOOR','USAGE WITHIN RANGE') --pure consumption tags
            THEN 1 ELSE 0
        END AS delay_flag,
        CASE --using the 'num' version of the year_quarter for joins & math (output text version for Sigma)
            WHEN b.quarter_of_usage_status = fp.forecast_start_qtr
             AND b.contract_vs_usage IN ('USAGE ABOVE FLOOR','USAGE WITHIN RANGE')
            THEN
                CASE
                    WHEN MOD(b.original_renewal_quarter_num, 10) = 4
                        THEN (FLOOR(b.original_renewal_quarter_num / 10) + 1) * 10 + 1
                    ELSE FLOOR(b.original_renewal_quarter_num / 10) * 10
                        + (MOD(b.original_renewal_quarter_num, 10) + 1)
                END
            ELSE b.original_renewal_quarter_num
        END AS new_renewal_quarter_num
    FROM SANDBOX.FPANDA.CONTRACTSACTIVE_BASELINE_ARR_STAGING b
    CROSS JOIN fp),
final AS (
    SELECT
        bw.UltimateID,
        bw.Ultimate,
        bw.Country_ISO,
        bw.Country,
        bw.Sales_Region,
        bw.Commercial_Program,
        bw.AU,
        bw.Domain,
        bw.Brand,
        bw.ARR_Gross_USD,
        bw.ARR_Net_USD,
        CASE --if plug, push forward 1 quarter, otherwise use original renewal date
            WHEN bw.delay_flag = 1 THEN cq.quarter_start
            ELSE bw.ultimate_renewal_date
        END AS ultimate_renewal_date,
        LPAD(bw.new_renewal_quarter_num::VARCHAR, 5, '0') AS renewal_quarter, --text for Sigma
        CASE
            WHEN bw.delay_flag = 1 THEN cq.first_month_in_qtr
            ELSE bw.original_renewal_month
        END AS renewal_month,
        bw.Revenue_Type,
        bw.contract_vs_usage,
        bw.quarter_of_usage_status
    FROM base_with_flag bw
    LEFT JOIN calendar_quarter cq ON cq.year_quarter_num = bw.new_renewal_quarter_num) --join on number version
SELECT * FROM final;



-------------------------------
--E365 MULTI-YEAR FLAG             
-------------------------------
--Categorize EPS & multi vs single year deals (at Ultimate level)
-- Was created as a table and not temp table
create or replace temp table SANDBOX.FPANDA.E365Terms_Flags as 
with LOOKUP_CURRENCYRATES as 
(SELECT dc."Currency ISO Code" AS currency,   
             1/fb."Fiscal Budget Rate Value" AS rate
        FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
        JOIN MART.DIM_CURRENCY dc
          ON fb.fk_source_currency_key = dc.sk_currency_key
       WHERE "Is Current Rate" = 'TRUE')  
select
    UltimateID,
    case                        
        when t.floorvalue is not null and t.ceilingvalue is not null and t.floorvalue = t.ceilingvalue then 1 
        else 0
    end as Is_EPS, 
    t.years_in_deal as Years_In_Deal, 
    t.current_year_of_deal as Current_Year_Of_Deal,
    case 
        when  t.years_in_deal > 1 and t.current_year_of_deal <> t.years_in_deal then 'Multi-Year'
        else 'Single-Year'
    end as contract_duration,
    case 
        when t.years_in_deal > 1 and t.current_year_of_deal = t.years_in_deal - 1 then 1 
        else 0
    end as Is_Final_Year_Of_MultiYear,
    t.contracttype as Contract_Type, --for plugs downstream 
    t.floorvalue / cr.rate as floorvalue_usd,  
    t.ceilingvalue / cr.rate as ceilingvalue_usd
from E365_TERMS t --old terms fall out downstream
left join LOOKUP_CURRENCYRATES cr on t.currency = cr.currency  --will bring new in automatically in Feb 
where UltimateID in (select distinct UltimateID from SANDBOX.FPANDA.ContractsActive_Baseline_ARR);




-------------------------------
--E365 MULTI-YEAR UPLIFTS
-------------------------------

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

select * from rankedfloors_v2 where ultimateid=1006893437;


--Pair sequential floors
create or replace temp table SANDBOX.FPANDA.pairedfloors_v2 as
select
    cur.ultimateid,
    cur.usage_quarter as current_terms_quarter,
    nxt.usage_quarter as next_terms_quarter,
    cur.floor_value as current_floor,
    nxt.floor_value as next_floor
from SANDBOX.FPANDA.rankedfloors_v2 cur
join SANDBOX.FPANDA.rankedfloors_v2 nxt
  on cur.ultimateid = nxt.ultimateid
 and nxt.rn = cur.rn + 1
order by cur.ultimateid, cur.usage_quarter;

select * from SANDBOX.FPANDA.pairedfloors_v2 where ultimateid=1006893437;


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

select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods where ultimateid=1006893437;


--small calendar temp table
create or replace temp table SANDBOX.FPANDA.QuarterIndex as
select
    year_quarter_num,
    row_number() over (order by year_quarter_num) as qtr_rn
from (
    select distinct "Year Quarter Num" as year_quarter_num
    from MART.DIM_DATE
    where "Year Quarter Num" > 20201);



--Store final uplift and backdate the year_quarter
create or replace temp table SANDBOX.FPANDA.KnownContractUplifts_Effective as
with base as (
    select
        ultimateid,
        current_terms_quarter,
        next_terms_quarter,
        renewal_year,
        current_floor,
        next_floor,
        known_contract_uplift_pct,
        lead(next_terms_quarter) over (
            partition by ultimateid
            order by next_terms_quarter
        ) as next_next_terms_quarter
    from SANDBOX.FPANDA.KnownContractUplifts_allperiods
    where known_contract_uplift_pct is not null),
q as (
    select
        b.*,
        qi_next.qtr_rn as next_rn,
        qi_nextnext.qtr_rn as nextnext_rn
    from base b
    left join SANDBOX.FPANDA.QuarterIndex qi_next on qi_next.year_quarter_num = b.next_terms_quarter
    left join SANDBOX.FPANDA.QuarterIndex qi_nextnext on qi_nextnext.year_quarter_num = b.next_next_terms_quarter),
start_end as (
    select
        q.*,
        qi_start.year_quarter_num as apply_start_quarter,
        qi_start.qtr_rn as start_rn,
        qi_end.year_quarter_num as apply_end_quarter_raw
    from q
    left join SANDBOX.FPANDA.QuarterIndex qi_start on qi_start.qtr_rn = q.next_rn - 1
    left join SANDBOX.FPANDA.QuarterIndex qi_end on qi_end.qtr_rn = q.nextnext_rn - 1)
select
    ultimateid,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    known_contract_uplift_pct,
    apply_start_quarter,
    --If no next uplift, cap to 1 year after apply_start
    coalesce(apply_end_quarter_raw, qi_cap.year_quarter_num) as apply_end_quarter
from start_end se
left join SANDBOX.FPANDA.QuarterIndex qi_cap on qi_cap.qtr_rn = se.start_rn + 4;   --end = start + 4 quarters




/*         ----------------------------------CLOSE, BUT DOES NOT WORK FOR ULTIMATES W/ JUST 1 ROW (2 YEAR DEALS) - THIS SHIFTED ALL %S UP
--------------------------------
--E365 MULTI-YEAR UPLIFTs      
--------------------------------
--Get all valid floor records p/ Ultimate - in analysis timeframe, ranked (find 1st available)
create or replace temp table SANDBOX.FPANDA.rankedfloors_V2 as
select
    ultimateid,
    usage_quarter,
    floor_value,
    row_number() over (partition by ultimateid order by usage_quarter) as rn
from e365_terms_extended e
where e.floor_value is not null
  and e.floor_value > 0;

--select ultimateid, usage_quarter, floor_value, ceiling_value, comments from e365_terms_extended e where ultimateid=1001384666 order by usage_quarter;
--select * from e365_terms where ultimateid=1001384666;

select ultimateid, usage_quarter, floor_value, comments, deal_iteration from e365_terms_extended where ultimateid=1001381826 order by usage_quarter;
select top 10 * from E365_TERMS_HISTORY where ultimateid=1001382970 order by yearquarter;

select * from SANDBOX.FPANDA.rankedfloors_V2 where ultimateid=1006893437 order by usage_quarter;
select ultimateid, usage_quarter, floor_value, comments, deal_iteration from e365_terms_extended where ultimateid=1002940797 order by usage_quarter;


--Find each ultimate's immediate next floor (if none, will calc to 0% & be dropped out when not flagged as multi-year downstream)
create or replace temp table SANDBOX.FPANDA.pairedfloors_V2 as
select
    cur.ultimateid,
    cur.usage_quarter as current_terms_quarter,
    nxt.usage_quarter as next_terms_quarter,
    cur.floor_value as current_floor,
    nxt.floor_value as next_floor,
from SANDBOX.FPANDA.rankedfloors_V2 cur
join SANDBOX.FPANDA.rankedfloors_V2 nxt on cur.ultimateid = nxt.ultimateid and nxt.rn = cur.rn + 1 --next 1 sequentially (already spread 4 quarters apart)
order by cur.ultimateid, cur.usage_quarter;


select * from SANDBOX.FPANDA.pairedfloors_V2 where ultimateid=1006893437 order by next_terms_quarter;
--usage quarter is when deal actually starts


--Calc uplift % by old floor % change to new floor (UltimateID × renewal period grain)  
create or replace table SANDBOX.FPANDA.KnownContractUplifts_allperiods as
select
    p.ultimateid,
    p.current_terms_quarter,
    p.next_terms_quarter,
    left(p.next_terms_quarter, 4) as renewal_year,
    p.current_floor,
    p.next_floor,
     case when p.current_floor > 0
         then (p.next_floor - p.current_floor) / p.current_floor
         else null
    end as known_contract_uplift_pct
from SANDBOX.FPANDA.pairedfloors_v2 p;

--select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods where ultimateid=1001384666;
select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods where ultimateid=1006893437 order by next_terms_quarter;


--new table w/ backdated % uplift
create or replace table SANDBOX.FPANDA.KnownContractUplifts_allperiods_backdated as
select
    ultimateid,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    lead(known_contract_uplift_pct) over (
        partition by ultimateid order by next_terms_quarter) as known_contract_uplift_pct,
    --lead(next_terms_quarter) over (
        --partition by ultimateid order by next_terms_quarter) as uplift_effective_terms_quarter,
    lead(current_floor) over (
        partition by ultimateid order by next_terms_quarter) as uplift_base_floor,
    lead(next_floor) over (
        partition by ultimateid order by next_terms_quarter) as uplift_next_floor
from SANDBOX.FPANDA.KnownContractUplifts_allperiods;

select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods_backdated where ultimateid=1006893437 order by next_terms_quarter;



--New table for backdating the % uplift (will only pick up at the renewal quarter anyway and should fill down)
create or replace temp table SANDBOX.FPANDA.KnownContractUplifts_Effective as
select
    ultimateid,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    --uplift_effective_terms_quarter as effective_terms_quarter,
    known_contract_uplift_pct,
    next_terms_quarter as apply_start_quarter,
    lead(next_terms_quarter) over (partition by ultimateid order by next_terms_quarter) as apply_end_quarter
    --uplift_base_floor,
    --uplift_next_floor,
    -----------may still want to put in an 'apply start quarter'
from SANDBOX.FPANDA.KnownContractUplifts_allperiods_backdated
where known_contract_uplift_pct is not null;  --drop the last shifted-null row


select * from SANDBOX.FPANDA.KnownContractUplifts_Effective where ultimateid=1001381826 order by next_terms_quarter;
select * from SANDBOX.FPANDA.KnownContractUplifts_Effective where ultimateid=1006893437 order by next_terms_quarter; 
*/

/*
--Store all calendar quarters & lag for prior           ----------------------------DIDN'T END UP USING - CAN DELETE
create or replace temp table SANDBOX.FPANDA.QuarterMap as
select
    year_quarter_num as year_quarter,
    lag(year_quarter_num) over (order by year_quarter_num) as prior_year_quarter
from (select distinct year_quarter_num from calendar where year_quarter_num > 20201);
*/



/* ---- RETAIN ORIGINAL
--Temp table to help resolve the multi-year uplift join downstream (add 'apply & end quarters')
create or replace temp table SANDBOX.FPANDA.KnownContractUplifts_Effective as
select
    ultimateid,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    known_contract_uplift_pct,
    next_terms_quarter as apply_start_quarter, --this should be the next_terms_quarter - 1 quarter
    lead(next_terms_quarter) over (partition by ultimateid order by next_terms_quarter) as apply_end_quarter
from SANDBOX.FPANDA.KnownContractUplifts_allperiods;

--select * from SANDBOX.FPANDA.KnownContractUplifts_Effective where ultimateid=1001384666;
--select * from e365_terms_extended where ultimateid=1001381641 order by usage_quarter;

select * from KnownContractUplifts_Effective where ultimateid=1002940797 order by next_terms_quarter;

---------------------------PUT FIX IN THIS UPSTREAM TABLE ONLY WHERE APPLY_START_QUARTER (TO USE IN JOIN DOWNSTREAM) IS APPLY_START_QTR - 1 (to carry forward the baseline)

------MAKE SURE NO %S IN BASELINE DATA IS BEING APPLIED (AGAIN) --> NO UPLIFTS >= THE BASELINE (last_complete_quarter)
*/-----------------RETAIN ORIGINAL


/*
--------------------------------
--E365 MULTI-YEAR UPLIFTs 
--------------------------------
--Get all valid floor records p/ Ultimate - in analysis timeframe, ranked (find 1st available)
create or replace temp table SANDBOX.FPANDA.rankedfloors_v3 as
select
    ultimateid,
    deal_iteration,
    usage_quarter,
    floor_value,
    row_number() over (partition by ultimateid, deal_iteration order by usage_quarter) as rn
from e365_terms_extended
where floor_value is not null and floor_value > 0;

--select ultimateid, usage_quarter, floor_value, ceiling_value, comments from e365_terms_extended e where ultimateid=1001384666 order by usage_quarter;
--select * from reporting_db.edw_tables.e365_terms where ultimateid=1001384666;

select ultimateid, usage_quarter, floor_value, comments, deal_iteration from e365_terms_extended where ultimateid=1001382970 order by usage_quarter;
select top 10 * from E365_TERMS_HISTORY where ultimateid=1001382970 order by yearquarter;

select * from SANDBOX.FPANDA.rankedfloors_v3 where ultimateid=1001382970 order by usage_quarter;



--Find each ultimate's immediate next floor (if none, will calc to 0% & be dropped out when not flagged as multi-year downstream)
create or replace temp table SANDBOX.FPANDA.pairedfloors_v3 as
select
    cur.ultimateid,
    cur.deal_iteration,
    cur.usage_quarter as current_terms_quarter,
    nxt.usage_quarter as next_terms_quarter,
    cur.floor_value as current_floor,
    nxt.floor_value as next_floor
from SANDBOX.FPANDA.rankedfloors_v3 cur
join SANDBOX.FPANDA.rankedfloors_v3 nxt on cur.ultimateid = nxt.ultimateid
 and cur.deal_iteration = nxt.deal_iteration
 and nxt.rn = cur.rn + 1
order by cur.ultimateid, cur.deal_iteration, cur.usage_quarter;

select * from SANDBOX.FPANDA.pairedfloors_v3 where ultimateid=1001382970 order by next_terms_quarter;



--Calc uplift % by old floor % change to new floor (UltimateID × renewal period grain)  
create or replace table SANDBOX.FPANDA.KnownContractUplifts_allperiods_v3 as
select
    ultimateid,
    deal_iteration,
    current_terms_quarter,
    next_terms_quarter,
    left(next_terms_quarter, 4) as renewal_year,
    current_floor,
    next_floor,
    case
        when current_floor > 0 then (next_floor - current_floor) / current_floor
        else null
    end as known_contract_uplift_pct
from SANDBOX.FPANDA.pairedfloors_v3;

--select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods where ultimateid=1001384666;
select * from SANDBOX.FPANDA.KnownContractUplifts_allperiods_v3 where ultimateid=1001382970 order by next_terms_quarter;


--Temp table to help resolve the multi-year uplift join downstream (add 'apply & end quarters')
create or replace temp table SANDBOX.FPANDA.KnownContractUplifts_Effective_v3 as
select
    ultimateid,
    deal_iteration,
    current_terms_quarter,
    next_terms_quarter,
    renewal_year,
    current_floor,
    next_floor,
    known_contract_uplift_pct,
    next_terms_quarter as apply_start_quarter,
    lead(next_terms_quarter) over (partition by ultimateid, deal_iteration order by next_terms_quarter) as apply_end_quarter
from SANDBOX.FPANDA.KnownContractUplifts_allperiods_v3;

select * from SANDBOX.FPANDA.KnownContractUplifts_Effective_v3 where ultimateid=1001382970 order by next_terms_quarter;
*/


--------------------------
--ULTIMATE PRICEBOOK           
--------------------------
--Find all combos of ultimate > rev_type > pricebook > currency (currency splits grain)
create or replace temp table SANDBOX.FPANDA.Pricebook_Metadata_Raw as
select distinct
    s."Ultimate ID" as UltimateID,
    m1."Revenue Type" as Revenue_Type,
    dp."Pricebook Number" as Price_List_Code,
    fp."Pricebook Description" as Price_List,
    dc."Currency ISO Code" Currency,
    sum(clm."ARR Net USD") as ARR_Net_USD
from MART.SSF_CONTRACT_LINE_MONTHLY clm
join MART.OBT_SITE_EXPANDED s on clm."FK_SITE_SHIP_TO_KEY" = s.sk_site_key 
join MART.DIM_PRODUCT p on clm.fk_product_key = p.sk_product_key
join MART.FCT_PRICEBOOK fp on p.sk_product_key = fp.fk_pricebook_product_key
join MART.DIM_PRICEBOOK dp on fp.fk_pricebook_key = dp.sk_pricebook_key
join MART.DIM_CURRENCY dc on fp.fk_pricebook_currency_key = dc.sk_currency_key
left join MART.DIM_MATERIAL_ORIGINAL m1 on clm.fk_material_original_key = m1.sk_material_original_key --how to bring in rev_type, per Paul
left join MART.DIM_MATERIAL m2 on clm.fk_material_key = m2.sk_material_key    
where clm."ARR Net USD" is not null and clm."ARR Net USD" <> 0
group by all;


select * from MART.OBT_CONTRACT_ACTIVE_LINE; -- where  = '0045994024';


--Pricebook (defaults, override downstream for E365) - take one w/ highest ARR to resolve currency grain issue
create or replace temp table SANDBOX.FPANDA.Pricebook_Metadata as
select
    UltimateID,
    Revenue_Type,
    Price_List_Code,
    Price_List,
    Currency
    from (select *, row_number() over (partition by UltimateID, Revenue_Type order by ARR_Net_USD desc) as rn
    from Pricebook_Metadata_Raw)
where rn = 1;

--E365 Pricebooks for override downstream (also implicitly 'checks' if Ultimate is active)
create or replace temp table SANDBOX.FPANDA.E365_Pricebook_Overrides as
select distinct
    t.ultimate_id as UltimateID,
    t.pricebook as E365_Pricebook
from E365_TERMS_HISTORY t; -- REPORTING_DB.EDW_TABLES.E365_TERMS t;



--E365 overwrite and get a final pricebook p/ Ultimate p/ Revenue_Type
create or replace temp table SANDBOX.FPANDA.Pricebook_Final as 
select
    pm.UltimateID,
    pm.Revenue_Type,
    pm.Price_List_Code,
    case --when rev_type=E365 and ultimate exists in e365_terms, then use e365 pricebook
        when pm.Revenue_Type = 'E365'
             and epo.UltimateID is not null
        then epo.E365_Pricebook
        else pm.Price_List
    end as Pricebook,
    pm.Currency, --future proof for FX rates 
    case --create Is_E365 flag for ultimate off same criteria (for downstream)
        when pm.Revenue_Type = 'E365'
             and epo.UltimateID is not null
        then 1 
        else 0 
    end as Is_E365
from SANDBOX.FPANDA.Pricebook_Metadata pm
left join SANDBOX.FPANDA.E365_Pricebook_Overrides epo on pm.UltimateID = epo.UltimateID;



----------------------------------
--STAGE TIME SPINE W/ BASE ARR         
----------------------------------
--For each Ultimate > Brand, populate 1 row p/ forecast quarter (populate current ARR into 1st quarter)
create or replace temp table SANDBOX.FPANDA.forecast_spine_staging as
select                                 
    fq.year_quarter,
    b.ultimateid,
    b.ultimate,
    b.country_iso,
    b.country,
    b.sales_region,
    b.commercial_program,
    b.revenue_type,
    b.domain,
    b.AU,
    b.brand,
    b.ultimate_renewal_date,
    b.renewal_quarter,
    b.renewal_month,
    b.contract_vs_usage as most_recent_usage_status,
    b.quarter_of_usage_status,
    b.arr_gross_usd as baseline_gross_arr_usd,
    b.arr_net_usd as baseline_net_arr_usd,             
    case 
        when fq.year_quarter = fp.forecast_start_qtr
        then b.arr_gross_usd 
    end as arr_gross_usd_forecast,
    case 
        when fq.year_quarter = fp.forecast_start_qtr
        then b.arr_net_usd
    end as arr_net_usd_forecast,
    case when fq.year_quarter = b.renewal_quarter then 1 else 0 end as is_renewal_quarter --second renewal quarter flag handled in Sigma
from SANDBOX.FPANDA.ContractsActive_Baseline_ARR b
cross join SANDBOX.FPANDA.forecast_quarters fq
cross join SANDBOX.FPANDA.forecast_parameters fp
order by ultimateid, year_quarter, brand;



------------------------------
--ADD DIMENSIONS TO SPINE
------------------------------
--Add derived pricebook, currency (for future FX implementation), and E365 terms (floors and ceilings...etc.)
-- Was created as a table and not temp table
create or replace temp table SANDBOX.FPANDA.forecast_spine_enriched_v3 as

with spine as (
    select *
    from SANDBOX.FPANDA.forecast_spine_staging)
select
    s.*,
    --pricebook data
    pb.Price_List_Code,
    pb.Pricebook,
    pb.Currency, 
    pb.Is_E365,
    --E365 terms data
    ef.Is_EPS,
    ef.Years_In_Deal,
    ef.Current_Year_Of_Deal,
    ef.Contract_Duration,
    case when ef.Contract_Duration='Multi-Year' then 1 else 0 end as Is_Multi_Year,
    ef.Is_Final_Year_Of_Multiyear,
    ef.Contract_Type,
    ef.FloorValue_USD,    
    ef.CeilingValue_USD,
    --E365 multi-year uplift & plugs (is_E365 also checks if in E365_Terms - not just rev_type, per Paul)
    case when pb.Is_E365=1 then ku.current_terms_quarter end as current_terms_quarter,
    case when pb.Is_E365=1 then ku.next_terms_quarter end as next_terms_quarter,
    case when pb.Is_E365=1 then ku.renewal_year end as renewal_year,
    case when pb.Is_E365=1 then ku.current_floor end as current_floor,
    case when pb.Is_E365=1 then ku.next_floor end as next_floor,
    case when pb.Is_E365=1 then ku.known_contract_uplift_pct end as known_contract_uplift_pct,
    --escalation dates (for validation) + flags for which to apply where, based on account's renewal
    ed.escalation_effective_date_2026,
    ed.escalation_effective_date_2025,
    ed.escalation_rule,
    case
        when s.ultimate_renewal_date >= ed.escalation_effective_date_2026 then '2026'
        when s.ultimate_renewal_date <  ed.escalation_effective_date_2026 then '2025'
        else 'UNKNOWN' 
    end as escalation_pricing_year,
    --when to apply old vs new FX rates (build small table in Sigma for new rates & calc on the fly there)
    case
        when s.year_quarter < 20262 then 'Current'
        else 'New_2026'
    end as FX_Version
from spine s
left join SANDBOX.FPANDA.Pricebook_Final pb 
    on s.ultimateid = pb.ultimateid 
    and s.revenue_type = pb.revenue_type --pricebook should join on rev_type too (since E365 is different)
left join SANDBOX.FPANDA.E365Terms_Flags ef 
    on s.ultimateid = ef.ultimateid  --implicit rev_type w/ how is_365 was defined
    and s.revenue_type='E365'
    and pb.is_e365 = 1
left join SANDBOX.FPANDA.KnownContractUplifts_Effective ku --updated to temp table (can persist at some point, adds start quarter)
    on s.ultimateid = ku.ultimateid -->implicitly on rev_type too from is_e365 logic
    and pb.is_e365 = 1 --only applicable to e365 (probably redundant)
    and s.year_quarter >= ku.apply_start_quarter --now using the apply quarter
    and s.year_quarter <  coalesce(ku.apply_end_quarter, 99999) --some apply_end_quarters are null (for when contract runs out) 9999 for no upper bounds
left join SANDBOX.FPANDA.effective_dates ed --to flag where to apply effective dates
    on s.brand = ed.brand 
    and s.revenue_type = ed.revenue_type --at rev_type grain
order by s.ultimateid, s.year_quarter, s.brand;




