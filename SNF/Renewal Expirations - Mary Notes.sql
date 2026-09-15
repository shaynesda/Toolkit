-----------------------------
--RENEWAL EXPIRATIONS
-----------------------------

select top 10 * from PRESENTATION.MART.obt_site_expanded;
select top 10 * from PRESENTATION.MART.dim_ultimate;
select top 10 * from PRESENTATION.MART.dim_product;

select top 10 * from PRESENTATION.MART.OBT_CONTRACT_HISTORY_LINE;
select top 10 * from PRESENTATION.MART.FCT_CONTRACT_LINE;
select top 10 * from PRESENTATION.MART.DIM_CONTRACT_HISTORY;
select top 10 * from PRESENTATION.MART.SSF_CONTRACT_LINE_MONTHLY;

select distinct fk_product_key from PRESENTATION.MART.OBT_CONTRACT_HISTORY_LINE;

select distinct om."Revenue Type"
from PRESENTATION.MART.obt_contract_history_line c
JOIN PRESENTATION.MART.dim_product p
    ON c.fk_product_key = p.sk_product_key
JOIN PRESENTATION.MART.dim_material_original om
    ON c.fk_material_original_key = om.sk_material_original_key
JOIN PRESENTATION.MART.dim_material m
    ON om.sk_material_original_key = m.sk_material_key
JOIN PRESENTATION.MART.obt_site_expanded s
    ON c.fk_site_ship_to_key = sk_site_key;
WHERE left(c.fk_snapshot_date_key,6) = 202604; --equivalent to filtering on calendarmonth in Contracts_History in "old world". Key has day of month at end, so need to do "left 6" function if you just want to reference yearmonth (e.g. February would be 20260228, December would be 20261231...etc.)

--Prasad also noted that the OBT table has no ARR $0 line items, so we shouldn't need to include that filter anymore, but "that might mean wrong quanitiy numbers for SELECT, if an account porfolio balances they get the new product line item added with the quantity but with $0 ARR until renewal"

----------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------OLD WORLD SCRIPT-------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------

--Single CTE           -------------------UPDATE YEAR MONTH
with Contracts_Combined as (
    select
        a3.ultimate,
        a2.brand,
        a2.acquired_from_id,
        a2.domain,
        a3.country,
        a3.country_iso,
        a3.sales_region,
        a3.sales_OU,
        a3.final_sector,
        a3.is_dot,
        a1.calendarmonth,
        a1.header_start_date,
        a1.header_end_date,
        a1.revenue_type,
        a1.arr_net_usd as ARR
    from REPORTING_DB.EDW.contracts_history AS a1
    left join REPORTING_DB.EDW.products AS a2 ON a1.productid = a2.productid
    left join REPORTING_DB.EDW.sites AS a3 ON a1.ship_toid = a3.siteid
    where a1.calendarmonth > '202212'  --------------update to month before EOQ
union all
    select
        a3.ultimate,
        a2.brand,
        a2.acquired_from_id,
        a2.domain,
        a3.country,
        a3.country_iso,
        a3.sales_region,
        a3.sales_OU,
        a3.final_sector,
        a3.is_dot,
        a1.calendarmonth,
        a1.header_start_date,
        a1.header_end_date,
        a1.revenue_type,
        a1.ARR_USD_NET
    from Reporting_DB.EDW_TABLES.CONTRACTS_CONSUMPTION_ACCRUAL_DWAPPS AS a1
    left join REPORTING_DB.EDW.products AS a2 ON a1.productid = a2.productid
    left join REPORTING_DB.EDW.sites AS a3 ON a1.ship_to = a3.siteid
    where a1.calendarmonth > '202212')  --------------update to month before EOQ
select
    ultimate,
    brand,
    acquired_from_id,
    domain,
    country,
    country_iso,
    sales_region,
    sales_OU,
    case
        when brand in ('MOSES', 'SACS') then 'Resources'
        when final_sector is NULL then 'Project Delivery'
        when final_sector = 'Uasssigned' then 'Project Delivery'
        else final_sector
    end as final_sector,
    is_dot,
    calendarmonth,
    header_start_date,
    header_end_date,
    revenue_type,
    sum(ARR) as ARR
from Contracts_Combined
group by all;



-------------------------------------------
--CONSUMPTION TIED TO EXPIRING RENEWALS
-------------------------------------------


----Terms Extended
select a2.Currency,a1.* from REPORTING_DB.EDW_TABLES.E365_TERMS_EXTENDED a1
left join REPORTING_DB.EDW.E365_TERMS a2 on a1.UltimateID = a2.UltimateID;

select cm.ultimateid, s.ultimate, year_quarter, sum(normalized_consumption) from consumption_metrics cm join sites s on s.siteid=cm.ultimateid join products p on p.productid=cm.productid where in_contracts=1 and acquired_from_id not in ('Seequent') and commercial_program='E365' and year_quarter between 20242 and 20251 and cm.ultimateid=1001381980 group by all;


--Q2 Expirations          -------------------UPDATE YEAR QUARTERS
select
    cm.ultimateid,
    s.ultimate,
    sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) as "26q1_ltm_consumption", 
    sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end) as "25q1_ltm_consumption", 
    (sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) -
        sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end)) 
    / nullif(sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end),0) as "ltm_pct_difference" 
from consumption_metrics cm
join sites s on s.siteid = cm.ultimateid
join products p on p.productid = cm.productid
where cm.in_contracts = 1
  and p.acquired_from_id not in ('Seequent')
  and s.commercial_program = 'E365'
  and cm.year_quarter between 20242 and 20261
  and cm.ultimateid in (1001381980,1001383421,1001385106,1001387491,1001390531,1002042705,1002049104,1002054668,1002064866,1005880744,1005952746,1006025121,1006630098,1006784390)
group by all
order by cm.ultimateid; 



--Q3 expirations            -------------------UPDATE YEAR QUARTERS
select
    --cm.ultimateid,
    --s.ultimate,
    sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) as "26q1_ltm_consumption",
    sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end) as "25q1_ltm_consumption",
    (sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) -
        sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end))
    / nullif(sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end),0) as "ltm_pct_difference"
from consumption_metrics cm
join sites s on s.siteid = cm.ultimateid
join products p on p.productid = cm.productid
where cm.in_contracts = 1
  and p.acquired_from_id not in ('Seequent')
  and s.commercial_program = 'E365'
  and cm.year_quarter between 20242 and 20261
  and cm.ultimateid in (1001382285,
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
order by cm.ultimateid; 



--Q4 expirations             -------------------UPDATE YEAR QUARTERS
select
    --cm.ultimateid,
    --s.ultimate,
    sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) as "26q1_ltm_consumption",
    sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end) as "25q1_ltm_consumption",
    (sum(case when cm.year_quarter between 20252 and 20261 then cm.normalized_consumption else 0 end) -
        sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end))
    / nullif(sum(case when cm.year_quarter between 20242 and 20251 then cm.normalized_consumption else 0 end),0) as "ltm_pct_difference"
from consumption_metrics cm
join sites s on s.siteid = cm.ultimateid
join products p on p.productid = cm.productid
where cm.in_contracts = 1
  and p.acquired_from_id not in ('Seequent')
  and s.commercial_program = 'E365'
  and cm.year_quarter between 20242 and 20261
  and cm.ultimateid in (1001381496,
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
order by cm.ultimateid; 




----------------------------------------------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------NEW WORLD SCRIPT-------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------------------------


SET EOQ_MONTH = '202212';

WITH Contracts_Combined AS (
    SELECT
        u."Ultimate Name",
        p."Brand",
        p."Acquisition Source",
        p."Domain",
        u."Ultimate Country",
        u."Industry",
        u."Industry Segment",
        u."Industry Short Code",
        u."Is DOT",
        LEFT(c.FK_Snapshot_Date_Key, 6) AS "Calendar Month",
        TO_DATE(c.contract_start_date_key::VARCHAR, 'YYYYMMDD') AS "Contract Start Date",
        TO_DATE(c.contract_end_date_key::VARCHAR, 'YYYYMMDD') AS "Contract End Date"
        om."Revenue Type",
        c."ARR Net USD"
    FROM PRESENTATION.MART.OBT_CONTRACT_HISTORY_LINE c
    LEFT JOIN PRESENTATION.MART.DIM_PRODUCT p
        ON c.FK_Product_Key = p.SK_Product_Key
    LEFT JOIN PRESENTATION.MART.DIM_MATERIAL_ORIGINAL om
        ON c.FK_Material_Original_Key = om.SK_Material_Original_Key
    LEFT JOIN PRESENTATION.MART.DIM_ULTIMATE u
        ON c.FK_Ultimate_Key = u.SK_Ultimate_Key
    WHERE LEFT(c.FK_Snapshot_Date_Key, 6) > $EOQ_MONTH
    UNION ALL
    SELECT
        u."Ultimate Name",
        p."Brand",
        p."Acquisition Source",
        p."Domain",
        u."Ultimate Country",
        u."Industry",
        u."Industry Segment",
        u."Industry Short Code",
        u."Is DOT",
        LEFT(c.FK_Snapshot_Date_Key, 6) AS "Calendar Month",
        c."Header Start Date",
        c."Header End Date",
        om."Revenue Type",
        c."ARR Net USD"
    FROM /* TODO: new-world consumption accrual contract table */ c  --TO DO: Need new-world equivalent of old:Reporting_DB.EDW_TABLES.CONTRACTS_CONSUMPTION_ACCRUAL_DWAPPS
    LEFT JOIN PRESENTATION.MART.DIM_PRODUCT p
        ON c.FK_Product_Key = p.SK_Product_Key
    LEFT JOIN PRESENTATION.MART.DIM_MATERIAL_ORIGINAL om
        ON c.FK_Material_Original_Key = om.SK_Material_Original_Key
    LEFT JOIN PRESENTATION.MART.DIM_ULTIMATE u
        ON c.FK_Ultimate_Key = u.SK_Ultimate_Key
    WHERE LEFT(c.FK_Snapshot_Date_Key, 6) > $EOQ_MONTH)
SELECT
    "Ultimate Name",
    "Brand",
    "Acquisition Source",
    "Domain",
    "Ultimate Country",
    "Industry",
    "Industry Segment",
    "Industry Short Code",
    "Is DOT",
    "Calendar Month",
    "Header Start Date",
    "Header End Date",
    "Revenue Type",
    SUM("ARR Net USD") AS "ARR Net USD"
FROM Contracts_Combined
GROUP BY ALL;

select top 10 * from PRESENTATION.MART.dim_ultimate;




----Final run
SET EOQ_MONTH = '202212';

WITH Contracts_Combined AS (
    SELECT
        u."Ultimate Name",
        p."Brand",
        p."Acquisition Source",
        p."Domain",
        u."Ultimate Country",
        u."Industry",
        u."Industry Segment",
        u."Industry Short Code",
        u."Is DOT",
        LEFT(c.FK_Snapshot_Date_Key, 6) AS "Calendar Month",
        TO_DATE(c.FK_Contract_Start_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract Start Date",
        TO_DATE(c.FK_Contract_End_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract End Date",
        om."Revenue Type",
        c."ARR Net USD"
    FROM PRESENTATION.MART.SSF_CONTRACT_LINE_MONTHLY c          --------------------------USE SSF_CONTRACT_LINE_MONTHLY instead 
    LEFT JOIN PRESENTATION.MART.DIM_PRODUCT p
        ON c.FK_Product_Key = p.SK_Product_Key
    LEFT JOIN PRESENTATION.MART.DIM_MATERIAL_ORIGINAL om
        ON c.FK_Material_Original_Key = om.SK_Material_Original_Key
    LEFT JOIN PRESENTATION.MART.DIM_ULTIMATE u
        ON c.FK_Ultimate_Key = u.SK_Ultimate_Key
    WHERE LEFT(c.FK_Snapshot_Date_Key, 6) > $EOQ_MONTH
    UNION ALL
    SELECT
        u."Ultimate Name",
        p."Brand",
        p."Acquisition Source",
        p."Domain",
        u."Ultimate Country",
        u."Industry",
        u."Industry Segment",
        u."Industry Short Code",
        u."Is DOT",
        LEFT(c.FK_Snapshot_Date_Key, 6) AS "Calendar Month",
        TO_DATE(c.FK_Contract_Start_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract Start Date",
        TO_DATE(c.FK_Contract_End_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract End Date",
        om."Revenue Type",
        c."ARR Net USD"
    FROM PRESENTATION.MART.SSF_CONTRACT_LINE_MONTHLY c
    LEFT JOIN PRESENTATION.MART.DIM_PRODUCT p
        ON c.FK_Product_Key = p.SK_Product_Key
    LEFT JOIN PRESENTATION.MART.DIM_MATERIAL_ORIGINAL om
        ON c.FK_Material_Original_Key = om.SK_Material_Original_Key
    LEFT JOIN PRESENTATION.MART.DIM_ULTIMATE u
        ON c.FK_Ultimate_Key = u.SK_Ultimate_Key
    WHERE LEFT(c.FK_Snapshot_Date_Key, 6) > $EOQ_MONTH)
SELECT
    "Ultimate Name",
    "Brand",
    "Acquisition Source",
    "Domain",
    "Ultimate Country",
    "Industry",
    "Industry Segment",
    "Industry Short Code",
    "Is DOT",
    "Calendar Month",
    "Contract Start Date",
    "Contract End Date",
    "Revenue Type",
    SUM("ARR Net USD") AS "ARR Net USD"
FROM Contracts_Combined
GROUP BY ALL;
--returns 3.2M rows



--------------
--PER LUCA
--------------

--For Infrastructure Sector (formerly Final Sector) you can join SSF_CONTRACT_LINE_MONTHLY to DIM_INFRASTRUCTURE_SECTOR (FK_INFRASTRUCTURE_SECTOR_KEY - SK_INFRASTRUCTURE_SECTOR_KEY). This dimension already has the relabeling you have in your query + SACS/MOSES pointing to Resources.

SET EOQ_MONTH = '202212';

SELECT
    'new contract history' AS source,
    COUNT(*) AS row_count,
    COUNT(DISTINCT FK_Snapshot_Date_Key) AS snapshot_dates
FROM PRESENTATION.MART.OBT_CONTRACT_HISTORY_LINE
WHERE LEFT(FK_Snapshot_Date_Key, 6) > $EOQ_MONTH

UNION ALL

SELECT
    'new accrual monthly' AS source,
    COUNT(*) AS row_count,
    COUNT(DISTINCT FK_Snapshot_Date_Key) AS snapshot_dates
FROM PRESENTATION.MART.SSF_CONTRACT_LINE_MONTHLY
WHERE LEFT(FK_Snapshot_Date_Key, 6) > $EOQ_MONTH;




-----Liz's rewrite

--RUN IN BIRD PROD (RETURNS 3.0M ROWS)
SET EOQ_MONTH = '202212';

WITH Contracts AS (
SELECT
        u."Ultimate Name",
        u."Ultimate ID",
        p."Brand",
        p."Acquisition Source",
        p."Domain",
        u."Ultimate Country",
        u."Industry",
        u."Industry Segment",
        u."Industry Short Code",
        u."Is DOT",
        LEFT(c.FK_Snapshot_Date_Key, 6) AS "Calendar Month",
        TO_DATE(c.FK_Contract_Start_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract Start Date",
        TO_DATE(c.FK_Contract_End_Date_Key::VARCHAR, 'YYYYMMDD') AS "Contract End Date",
        om."Revenue Type",
        dis."Infrastructure Sector",
        c."ARR Net USD"
    FROM PRESENTATION.MART.SSF_CONTRACT_LINE_MONTHLY c
    LEFT JOIN PRESENTATION.MART.DIM_PRODUCT p
        ON c.FK_Product_Key = p.SK_Product_Key
    LEFT JOIN PRESENTATION.MART.DIM_MATERIAL_ORIGINAL om
        ON c.FK_Material_Original_Key = om.SK_Material_Original_Key
    LEFT JOIN PRESENTATION.MART.DIM_ULTIMATE u
        ON c.FK_Ultimate_Key = u.SK_Ultimate_Key
    LEFT JOIN PRESENTATION.MART.DIM_INFRASTRUCTURE_SECTOR dis 
        ON c.FK_INFRASTRUCTURE_SECTOR_KEY = dis.sk_infrastructure_sector_key
    WHERE LEFT(c.FK_Snapshot_Date_Key, 6) > $EOQ_MONTH and LEFT(c.FK_Snapshot_Date_Key, 6) < '202605'
    )
SELECT
    "Ultimate Name",
    "Ultimate ID",
    "Brand",
    "Acquisition Source",
    "Domain",
    "Ultimate Country",
    "Industry",
    "Industry Segment",
    "Industry Short Code",
    "Infrastructure Sector",
    "Is DOT",
    "Calendar Month",
    "Contract Start Date",
    "Contract End Date",
    "Revenue Type",
    SUM("ARR Net USD") AS "ARR Net USD"
FROM Contracts
GROUP BY ALL;

--48,866,287,054