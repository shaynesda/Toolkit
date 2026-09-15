/********************************************************************
**  Name: Invoiced Revenue Recognition
**  Refactored Date: 7/24/2026 
**  
**  Tables Used:
**  BENTLEYPROD (DWH.PROD)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                                  SITES = OBT_SITE_EXPANDED
**                   LOOKUP_CURRENCYRATES = LOOKUP_CURRENCYRATES (FCT_FX_RATE_FISCAL_BUDGET?, DIM_CURRENCY?)
**                               INVOICES = OBT_INVOICE_LINE, FCT_INVOICE_LINE, DIM_MATERIAL_ORIGINAL
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
	Set Q1_start = '2026-03-01';
	Set Q1_end = '2026-03-31';
	Set Q2_start = '2026-04-01';
	Set Q2_end = '2026-06-30';
	Set Q3_start = '2026-07-01';
	Set Q3_end = '2026-09-30';
	Set Q4_start = '2026-10-01';
	Set Q4_end = '2026-12-31';
	Set Recast_start = '2024-12-31';
    
--select * from [dwh-db].DWH.dbo.Lookup_CurrencyRates where ratetype = 'x' and year = '2019'
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.BudgetRates AS
	SELECT dc."Currency ISO Code" as currency, dc.sk_currency_key,  
       DATE_PART(YEAR,"Fiscal Budget Year End Date") as year,
       1/fb."Fiscal Budget Rate Value" as rate
  FROM MART.FCT_FX_RATE_FISCAL_BUDGET fb
  JOIN MART.DIM_CURRENCY dc
    ON fb.fk_source_currency_key = dc.sk_currency_key
 WHERE "Is Current Rate" = 'TRUE'
   AND fb."Fiscal Budget Rate Value";

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCRMInvoicePrepselect AS
select distinct
       a4."Ultimate Name" as ultimatename1, 
       a4."Ultimate ID" as ultimateid, 
       dmo."Revenue Type" as Revenue_Type,
       a1."Invoice Create Date" as invoice_date,
       il."Invoice Line Billing Start Date" as Invoice_start_date,
       il."Invoice Line Billing End Date" as Invoice_end_date,
       a2.subrevenuetype as SubRevenueType,
       a2.revrecbasis as RevRecBasis,
       (a2.SUBREVENUETYPEALLOCPERC * a1."Invoice Line Net Amount USD" / a3.rate) as Invoice_Amt, 
       cast ('0' as float) Q1_PT, cast ('0' as float) Q2_PT, cast ('0' as float) Q3_PT, cast ('0' as float) Q4_PT,
       cast ('0' as float) Q1_OT, cast ('0' as float) Q2_OT, cast ('0' as float) Q3_OT, cast ('0' as float) Q4_OT,
       cast ('0' as float) Q1_ET, cast ('0' as float) Q2_ET, cast ('0' as float) Q3_ET, cast ('0' as float) Q4_ET,
       cast ('0' as float) Q1_Total, cast ('0' as float) Q2_Total, cast ('0' as float) Q3_Total, cast ('0' as float) Q4_Total
from MART.OBT_INVOICE_LINE a1  -- RevProExport a1 
join MART.FCT_INVOICE_LINE il on a1.fk_invoice_line_key = il.fk_invoice_line_key 
join MART.OBT_SITE_EXPANDED a4 on a1."FK_SITE_SHIP_TO_KEY" = a4.sk_site_key
join SANDBOX.FPANDA.BudgetRates a3 on a1.fk_transaction_currency_key = a3.sk_currency_key
left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
join SANDBOX.FPANDA.ZForecastRevTypesAllocations a2 on dmo."Revenue Type" = UPPER(a2.RevenueType)
where (case when il."Invoice Line Billing End Date" > a1."Invoice Create Date" then il."Invoice Line Billing End Date" else a1."Invoice Create Date" 
              end) > $Recast_start and (case when il."Invoice Line Billing End Date" > a1."Invoice Create Date" then il."Invoice Line Billing End Date" else a1."Invoice Create Date" end) > '20181231'             
and dmo."Revenue Type" <> 'RECURRING SERVICES';

/*
select a1.invoice_line_id, a4.ultimateid, a4.ultimatename1, a1.revenue_type, a1.invoice_date, a1.start_date as Invoice_start_date, a1.end_date as Invoice_end_date, a2.SubRevenueType, a2.RevRecBasis, 
(a2.SubRevenueTypeAllocPerc * a1.NET_PRICE / a3.rate) as Invoice_Amt, cast ('0' as float) Q1_PT, cast ('0' as float) Q2_PT, cast ('0' as float) Q3_PT, cast ('0' as float) Q4_PT,
cast ('0' as float) Q1_OT, cast ('0' as float) Q2_OT, cast ('0' as float) Q3_OT, cast ('0' as float) Q4_OT,
cast ('0' as float) Q1_ET, cast ('0' as float) Q2_ET, cast ('0' as float) Q3_ET, cast ('0' as float) Q4_ET,
cast ('0' as float) Q1_Total, cast ('0' as float) Q2_Total, cast ('0' as float) Q3_Total, cast ('0' as float) Q4_Total
join ZForecastRevTypesAllocations a2 on a1.REVENUE_TYPE = a2.RevenueType
join SANDBOX.FPANDA.BudgetRates a3 on a1.TRANSACTION_CURRENCY = a3.currency
left JOIN MART.OBT_SITE_EXPANDED a4 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
where (case when a1.END_DATE > a1. INVOICE_DATE then a1.END_DATE else a1.INVOICE_DATE end) > $Recast_start and (case when a1.END_DATE > a1. INVOICE_DATE then a1.END_DATE else a1.INVOICE_DATE end) < '20190101' 
--and not a1.revenue_type in ('recurring services','license','oem product') 
and not a1.REVENUE_TYPE in ('recurring services'); 
where (case when a1.END_DATE > a1. INVOICE_DATE 
              then a1.END_DATE else a1.INVOICE_DATE 
              end) > $Recast_start and (case when a1.END_DATE > a1. INVOICE_DATE then a1.END_DATE else a1.INVOICE_DATE end) > '20181231'
--and not a1.revenue_type in ('recurring services','license','oem product') 
and not a1.REVENUE_TYPE in ('recurring services'); */


--zjack_revproexport2 
--ZForecastRevTypesAllocations

-- Inactive invoice table old and new invoice table 

-- find replacement for RevProExport
-- ignore zjack_revproexport2

--ignore the follwing script
/*CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCRMInvoicePrepselect
select a1.invoice_line_id, a4.ultimateid, a4.ultimatename1, a1.revenue_type, a1.invoice_date, a1.start_date as Invoice_start_date, a1.end_date as Invoice_end_date, a2.SubRevenueType, a2. RevRecBasis, 
(a2.SubRevenueTypeAllocPerc * a1.NET_PRICE / a3.rate) as Invoice_Amt, cast ('' as float) Q1_PT, cast ('' as float) Q2_PT, cast ('' as float) Q3_PT, cast ('' as float) Q4_PT,
cast ('' as float) Q1_OT, cast ('' as float) Q2_OT, cast ('' as float) Q3_OT, cast ('' as float) Q4_OT,
cast ('' as float) Q1_ET, cast ('' as float) Q2_ET, cast ('' as float) Q3_ET, cast ('' as float) Q4_ET,
cast ('' as float) Q1_Total, cast ('' as float) Q2_Total, cast ('' as float) Q3_Total, cast ('' as float) Q4_Total
from zjack_revproexport2 a1 
join ZForecastRevTypesAllocations a2 on a1.REVENUE_TYPE = a2.RevenueType
join SANDBOX.FPANDA.BudgetRates a3 on a1.TRANSACTION_CURRENCY = a3.currency
left JOIN  MART.OBT_SITE_EXPANDED a4 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
where (case when a1.END_DATE > a1. INVOICE_DATE then a1.END_DATE else a1.INVOICE_DATE end) > $Recast_start and (case when a1.END_DATE > a1. INVOICE_DATE then a1.END_DATE else a1.INVOICE_DATE end) < '20190101' 
--and not a1.revenue_type in ('recurring services','license','oem product') 
and not a1.REVENUE_TYPE in ('recurring services'); */

--select max(invoice_date) from ZJACK_RevProExport2
--select top 10 * from revproexport where invoice_date > '20191231'

update SANDBOX.FPANDA.TempCRMInvoicePrepselect set RevRecBasis = 'over-time' where REVENUE_TYPE = 'VISAS';
--update ##TempCRMInvoicePrepselect set RevRecBasis = 'over-time' 

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q1_PT = Invoice_Amt where (case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) between $Q1_start and $Q1_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q2_PT = Invoice_Amt where (case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) between $Q2_start and $Q2_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q3_PT = Invoice_Amt where (case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) between $Q3_start and $Q3_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q4_PT = Invoice_Amt where (case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) between $Q4_start and $Q4_end and RevRecBasis = 'point-in-time';

---fix the spelling in the underlying table
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q1_ET = Invoice_Amt where (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) between $Q1_start and $Q1_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q2_ET = Invoice_Amt where (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) between $Q2_start and $Q2_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q3_ET = Invoice_Amt where (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) between $Q3_start and $Q3_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q4_ET = Invoice_Amt where (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) between $Q4_start and $Q4_end and RevRecBasis = 'End-of-term';

--case when invoice_start_date > $Q1_start then invoice_start_date else $Q1_start end,
--select * from ##TempCRMInvoicePrepselect where RevRecBasis = 'point-in-time'
--select * from ##TempCRMInvoicePrepselect where RevRecBasis = 'end off term' and Invoice_Amt > 0
--select * from RevTypesAllocations

--Update ##TempUnbundling set Q1_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,(min(invoice_end_date, '2020-03-01'), max(Invoice_Start_date, '2020-01-01')))+1)
--Update ##TempUnbundling set Q1_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $Q1_start then invoice_start_date else $Q1_start end,
--	case when invoice_end_date < $Q1_end then invoice_end_date else $Q1_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $Q1_end or Invoice_End_date < $Q1_start)

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q1_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * 
	(datediff(day,case when (case when invoice_start_date > invoice_date then Invoice_start_date else INVOICE_DATE end) > $Q1_start then invoice_start_date else $Q1_start end,
	case when (case when invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q1_end then invoice_end_date else $Q1_end end)+1)) where RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q1_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q1_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q1_OT = Invoice_Amt where INVOICE_DATE > Invoice_end_date and RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q1_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q1_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q2_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * 
	(datediff(day,case when (case when invoice_start_date > invoice_date then Invoice_start_date else INVOICE_DATE end) > $Q2_start then invoice_start_date else $Q2_start end,
	case when (case when invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q2_end then invoice_end_date else $Q2_end end)+1)) where RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q2_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q2_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q2_OT = Invoice_Amt where INVOICE_DATE > Invoice_end_date and RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q2_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q2_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q3_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * 
	(datediff(day,case when (case when invoice_start_date > invoice_date then Invoice_start_date else INVOICE_DATE end) > $Q3_start then invoice_start_date else $Q3_start end,
	case when (case when invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q3_end then invoice_end_date else $Q3_end end)+1)) where RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q3_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q3_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q3_OT = Invoice_Amt where INVOICE_DATE > Invoice_end_date and RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q3_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q3_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q4_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * 
	(datediff(day,case when (case when invoice_start_date > invoice_date then Invoice_start_date else INVOICE_DATE end) > $Q4_start then invoice_start_date else $Q4_start end,
	case when (case when invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q4_end then invoice_end_date else $Q4_end end)+1)) where RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q4_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q4_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q4_OT = Invoice_Amt where INVOICE_DATE > Invoice_end_date and RevRecBasis = 'over-time' 
	and not ((case when invoice_start_date > INVOICE_DATE then Invoice_start_date else INVOICE_DATE end) > $Q4_end 
	or (case when Invoice_end_date > INVOICE_DATE then Invoice_end_date else INVOICE_DATE end) < $Q4_start);

Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q1_Total = Q1_PT + Q1_OT + Q1_ET;
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q2_Total = Q2_PT + Q2_OT + Q2_ET;
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q3_Total = Q3_PT + Q3_OT + Q3_ET;
Update SANDBOX.FPANDA.TempCRMInvoicePrepselect set Q4_Total = Q4_PT + Q4_OT + Q4_ET;

select * from SANDBOX.FPANDA.TempCRMInvoicePrepselect where INVOICE_DATE between '2025-12-01' and '2025-12-31';
select * from SANDBOX.FPANDA.TempCRMInvoicePrepselect where INVOICE_DATE between '2024-12-26' and '2024-12-31';
select * from SANDBOX.FPANDA.TempCRMInvoicePrepselect where INVOICE_DATE between '2026-03-01' and '2026-03-31';

select revenue_type, sum(Q1_total) as Q1 , sum(Q2_total) as Q2 , sum(Q3_total) as Q3 , sum(Q4_total) as Q4 from SANDBOX.FPANDA.TempCRMInvoicePrepselect group by revenue_type

-------------ANYTHING BELOW THIS LINE IS ADDITIONAL ANALYSIS AND NOT MIMIC'ING RevPro Recognition (timing and ubundling)----------------

select max(INVOICE_DATE) from SANDBOX.FPANDA.RevProExport

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep AS
select ultimateid, ultimatename1, cast('' as varchar) CustCategory, sum(Q1_Total) CY_Rev, sum(Q2_Total) PY_Rev
from SANDBOX.FPANDA.TempCRMInvoicePrepselect
group by ultimateid, ultimatename1;

-----check to see what to do with negative PY revenue - included in existing for now
update SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep set CustCategory = 'Existing' where CY_Rev > 0 and not PY_Rev = 0;
update SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep set CustCategory = 'New' where PY_Rev = 0 and CY_Rev > 0;
update SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep set CustCategory = 'Lost' where PY_Rev > 0 and not CY_Rev > 0;
update SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep set CustCategory = 'Lost' where not PY_Rev > 0 and CY_Rev = 0;
update SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep set CustCategory = 'Lost' where PY_Rev = 0 and not CY_Rev > 0;

select CustCategory, sum(CY_Rev) CY_Rev, sum(PY_Rev) PY_Rev, count(ultimateID) UltimateCount from SANDBOX.FPANDA.TempCRMInvoiceRetentionCalcPrep group by CustCategory


----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
