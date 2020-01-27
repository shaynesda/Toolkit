CREATE OR REPLACE FUNCTION NEW_APDEV.COV_PARMS (in_pol_num NEW_APDEV.ITEM_AT_RISK.POLICY_NUMBER%TYPE,
                                                  in_iar_id  NEW_APDEV.ITEM_AT_RISK.ITEM_AT_RISK_ID%TYPE,
                                        in_endt NEW_APDEV.ITEM_AT_RISK_COVERAGE.COVERAGE_CODE%TYPE)
RETURN ENDT_PARMS_TABLE_OUT PIPELINED IS
--****


 out_rec ENDT_PARMS_OUT := ENDT_PARMS_OUT(null, null, null, null, null, null, null);


v_pol_num  new_apdev.item_at_risk.policy_number%type;
v_iar_id  new_apdev.item_at_risk.item_at_risk_id%type;
v_end_num new_apdev.item_at_risk_coverage.coverage_code%type;
v_bop_conv varchar2(1);


BEGIN


v_pol_num   :=   in_pol_num;
v_iar_id    :=   in_iar_id;
v_end_num   :=   in_endt;


     -- PREMISES ALARM OR FIRE PROTECTION SYSTEM CREDIT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 04 16' THEN
      SELECT v_pol_num, v_end_num, alarm_fire_type, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- STRUCTURE RENTED TO OTHERS-RESIDENCE PREMISES COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 04 40' THEN
      SELECT v_pol_num, v_end_num, NO_OF_STRUCTURES, 0, 0, 0, 0
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1,out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


       --ADDITIONAL INSURED COV PARM DATA COLLECT CONVERSION
   --*** ADDED 5/14/2014 TO SUPPORT ADDITIONAL PARMS FOR HO 04 41 SHAYNES

    IF v_end_num IN ('HO 04 41','HO 04A41','HO 04B41','HO 04C41','HO 04D41') THEN
      SELECT v_pol_num, v_end_num, PARM1, PARM2, PARM3, PARM4, PARM5
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1,out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


      -- ELECTRONIC APPARATUS COV PARM DATA COLLECT CONVERSION

    IF v_end_num in ('HO 04E65', 'HO 04E66') THEN
      SELECT v_pol_num, v_end_num, ELECT_APARATUS/100, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

    ELSE


     -- JEWELRY, MONEY, SECURITIES, SILVERWARE, GUNS  COV PARM DATA COLLECT CONVERSION


    IF v_end_num in ('HO 04 65', 'HO 04 66') THEN
      SELECT v_pol_num, v_end_num, JEWELRY_FURS/100, MONEY/100, SECURITIES/100, SILVERWARE/100, FIREARMS/100
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4,out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- ORDINANCE OR LAW COVERAGE COV PARM DATA COLLECT CONVERSION

       IF v_end_num = 'HO 04 77' THEN
      SELECT v_pol_num, v_end_num, PRCNT_INCREASE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


      -- ADDITIONAL RESIDENCE RENTED TO OTHERS COV PARM DATA COLLECT CONVERSION

    IF v_end_num in ('HO 24 70', 'HO 24A70', 'HO 24B70', 'HO 24C70') THEN
      SELECT v_pol_num, v_end_num, NO_FAMILIES, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- BUSINESS PURSUITS (EMPLOYMENT TYPE) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 24 71' THEN
      SELECT v_pol_num, v_end_num, et.CODE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL CD, NEW_APDEV.EMPLOYMENT_TYPE et
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id
         AND et.DESCRIPTION = CD.EMPLOY_TYPE;

      PIPE ROW(out_rec);

     ELSE

    -- WATERCRAFT LIABILITY COV PARM DATA COLLECT CONVERSION


        IF v_end_num = 'HO 24 75' THEN
      SELECT v_pol_num, v_end_num, wll.WANG_CODE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL CD, NEW_APDEV.WATERCRAFT_LIAB_LKUP wll
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id
         AND wll.HORSEPOWER  = CD.HORSEPOWER
        AND wll.BOAT_TYPE   = CD.LIAB_BOAT_TYPE
        AND wll.BOAT_LENGTH = CD.LENGTH;

      PIPE ROW(out_rec);

     ELSE

     -- ACCOUNT CREDIT COV PARM DATA COLLECT CONVERSION


    IF v_end_num = 'HO-CC' THEN
      SELECT v_pol_num, v_end_num, NI_STEP, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- LOSS FREE CREDIT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO-LF' THEN
      SELECT v_pol_num, v_end_num, LOSS_FREE_YEARS, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
       FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'PM ND 30' THEN
      SELECT v_pol_num, v_end_num, BOAT_TYPE, WATER_TYPE,
          CASE
              WHEN DEDUCTIBLE = '100' THEN '010'
              WHEN DEDUCTIBLE = '250' THEN '250'
              WHEN DEDUCTIBLE = '500' THEN '500'
              WHEN DEDUCTIBLE = '1000' THEN '100'
             END, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

      -- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'PM NDA30' THEN
      SELECT v_pol_num, v_end_num, BOAT_TYPE, WATER_TYPE,
          CASE
              WHEN DEDUCTIBLE = '100' THEN '010'
              WHEN DEDUCTIBLE = '250' THEN '250'
              WHEN DEDUCTIBLE = '500' THEN '500'
              WHEN DEDUCTIBLE = '1000' THEN '100'
             END, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

      -- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'PM NDB30' THEN
      SELECT v_pol_num, v_end_num, BOAT_TYPE, WATER_TYPE,
          CASE
              WHEN DEDUCTIBLE = '100' THEN '010'
              WHEN DEDUCTIBLE = '250' THEN '250'
              WHEN DEDUCTIBLE = '500' THEN '500'
              WHEN DEDUCTIBLE = '1000' THEN '100'
             END, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

      -- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'PM NDC30' THEN
      SELECT v_pol_num, v_end_num, BOAT_TYPE, WATER_TYPE,
          CASE
              WHEN DEDUCTIBLE = '100' THEN '010'
              WHEN DEDUCTIBLE = '250' THEN '250'
              WHEN DEDUCTIBLE = '500' THEN '500'
              WHEN DEDUCTIBLE = '1000' THEN '100'
             END, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

      -- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'PM NDD30' THEN
      SELECT v_pol_num, v_end_num, BOAT_TYPE, WATER_TYPE,
          CASE
              WHEN DEDUCTIBLE = '100' THEN '010'
              WHEN DEDUCTIBLE = '250' THEN '250'
              WHEN DEDUCTIBLE = '500' THEN '500'
              WHEN DEDUCTIBLE = '1000' THEN '100'
             END, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- ADDITIONAL RESIDENCE COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'ADD RES' THEN
      SELECT v_pol_num, v_end_num, NO_FAMILIES, RATE_GROUP, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    IF v_end_num = 'ADD RES2' THEN
      SELECT v_pol_num, v_end_num, NO_FAMILIES, RATE_GROUP, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     -- MOLD COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 04 26' THEN
      SELECT v_pol_num, v_end_num, DECODE(LIAB_LIMIT, '100000', LIAB_LIMIT, null), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    IF v_end_num = 'HO 04 27' THEN
      SELECT v_pol_num, v_end_num, DECODE(LIAB_LIMIT, '100000', LIAB_LIMIT, null), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     IF v_end_num = 'HO 04 28' THEN
      SELECT v_pol_num, v_end_num, DECODE(LIAB_LIMIT, '100000', LIAB_LIMIT, null), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     -- RESIDENCE HELD IN TRUST COV PARM DATA COLLECT CONVERSION

IF v_end_num = 'HO 05 43' THEN
      SELECT v_pol_num, v_end_num, COVERAGE_SEQ, TRUST_OPREM,
case when BEN_GRANT_NM = 'BG' THEN 'B'
     when BEN_GRANT_NM = 'B'  THEN 'B'
     when BEN_GRANT_NM = 'G'  THEN 'G'
     when BEN_GRANT_NM IS NULL THEN NULL
 END COV_PARM_3,
case when BEN_GRANT_NM = 'BG' THEN 'G'
     when BEN_GRANT_NM = 'G'  THEN 'G'
     when BEN_GRANT_NM IS NULL THEN NULL
 END COV_PARM_4, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
       FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     -- RENOVATED DWELLING CREDIT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'DM-18' THEN
      SELECT v_pol_num, v_end_num, RENO_CR_YR_ELIG, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


     -- BED AND BREAKFAST COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO-888' THEN
      SELECT v_pol_num, v_end_num, NO_RENTAL_BR, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


     -- YEAR OF CONSTRUCTION CREDIT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'DM-4' THEN
      SELECT v_pol_num, v_end_num, NEW_CONST_AGE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


     -- WINDSTORM OR HAIL PERCENTAGE DEDUCT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 03 12' THEN
      SELECT v_pol_num, v_end_num, DECODE(WIND_HAIL_PRCT, 'N/A', NULL, WIND_HAIL_PRCT), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     -- NAMED STORM COV PARM DATA COLLECT CONVERSION

IF v_end_num = 'ND NS' THEN
      SELECT v_pol_num, v_end_num, DECODE(WIND_HAIL_PRCT, 'N/A', NULL, WIND_HAIL_PRCT), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


     -- WINDSTORM OR HAIL PERCENTAGE DEDUCT COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO WIND' THEN
      SELECT v_pol_num, v_end_num, DECODE(WIND_HAIL_PRCT, 'N/A', NULL, WIND_HAIL_PRCT), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE


      -- TENANTS RELOCATION COVERAGE COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 23 71' THEN
      SELECT v_pol_num, v_end_num, NUM_RENTAL_UNITS, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

     -- HOMEPAK COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO-HPK' THEN
      SELECT v_pol_num, v_end_num, LIAB_LIMIT, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

     ELSE

    -- NEW BUYERS CREDIT NBC-92 COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'NBC-92' THEN
      SELECT v_pol_num, v_end_num, NEW_CONST_AGE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

    ELSE

   -- NEW BUYERS CREDIT NBC-05 COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'NBC-05' THEN
      SELECT v_pol_num, v_end_num, NEW_CONST_AGE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

   ELSE

     -- INFLATION GUARD HO 04 46 COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO 04 46' THEN
      SELECT v_pol_num, v_end_num, PRCNT_INCREASE, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

      ELSE

     -- NJ HURRICANE DEDUCTIBLE FM-HURR COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'FM-HURR' THEN
      SELECT v_pol_num, v_end_num, WIND_HAIL_PRCT, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

    ELSE

     -- NJ WIND RELATED DEDUCTIBLE MPL22 COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'MPL22' THEN
      SELECT v_pol_num, v_end_num,  lpad(endt_limit*.01, 3, 0), null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

    ELSE


    -- HOME BUSINESS OPTION HO X7 01 COV PARM DATA COLLECT CONVERSION

    IF v_end_num = 'HO X7 01' THEN
      SELECT v_pol_num, v_end_num, SUBSTR(PARM1_DESC, 4, 2), PARM5_DESC, null, null, null  -- Stat Reporting Requirement: last 2 positions of PARM1_DESC represents the stat class for the HO X7 01, Exposure # visitors/week receipts code is stored in PARM5_DESC.
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);

   -- Compak rewrite START
    ELSE

      -- AI Endorsements
    IF v_end_num in ('BP 04 02', 'BP 04 06', 'BP 04 07','BP 04 08', 'BP 04 09', 'BP 04 10', 'BP 04 16',
                     'BP 04 47', 'BP 04 48','BP 04 50', 'BP 04 51','BP 04 52','BP 04 13' )
    THEN
      SELECT v_pol_num, v_end_num, limit, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.ITEM_AT_RISK_COVERAGE_LIMIT
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);
    ELSE

  /*  IF v_end_num = 'BP 04 04' and  v_bop_conv = 'N' THEN  -- -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
      SELECT v_pol_num, v_end_num,
             CASE when limit = 1 THEN 'H'
                  when limit = 2 THEN 'N'
                  when limit = 3 THEN 'H'
                 ELSE limit||''
             END COV_PARM_1,
             CASE when limit = 3 THEN 'N'
                  ELSE limit||''
             END COV_PARM_2,
             null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM ITEM_AT_RISK_COVERAGE_LIMIT
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);
    ELSE */

      -- BP 04 04 HIRED AND NON OWNED AUTO AFTER COMPAK/AQS CONVERSION 2010
    IF v_end_num = 'BP 04 04' and  v_bop_conv = 'Y' THEN  -- -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
      SELECT v_pol_num, v_end_num,
             CASE when parm1 = 'HIRED'then'H'           -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                  when parm1 = 'NON-OWNED' then'N'      -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                  when parm1 = 'BOTH'then 'B'            -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                 ELSE null
             END COV_PARM_1,
             null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
       FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL iard, NEW_APDEV.ITEM_AT_RISK_COVERAGE  IAR
       WHERE IAR.COVERAGE_CODE = v_end_num
        AND IAR.ITEM_AT_RISK_ID = v_iar_id
        AND IAR.ITEM_AT_RISK_ID=IARD.ITEM_AT_RISK_ID
        AND IAR.COVERAGE_CODE=IARD.COVERAGE_CODE;

      PIPE ROW(out_rec);
    ELSE


      -- BP 04 15 SPOILAGE COVERGAE
    IF v_end_num = 'BP 04 15' THEN
      SELECT v_pol_num, v_end_num,
             CASE when  parm1= 'C' THEN 'BR'
                  else DECODE(instr(PARM1, 'CONTAMINATION'),14, 'C', DECODE(instr(PARM1, 'POWER OUTAGE'), 0, PARM1,'PO'))  -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                  --ELSE parm1
             END COV_PARM_1,
       CASE when  parm1= 'C' THEN 'PO'
                  ELSE NULL
             END COV_PARM_2,
             DECODE(parm3,'NOT APPLICABLE', 'N', PARM3),
             CASE when  parm4= '004' THEN '001'
                  when  parm4= '005' THEN '001'
                  when  parm4= '006' THEN '001'
                  when  parm4= '007' THEN '001'
                  when  parm4= '008' THEN '002'
                  when  parm4= '009' THEN '002'
                  when  parm4= '010' THEN '002'
                  when  parm4= '011' THEN '002'
                  when  parm4= '012' THEN '003'
                  when  parm4= '012' THEN '003'
                  ELSE NULL
             END COV_PARM_4,
             SUBSTR(IAR.DEDUCTIBLE,0,3) parm5--TICKET 41956 CHANDU 11/21/2012
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
       FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL iard, NEW_APDEV.ITEM_AT_RISK_COVERAGE  IAR--TICKET 41956 CHANDU 11/21/2012
       WHERE IAR.COVERAGE_CODE = v_end_num
        AND IAR.ITEM_AT_RISK_ID = v_iar_id
        AND IAR.ITEM_AT_RISK_ID=IARD.ITEM_AT_RISK_ID
        AND IAR.COVERAGE_CODE=IARD.COVERAGE_CODE
        AND IARD.COVERAGE_SEQ = 1;

      PIPE ROW(out_rec);

    ELSE

      -- D+O-1 Directors and Officers Liability
    IF v_end_num = 'D+O-1' THEN
      SELECT v_pol_num, v_end_num,
             CASE when parm2 = 'A' AND parm3 = 'M' THEN parm1||'B'
             ELSE parm1||parm2
             END COV_PARM_1,
             null, null, substr(ICED.parm4,1,2)||substr(ICED.parm4,4,1), substr(ICED.parm4,5,1)||decode(length(ICED.parm4), 10, substr(ICED.parm4,9,2), substr(ICED.parm4,7,2)) -- CHANGED PARM4 YEAR TO CONDITIONAL SUBSTRING BASED ON 2 VS.4 DIGIT YEAR 7/16/2014
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL ICED
      WHERE COVERAGE_CODE = v_end_num
        AND ITEM_AT_RISK_ID = v_iar_id
        AND ICED.COVERAGE_SEQ = 1;

      PIPE ROW(out_rec);
    ELSE

      -- BP 01 86 AND IL 01 08 Directors and Officers Liability
    IF v_end_num IN ( 'BP 01 86','IL 01 08') THEN
      SELECT v_pol_num, v_end_num, number_of_units, null, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COMPAK
      WHERE ITEM_AT_RISK_ID = v_iar_id;

      PIPE ROW(out_rec);
    ELSE

      -- BP 22  Manual AI endorsement
    IF v_end_num IN ( 'BP-22') THEN
      SELECT v_pol_num, v_end_num, COUNT(*), null, null, null, null
      INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.ITEM_NAME INN, NAME N
      WHERE INN.ITEM_AT_RISK_ID = v_iar_id AND INN.NAME_ID = N.NAME_ID AND N.LICENSE_NUMBER='BP-22';

      PIPE ROW(out_rec);
    ELSE
    
      -- BP EP 00, BP EP 11  EPLI endorsements , DRE1
    IF v_end_num IN ( 'BP EP 00', 'BP EP 11', 'DRE1', 'BP 02 30') THEN
      SELECT v_pol_num, v_end_num,lpad(to_char(IARC.deductible/100),3,0), null, null, substr(ICED.parm4,1,2)||substr(ICED.parm4,4,1), substr(ICED.parm4,5,1)||decode(length(ICED.parm4), 10, substr(ICED.parm4,9,2), substr(ICED.parm4,7,2)) -- CHANGED PARM4 YEAR TO CONDITIONAL SUBSTRING BASED ON 2 VS.4 DIGIT YEAR 7/16/2014
      INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.ITEM_AT_RISK_COVERAGE IARC, NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL ICED
      WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num
            AND ICED.ITEM_AT_RISK_ID = v_iar_id AND ICED.COVERAGE_CODE = v_end_num;

      PIPE ROW(out_rec);

    ELSE

       --BP 04 98 (EMP BENEFITS), BP 02 50 , BP 14 31 (ESCAPED FUEL) ALL W/ RETROACTIVE DATE IN PARM1
     IF v_end_num IN ('BP 04 98','BP 02 50','BP 14 31') THEN
      SELECT v_pol_num, v_end_num,lpad(to_char(IARC.deductible/100),3,0), null, null, substr(ICED.parm1,1,2)||substr(ICED.parm1,4,1), substr(ICED.parm1,5,1)||decode(length(ICED.parm1), 10, substr(ICED.parm1,9,2), substr(ICED.parm1,7,2)) -- ADJUSTED TO START SENDING DATE FROM PARM1 7/30/2014      
        INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
        FROM ITEM_AT_RISK_COVERAGE IARC, IAR_COVERAGE_ENDT_DETAIL ICED
       WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num
         AND ICED.ITEM_AT_RISK_ID = v_iar_id AND ICED.COVERAGE_CODE = v_end_num
         AND COVERAGE_SEQ = 1;

      PIPE ROW(out_rec);

    ELSE
    
    --BP 17 24 W/ RETROACTIVE DATE IN PARM7
     IF v_end_num IN ('BP 17 24') THEN
      SELECT v_pol_num, v_end_num,lpad(to_char(IARC.deductible/100),3,0), null, null, substr(ICED.parm7,1,2)||substr(ICED.parm7,4,1), substr(ICED.parm7,5,1)||decode(length(ICED.parm7), 10, substr(ICED.parm7,9,2), substr(ICED.parm7,7,2)) -- ADJUSTED TO START SENDING DATE FROM PARM7 7/30/2014      
        INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
        FROM ITEM_AT_RISK_COVERAGE IARC, IAR_COVERAGE_ENDT_DETAIL ICED
       WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num
         AND ICED.ITEM_AT_RISK_ID = v_iar_id AND ICED.COVERAGE_CODE = v_end_num;

      PIPE ROW(out_rec);

    ELSE
    
    -- BP 02 86 & BP 02 44 DIGITAL RISK EACH RETROACTIVE DATE IN PARM14
     IF v_end_num IN ('BP 02 86','BP 02 44') THEN
      SELECT v_pol_num, v_end_num,lpad(to_char(IARC.deductible/100),3,0), null, null, substr(ICED.parm14,1,2)||substr(ICED.parm14,4,1), substr(ICED.parm14,5,1)||decode(length(ICED.parm14), 10, substr(ICED.parm14,9,2), substr(ICED.parm14,7,2)) -- ADJUSTED TO START SENDING DATE FROM PARM1 7/30/2014      
        INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
        FROM ITEM_AT_RISK_COVERAGE IARC, IAR_COVERAGE_ENDT_DETAIL ICED
       WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num
         AND ICED.ITEM_AT_RISK_ID = v_iar_id AND ICED.COVERAGE_CODE = v_end_num;

      PIPE ROW(out_rec);

    ELSE

    
      -- MPL endorsement
    IF v_end_num = 'MPL1' THEN
      SELECT v_pol_num, v_end_num,lpad(to_char(IARC.deductible/100),3,0), ICED.parm2, ICED.parm3, substr(ICED.parm4,1,2)||substr(ICED.parm4,4,1), substr(ICED.parm4,5,1)||decode(length(ICED.parm4), 10, substr(ICED.parm4,9,2), substr(ICED.parm4,7,2)) -- CHANGED PARM4 YEAR TO CONDITIONAL SUBSTRING BASED ON 2 VS.4 DIGIT YEAR 7/16/2014
      INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.ITEM_AT_RISK_COVERAGE IARC, NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL ICED
      WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num
            AND ICED.ITEM_AT_RISK_ID = v_iar_id AND ICED.COVERAGE_CODE = v_end_num;

      PIPE ROW(out_rec);

    ELSE

      -- WD1 endorsement
    IF v_end_num = 'WD1' THEN
      SELECT v_pol_num, v_end_num,IARC.deductible,null, null, null, null
      INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.ITEM_AT_RISK_COVERAGE IARC
      WHERE IARC.ITEM_AT_RISK_ID = v_iar_id AND IARC.COVERAGE_CODE = v_end_num;

      PIPE ROW(out_rec);

    ELSE

     -- BP 02 48 NAMED STORM endorsement     -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
    IF v_end_num = 'BP 02 48' THEN
        SELECT v_pol_num, v_end_num, ICL.WIND_ZONE, ICL.WIND_DEDUCT_PCT, null, null, null
       INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
         FROM NEW_APDEV.IAR_COMPAK_LOCATION ICL
        WHERE ICL.ITEM_AT_RISK_ID = v_iar_id;

        PIPE ROW(out_rec);

    ELSE

      -- ALL OTHER COMPAK ENDORSEMENTS & DWELLING FIRE ENDORSEMENTS
    IF v_end_num in ('BP 05 76','BP 08 01','BP 08 02','BP 03 12','BP 05 78',
                     'BP 04 19','B+B-1','BP 05 75','815','813','BP 05 77','BP 12 03','BP 04 46',
                     'DF NS','DP 04 11','DP 04 71','DP 04 97','DP 04 70','DF-AC','HO-FRZ',
                     --'DL 34 09',
                     'DP 04 69') THEN
      SELECT v_pol_num, v_end_num,parm1,parm2,parm3,parm4,parm5
      INTO out_rec.EN_POL_NUM, out_rec.EN_END_NUM, out_rec.EN_COV_PARM_1, out_rec.EN_COV_PARM_2, out_rec.EN_COV_PARM_3, out_rec.EN_COV_PARM_4, out_rec.EN_COV_PARM_5
      FROM NEW_APDEV.IAR_COVERAGE_ENDT_DETAIL
      WHERE ITEM_AT_RISK_ID = v_iar_id AND COVERAGE_CODE = v_end_num
        AND COVERAGE_SEQ = 1;   --- Had to add coverage_seq due to how some endorsements are configured in new Compak/AQS and impact on Data Collect Trigger -- SHAYNES

      PIPE ROW(out_rec);

 -- Compak rewrite END


     END IF;-- PREMISES ALARM OR FIRE PROTECTION SYSTEM CREDIT COV PARM DATA COLLECT CONVERSION
      END IF;-- STRUCTURE RENTED TO OTHERS-RESIDENCE PREMISES COV PARM DATA COLLECT CONVERSION
      END IF;--ADDITIONAL INSURED COV PARM DATA COLLECT CONVERSION
       END IF;-- ELECTRONIC APPARATUS COV PARM DATA COLLECT CONVERSION
        END IF;-- JEWELRY, MONEY, SECURITIES, SILVERWARE, GUNS  COV PARM DATA COLLECT CONVERSION
         END IF;-- ORDINANCE OR LAW COVERAGE COV PARM DATA COLLECT CONVERSION
          END IF;-- ADDITIONAL RESIDENCE RENTED TO OTHERS COV PARM DATA COLLECT CONVERSION
           END IF;-- BUSINESS PURSUITS (EMPLOYMENT TYPE) COV PARM DATA COLLECT CONVERSION
            END IF;-- WATERCRAFT LIABILITY COV PARM DATA COLLECT CONVERSION
             END IF;-- ACCOUNT CREDIT COV PARM DATA COLLECT CONVERSION
              END IF;-- LOSS FREE CREDIT COV PARM DATA COLLECT CONVERSION
               END IF;-- ADDITIONAL RESIDENCE COV PARM DATA COLLECT CONVERSION
                END IF;-- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION
                 END IF;-- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION
                  END IF;-- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION
                   END IF;-- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION
                    END IF;-- WATERCRAFT (PD) COV PARM DATA COLLECT CONVERSION
                     END IF;-- ADDITIONAL RESIDENCE COV PARM DATA COLLECT CONVERSION
                      END IF;-- MOLD COV PARM DATA COLLECT CONVERSION
                       END IF;-- MOLD COV PARM DATA COLLECT CONVERSION
                        END IF;-- MOLD COV PARM DATA COLLECT CONVERSION
                         END IF;-- RESIDENCE HELD IN TRUST COV PARM DATA COLLECT CONVERSION
                          END IF;-- RENOVATED DWELLING CREDIT COV PARM DATA COLLECT CONVERSION
                           END IF;-- BED AND BREAKFAST COV PARM DATA COLLECT CONVERSION
                            END IF;-- YEAR OF CONSTRUCTION CREDIT COV PARM DATA COLLECT CONVERSION
                             END IF;-- WINDSTORM OR HAIL PERCENTAGE DEDUCT COV PARM DATA COLLECT CONVERSION HO 03 12
                              END IF; -- NAMED STORM COV PARM DATA COLLECT CONVERSION ND NS
                              END IF;-- WINDSTORM OR HAIL PERCENTAGE DEDUCT COV PARM DATA COLLECT CONVERSION HO WIND
                               END IF;-- TENANTS RELOCATION COVERAGE COV PARM DATA COLLECT CONVERSION
                                END IF;-- HOMEPAK COV PARM DATA COLLECT CONVERSION
                                 END IF;-- NEW BUYERS CREDIT NBC-92 COV PARM DATA COLLECT CONVERSION
                                  END IF;-- NEW BUYERS CREDIT NBC-05 COV PARM DATA COLLECT CONVERSION
                                   END IF;-- INFLATION GUARD HO 04 46 COV PARM DATA COLLECT CONVERSION
                                    END IF;-- NJ HURRICANE DEDUCTIBLE FM-HURR COV PARM DATA COLLECT CONVERSION
                                     END IF;-- NJ WIND RELATED DEDUCTIBLE MPL22 COV PARM DATA COLLECT CONVERSION
                                      END IF;-- HOME BUSINESS OPTION HO X7 01 PARM DATA COLLECT CONVERSION
           -- Compak Rewrite START
               END IF;-- AI ENDORSEMENTS
                END IF;-- BP 04 04 HIRED AND NON OWNED AUTO
              --   END IF;-- BP 04 04 HIRE AND NON OWNED POST COMPAK/AQS CONVERSION 2010  -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                 END IF;--BP 04 15 SPOILAGE COVERGAE
                  END IF;--D+O-1 DIRECTORS AND OFFICERS LIABILITY
                   END IF;--BP 01 86 AND IL 01 08 Directors and Officers Liability
                    END IF;--BP 22  Manual AI endorsement
                     END IF;--BP EP 00, BP EP 11  EPLI endorsements,EBLI, DRE1
                      END IF; --BP 04 98 (EMP BENEFITS), BP 02 50 , BP 14 31 (ESCAPED FUEL) ALL W/ RETROACTIVE DATE IN PARM1
                       END IF; --BP 17 24 W/ RETROACTIVE DATE IN PARM7
                        END IF;-- BP 02 86 & BP 02 44 DIGITAL RISK EACH RETROACTIVE DATE IN PARM14
                         END IF;--MPL endorsement
                        END IF;--WD1 endorsement
                         END IF; -- BP 02 48 NAMED STORM ENDORSEMENT  -- updated on 3/11/2014 to support Agency Download parms for Compak/AQS conv- shaynes
                          END IF;--ALL OTHER COMPAK ENDORSEMENTS
                             -- Compak Rewrite END
  RETURN;

END COV_PARMS;
/
