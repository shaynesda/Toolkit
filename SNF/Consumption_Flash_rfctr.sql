/********************************************************************
**  Name: Consumption Flash
**  Refactored Date: 5/27/2026 
**  
**  Tables Used:
**  BENTLEYPROD (REPORTING_DB.EDW)  ->  BIRD_PROD (PRESENTATION.MART)
**  CONSUMPTION_METRICS = OBT_CONSUMPTION_DAILY
**
**  Description: 
**
********************************************************************/

USE DATABASE PRESENTATION;
USE SCHEMA MART;

select max(cm."Usage Date") from OBT_CONSUMPTION_DAILY cm;
--4/25/26

--Full quarters (normalized)  Refactored for BIRD_PROD.PRESENTATION.MART
SELECT
    SUM(cm."Normalized Consumption") AS All_Accounts,
    SUM(CASE WHEN cm."Ultimate Commercial Program" = 'E365' THEN cm."Normalized Consumption" ELSE 0 END) AS E365
FROM OBT_CONSUMPTION_DAILY cm
WHERE cm."Year Quarter"=20251
  AND cm."Acquisition Source" <> 'Seequent' 
  AND cm."In Contracts" = 'Yes'
GROUP BY cm."Year Quarter"
ORDER BY cm."Year Quarter" ASC;

/*Results 5/27/2026
--BIRD_PROD
176 distinct product id's

ALL_ACCOUNTS	E365
413369914.151689	229717576.531398

--BENTLEYPROD
192 distinct product id's

ALL_ACCOUNTS	     E365
411900438.813148	238925311.715769
*/

--Full months (normalized) Refactored for BIRD_PROD.PRESENTATION.MART
SELECT 
    cm."Year Month",
    SUM(cm."Normalized Consumption") AS All_Accounts,
    SUM(CASE WHEN cm."Ultimate Commercial Program" = 'E365' THEN cm."Normalized Consumption" ELSE 0 END) AS E365
FROM OBT_CONSUMPTION_DAILY cm
WHERE cm."In Contracts" = 'Yes'
  AND cm."Acquisition Source" <> 'Seequent' 
    --AND cm."Year Month" IN (202501,202601) --January
    --AND cm."Year Month" IN (202502,202602) --February
    AND cm."Year Month" IN (202503,202603) --March
GROUP BY cm."Year Month"
ORDER BY cm."Year Month";

/*Results 5/27/2026
--BIRD_PROD
Year Month	ALL_ACCOUNTS	E365
202503	141314147.792766	78610208.987348
202603	138367890.615486	78062469.0645595

--BENTLEYPROD
YEAR_MONTH	ALL_ACCOUNTS	E365
202503	140939074.246928	81822209.8383758
202603	137558667.033772	80962820.6471146
*/

--YTD (for whole months) Refactored for BIRD_PROD.PRESENTATION.MART
--> skip if mid-month (Jan - Aug for this run, plus tack on non-normalized Sept)
SELECT 
    SUM(cm."Normalized Consumption") as normalized_consumption
FROM OBT_CONSUMPTION_DAILY cm
WHERE cm."In Contracts" = 'Yes'
AND cm."Acquisition Source" <> 'Seequent' 
AND cm."Ultimate Commercial Program" ='E365'
AND cm."Year Month" between 202401 and 202408
GROUP BY ALL;

/*Results 5/27/2026
--BIRD_PROD
NORMALIZED_CONSUMPTION
610608374.99808

--BENTLEYPROD
NORMALIZED_CONSUMPTION
635257468.19486
*/

--Partial months/weeks (un-normalized) Refactored for BIRD_PROD.PRESENTATION.MART
SELECT
    SUM(cm."Normalized Consumption") AS All_Accounts,
    SUM(CASE WHEN cm."Ultimate Commercial Program" = 'E365' THEN cm."Normalized Consumption" ELSE 0 END) AS E365
 FROM OBT_CONSUMPTION_DAILY cm
WHERE cm."In Contracts" = 'Yes'
  AND cm."Acquisition Source" <> 'Seequent' 
--AND cm."Usage Date" between '2025-04-02' and '2025-04-20'
  AND cm."Usage Date" between '2026-04-01' and '2026-04-19'
GROUP BY ALL;

/*Results 5/27/2026
--BIRD_PROD
ALL_ACCOUNTS	E365
79656415.9631111	45011477.4269702

--BENTLEYPROD
ALL_ACCOUNTS	E365
81193163.6431984	48078374.7239974
*/




-- BIRD_PROD
SELECT cm."Ultimate ID", cm."Ultimate Commercial Program", cm."Ultimate Commercial Program", count(1)
FROM OBT_CONSUMPTION_DAILY cm
WHERE cm."In Contracts" = 'Yes'
  AND cm."Acquisition Source" <> 'Seequent' 
  AND cm."Year Quarter" = 20251
GROUP BY ALL;