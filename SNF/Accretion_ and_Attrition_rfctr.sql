/********************************************************************
**  Name: Accretion and Attrition
**  Refactored Date: 7/16/2026 
**  
**  Tables Used:
**  BENTLEYPROD (DWH.PROD)  ->  BIRD_PROD (PRESENTATION.MART,
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

USE SCHEMA MART;

-- VAR's
SET ARR_START_DATE = 202412; 
SET ARR_END_DATE = 202503; 
SET WELCOME_BACK = 202306;

/*DECLARE @ARR_StartDate float; 	
	Set @ARR_StartDate = '202412'
DECLARE @ARR_EndDate float; 	
	Set @ARR_EndDate = '202503'
DECLARE @Welcome_Back float; 	
	Set @Welcome_Back = '202306' */

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsHistory AS  
  select   
    a1."FK_SITE_SHIP_TO_KEY" as Ship_To, 
    to_char(a1."Snapshot Date",'YYYYMM') as CalendarMonth,
    a1."Brand" as Brand,
    a1."Contract Start Date" as header_start_date,
    a1."Contract End Date" as header_end_date,
    a1."ARR Net USD" as ARR_USD_NET,
    dmo."Revenue Type" as Revenue_type,
    dmo."Original Material ID" as Original_Material_Id,
    dmo."Original Material Description" as OriginalMaterial
    from MART.SSF_CONTRACT_LINE_MONTHLY a1 
    join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
    left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
   where to_char(a1."Snapshot Date",'YYYYMM') in ($ARR_START_DATE, $ARR_END_DATE);
	
/*DROP TABLE IF EXISTS ##TempContractsHistory	
select * into ##TempContractsHistory from DWH.PROD.Contracts_history where calendarmonth in (@ARR_StartDate,@ARR_EndDate) */
	
/*INSERT into ##TempContractsHistory	
select * from DWAPPS.[dbo].[Contracts_Consumption_Accrual] where calendarmonth in (@ARR_StartDate, @ARR_EndDate)*/
	
/*DROP TABLE IF EXISTS ##TempAcquisitionExclude	
SELECT a4.Acquisition_Source, MIN(a1.CalendarMonth) CalendarMonth, CAST(NULL AS VARCHAR(4)) CalendarYear	
INTO ##TempAcquisitionExclude FROM DWH.PROD.Contracts_History a1	
JOIN DWH.PROD.Sites a2 ON a1.Ship_To = a2.SiteID	
JOIN DWH.PROD.ProductAttributes a3 ON a1.ProductID = a3.ProductID	
JOIN DWH.PROD.Materials a4 ON a1.OriginalMaterial = a4.Material	
WHERE a1.ARR_USD_Net <> 0	
GROUP BY a4.Acquisition_Source	
HAVING RIGHT(MIN(a1.CalendarMonth),2) = 12	
ORDER BY MIN(a1.CalendarMonth)	*/

UPDATE ##TempAcquisitionExclude SET CalendarYear = LEFT(CalendarMonth,4);
	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempAcquisitionExclude AS
select a2."Acquisition Source" as Acquistion_Source,
       MIN(to_char(a1."Snapshot Date",'YYYYMM')) as CalendarMonth,
       CAST(NULL AS VARCHAR(4)) CalendarYear
     from MART.SSF_CONTRACT_LINE_MONTHLY a1 
     join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
     join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
where a1."ARR Net USD" <> 0
group by a2."Acquisition Source"
having right(min(to_char(a1."Snapshot Date",'YYYYMM')),2) = 12;
    
UPDATE SANDBOX.FPANDA.TempAcquisitionExclude SET CalendarYear = LEFT(CalendarMonth,4);
    
/* DROP TABLE IF EXISTS ##TempAcquisitions	
select *, case when YearMonthAcquired > YearMonthARR then YearMonthAcquired ELSE YearMonthARR END as LatestDateAcq into ##TempAcquisitions 	
from dbo.Lookup_Acquisitions where (case when YearMonthAcquired > YearMonthARR then YearMonthAcquired ELSE YearMonthARR END) > @ARR_StartDate and YearMonthAcquired < @ARR_EndDate; */	

-- Can EDW_TABLES.LOOKUP_ACQUISITIONS table be used in the new world?

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempAcquisitions AS
select *, case when YEARMONTH_ACQUIRED > YEARMONTH_ARR then
YEARMONTH_ACQUIRED else YEARMONTH_ARR end as LatestDateAcq
from EDW_TABLES.LOOKUP_ACQUISITIONS
where (case when YEARMONTH_ACQUIRED > YEARMONTH_ARR then YEARMONTH_ACQUIRED else YEARMONTH_ARR end) > $ARR_START_DATE and YEARMONTH_ACQUIRED < $ARR_END_DATE;
   
--select * from ##TempAcquisitions	

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaseline AS
select a3."Ultimate Name" as ultimateName1, 
       a3."Ultimate ID" as ultimateID, 
       dmo."Revenue Type" as Revenue_Type, 
       a1."Brand" as Brand,
       a2."Acquisition Source" as acquisition_source, 
       dmo."Original Material Description" as OriginalMaterial, 
       sum(a1."Quantity") as SumQuantityBaseline, 
       sum(a1."ARR Gross USD") as ARRGrossBaseline, 
       sum(a1."ARR Net USD") as ARRBaseline, 
       cast('0' as float) SumQuantityCurrent, 
       cast('0' as float) ARRCurrentGross,	
       cast('0' as float) ARRCurrent, 
       cast(' ' as varchar) CustCategory,	
       cast(' ' as varchar) BrandCategory, 
       cast(' ' as varchar) CountryCategory, 
       cast('0' as numeric ) BrandCount, 
       cast(' ' as varchar) ARRBand 
 from MART.SSF_CONTRACT_LINE_MONTHLY a1 
      join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
      join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
 left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
 left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
 left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
where to_char(a1."Snapshot Date",'YYYYMM') = $ARR_START_DATE
--and not a3."Country ISO" in ('CN','HK','TW','MO','MN','RU') 	
--and a3."Country ISO" in ('CN','HK','TW','MO','MN') 
--and dmo."Revenue Type" not like '%SQ%' and not a2."Acquisition Source" = 'PLS' and dmo."Revenue Type" not like '%Virt%' and not a1."Brand" = 'OpenTower'  	
--and not dmo."Revenue Type" = 'E365' --and not a2."Acquisition Source" = 'Seequent'
  and dmo."Revenue Type" like '%VIRT%'
  and not dm."Display Material" = '2649'
--and not a2."Domain" = 'SEEQUENT' and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a3."Ultimate Commercial Program" = 'E365' and a3."Ultimate Account Size" = 'SMB' and not dm."Display Material" = '2649'	
--and a2."Domain" = 'PLS'
--and not a2."Domain" in ('Seequent','PLS')
--and not a1."Brand" in ('OpenTower')
--and a2."Domain" = 'Seequent'
 group by a3."Ultimate Name", a3."Ultimate ID", a1."Brand", a2."Acquisition Source", dmo."Original Material Description", dmo."Revenue Type";


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaseline AS
select a3."Ultimate Name" as ultimateName1, 
       a3."Ultimate ID" as ultimateID, 
       dmo."Revenue Type" as Revenue_Type, 
       a1."Brand" as Brand,
       a2."Acquisition Source" as acquisition_source, 
       dmo."Original Material Description" as OriginalMaterial, 
       sum(a1."Quantity") as SumQuantityBaseline, 
       sum(a1."ARR Gross USD") as ARRGrossBaseline, 
       sum(a1."ARR Net USD") as ARRBaseline, 
       cast('0' as float) SumQuantityCurrent, 
       cast('0' as float) ARRCurrentGross,	
       cast('0' as float) ARRCurrent, 
       cast(' ' as varchar) CustCategory,	
       cast(' ' as varchar) BrandCategory, 
       cast(' ' as varchar) CountryCategory, 
       cast('0' as numeric ) BrandCount, 
       cast(' ' as varchar) ARRBand 
 from MART.SSF_CONTRACT_LINE_MONTHLY a1 
      join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
      join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
 left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
 left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
 left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
where to_char(a1."Snapshot Date",'YYYYMM') = $ARR_START_DATE
--and not a3."Country ISO" in ('CN','HK','TW','MO','MN','RU') 	
--and a3."Country ISO" in ('CN','HK','TW','MO','MN') 
--and dmo."Revenue Type" not like '%SQ%' and not a2."Acquisition Source" = 'PLS' and dmo."Revenue Type" not like '%Virt%' and not a1."Brand" = 'OpenTower'  	
--and not dmo."Revenue Type" = 'E365' --and not a2."Acquisition Source" = 'Seequent'
  and dmo."Revenue Type" like '%VIRT%'
  and not dm."Display Material" = '2649'
--and not a2."Domain" = 'SEEQUENT' and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a3."Ultimate Commercial Program" = 'E365' and a3."Ultimate Account Size" = 'SMB' and not dm."Display Material" = '2649'	
--and a2."Domain" = 'PLS'
--and not a2."Domain" in ('Seequent','PLS')
--and not a1."Brand" in ('OpenTower')
--and a2."Domain" = 'Seequent'
 group by a3."Ultimate Name", a3."Ultimate ID", a1."Brand", a2."Acquisition Source", dmo."Original Material Description", dmo."Revenue Type";


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaseline AS
select a3."Ultimate Name" as ultimateName1, 
       a3."Ultimate ID" as ultimateID, 
       dmo."Revenue Type" as Revenue_Type, 
       a1."Brand" as Brand,
       a2."Acquisition Source" as acquisition_source, 
       dmo."Original Material Description" as OriginalMaterial, 
       sum(a1."Quantity") as SumQuantityBaseline, 
       sum(a1."ARR Gross USD") as ARRGrossBaseline, 
       sum(a1."ARR Net USD") as ARRBaseline, 
       cast('0' as float) SumQuantityCurrent, 
       cast('0' as float) ARRCurrentGross,	
       cast('0' as float) ARRCurrent, 
       cast(' ' as varchar) CustCategory,	
       cast(' ' as varchar) BrandCategory, 
       cast(' ' as varchar) CountryCategory, 
       cast('0' as numeric ) BrandCount, 
       cast(' ' as varchar) ARRBand 
 from MART.SSF_CONTRACT_LINE_MONTHLY a1 
      join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
      join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
 left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
 left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
 left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
where to_char(a1."Snapshot Date",'YYYYMM') = $ARR_START_DATE
--and not a3."Country ISO" in ('CN','HK','TW','MO','MN','RU') 	
--and a3."Country ISO" in ('CN','HK','TW','MO','MN') 
--and dmo."Revenue Type" not like '%SQ%' and not a2."Acquisition Source" = 'PLS' and dmo."Revenue Type" not like '%Virt%' and not a1."Brand" = 'OpenTower'  	
--and not dmo."Revenue Type" = 'E365' --and not a2."Acquisition Source" = 'Seequent'
  and dmo."Revenue Type" like '%VIRT%'
  and not dm."Display Material" = '2649'
--and not a2."Domain" = 'SEEQUENT' and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a3."Ultimate Commercial Program" = 'E365' and a3."Ultimate Account Size" = 'SMB' and not dm."Display Material" = '2649'	
--and a2."Domain" = 'PLS'
--and not a2."Domain" in ('Seequent','PLS')
--and not a1."Brand" in ('OpenTower')
--and a2."Domain" = 'Seequent'
 group by a3."Ultimate Name", a3."Ultimate ID", a1."Brand", a2."Acquisition Source", dmo."Original Material Description", dmo."Revenue Type";

	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRCurrent AS
select a3."Ultimate Name" as ultimateName1, 
       a3."Ultimate ID" as ultimateID, 
       dmo."Revenue Type" as Revenue_Type, 
       a1."Brand" as Brand,
       a2."Acquisition Source" as acquisition_source, 
       dmo."Original Material Description" as OriginalMaterial, 
       sum(a1."Quantity") as SumQuantityBaseline, 
       sum(a1."ARR Gross USD") as ARRGrossBaseline, 
       sum(a1."ARR Net USD") as ARRBaseline, 
       cast('0' as float) SumQuantityCurrent, 
       cast('0' as float) ARRCurrentGross,	
       cast('0' as float) ARRCurrent, 
       cast(' ' as varchar) CustCategory,	
       cast(' ' as varchar) BrandCategory, 
       cast(' ' as varchar) CountryCategory, 
       cast('0' as numeric ) BrandCount, 
       cast(' ' as varchar) ARRBand 
 from MART.SSF_CONTRACT_LINE_MONTHLY a1 
      join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key
      join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
 left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
 left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
 left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
where to_char(a1."Snapshot Date",'YYYYMM') = $ARR_START_DATE
--and not a3."Country ISO" in ('CN','HK','TW','MO','MN','RU') 	
--and a3."Country ISO" in ('CN','HK','TW','MO','MN') 
--and dmo."Revenue Type" not like '%SQ%' and not a2."Acquisition Source" = 'PLS' and dmo."Revenue Type" not like '%Virt%' and not a1."Brand" = 'OpenTower'  	
--and not dmo."Revenue Type" = 'E365' --and not a2."Acquisition Source" = 'Seequent'
  and dmo."Revenue Type" like '%VIRT%'
  and not dm."Display Material" = '2649'
--and not a2."Domain" = 'SEEQUENT' and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a2."Domain" = 'PLS' and not a1."Brand" = 'EasyPower'	
--and not a3."Ultimate Commercial Program" = 'E365' and a3."Ultimate Account Size" = 'SMB' and not dm."Display Material" = '2649'	
--and a2."Domain" = 'PLS'
--and not a2."Domain" in ('Seequent','PLS')
--and not a1."Brand" in ('OpenTower')
--and a2."Domain" = 'Seequent'
 group by a3."Ultimate Name", a3."Ultimate ID", a1."Brand", a2."Acquisition Source", dmo."Original Material Description", dmo."Revenue Type";

Insert into SANDBOX.FPANDA.TempContractsARRBaseline	
select * from SANDBOX.FPANDA.TempContractsARRCurrent;	
	
--select UltimateID, Brand, Acquisition_Source, Revenue_Type, OriginalMaterial, sum(SumQuantityBaseline) QuantityBaseline, sum(ARRGrossBaseline) ARRGrossBaseline, sum(ARRBaseline) ARRBaseline, sum(SumQuantityCurrent) QuantityCurrent, sum(ARRCurrentGross) ARRCurrentGross, 	
--sum(ARRCurrent) ARRCurrent from ##TempContractsARRBaseline group by UltimateID, Brand, Acquisition_Source, Revenue_Type, OriginalMaterial	
	
update SANDBOX.FPANDA.TempContractsARRBaseline set Brand = 'AssetWise' where Brand like '%AssetWise%';	
	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRRetention AS	
select ultimateName1, ultimateID, sum(ARRBaseline) as ARRBaseline, sum(ARRCurrent) as ARRCurrent, CustCategory, cast('' as varchar(12)) as ARRBand	
from SANDBOX.FPANDA.TempContractsARRBaseline group by ultimateName1, ultimateID, CustCategory;	
	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsE365ConversionPrep AS
select UltimateID, Revenue_Type, sum(ARRCurrent) ARRCurrent, sum(ARRBaseline) ARRBaseline 
  from SANDBOX.FPANDA.TempContractsARRBaseline 
 group by UltimateID, Revenue_Type;
	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsE365Conversion AS
select ultimateID, Revenue_Type, sum(ARRCurrent) ARRCurrent, sum(ARRBaseline) ARRBaseline	
from SANDBOX.FPANDA.TempContractsE365ConversionPrep	
where Revenue_Type = 'E365' and ARRCurrent > 100 and ARRBaseline = 0	
group by ultimateID, Revenue_Type;
	
--select * from ##TempContractsARRBaseline where UltimateID = '1000139694'	
	
--select * from ##TempContractsE365Conversion	
	
update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'Existing Account' where ARRBaseline > 0 and ARRCurrent > 0;

update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'E365Conversion' 
 where UltimateID in (select distinct UltimateID from SANDBOX.FPANDA.TempContractsE365Conversion);	

update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'New Account' where ARRBaseline = 0 and ARRCurrent > 0;

update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'Lost Account' where ARRBaseline > 0 and ARRCurrent = 0;	
--update ##TempContractsARRRetention set CustCategory = 'Reduce>50k' where CustCategory = 'Existing Account' and (ARRBaseline - ARRCurrent) > 49999	
--update ##TempContractsARRRetention set CustCategory = 'Increase>50k' where CustCategory = 'Existing Account' and (ARRCurrent - ARRBaseline ) > 49999	

update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'Existing Account - Attrition' where CustCategory = 'Existing Account' and ARRBaseline > ARRCurrent;

update SANDBOX.FPANDA.TempContractsARRRetention set CustCategory = 'Existing Account - Accretion' where CustCategory = 'Existing Account' and ARRBaseline < ARRCurrent;	
--update ##TempContractsARRRetention set CustCategory = 'E365Conversion' where UltimateID in (select distinct UltimateID from ##TempContractsE365Conversion)	
	
	
update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '>$1M' where ARRBaseline > 1000000;

update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '<$1M' where ARRBaseline < 1000000;	

update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '<$500k' where ARRBaseline < 500000;	

update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '<$250k' where ARRBaseline < 250000;	

update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '<$100k' where ARRBaseline < 100000;	

update SANDBOX.FPANDA.TempContractsARRRetention set ARRBand = '<$50k' where ARRBaseline < 50000;
	
	
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRRetentionDomain AS	
select a1.ultimateName1, a1.ultimateID, a1.brand, sum(a1.ARRBaseline) as ARRBaseline, sum(a1.ARRCurrent) as ARRCurrent, a1.CustCategory, a1.BrandCategory,	
a2.BrandCount	
from SANDBOX.FPANDA.TempContractsARRBaseline a1	
left join (select ultimateID, count(distinct brand) as BrandCount 
             from SANDBOX.FPANDA.TempContractsARRBaseline 
            group by ultimateid) a2 on a1.UltimateID = a2.UltimateID	
group by a1.ultimateName1, a1.ultimateID, a1.brand, a1.BrandCategory, a1.CustCategory, a2.BrandCount;	
	
update SANDBOX.FPANDA.TempContractsARRRetentionDomain set BrandCategory = 'Existing Brand' where ARRBaseline > 0 and ARRCurrent > 0;
update SANDBOX.FPANDA.TempContractsARRRetentionDomain set BrandCategory = 'New Brand' where ARRBaseline = 0 and ARRCurrent > 0;	
update SANDBOX.FPANDA.TempContractsARRRetentionDomain set BrandCategory = 'Lost Brand' where ARRBaseline > 0 and ARRCurrent = 0;	
	
--DROP TABLE IF EXISTS ##TempContractsARRRetentionCountry	
--select ultimateName1, ultimateID, CountryIso, sum(ARRBaseline) as ARRBaseline, sum(ARRCurrent) as ARRCurrent, CustCategory, BrandCategory, CountryCategory into ##TempContractsARRRetentionCountry 	
--from ##TempContractsARRBaseline group by ultimateName1, ultimateID, CountryIso, BrandCategory, CustCategory, CountryCategory	
	
--update ##TempContractsARRRetentionCountry set CountryCategory = 'Existing Country' where ARRBaseline > 0 and ARRCurrent > 0	
--update ##TempContractsARRRetentionCountry set CountryCategory = 'New Country' where ARRBaseline = 0 and ARRCurrent > 0	
--update ##TempContractsARRRetentionCountry set CountryCategory = 'Lost Country' where ARRBaseline > 0 and ARRCurrent = 0	
	
update SANDBOX.FPANDA.TempContractsARRBaseline 
   set CUSTCATEGORY = a2.CUSTCATEGORY	
from SANDBOX.FPANDA.TempContractsARRBaseline a1 
 join SANDBOX.FPANDA.TempContractsARRRetention a2 on a1.ultimateID = a2.ultimateid;
    
update SANDBOX.FPANDA.TempContractsARRBaseline set BRANDCATEGORY = a2.BRANDCATEGORY	
from SANDBOX.FPANDA.TempContractsARRBaseline a1 join SANDBOX.FPANDA.TempContractsARRRetentionDomain a2 on a1.ultimateID = a2.ultimateid and a1.brand = a2.brand;	

--from ##TempContractsARRBaseline a1 join ##TempContractsARRRetentionCountry a2 on a1.ultimateID = a2.ultimateid and a1.countryiso = a2.countryiso	
	
update SANDBOX.FPANDA.TempContractsARRBaseline set ARRBand = a2.ARRBand	
from SANDBOX.FPANDA.TempContractsARRBaseline a1 join SANDBOX.FPANDA.TempContractsARRRetention a2 on a1.ultimateID = a2.ultimateid;	
	
update SANDBOX.FPANDA.TempContractsARRBaseline set BrandCount = a2.BrandCount	
from SANDBOX.FPANDA.TempContractsARRBaseline a1 join SANDBOX.FPANDA.TempContractsARRRetentionDomain a2 on a1.ultimateID = a2.ultimateid and a1.brand = a2.brand;	
	
update SANDBOX.FPANDA.TempContractsARRBaseline 
set CustCategory = 'Acquisition' 
where ACQUISITION_SOURCE in (select distinct ACQUISITION_SOURCE from SANDBOX.FPANDA.TempAcquisitions);	

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaselineV2 AS
select a1.*, a2."Ultimate Account Size", a3.Domain, cast('SELECT/Other' as varchar(20))as CommercialPaper, cast('Core' as varchar(20))as Segment, a1.CustCategory as CustCatV2 
from SANDBOX.FPANDA.TempContractsARRBaseline a1
left join MART.OBT_SITE_EXPANDED a2 on a1.ULTIMATEID = a2."Ultimate ID"
left join (select distinct "Brand" as Brand, "Domain" as Domain from MART.DIM_PRODUCT) a3 on a1.BRAND = a3.Brand;


update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'AA' where brand in ('OpenPaths','OpenTower','iTwin IoT','eagle.io','OpenPaths Patterns','LEGION','Blyncsy','VDV','AssetWise 4D Analytics');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'PLS' where domain in ('PLS');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'SQ' where revenue_type in ('SQ Subscription','SQ Maintenance','SQ SAAS');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'Bentley Store' where revenue_type in ('Virtuoso Subscription','Virtuoso SAAS');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'E365' where revenue_type in ('E365');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set CommercialPaper = 'E365 Conversion' where CustCategory = 'E365Conversion';

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set Segment = 'AA' where brand in ('OpenPaths','OpenTower','iTwin IoT','eagle.io','OpenPaths Patterns','LEGION','Blyncsy','VDV','AssetWise 4D Analytics');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set Segment = 'PLS' where domain in ('PLS');

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set Segment = 'SQ' where Domain in ('Seequent');
--update ##TempContractsARRBaselineV2 set Segment = 'Bentley Store' where revenue_type in ('Virtuoso Subscription','Virtuoso SAAS')
--update ##TempContractsARRBaselineV2 set Segment = 'E365' where revenue_type in ('E365')

update SANDBOX.FPANDA.TempContractsARRBaselineV2 set Segment = 'E365 Conversion' where CustCategory = 'E365Conversion';

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempMinARR AS
select a2."Ultimate ID" as UltimateID, max(to_char(a1."Snapshot Date",'YYYYMM')) MaxCalendarMonth 
from MART.SSF_CONTRACT_LINE_MONTHLY a1
left join MART.OBT_SITE_EXPANDED a2 on a1."FK_SITE_SHIP_TO_KEY" = a2.sk_site_key
where to_char(a1."Snapshot Date",'YYYYMM') < $ARR_START_DATE group by a2."Ultimate ID" having sum(a1."ARR Net USD") > 0;


update SANDBOX.FPANDA.TempContractsARRBaselineV2 
   set CustCatV2 = 'New-WelcomeBack' 
 where UltimateID in (select distinct ultimateid from SANDBOX.FPANDA.TempMinARR where MaxCalendarMonth > $WELCOME_BACK)     and CustCategory = 'New Account';

-----------------VIRT ARR ROLLFORWARD

-----------ONLY RUN FOR FULL RUN-------------
--DROP TABLE IF EXISTS ##TempContractsARRBaselineV2ALL
--select * into ##TempContractsARRBaselineV2ALL from ##TempContractsARRBaselineV2 

--RUN BELOW AFTER FULL RUN IN ABOVE TEMP TABLE AND THEN FULL ABOVE SCRIPT FOR VIRT ONLY

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaselineV2ALL AS
(select * from SANDBOX.FPANDA.TempContractsARRBaselineV2);


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT AS
select a1.*, a2.CustCategory as OverallCustCat, a2.CustCatV2 as OverallCutCat2, a3.BrandCategory as OverallBrandCat, cast('' as varchar(40)) as VirtCustCat, cast('' as varchar(40)) as VirtBrandCat
 from SANDBOX.FPANDA.TempContractsARRBaselineV2 a1
left join (select distinct ultimateID, CustCategory, CustCatV2 from SANDBOX.FPANDA.TempContractsARRBaselineV2ALL) a2 on a1.ultimateID = a2.ultimateid
left join (select distinct ultimateID, brand, BrandCategory from SANDBOX.FPANDA.TempContractsARRBaselineV2ALL) a3 on a1.ultimateID = a3.ultimateid and a1.brand = a3.brand;

Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'New Account' where OverallCustCat = 'New Account';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set CustCatV2 = 'New Account Returning' where OverallCustCat = 'New-WelcomeBack';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'New Account' where OverallCustCat like '%Existing%' and CustCategory = 'New Account' and OverallBrandCat = 'New Brand';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Lost Account' where OverallCustCat = 'Lost Account';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Lost Account' where OverallCustCat like '%Existing%' and CustCategory = 'Lost Account' and OverallBrandCat = 'Lost Brand';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Transfer In' where OverallCustCat like '%Existing%' and OverallBrandCat like '%Existing%' and CustCategory = 'New Account';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Transfer Out' where OverallCustCat like '%Existing%' and OverallBrandCat like '%Existing%' and CustCategory = 'Lost Account';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Transfer Out' where OverallCustCat = 'E365Conversion';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Existing Account - Accretion' where CustCategory = 'Existing Account - Accretion';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Existing Account - Attrition' where CustCategory = 'Existing Account - Attrition';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'Existing Account' where CustCategory = 'Existing Account';
Update SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT set VirtCustCat = 'CHECK' where CustCategory = '';

select distinct OverallCustCat from SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT;

select * from SANDBOX.FPANDA.TempContractsARRBaselineV2VIRT;

