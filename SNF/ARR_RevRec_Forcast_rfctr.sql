/********************************************************************
**  Name: ARR Rev Rec Forcast
**  Refactored Date: 7/20/2026 
**  
**  Tables Used:
**  BENTLEYPROD (DWH.PROD)  ->  BIRD_PROD (PRESENTATION.MART,
**                                                 PRESENTATION.EDW_TABLES)
**                               PRODUCTS = DIM_PRODUCT
**                                  SITES = OBT_SITE_EXPANDED
**                      CONTRACTS_HISTORY = SSF_CONTRACT_LINE_MONTHLY, DIM_CONTRACT, 
**                                          DIM_MATERIAL, DIM_MATERIAL_ORIGINAL
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
	Set Q1_start = '2025-04-01';
	Set Q1_end = '2025-06-30';
	Set Q2_start = '2025-07-01';
	Set Q2_end = '2025-09-30';
	Set Q3_start = '2025-10-01';
	Set Q3_end = '2025-12-31';
	Set Q4_start = '2026-01-01';
	Set Q4_end = '2026-03-31';
	Set ARR_Date = '202503';
	Set Forecast_End = '2027';
	Set Forecast_EndV = '2027';
	Set Forecast_start = '2023-12-31';
	Set PYRev_start = '2023-01-01';
	Set PYRev_end = '2025-03-31';


/*DROP TABLE IF EXISTS ##TempContractsHistoryCombined
select * into ##TempContractsHistoryCombined from [dwh-db].DWH.PROD.Contracts_history where calendarmonth = $ARR_Date */

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsHistoryCombined AS
select a3."Ultimate Name" as ultimateName1, 
       a3."Ultimate ID" as ultimateID, 
       dmo."Revenue Type" as Revenue_Type, 
       a1."Brand" as Brand,
       a2."Acquisition Source" as acquisition_source, 
       dmo."Original Material Description" as OriginalMaterial, 
       a1."Quantity" as Quantity, 
       a1."ARR Gross USD", 
       a1."ARR Net USD",
        case when a1."Source" = 'Workday Invoices' then a1."Non Contract Invoice Number"
            else dc."Contract ID"
        end transaction_num,
       case when a1."Source" = 'Workday Invoices' then to_char(a1."Non Contract Invoice Line Number")
            else to_char(a1."Contract Line Number")
        end line_num, 
       case when a1."Source" = 'Workday Invoices' then to_char(a1."Non Contract Invoice Number")||'-'||to_char(a1."Non Contract Invoice Line Number")
            else to_char(dc."Contract ID")||'-'||to_char(a1."Contract Line Number")
        end Transaction_Line_ID,
       case when a1."Source" = 'Workday Invoices' then to_char(a1."Non Contract Invoice Number")||'-'||to_char(a1."Non Contract Invoice Line Number")||'-'||to_char(dm."Material ID")
            else to_char(dc."Contract ID")||'-'||to_char(a1."Contract Line Number")||'-'||to_char(dm."Material ID")
        end Trans_Line_Mat_ID,
       a1."Contract End Date" cancellation_effective_date,
       a1."Source",
       a1."Contract Start Date" as header_start_date,
       a1."Contract End Date" as header_end_date,
       a1."Snapshot Date" as create_date,
       a1.fk_site_ship_to_key,
       a1.fk_site_sold_to_key,
       a1.fk_product_key,
       a1.fk_material_original_key,
       a1.fk_material_key,
       a3."Site ID" as ship_to,
       a3."Ultimate ID" as sold_to,
       dc."Billing Frequency" as billing_period,
       to_char(a1."Snapshot Date",'YYYY')||lpad(QUARTER(a1."Snapshot Date"),2,0) as CalendarQuarter,
       to_char(a1."Snapshot Date",'YYYYMM') as CalendarMonth
from MART.SSF_CONTRACT_LINE_MONTHLY a1 
join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
left join MART.DIM_CONTRACT dc on a1.fk_contract_key = dc.sk_contract_key     
left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
where to_char(a1."Snapshot Date",'YYYYMM') = $ARR_Date;


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempContractsARR AS
select a1.transaction_num,
       a1.line_num,    
       a1.Transaction_Line_ID, 
       a1.Trans_Line_Mat_ID, 
       a1.create_date as createdate, 
       a1.cancellation_effective_date, 
       a1.header_start_date, 
       a1.header_end_date, 
       cast(a1.header_end_date as date) as Header_End_Date_Real, 
       cast ('' as varchar) updated_header_end_date, 
       CAST(365 as FLOAT) Billing_Term_Days, 
       cast (0 as float) Invoices_to_go, 
       a1.sold_to, 
       a1.ship_to, 
       a1.Revenue_Type as revenue_type, 
       a1.billing_period, 
       a1."ARR Net USD" as ARR_USD_NET, 
       a1.OriginalMaterial, 
       a1.CalendarMonth, 
       a1.CalendarQuarter, 
       a2."Product ID" as ProductID, 
       a1.ultimateID
  from SANDBOX.FPANDA.TempContractsHistoryCombined a1 
       join MART.OBT_SITE_EXPANDED a3 on a1."FK_SITE_SHIP_TO_KEY" = a3.sk_site_key
  left join MART.DIM_PRODUCT a2 on a1.fk_product_key = a2.sk_product_key
  left join MART.DIM_MATERIAL_ORIGINAL dmo on a1.fk_material_original_key = dmo.sk_material_original_key
  left join MART.DIM_MATERIAL dm on a1.fk_material_key = dm.sk_material_key
 where a1.Revenue_Type not ilike '%RECURRING SERVICES%' 
   and TO_VARCHAR(a1.create_date, 'YYYYMM') = $ARR_Date;  



CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempUpdatingBillingTerm AS
select * from SANDBOX.FPANDA.TempContractsARR;

select distinct BILLING_PERIOD from SANDBOX.FPANDA.TempUpdatingBillingTerm;

-- BILLING_PERIOD is not mapped the same 'ZBILL0006?'

--Billing Term Days to Quarterly = 91.25, monthly = 30.42 semi Biannual = 182, Annual = 365, Biennial = 730, Triennial = 1095 

--adjusted  from 183 to 182 - 183 converts to 7 months - 182 converts to 6 months - 3.29
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 182 where billing_period = 'Biannual';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 365 where billing_period = 'Annual'; 
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 91.25 where billing_period = 'Quarterly';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 30.42 where billing_period = 'Monthly';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 730 where billing_period = 'Biennial';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 1095 where billing_period = 'Triennial'; 
---added 3.27 to plug VISA and E365 billing term to 91.25
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 91.25 where revenue_type = 'VISAS';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 91.25 where revenue_type = 'E365';
Update SANDBOX.FPANDA.TempUpdatingBillingTerm set Billing_Term_Days = 365 where revenue_type like '%virtuoso%';


update SANDBOX.FPANDA.TempUpdatingBillingTerm set updated_header_end_date = ($Forecast_EndV || RIGHT(header_end_date,6)) where left(header_end_date,4) < $Forecast_End;
update SANDBOX.FPANDA.TempUpdatingBillingTerm set updated_header_end_date = header_end_date where not left(header_end_date,4) < $Forecast_End;

--update ##TempUpdatingBillingTerm set updated_header_end_date = DATEFROMPARTS (left(updated_header_end_date,4), substring(updated_header_end_date,5,2), right(updated_header_end_date,2)) where not updated_header_end_date = '20220229'

update SANDBOX.FPANDA.TempUpdatingBillingTerm 
   set updated_header_end_date = left(updated_header_end_date,4)||'-'||substr(updated_header_end_date,6,2)||'-'||right(updated_header_end_date,2) 
  where not updated_header_end_date = '2026-02-29';

update SANDBOX.FPANDA.TempUpdatingBillingTerm set updated_header_end_date = '2025-02-28' where updated_header_end_date = '20260229';
---added 3.29 to adjust for billing terms over 1 year - can clean up to make the dates better --it's losing a day over lear year - can be harmful when on a month/quarter end

update SANDBOX.FPANDA.TempUpdatingBillingTerm set updated_header_end_date = DATEADD(dd,730,date_from_parts(left(header_end_date,4), substring(header_end_date,5,2), right(header_end_date,2))) where billing_term_days = '730';

update SANDBOX.FPANDA.TempUpdatingBillingTerm set updated_header_end_date = DATEADD(dd,1095,date_from_parts(left(header_end_date,4), substring(header_end_date,5,2), right(header_end_date,2))) where billing_term_days = '1095';

update SANDBOX.FPANDA.TempUpdatingBillin
gTerm set Invoices_to_go = ceil(datediff(day,$Forecast_start,updated_header_end_date) / Billing_Term_Days);

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCreatingInvoiceLines AS
select a2.invoice_lines, a1.* from SANDBOX.FPANDA.TempUpdatingBillingTerm a1
join SANDBOX.FPANDA.zforecast_invoice_lines a2 on a1.invoices_to_go = a2.invoice_lines;


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempPrepInvoiceDates AS
select transaction_num, line_num, Transaction_Line_ID, Trans_Line_Mat_ID, createdate, cancellation_effective_date, header_start_date, header_end_date, Header_End_Date_Real, updated_header_end_date, Billing_Term_Days, Invoices_to_go, round((ARR_USD_NET / 365 * Billing_Term_Days),2) as Invoice_Amt, 
cast ('01/01/9999' as date) Invoice_Start_date, cast ('01/01/9999' as date) Invoice_End_date, sold_to, ship_to, revenue_type, billing_period, ARR_USD_NET, OriginalMaterial, 
CalendarMonth, CalendarQuarter, ProductID, UltimateID
from SANDBOX.FPANDA.TempCreatingInvoiceLines;

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCreatingInvoiceDates AS
select Trans_Line_Mat_ID, ultimateid, revenue_type, updated_header_end_date, Header_End_Date_Real, Billing_Term_Days, ceil( Billing_Term_Days/30.42) as Billing_Months, Invoices_to_go, Invoice_Amt, Invoice_Start_date, Invoice_End_date,
ROW_NUMBER() OVER (PARTITION BY Trans_Line_Mat_ID ORDER BY Trans_Line_Mat_ID) as RowNo, dense_rank() OVER (ORDER BY Trans_Line_Mat_ID) as RowNoGroup
from SANDBOX.FPANDA.TempPrepInvoiceDates order by Trans_Line_Mat_ID, RowNo;

update SANDBOX.FPANDA.TempCreatingInvoiceDates set invoice_end_date = updated_header_end_date where RowNo = '1';
update SANDBOX.FPANDA.TempCreatingInvoiceDates set Invoice_Start_date = DATEADD(DD,-1 * (billing_term_days - 1), updated_header_end_date) where RowNo = '1';

update SANDBOX.FPANDA.TempCreatingInvoiceDates set Invoice_Start_date = DATEADD(DD,-1*billing_months,last_day(invoice_end_date))
where RowNo = '1' and Invoice_End_date = last_day(Invoice_End_date);

/*select INVOICE_END_DATE, last_day(INVOICE_END_DATE), -1*billing_months, DATEADD(DD,-1*billing_months,last_day(invoice_end_date))
  from SANDBOX.FPANDA.TempCreatingInvoiceDates;*/

update SANDBOX.FPANDA.TempCreatingInvoiceDates set Invoice_Start_date = DATEADD(DD, 1,Invoice_Start_date ) where RowNo = '1' and Invoice_End_date = last_day(Invoice_End_date);

--select * from ##TempCreatingInvoiceDates where Trans_Line_Mat_ID = '0045127141-0000000020-000000000000012662' order by Trans_Line_Mat_ID, rowno
--select * from ##TempCreatingInvoiceDates order by Trans_Line_Mat_ID, rowno
--select * from ##TempCreatingInvoiceDates


CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempStartEndDates AS
select  Trans_Line_Mat_ID, invoice_start_date, Invoice_end_date 
from SANDBOX.FPANDA.TempCreatingInvoiceDates
where not Invoice_Start_date = '';

/*DROP TABLE IF EXISTS ##TempCreatingInvoiceDatesV2
select a1.*, a2.Invoice_Start_date as INV_Start_Prior, a2.Invoice_End_date as INV_End_Prior into ##TempCreatingInvoiceDatesV2 from ##TempCreatingInvoiceDates a1
left join ##TempCreatingInvoiceDates a2 ON a1.RowNo = a2.RowNo + 1 and a1.Trans_Line_Mat_ID = a2.Trans_Line_Mat_ID 
order by a1.Trans_Line_Mat_ID, a1.RowNo */

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 AS
select a1.*, a2.Invoice_Start_date as INV_Start_Prior, a2.Invoice_End_date as INV_End_Prior 
  from SANDBOX.FPANDA.TempCreatingInvoiceDates a1
left join SANDBOX.FPANDA.TempCreatingInvoiceDates a2 ON a1.RowNo = a2.RowNo + 1 and a1.Trans_Line_Mat_ID = a2.Trans_Line_Mat_ID 
order by a1.Trans_Line_Mat_ID, a1.RowNo;

update SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 
   set INV_Start_Prior = a2.invoice_start_date 
  from SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 a1
left join SANDBOX.FPANDA.TempStartEndDates a2 on a1.Trans_Line_Mat_ID = a2.Trans_Line_Mat_ID
where not a1.RowNo = '1';

update SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 
   set INV_End_Prior = a2.Invoice_End_date 
  from SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 a1
left join SANDBOX.FPANDA.TempStartEndDates a2 on a1.Trans_Line_Mat_ID = a2.Trans_Line_Mat_ID
where not a1.RowNo = '1';

-- Sanity checks
Update SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 
   set invoice_end_date = DATEADD(MM,(-1*(rowno - 1)*Billing_Months), INV_End_Prior)
 where not INV_Start_Prior = '';  --should i change these to where inv_start_prior is not null?
 
Update SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 
   set invoice_end_date = last_day(INV_END_PRIOR, (-1*(rowno - 1) * Billing_Months)) 
 where INV_END_PRIOR = last_day(INV_END_PRIOR) and not INV_START_PRIOR = '';
 
update SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 
   set Invoice_Start_date = DATEADD(MM,(-1 * ((Billing_Months * (RowNo - 1)))), INV_Start_Prior) 
 where not INV_START_PRIOR = '';
--update ##TempCreatingInvoiceDatesV2 set Invoice_Start_date = last_day(INV_END_PRIOR, (-1*(rowno - 1) * Billing_Months)) where Invoice_End_date = last_day(Invoice_End_date) and not Invoice_Start_date = last_day(Invoice_Start_date) and not RowNo = '1'



	Set Q1_start = '2025-04-01';
	Set Q1_end = '2025-06-30';
	Set Q2_start = '2025-07-01';
	Set Q2_end = '2025-09-30';
	Set Q3_start = '2025-10-01';
	Set Q3_end = '2025-12-31';
	Set Q4_start = '2026-01-01';
	Set Q4_end = '2026-03-31';
	Set ARR_Date = '202503';
	Set Forecast_End = '2027';
	Set Forecast_EndV = '2027';
	Set Forecast_start = '2023-12-31';
	Set PYRev_start = '2023-01-01';
	Set PYRev_end = '2025-03-31';

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempUnbundling as
select a1.Trans_Line_Mat_ID,a1.ultimateID, a1.revenue_type, Header_End_Date_Real,a1.Invoice_Start_date as InvoiceDate, a1.Invoice_Start_date as CashDate, a1.Invoice_Start_date, a1.Invoice_End_date, a2.subrevenuetype, a2.RevRecBasis, 
(a2.SubRevenueTypeAllocPerc * a1.Invoice_Amt) as Invoice_Amt, (a2.SubRevenueTypeAllocPerc * a1.Invoice_Amt) as Cash_Amt, 
cast ('0' as float) PY_PT, cast ('0' as float) Q1_PT, cast ('0' as float) Q2_PT, cast ('0' as float) Q3_PT, cast ('0' as float) Q4_PT,
cast ('0' as float) PY_OT, cast ('0' as float) Q1_OT, cast ('0' as float) Q2_OT, cast ('0' as float) Q3_OT, cast ('0' as float) Q4_OT,
cast ('0' as float) PY_ET, cast ('0' as float) Q1_ET, cast ('0' as float) Q2_ET, cast ('0' as float) Q3_ET, cast ('0' as float) Q4_ET,
cast ('0' as float) PY_Total, cast ('0' as float) Q1_Total, cast ('0' as float) Q2_Total, cast ('0' as float) Q3_Total, cast ('0' as float) Q4_Total
from SANDBOX.FPANDA.TempCreatingInvoiceDatesV2 a1
left join SANDBOX.FPANDA.ZForecastRevTypesAllocations a2 on a1.revenue_type = a2.Revenuetype;

--zforecast_invoice_lines
--ZForecastRevTypesAllocations
--ignore zjack_revproexport2

select * from SANDBOX.FPANDA.ZForecastRevTypesAllocations;

Update SANDBOX.FPANDA.TempUnbundling 
   set RevRecBasis = 'over-time' 
 where revenue_type in ('VISAS','E365');

--NEED TO UPDATE VISA REV REC SCHEDULE -- and MAYBE E365? check separately
--Need to update so the quarter start/end dates are pulling from a separate table that can be updated easier ---can use a declare at the beginning of this
Update SANDBOX.FPANDA.TempUnbundling set Q1_PT = Invoice_Amt where Invoice_Start_date between $Q1_start and $Q1_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempUnbundling set Q2_PT = Invoice_Amt where Invoice_Start_date between $Q2_start and $Q2_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempUnbundling set Q3_PT = Invoice_Amt where Invoice_Start_date between $Q3_start and $Q3_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempUnbundling set Q4_PT = Invoice_Amt where Invoice_Start_date between $Q4_start and $Q4_end and RevRecBasis = 'point-in-time';
Update SANDBOX.FPANDA.TempUnbundling set PY_PT = Invoice_Amt where Invoice_Start_date between $PYRev_start and $PYRev_end and RevRecBasis = 'point-in-time';

---fix the spelling in the underlying table
Update SANDBOX.FPANDA.TempUnbundling set Q1_ET = Invoice_Amt where Invoice_End_date between $Q1_start and $Q1_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempUnbundling set Q2_ET = Invoice_Amt where Invoice_End_date between $Q2_start and $Q2_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempUnbundling set Q3_ET = Invoice_Amt where Invoice_End_date between $Q3_start and $Q3_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempUnbundling set Q4_ET = Invoice_Amt where Invoice_End_date between $Q4_start and $Q4_end and RevRecBasis = 'End-of-term';
Update SANDBOX.FPANDA.TempUnbundling set PY_ET = Invoice_Amt where Invoice_End_date between $PYRev_start and $PYRev_end and RevRecBasis = 'End-of-term';

--Update ##TempUnbundling set Q1_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,(min(invoice_end_date, '2020-03-01'), max(Invoice_Start_date, '2020-01-01')))+1)
Update SANDBOX.FPANDA.TempUnbundling set Q1_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $Q1_start then invoice_start_date else $Q1_start end,
	case when invoice_end_date < $Q1_end then invoice_end_date else $Q1_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $Q1_end or Invoice_End_date < $Q1_start);
Update SANDBOX.FPANDA.TempUnbundling set Q2_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $Q2_start then invoice_start_date else $Q2_start end,
	case when invoice_end_date < $Q2_end then invoice_end_date else $Q2_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $Q2_end or Invoice_End_date < $Q2_start);
Update SANDBOX.FPANDA.TempUnbundling set Q3_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $Q3_start then invoice_start_date else $Q3_start end,
	case when invoice_end_date < $Q3_end then invoice_end_date else $Q3_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $Q3_end or Invoice_End_date < $Q3_start);
Update SANDBOX.FPANDA.TempUnbundling set Q4_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $Q4_start then invoice_start_date else $Q4_start end,
	case when invoice_end_date < $Q4_end then invoice_end_date else $Q4_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $Q4_end or Invoice_End_date < $Q4_start);
Update SANDBOX.FPANDA.TempUnbundling set PY_OT = (Invoice_Amt / ((datediff(day, invoice_start_date, invoice_end_date))+1) * (datediff(day,case when invoice_start_date > $PYRev_start then invoice_start_date else $PYRev_start end,
	case when invoice_end_date < $PYRev_end then invoice_end_date else $PYRev_end end)+1)) where RevRecBasis = 'over-time' and not (Invoice_Start_date > $PYRev_end or Invoice_End_date < $PYRev_start);

Update SANDBOX.FPANDA.TempUnbundling set Q1_Total = Q1_PT + Q1_OT + Q1_ET;
Update SANDBOX.FPANDA.TempUnbundling set Q2_Total = Q2_PT + Q2_OT + Q2_ET;
Update SANDBOX.FPANDA.TempUnbundling set Q3_Total = Q3_PT + Q3_OT + Q3_ET;
Update SANDBOX.FPANDA.TempUnbundling set Q4_Total = Q4_PT + Q4_OT + Q4_ET;
Update SANDBOX.FPANDA.TempUnbundling set PY_Total = PY_PT + PY_OT + PY_ET;

Update SANDBOX.FPANDA.TempUnbundling set InvoiceDate = DATEADD(DD, -45,Invoice_Start_date) where revenue_type not in ('Virutoso SAAS','Virtuoso Subscription','E365','VISAS');
Update SANDBOX.FPANDA.TempUnbundling set CashDate = DATEADD(DD, 30,InvoiceDate) where revenue_type not in ('Virutoso SAAS','Virtuoso Subscription','E365','VISAS');

CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempE365Anniversary AS
select ULTIMATE_ID as ultimateID, CAST(DATE_PART(YEAR, REVISIT_DATE) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, REVISIT_DATE) AS VARCHAR(5)) as NextAnniversary, (DATE_PART(QUARTER, REVISIT_DATE)) AS AnniversaryQuarter,
cast('2025-01-01' as date) as AnniversaryDateCY, cast('2026-01-01' as date) as AnniversaryDateNY, cast('2026-01-01' as date) as AnniversaryDatePY
from CURATED.STREAMLIT_DB_REFERENCE_DATA.REF_E365_TERMS where IS_ACTIVE = 'Y';


-------------NEED TO UPDATE EACH TIME IT RUNS--------DON'T FORGET-----------------------------
Update SANDBOX.FPANDA.TempE365Anniversary set NextAnniversary = '20261' where NextAnniversary is Null;
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateCY = '2025-01-01' where AnniversaryQuarter = '1';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateCY = '2025-04-01' where AnniversaryQuarter = '2';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateCY = '2025-07-01' where AnniversaryQuarter = '3';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateCY = '2025-10-01' where AnniversaryQuarter = '4';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateNY = '2026-01-01' where AnniversaryQuarter = '1';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateNY = '2026-04-01' where AnniversaryQuarter = '2';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateNY = '2026-07-01' where AnniversaryQuarter = '3';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDateNY = '2026-10-01' where AnniversaryQuarter = '4';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDatePY = '2024-01-01' where AnniversaryQuarter = '1';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDatePY = '2024-04-01' where AnniversaryQuarter = '2';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDatePY = '2024-07-01' where AnniversaryQuarter = '3';
Update SANDBOX.FPANDA.TempE365Anniversary set AnniversaryDatePY = '2024-10-01' where AnniversaryQuarter = '4';

Update SANDBOX.FPANDA.TempUnbundling set Cash_Amt = (a1.Cash_Amt * 4) from SANDBOX.FPANDA.TempUnbundling a1
left join SANDBOX.FPANDA.TempE365Anniversary a2 on a1.ultimateID = a2.ultimateID
where a1.Invoice_Start_date in (AnniversaryDateCY, AnniversaryDateNY, AnniversaryDatePY) and a1.revenue_type = 'E365';

Update SANDBOX.FPANDA.TempUnbundling set Invoice_Amt = (a1.Invoice_Amt * 4) from SANDBOX.FPANDA.TempUnbundling a1
left join SANDBOX.FPANDA.TempE365Anniversary a2 on a1.ultimateID = a2.ultimateID
where a1.Invoice_Start_date in (AnniversaryDateCY, AnniversaryDateNY, AnniversaryDatePY) and a1.revenue_type = 'E365';

Update SANDBOX.FPANDA.TempUnbundling set Cash_Amt = (a1.Cash_Amt * 0) from SANDBOX.FPANDA.TempUnbundling a1
left join SANDBOX.FPANDA.TempE365Anniversary a2 on a1.ultimateID = a2.ultimateID
where a1.Invoice_Start_date not in (AnniversaryDateCY, AnniversaryDateNY, AnniversaryDatePY) and a1.revenue_type = 'E365';

Update SANDBOX.FPANDA.TempUnbundling set Invoice_Amt = (a1.Invoice_Amt * 0) from SANDBOX.FPANDA.TempUnbundling a1
left join SANDBOX.FPANDA.TempE365Anniversary a2 on a1.ultimateID = a2.ultimateID
where a1.Invoice_Start_date not in (AnniversaryDateCY, AnniversaryDateNY, AnniversaryDatePY) and a1.revenue_type = 'E365';

Update SANDBOX.FPANDA.TempUnbundling set InvoiceDate = DATEADD(DD, -45,Invoice_Start_date) where revenue_type in ('E365');

Update SANDBOX.FPANDA.TempUnbundling set CashDate = DATEADD(DD, 30,InvoiceDate) where revenue_type in ('E365');

Update SANDBOX.FPANDA.TempUnbundling set Header_End_Date_Real = DATEADD(DD,-1,a2.AnniversaryDateCY) from SANDBOX.FPANDA.TempUnbundling a1
join SANDBOX.FPANDA.TempE365Anniversary a2 on a1.ultimateID = a2.ultimateID where a1.revenue_type = 'E365';


-------------QUICK/LAZY WAY TO DO IT----------INDIVIDUAL BUILD UPS WON'T BE CORRECT....THIS SHOULD BE DONE MORE UPSTREAM
Update SANDBOX.FPANDA.TempUnbundling set Q1_Total = (Q1_Total * 1.115) where Invoice_Start_date > Header_End_Date_Real and revenue_type not in ('E365','VISAS');
Update SANDBOX.FPANDA.TempUnbundling set Q2_Total = (Q2_Total * 1.115) where Invoice_Start_date > Header_End_Date_Real;
Update SANDBOX.FPANDA.TempUnbundling set Q3_Total = (Q3_Total * 1.115) where Invoice_Start_date > Header_End_Date_Real;
Update SANDBOX.FPANDA.TempUnbundling set Q4_Total = (Q4_Total * 1.115) where Invoice_Start_date > Header_End_Date_Real;
Update SANDBOX.FPANDA.TempUnbundling set Invoice_Amt = (Invoice_Amt * 1.115) where Invoice_Start_date > Header_End_Date_Real;
Update SANDBOX.FPANDA.TempUnbundling set Cash_Amt = (Cash_Amt * 1.115) where Invoice_Start_date > Header_End_Date_Real;

select * from SANDBOX.FPANDA.TempE365Anniversary order by ultimateid;

select cast(Header_End_Date_Real as date),* from SANDBOX.FPANDA.TempUnbundling where ultimateID = '1000009736';

select revenue_type, sum(invoice_amt) invoice_amt, sum(Q1_Total) Q1_Total, sum(Q2_Total) Q2_Total, sum(Q3_Total) Q3_Total, sum(Q4_Total) Q4_Total 
from SANDBOX.FPANDA.TempUnbundling group by revenue_type;

select revenue_type, sum(invoice_amt) invoice_amt, sum(Q1_Total) Q1_Total, sum(Q2_Total) Q2_Total, sum(Q3_Total) Q3_Total, sum(Q4_Total) Q4_Total 
from SANDBOX.FPANDA.TempUnbundling where invoice_end_date > '2024-12-31' and invoicedate < '2025-12-31' group by revenue_type;

select revenue_type, sum(invoice_amt) invoice_amt, sum(PY_Total) PY_Total,sum(Q1_Total) Q1_Total, sum(Q2_Total) Q2_Total, sum(Q3_Total) Q3_Total, sum(Q4_Total) Q4_Total 
from SANDBOX.FPANDA.TempUnbundling where invoice_end_date > '2024-12-31' and invoicedate < '2026-01-01' group by revenue_type;

select revenue_type, sum(invoice_amt) invoice_amt, sum(PY_Total) PY_Total,sum(Q1_Total) Q1_Total, sum(Q2_Total) Q2_Total, sum(Q3_Total) Q3_Total, sum(Q4_Total) Q4_Total 
from SANDBOX.FPANDA.TempUnbundling where invoice_end_date > '2025-03-31' and invoicedate < '2026-04-01' group by revenue_type;

select CAST(DATE_PART(YEAR, InvoiceDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, InvoiceDate) AS VARCHAR(5)) as InvoiceYear, sum(Invoice_Amt) from SANDBOX.FPANDA.TempUnbundling
group by CAST(DATE_PART(YEAR, InvoiceDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, InvoiceDate) AS VARCHAR(5)) 
order by CAST(DATE_PART(YEAR, InvoiceDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, InvoiceDate) AS VARCHAR(5));

select CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, CashDate) AS VARCHAR(5)) as CashYear, sum(Cash_Amt) from SANDBOX.FPANDA.TempUnbundling
group by CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, CashDate) AS VARCHAR(5)) having sum(Cash_Amt) > 0
order by CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)) + CAST(DATE_PART(QUARTER, CashDate) AS VARCHAR(5));

select CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)) as CashYear, revenue_type, sum(Cash_Amt) from ##TempUnbundling
where CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)) ='2025'
group by CAST(DATE_PART(YEAR, CashDate) AS VARCHAR(5)), revenue_type having sum(Cash_Amt) > 0;

select * from SANDBOX.FPANDA.TempUnbundling where revenue_type = 'practitioner license' and ultimateid = '1006098135' order by InvoiceDate;

select * from SANDBOX.FPANDA.TempUnbundling where revenue_type = 'SQ Subscription';

select * from SANDBOX.FPANDA.TempUnbundling where CAST(DATEPART(YEAR, CashDate) AS VARCHAR(5)) + CAST(DATEPART(QUARTER, CashDate) AS VARCHAR(5)) = 20211;

--------------------END SCRIPT----------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE TEMPORARY TABLE SANDBOX.FPANDA.TempUnbundlingJC AS
select * from SANDBOX.FPANDA.TempUnbundling
