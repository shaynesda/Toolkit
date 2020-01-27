CREATE OR REPLACE PROCEDURE STAGING.POST_ITEM_LOAD  IS
/*
*****************************************************************************
   NAME:       STAGING.POST_ITEM_LOAD

   REVISIONS:
   VER        DATE        AUTHOR           DESCRIPTION
   ---------  ----------  ---------------  ------------------------------------
   1.0        8/24/2018    Vasudha           1. INITIAL RELEASE

   PURPOSE      SETS THE BOP COLUMNS FROM APDEV.OTACOMPAKPOLICY
                SETS THE CRU AND CRU DATE FROM APDEV.ITEM_AT_RISK

******************************************************************************/

V_ERR_MSG   VARCHAR2(1000) := '';
V_PROCNAME  VARCHAR2(20) := 'POST_ITEM_LOAD';
v_err_loc   varchar2(300);


BEGIN

   v_err_loc:='Updating clm_free_credit';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CLM_FREE_CREDIT, H.GROSS_SRR, H.INS_TO_VAL_CREDIT, H.OWNER_OCCUP_PERC) =(
         SELECT IARC.CLAIM_FREE_CREDIT ,IARC.GROSS_ANNUAL_SALES ,IARC.INSURANCE_TO_VALUE ,IARC.SOLE_OCCUPANCY_CREDIT
         FROM NEW_APDEV.ITEM_AT_RISK iar,
             NEW_APDEV.IAR_COMPAK iarc
         WHERE IAR.ITEM_AT_RISK_ID=IARC.ITEM_AT_RISK_ID
         AND  H.POL_NUM=IAR.POLICY_NUMBER
         AND H.ITEM_SEQ=IAR.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE='75'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

-- Load RPT_ITEM CRU and CRU_DT FROM APDEV.ITEM_AT_RISK

v_err_loc:='Updating CRU details';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CRU, H.CRU_DT) =
        (SELECT  IAR.TILL_GRID_VALUE,IAR.DATE_ENTERED
         FROM APDEV.ITEM_AT_RISK IAR
         WHERE IAR.POLICY_NUMBER = H.POL_NUM
         AND   IAR.WANG_ITEM_SEQ = H.ITEM_SEQ)
    WHERE H.POL_NUM IN (SELECT IR.POLICY_NUMBER
                        FROM APDEV.ITEM_AT_RISK IR
                        WHERE IR.USER_LINE_CODE = '06'
                        AND IR.TILL_GRID_VALUE IS NOT NULL)
    AND H.USER_LINE = '06'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);


 v_err_loc:='Updating Liability_symbol';

    UPDATE STAGING.HISTORY_WANG_ITEM H SET (H.LIABILITY_SYMBOL, H.PIP_MED_SYMBOL, H.ABS_FLAG) =
                                  (SELECT iara.LIABILITY_SYMBOL, iara.PIP_MED_SYMBOL, iara.ABS_FLAG
                                   FROM NEW_APDEV.IAR_AUTO iara, NEW_APDEV.ITEM_AT_RISK iar
                                   WHERE iara.ITEM_AT_RISK_ID = iar.ITEM_AT_RISK_ID
                                   AND H.POL_NUM = iar.POLICY_NUMBER
                                   AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.POL_NUM in (SELECT P.POLICY_NUMBER
                        FROM RPTVIEWER.RPT_POLICY P
                        WHERE P.RUN_DATE=(SELECT MAX(RUN_DATE)
                                          FROM RPTVIEWER.RPT_POLICY)
                        AND P.GROUP_LINE_CODE ='01'
                        AND P.STATE_ALPHA_CODE='NJ')
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

/*collecting alteration cost information for NJPPA  -- */

     v_err_loc:='Updating alt_cost';

    UPDATE STAGING.HISTORY_WANG_ITEM H SET ALT_COST=
                                        (SELECT IARA.ALTERATION_COST
                                         FROM NEW_APDEV.ITEM_AT_RISK iar,
                                              NEW_APDEV.IAR_AUTO iara
                                         WHERE H.SDS_LINE IN ('07')
                                         AND H.POL_NUM = IAR.POLICY_NUMBER
                                         AND H.ITEM_SEQ = IAR.WANG_ITEM_SEQ
                                         AND IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID)
    WHERE H.SDS_LINE='07'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

 /* collecting aPart time time employee  information for COMPAk --  */
  v_err_loc:='Updating Employees_Pt';

    UPDATE STAGING.HISTORY_WANG_ITEM H SET EMPLOYEES_PT=
                (SELECT IARA.NUMBER_PART_TIME
                 FROM NEW_APDEV.ITEM_AT_RISK iar,
                      NEW_APDEV.IAR_COMPAK iara
                 WHERE H.SDS_LINE IN ('75')
                 AND H.POL_NUM = IAR.POLICY_NUMBER
                 AND H.ITEM_SEQ = IAR.WANG_ITEM_SEQ
                 AND IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID)
    WHERE H.SDS_LINE='75'
    AND H.RUN_DATE = (SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;


/* collecting aPart time time employee  information for COMPAk --  */
  v_err_loc:='Updating from IAR_COMPAK';

-- added  mail_type, franchisee, parking_lot_garage_resp, number_seats_range load from NEW_APDEV.IAR_COMPAK
-- added flood_zone

    UPDATE STAGING.HISTORY_WANG_ITEM H SET (EMPLOYEES_PT, MALL_TYPE, FRANCHISEE, PARKING_LOT_GARAGE_RESP, NUMBER_SEATS_RANGE, FLOOD_ZONE)   =
                    (SELECT iara.NUMBER_PART_TIME, iara.MALL_TYPE, iara.FRANCHISEE, iara.PARKING_LOT_GARAGE_RESP, iara.NUMBER_SEATS_RANGE, iara.FLOOD_ZONE
                     FROM NEW_APDEV.ITEM_AT_RISK iar, NEW_APDEV.IAR_COMPAK iara
                     WHERE H.SDS_LINE IN ('75')
                     AND H.POL_NUM = iar.POLICY_NUMBER
                     AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
                     AND iar.ITEM_AT_RISK_ID = iara.ITEM_AT_RISK_ID)
    WHERE H.SDS_LINE ='75'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

 /* collecting include_in_payroll information for Workpak --*/

  v_err_loc:='Updating Include_in_Payroll';

    UPDATE STAGING.HISTORY_WANG_ITEM H SET INCLUDE_IN_PAYROLL=
                (SELECT IARA.INCLUDE_IN_PAYROLL
                  FROM NEW_APDEV.ITEM_AT_RISK iar,
                       NEW_APDEV.IAR_WORKERS_COMP iara
                  WHERE  H.SDS_LINE IN ('42')
                  AND H.POL_NUM = IAR.POLICY_NUMBER
                  AND H.ITEM_SEQ = IAR.WANG_ITEM_SEQ
                  AND IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID)
    WHERE H.SDS_LINE ='42'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

/* to add constuction code to Workpak items --*/

  v_err_loc:='Updating Construction Code';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET H.CONSTRUCT = (SELECT DISTINCT CONSTRUCTION_CODE
                       FROM (SELECT iar.POLICY_NUMBER, iar.WANG_ITEM_SEQ, nm.CONSTRUCTION_CODE
                             FROM NEW_APDEV.NAME nm, NEW_APDEV.ITEM_NAME itn, NEW_APDEV.ITEM_AT_RISK iar
                             WHERE nm.CONSTRUCTION_CODE IS NOT NULL
                             AND nm.NAME_ID = itn.NAME_ID
                             AND itn.ITEM_AT_RISK_ID = iar.ITEM_AT_RISK_ID
                             AND itn.ITEM_NAME_TYPE_CODE = '42') cc
                        WHERE cc.policy_number = H.POL_NUM
                        AND cc.WANG_ITEM_SEQ = H.ITEM_SEQ)
    WHERE H.SDS_LINE='42'
    AND H.RUN_DATE=(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

/* to load original Agentpak value for BOP Class Code and Business/Building Type --*/
/*
  v_err_loc:='Updating Class Code/Building Type';

for ri in (select i.policy_number,i.item_seq
                  from rptviewer.rpt_policy p,rptviewer.rpt_item i
                 where p.policy_number = i.policy_number
                  -- and p.policy_effective_Date>=to_date('06012014','mmddyyyy')COMMENTED ON 6/23/15 CV
                   and ((policy_effective_date>='1-jun-2014' and state_alpha_code='MA')OR(policy_effective_date>='1-MAY-2015' and state_alpha_code='NJ'))
                   --and p.policy_status_code = 'A'
                   and p.group_line_code = '75'
                   --and p.state_alpha_code = 'MA' COMMENTED ON 6/23/15 CV
                    and p.state_alpha_code IN ('MA','NJ')
                   and p.RUN_DATE = (select max(run_date) from rpt_policy))
  loop
begin
update rptviewer.rpt_item i
   set (i.class_code, i.build_type) = (select distinct CLASS_CODE, BUSINESS_TYPE_CODE
                                         from
                                     ( BOP CLASS LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICB.CLASS_CODE, 7, 0) CLASS_CODE,  ICB.BUSINESS_TYPE_CODE
                                        from new_apdev.iar_compak_bus_class icb, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icb.item_at_risk_id
                                      union
                                       BOP BUILDING LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICB.MASTER_CLASS_CODE, 7, 0) CLASS_CODE,  ICB.BUILD_BUS_TYPE_CODE
                                        from new_apdev.iar_compak_building icb, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icb.item_at_risk_id
                                       union
                                       /* BOP LOCATION LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICL.MASTER_CLASS_CODE, 7, 0) CLASS_CODE, ICB.BUILD_BUS_TYPE_CODE
                                        from (select parent_item_at_risk_id, master_class_code, build_bus_type_code
                                                from new_apdev.iar_compak_building) icb,
                                                     new_apdev.iar_compak_location icl, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icl.item_at_risk_id
                                         and icb.parent_item_at_risk_id = ICL.ITEM_AT_RISK_ID
                                         and icb.master_class_code = icl.master_class_code
                                       union
                                       /* BOP POLICY LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE
                                      select distinct iar.policy_number, 999 WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICL.MASTER_CLASS_CODE, 7, 0) CLASS_CODE, ICB.BUILD_BUS_TYPE_CODE
                                        from (select parent_item_at_risk_id, master_class_code, build_bus_type_code
                                                from new_apdev.iar_compak_building) icb,
                                              (select min(wang_item_seq) wang_item_seq, policy_number
                                                 from new_apdev.item_at_risk
                                                where user_line_code = '75'
                                                group by policy_number) mn,
                                              new_apdev.iar_compak_location icl, new_apdev.item_at_risk iar
                                        where iar.item_at_risk_id = icl.item_at_risk_id
                                          and icb.parent_item_at_risk_id = icl.item_at_risk_id
                                          and icb.master_class_code = icl.master_class_code
                                          and iar.policy_number = mn.policy_number
                                          and iar.wang_item_seq = mn.wang_item_seq) CLS_UPD
                                        where I.POLICY_NUMBER = CLS_UPD.POLICY_NUMBER
                                          and I.ITEM_SEQ = CLS_UPD.WANG_ITEM_SEQ)
  where    i.run_date=(select max(run_date) from rpt_policy)
    and i.policy_number=ri.policy_number
    and i.item_seq=RI.ITEM_SEQ */
    /*and exists (select 1
                  from rptviewer.rpt_policy p
                 where p.policy_number = i.policy_number
                   and p.policy_effective_Date>=to_date('06012014','mmddyyyy')
                   --and p.policy_status_code = 'A'
                   and p.group_line_code = '75'
                   and p.state_alpha_code = 'MA'
                   and p.RUN_DATE = (select max(run_date) from rpt_policy))
        ;
commit;
 exception
 when others then
 null;

end;

end loop;

commit;*/

/* to load the Building Owner Occupancy Percent --*/


   v_err_loc:='Updating Owner Occupancy Percent';


     UPDATE STAGING.HISTORY_WANG_ITEM H
     SET H.OWNER_OCCUP_PERC = (SELECT iarc.OWNER_OCCUPANCY_PCT
                          FROM NEW_APDEV.ITEM_AT_RISK iar,
                                          NEW_APDEV.IAR_COMPAK_BUILDING iarc
                          WHERE iar.ITEM_AT_RISK_ID = iarc.ITEM_AT_RISK_ID
                          AND H.POL_NUM =iar.POLICY_NUMBER
                          AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE='76'
    AND H.OWNER_OCCUP_PERC IS NULL
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;


-- Added to include additional BOP data --
 v_err_loc:='Updating BOP Building Attributes';


    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.DWELL_CODE,
              H.SQ_FEET,
              H.NUM_UNITS,
              H.BLANK_IND,
              H.SPRINKLERS,
              H.WIRING_YEAR_UPDATE,
              H.CONDO_BUILD_LIMIT,
              H.INS_OWNED_SFT ) = (SELECT iarc.SEASONAL,
                                               substr(iarc.BUILDING_SFT, 1, 7), -- to accept only the first 7 bytes
                                               NVL(iarc.NUMBER_OF_UNITS,
                                               iarc.NUMBER_APARTMENTS),
                                               iarc.INCLUDE_BLDG_IN_BLANKET,
                                               iarc.SPRINKLERS,
                                               iarc.wire_year_upd,
                                               IARC.CONDO_BUILD_LIMIT,
                                               IARC.INS_OWNED_SFT
                                   FROM NEW_APDEV.ITEM_AT_RISK iar,
                                               NEW_APDEV.IAR_COMPAK_BUILDING iarc
                                   WHERE iar.ITEM_AT_RISK_ID = iarc.ITEM_AT_RISK_ID
                                   AND H.POL_NUM =iar.POLICY_NUMBER
                                   AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE='76'
    AND H.RUN_DATE = (SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

v_err_loc:= 'Updating BOP Location Attributes';  --'Updating Flood Zone' --VASUDHA;


    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.FLOOD_ZONE,
            H.FIRE_STATION_DIST_BAND,
            H.ELEVATION_RANGE_LOW_FEET,
            H.ELEVATION_RANGE_HIGH_FEET,
            H.WIND_DED_PCT,
            H.REIN_LOCATION) =  (SELECT iarcl.FLOOD_ZONE,
                                       iarcl.FIRE_STATION_DIST_BAND,
                                       iarcl.ELEVATION_RANGE_LOW_FEET,
                                       iarcl.ELEVATION_RANGE_HIGH_FEET,  -- Added Fire Station Dist Band to include additional BOP data
                                       iarcl.WIND_DEDUCT_PCT,            --Added wind deductible percentage
                                       NVL(iarcl.REIN_LOCATION_NUM, iarcl.SYS_REIN_LOCATION_NUM) --Added Reinsurance Location
                                  FROM NEW_APDEV.ITEM_AT_RISK iar,
                                        NEW_APDEV.IAR_COMPAK_LOCATION iarcl
                                  WHERE iar.ITEM_AT_RISK_ID=iarcl.ITEM_AT_RISK_ID
                                  AND H.POL_NUM = iar.POLICY_NUMBER
                                  AND iar.USER_LINE_CODE = '75'
                                  AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE ='75'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;


   -- ADDED Roof Age calculation for Dwelling Fire to support ISO STAT changes --------------
/*    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.ROOF_YEAR) =(SELECT GET_ROOF_YEAR(ri.POLICY_NUMBER)
                    FROM RPTVIEWER.RPT_ITEM ri
                    WHERE RI.SDS_LINE = '22'
                    AND ri.POLICY_NUMBER = H.POL_NUM
                    AND ri.ITEM_SEQ = H.ITEM_SEQ
                    AND ri.RUN_DATE = (SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY))
    WHERE H.SDS_LINE='22'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);
COMMENTED OUT THIS SECTION AFTER A DISCUSSION WITH CHANDU ON JULY 17TH 2018. THIS UPDATION IS NOT NEEDED.
COMMIT;--------------------------------------------------------------------------------------------------------------------------------------*/

v_err_loc:= 'Updating BOP Class Attributes';  --'Updating Flood Zone'--

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.GROSS_SRR,
            H.RATE_NUMBER,
            H.CLASS_GROUP,
            H.LIABILITY_EXPOSURE_BASE,
            H.PAYROLL)  = (SELECT iarcbc.GROSS_ANNUAL_SALES,
                                  iarcbc.RATE_NUMBER,
                                  iarcbc.CLASS_GROUP,
                                  iarcbc.LIAB_EXP_BASE,
                                  iarcbc.PAYROLL
                           FROM NEW_APDEV.ITEM_AT_RISK iar,
                                NEW_APDEV.IAR_COMPAK_BUS_CLASS iarcbc
                           WHERE iar.ITEM_AT_RISK_ID = iarcbc.ITEM_AT_RISK_ID
                           AND H.POL_NUM = iar.POLICY_NUMBER
                           AND iar.USER_LINE_CODE = '77'
                           AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE='77'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

 COMMIT;

---Added 6/14/2018 --
 v_err_loc:='Updating COASTAL';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (COASTAL, COASTAL_TRANSITION)=
        (SELECT ipd.COASTAL,ipd.COASTAL_TRANSITION
        FROM NEW_APDEV.ITEM_AT_RISK iar,
             NEW_APDEV.IAR_PERSONAL_DWELLING  ipd
        WHERE H.SDS_LINE IN ('24','22')
        AND H.POL_NUM = IAR.POLICY_NUMBER
        AND H.SDS_LINE = IAR.USER_LINE_CODE
        AND H.ITEM_SEQ=IAR.WANG_ITEM_SEQ
        AND IAR.ITEM_AT_RISK_ID = ipd.ITEM_AT_RISK_ID)
    WHERE SDS_LINE IN('24','22')
    AND H.POL_NUM IN(SELECT POLICY_NUMBER FROM  RPTVIEWER.RPT_POLICY WHERE GROUP_LINE_CODE='24' OR(GROUP_LINE_CODE='22' AND POLICY_EFFECTIVE_DATE>=TO_DATE('01012019','MMDDYYYY') AND RUN_DATE=(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY) ))
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;


-- 26 line (Farmowner) load of Cause Of Loss for Coverage E Farm --

v_err_loc:='Updating Cause_of_loss_e';


    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS_COV_E) =
        (SELECT acol.CAUSE_OF_LOSS_CODE
        FROM NEW_APDEV.ITEM_AT_RISK iar,
          NEW_APDEV.IAR_FARM_OWNERS ifo,
          RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
        WHERE iar.ITEM_AT_RISK_ID = ifo.ITEM_AT_RISK_ID
        AND H.POL_NUM = iar.POLICY_NUMBER
        AND iar.USER_LINE_CODE = '26'
        AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
        AND IFO.USFPP_CAUSE_OF_LOSS = ACOL.CAUSE_OF_LOSS
        AND NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_NA, 'N')    = ACOL.COL_EXL_NA
        AND NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_HAIL, 'N')  = ACOL.COL_EXL_HAIL_D
        AND NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_THEFT, 'N') = ACOL.COL_EXL_THEFT_A
        AND NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_VAND, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE ='26'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;
-- 26 line (Farmowner) load of Cause Of Loss for Coverage B Home --

v_err_loc:='Updating Cause_of_loss_b';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS_COV_B) =
        (SELECT acol.CAUSE_OF_LOSS_CODE
         FROM NEW_APDEV.ITEM_AT_RISK iar,
              NEW_APDEV.IAR_FARM_OWNERS ifo,
              RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
         WHERE iar.ITEM_AT_RISK_ID=ifo.ITEM_AT_RISK_ID
         AND H.POL_NUM = iar.POLICY_NUMBER
         AND iar.USER_LINE_CODE = '26'
         AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
         AND IFO.USHHPP_CAUSE_OF_LOSS = ACOL.CAUSE_OF_LOSS
         AND NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_NA, 'N')    = ACOL.COL_EXL_NA
         AND NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_HAIL, 'N')  = ACOL.COL_EXL_HAIL_D
         AND NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_THEFT, 'N') = ACOL.COL_EXL_THEFT_A
         AND NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_VAND, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE='26'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

 COMMIT;

 -- 27 line (Farmowner Building Structure) load of Cause Of Loss --

v_err_loc:='Updating Cause_of_loss_bldg_struct';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS) =
        (SELECT acol.CAUSE_OF_LOSS_CODE
         FROM NEW_APDEV.ITEM_AT_RISK iar,
              NEW_APDEV.IAR_FARM_OWNERS_BLDG_ST ifo,
              RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
         WHERE iar.ITEM_AT_RISK_ID=ifo.ITEM_AT_RISK_ID
         AND H.POL_NUM = iar.POLICY_NUMBER
         AND iar.USER_LINE_CODE = '27'
         AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
         AND IFO.CAUSE_OF_LOSS = ACOL.CAUSE_OF_LOSS
         AND NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N') = ACOL.COL_EXL_NA
         AND NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
         AND NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
         AND NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE='27'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

-- 70 line (Farmowner Commercial Inland Marine) load of Cause Of Loss --

v_err_loc:='Updating Cause_of_loss_coml_im';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS) =
        (SELECT acol.CAUSE_OF_LOSS_CODE
            FROM NEW_APDEV.ITEM_AT_RISK iar,
                 NEW_APDEV.IAR_COMMERCIAL_INLAND_MARINE ifo,
                (SELECT POLICY_NUMBER
                 FROM NEW_APDEV.POLICY
                 WHERE GROUP_LINE_CODE = '26') fo,
                 RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
            WHERE iar.ITEM_AT_RISK_ID=ifo.ITEM_AT_RISK_ID
            AND iar.POLICY_NUMBER = fo.POLICY_NUMBER
            AND H.POL_NUM = iar.POLICY_NUMBER
            AND iar.USER_LINE_CODE = '70'
            AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
            AND IFO.CAUSE_OF_LOSS  = ACOL.CAUSE_OF_LOSS
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')  = ACOL.COL_EXL_NA
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')  = ACOL.COL_EXL_THEFT_A
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE='70'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

 -- 24 line (Farmowner Permanent Structure HO) load of Cause Of Loss --

v_err_loc:='Updating Cause_of_loss_dwelling';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS)  =
           (SELECT acol.CAUSE_OF_LOSS_CODE
            FROM NEW_APDEV.ITEM_AT_RISK iar,
                 NEW_APDEV.IAR_PERSONAL_DWELLING ifo,
                (SELECT POLICY_NUMBER FROM NEW_APDEV.POLICY WHERE GROUP_LINE_CODE = '26') fo,
                 RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
            WHERE iar.ITEM_AT_RISK_ID = ifo.ITEM_AT_RISK_ID
            AND H.POL_NUM = iar.POLICY_NUMBER
            AND iar.POLICY_NUMBER = fo.POLICY_NUMBER
            AND iar.USER_LINE_CODE = '24'
            AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
            AND IFO.CAUSE_OF_LOSS  = ACOL.CAUSE_OF_LOSS
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')  = ACOL.COL_EXL_NA
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
            AND NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE ='24'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;
 -- 32 line (Farmowner Mobilehome) load of Cause Of Loss --

v_err_loc:='Updating Cause_of_loss_mobilehome';

    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.CAUSE_OF_LOSS)  =
            (SELECT acol.CAUSE_OF_LOSS_CODE
             FROM NEW_APDEV.ITEM_AT_RISK iar,
                  NEW_APDEV.IAR_MOBILEHOME ifo,
                  (SELECT POLICY_NUMBER FROM NEW_APDEV.POLICY WHERE GROUP_LINE_CODE = '26') fo,
                  RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
             WHERE iar.ITEM_AT_RISK_ID = ifo.ITEM_AT_RISK_ID
             AND iar.POLICY_NUMBER = fo.POLICY_NUMBER
             AND H.POL_NUM = iar.POLICY_NUMBER
             AND iar.USER_LINE_CODE = '32'
             AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ
             AND IFO.CAUSE_OF_LOSS  = ACOL.CAUSE_OF_LOSS
             AND NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N') = ACOL.COL_EXL_NA
             AND NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
             AND NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N') = ACOL.COL_EXL_THEFT_A
             AND NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
    WHERE H.SDS_LINE ='32'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

v_err_loc:='Updating Missouri Territory';

 -- Added Missouri territory code decode --
    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.TERR) =
        (SELECT DECODE(LENGTH(TRIM(TRANSLATE(FTC.TERRITORY_CODE, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', ' '))),
                                 NULL, FTC.TERRITORY_CODE,
                                 lpad(ftc.TERRITORY_CODE, 5, '0'))  -- if territory code is not alpha numeric pad with 0's
         FROM RPTVIEWER.RPT_ITEM ri,
              (SELECT DISTINCT STATE_ALPHA_CODE, TERRITORY_CODE, WANG_TERRITORY_CODE
               FROM NEW_APDEV.R_FO_ZIP_TERRITORY_CODE
               WHERE STATE_ALPHA_CODE = 'MO'
               UNION
               SELECT DISTINCT STATE_ALPHA_CODE, TERRITORY_CODE, WANG_TERRITORY_CODE
               FROM NEW_APDEV.R_FO_TERRITORY_CODE
               WHERE STATE_ALPHA_CODE = 'MO') FTC
         WHERE ri.ITEM_STATE = 'MO'
         AND ri.POLICY_NUMBER = H.POL_NUM
         AND ri.ITEM_SEQ = H.ITEM_SEQ
         AND ri.ITEM_STATE = ftc.STATE_ALPHA_CODE
         AND ri.TERR = ftc.WANG_TERRITORY_CODE
         AND ri.TERR = lpad(ftc.WANG_TERRITORY_CODE, 5, '0')
         AND ri.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY))
    WHERE H.ITEM_STATE = 'MO'
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

          v_err_loc:='Updating IRPM Deviation';

-- Adding IRPM Deviation for CU  --
    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.IRPM_DEVIATION) =
        (SELECT SUM(PI.IRPM_PCT)*.01
         FROM NEW_APDEV.POLICY_IRPM PI
         WHERE H.POL_NUM = PI.POLICY_NUMBER)
    WHERE H.USER_LINE in ('26', '46','10')
    AND H.USER_LINE = H.SDS_LINE
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;

 -- FLOOD ZONE for Homeowners. --
 --ADDED ROOF_COVER, TRAMPOLINE AND ROOF_AGE #  for ISO STAT changes
    UPDATE STAGING.HISTORY_WANG_ITEM H
    SET (H.FLOOD_ZONE, H.ROOF_TYPE, H.SQ_FEET,H.TRAMPOLINE,H.ROOF_YEAR) =
                    (SELECT IPD.FLOOD_ZONE,
                            IPD.ROOF_COVER,
                            SUBSTR((REGEXP_REPLACE(TOT_SQR_FT,'[^[:digit:]]+',null)),1,7),
                            UI.TRAMPOLINE,
                            RPTVIEWER.GET_ROOF_YEAR(IAR.POLICY_NUMBER)
                     FROM  NEW_APDEV.ITEM_AT_RISK iar,
                           NEW_APDEV.IAR_PERSONAL_DWELLING ipd,
                           NEW_APDEV.UNDERWRITING_INFO ui
                     WHERE iar.ITEM_AT_RISK_ID = ipd.ITEM_AT_RISK_ID
                     AND H.POL_NUM = iar.POLICY_NUMBER
                     AND iar.USER_LINE_CODE IN( '24','22')
                     AND ui.POLICY_NUMBER(+) = iar.POLICY_NUMBER
                     AND H.ITEM_SEQ = iar.WANG_ITEM_SEQ)
    WHERE H.SDS_LINE IN('22','24')
    AND H.POL_NUM IN(SELECT POLICY_NUMBER FROM  RPTVIEWER.RPT_POLICY WHERE GROUP_LINE_CODE='24' OR(GROUP_LINE_CODE='22' AND POLICY_EFFECTIVE_DATE>=TO_DATE('01012019','MMDDYYYY') AND RUN_DATE=(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY) ))
    AND H.RUN_DATE =(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;


EXCEPTION
    WHEN NO_DATA_FOUND  THEN
        NULL;
    WHEN OTHERS THEN
        V_ERR_MSG:='FAILED AT'||v_err_loc||SQLCODE||':'||SQLERRM(SQLCODE)||V_PROCNAME;
        RPTVIEWER.RPT_UTIL.WRITE_ERROR(V_PROCNAME,V_ERR_MSG);

END;
/
