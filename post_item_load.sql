CREATE OR REPLACE PROCEDURE RPTVIEWER.POST_ITEM_LOAD    IS
/******************************************************************************
   NAME:       RPTVIEWER.POST_ITEM_LOAD

   REVISIONS:
   VER        DATE        AUTHOR           DESCRIPTION
   ---------  ----------  ---------------  ------------------------------------
   1.0        5/11/2009    MJM             1. INITIAL RELEASE
   1.1        6/10/2009    MJM             1,1. Removed Check of Potential Updates vs. Actuals
                                               and Error Message.
   2.0        5/22/2009    MJM             2.  Added Logic to Update the CRU and CRU_DT fields.
   3.0        12/10/2009   CHANDU          3.  Added logic to update tort value.
   4.0        12/31/2009   KERIANN         4.  Added logic to update LIABILTIY_SYMBOL, PIP_MED_SYMBOL, and ABS_FLAG
   5.0        03/04/2010   CHANDU          5.  Added logic to load alt_cost, employees_pt,include_in_payroll
   6.0        07/29/2011   CHANDU          6.  REMOVED The part loading tort as part of bug 18025
   7.0        08/17/2012   SHAYNES         7.  Added logic to load ADVANCE_PURCHASE, EMPLOYEES_PT, MALL_TYPE, FRANCHISEE, PARKING_LOT_GARAGE_RESP, NUMBER_SEATS_RANGE
                                               from APDEV ITEM_AT_RISK_MA_AUTO NEW_APDEV IAR_COMPAK.
   8.0        02/20/2015   SHAYNES         8.  Added Flood Zone from IAR_COMPAK, IAR_COMPAK_LOCATION and IAR_PERSONAL_DWELLING.
   9.0        05/22/15     CV              9.  Added the part to update coastal and transistion_coastal for HO.
  10.0        04/15/2016   SHAYNES         10. Update of Wind Deductible percentage for Compak.
  11.0        07/22/2016   SHAYNES         11. Added ROOF_COVER, TRAMPOLINE AND ROOF_YEAR  for ISO Stat Changes.  Roof Year calling new function GET_ROOF_YEAR()
  12.0        09/23/2016   SHAYNES         12. Updated Cause of Loss data for ARFO LOB.
  13.0        09/23/2016   SHAYNES         13. Added Reinsurance Location for Compak to RPT_ITEM and updated Post Load.
  14.0        2/17/2017    SHAYNES         14. Added the update of Territories for Missouri territories originally defined as alpha numeric
  15.0        4/7/2017     PSHETTY         15. Added the update of Square Footage for Homeowner items.
  16.0        7/7/2017     SHAYNES         16. Added the update of Payroll for Compak items
  17.0        3/16/2018    VNG             17. Adding update of IRPM_DEVIATION for CU


   PURPOSE      SETS THE BOP COLUMNS FROM APDEV.OTACOMPAKPOLICY
                SETS THE CRU AND CRU DATE FROM APDEV.ITEM_AT_RISK

******************************************************************************/

V_ERR_MSG   VARCHAR2(1000) := '';
V_PROCNAME  VARCHAR2(20) := 'POST_ITEM_LOAD';
v_err_loc   varchar2(300);


BEGIN
 INSERT INTO rptviewer.load_log (event_date,
                                           event_routine,
                                      event_message)
                                 VALUES (SYSDATE,
                                           V_PROCNAME,
                                      'Post Item Started');


      COMMIT;
   v_err_loc:='Updating clm_free_credit';

update rptviewer.rpt_item i
  SET (i.CLM_FREE_CREDIT, i.GROSS_SRR, i.INS_TO_VAL_CREDIT, i.OWNER_OCCUP_PERC) =(
  SELECT IARC.CLAIM_FREE_CREDIT ,IARC.GROSS_ANNUAL_SALES ,IARC.INSURANCE_TO_VALUE ,IARC.SOLE_OCCUPANCY_CREDIT
         FROM NEW_APDEV.ITEM_AT_RISK iar,
             NEW_APDEV.IAR_COMPAK iarc
                      WHERE IAR.ITEM_AT_RISK_ID=IARC.ITEM_AT_RISK_ID
         and  I.POLICY_NUMBER=IAR.POLICY_NUMBER
         and I.ITEM_SEQ=IAR.WANG_ITEM_SEQ)
         where I.SDS_LINE='75'
         and I.RUN_DATE=(select max(run_date) from rptviewer.rpt_policy);

         commit;


-- Load RPT_ITEM CRU and CRU_DT FROM APDEV.ITEM_AT_RISK  MJM  5/22/2007

v_err_loc:='Updating CRU details';

    UPDATE RPT_ITEM A
    SET (A.CRU, A.CRU_DT) =
        (SELECT  IAR.TILL_GRID_VALUE,IAR.DATE_ENTERED
         FROM APDEV.ITEM_AT_RISK IAR
         WHERE IAR.POLICY_NUMBER = A.POLICY_NUMBER
         AND   IAR.WANG_ITEM_SEQ = A.ITEM_SEQ)
    WHERE A.POLICY_NUMBER IN (SELECT IR.POLICY_NUMBER  FROM APDEV.ITEM_AT_RISK IR WHERE IR.USER_LINE_CODE = '06'
                    AND IR.TILL_GRID_VALUE IS NOT NULL)
    AND A.USER_LINE = '06'
    AND A.POLICY_NUMBER IN (SELECT I.POL_NUM  FROM STAGING.STG_WF_WANG_ITEM I WHERE I.USER_LINE = '06');


 v_err_loc:='Updating Liability_symbol';

            UPDATE rpt_item I SET (liability_symbol, pip_med_symbol, abs_flag) =
                                  (SELECT iara.liability_symbol, iara.pip_med_symbol, iara.abs_flag
                                   FROM new_apdev.iar_auto iara, new_apdev.item_at_risk iar
                                   WHERE iara.item_at_risk_id = iar.item_at_risk_id
                                   AND i.policy_number=iar.policy_number and i.item_seq=iar.wang_item_seq)
                                   WHERE policy_number in (SELECT policy_number
                                                  FROM rpt_policy
                                                  WHERE run_date=(SELECT max(run_date)
                                                                  FROM rpt_policy)
                                                    and group_line_code='01'
                                                    and state_alpha_code='NJ');

COMMIT;


/* added by chandu 03/04/2010 collecting alteration cost information for NJPPA*/

     v_err_loc:='Updating alt_cost';
   update rpt_item i set alt_cost=(
select IARA.ALTERATION_COST
from
new_apdev.item_at_risk iar,
NEW_APDEV.IAR_AUTO iara
where   I.SDS_LINE IN ('07') AND
  I.POLICY_NUMBER = IAR.POLICY_NUMBER AND
  I.ITEM_SEQ = IAR.WANG_ITEM_SEQ AND
  IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID
)
where sds_line='07'
and run_date=(select max(run_date) from rpt_policy);

commit;

 /* added by chandu 03/04/2010 collecting aPart time time employee  information for COMPAk*/
  v_err_loc:='Updating Employees_Pt';

update rpt_item i set employees_pt=(
select IARA.number_part_time
from
new_apdev.item_at_risk iar,
NEW_APDEV.IAR_compak iara
where   I.SDS_LINE IN ('75') AND
  I.POLICY_NUMBER = IAR.POLICY_NUMBER AND
  I.ITEM_SEQ = IAR.WANG_ITEM_SEQ AND
  IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID
)
where sds_line='75'
and run_date=(select max(run_date) from rpt_policy);

commit;


 /* added by chandu 03/02/2010 collecting aPart time time employee  information for COMPAk*/
  v_err_loc:='Updating from IAR_COMPAK';

-- added  mail_type, franchisee, parking_lot_garage_resp, number_seats_range load from NEW_APDEV.IAR_COMPAK  8/10/2012 SHAYNES
-- added flood_zone 2/16/2015 SHAYNES

update rpt_item i set (employees_pt, mall_type, franchisee, parking_lot_garage_resp, number_seats_range, flood_zone)   =(
select iara.number_part_time, iara.mall_type, iara.franchisee, iara.parking_lot_garage_resp, iara.number_seats_range, flood_zone
  from new_apdev.item_at_risk iar, new_apdev.IAR_compak iara
 where i.SDS_LINE IN ('75')
   and i.POLICY_NUMBER = iar.POLICY_NUMBER
   and i.ITEM_SEQ = iar.WANG_ITEM_SEQ
   and iar.ITEM_AT_RISK_ID = iara.ITEM_AT_RISK_ID
)
where sds_line='75'
  and run_date=(select max(run_date) from rpt_policy);

commit;

 /* added by chandu 03/04/2010 collecting include_in_payroll information for Workpak*/

  v_err_loc:='Updating Include_in_Payroll';

update rpt_item i set include_in_payroll=(
select IARA.include_in_payroll
from
new_apdev.item_at_risk iar,
NEW_APDEV.iar_workers_comp iara
where   I.SDS_LINE IN ('42') AND
  I.POLICY_NUMBER = IAR.POLICY_NUMBER AND
  I.ITEM_SEQ = IAR.WANG_ITEM_SEQ AND
  IAR.ITEM_AT_RISK_ID = IARA.ITEM_AT_RISK_ID
)
where sds_line='42'
and run_date=(select max(run_date) from rpt_policy);

COMMIT;

 /* added by shaynes 7/31/2013 in order to add constuction code to Workpak items*/

  v_err_loc:='Updating Construction Code';

update rptviewer.rpt_item i
   set i.CONSTRUCT = (select distinct CONSTRUCTION_CODE
                        from (select iar.POLICY_NUMBER, iar.WANG_ITEM_SEQ, nm.CONSTRUCTION_CODE
                                from NEW_APDEV.NAME nm, NEW_APDEV.ITEM_NAME itn, NEW_APDEV.ITEM_AT_RISK iar
                               where nm.construction_code is not null
                                 and nm.name_id = itn.name_id
                                 and itn.item_at_risk_id = iar.item_at_risk_id
                                 and itn.item_name_type_code = '42') cc
                       where cc.policy_number = i.POLICY_NUMBER
                         and cc.wang_item_seq = i.ITEM_SEQ)
where sds_line='42'
  and run_date=(select max(run_date) from rpt_policy);

commit;

/* added by shaynes 7/15/2014 in order to load original Agentpak value for BOP Class Code and Business/Building Type*/

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
                                     (/* BOP CLASS LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE */
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICB.CLASS_CODE, 7, 0) CLASS_CODE,  ICB.BUSINESS_TYPE_CODE
                                        from new_apdev.iar_compak_bus_class icb, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icb.item_at_risk_id
                                      union
                                      /* BOP BUILDING LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE */
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICB.MASTER_CLASS_CODE, 7, 0) CLASS_CODE,  ICB.BUILD_BUS_TYPE_CODE
                                        from new_apdev.iar_compak_building icb, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icb.item_at_risk_id
                                       union
                                       /* BOP LOCATION LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE */
                                      select distinct iar.policy_number, IAR.WANG_ITEM_SEQ, IAR.USER_LINE_CODE, rpad(ICL.MASTER_CLASS_CODE, 7, 0) CLASS_CODE, ICB.BUILD_BUS_TYPE_CODE
                                        from (select parent_item_at_risk_id, master_class_code, build_bus_type_code
                                                from new_apdev.iar_compak_building) icb,
                                                     new_apdev.iar_compak_location icl, new_apdev.item_at_risk iar
                                       where iar.item_at_risk_id = icl.item_at_risk_id
                                         and icb.parent_item_at_risk_id = ICL.ITEM_AT_RISK_ID
                                         and icb.master_class_code = icl.master_class_code
                                       union
                                       /* BOP POLICY LEVEL CLASS_CODE AND BUSINESS/BUILD_TYPE CODE UPDATE */
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
    and i.item_seq=RI.ITEM_SEQ
    /*and exists (select 1
                  from rptviewer.rpt_policy p
                 where p.policy_number = i.policy_number
                   and p.policy_effective_Date>=to_date('06012014','mmddyyyy')
                   --and p.policy_status_code = 'A'
                   and p.group_line_code = '75'
                   and p.state_alpha_code = 'MA'
                   and p.RUN_DATE = (select max(run_date) from rpt_policy))*/
        ;
commit;
 exception
 when others then
 null;

end;

end loop;

commit;

/* added by shaynes 11/20/2014 in order to load the Building Owner Occupancy Percent */


   v_err_loc:='Updating Owner Occupancy Percent';


      update rptviewer.rpt_item i
         set i.owner_occup_perc = (select iarc.owner_occupancy_pct
                                     from new_apdev.item_at_risk iar,
                                          new_apdev.iar_compak_building iarc
                                    where iar.item_at_risk_id=iarc.item_at_risk_id
                                      and i.policy_number=iar.policy_number
                                      and i.item_seq=iar.wang_item_seq)
       where i.sds_line='76'
         and i.owner_occup_perc is null
         and i.run_date=(select max(run_date) from rptviewer.rpt_policy);


commit;


-- Added to include additional BOP data 2/10/2016 shaynes
 v_err_loc:='Updating BOP Building Attributes';


      update rptviewer.rpt_item i
         set (i.dwell_code,
              i.sq_feet,
              i.num_units,
              i.blank_ind,
              i.sprinklers,
              i.wiring_year_update,
              I.CONDO_BUILD_LIMIT,
              I.INS_OWNED_SFT ) = (select iarc.SEASONAL,
                                               substr(iarc.BUILDING_SFT, 1, 7), -- updated to accept only the first 7 bytes - 3/20/2017 shaynes
                                               NVL(iarc.NUMBER_OF_UNITS,
                                               iarc.NUMBER_APARTMENTS),
                                               iarc.INCLUDE_BLDG_IN_BLANKET,
                                               iarc.SPRINKLERS,
                                               iarc.wire_year_upd,
                                               IARC.CONDO_BUILD_LIMIT,
                                               IARC.INS_OWNED_SFT
                                          from new_apdev.item_at_risk iar,
                                               new_apdev.iar_compak_building iarc
                                         where iar.item_at_risk_id=iarc.item_at_risk_id
                                           and i.policy_number=iar.policy_number
                                           and i.item_seq=iar.wang_item_seq)
       where i.sds_line='76'
         and i.run_date=(select max(run_date) from rptviewer.rpt_policy);


commit;

v_err_loc:= 'Updating BOP Location Attributes';  --'Updating Flood Zone';


    update rptviewer.rpt_item i
       set (i.flood_zone,
            i.fire_station_dist_band,
            i.elevation_range_low_feet,
            i.elevation_range_high_feet,
            i.wind_ded_pct,
            i.rein_location) =  (select iarcl.flood_zone,
                                       iarcl.fire_station_dist_band,
                                       iarcl.ELEVATION_RANGE_LOW_FEET,
                                       iarcl.ELEVATION_RANGE_HIGH_FEET,  -- Added Fire Station Dist Band to include additional BOP data 2/10/2016 shaynes
                                       iarcl.WIND_DEDUCT_PCT,            --Added wind deductible percentage 4/15/2016 shaynes
                                       NVL(iarcl.REIN_LOCATION_NUM, iarcl.SYS_REIN_LOCATION_NUM) --Added Reinsurance Location 9/23/2016
                                   from new_apdev.item_at_risk iar,
                                        new_apdev.iar_compak_location iarcl
                                  where iar.item_at_risk_id=iarcl.item_at_risk_id
                                    and i.policy_number=iar.policy_number
                                    and iar.user_line_code = '75'
                                                and i.item_seq=iar.wang_item_seq)
     where i.sds_line='75'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

 commit;


 -- FLOOD ZONE for Homeowners.  Added on 2/16/2015 SHAYNES
 --ADDED ROOF_COVER, TRAMPOLINE AND ROOF_AGE #  for ISO STAT changes 7/22/2016 SHAYNES
    update rptviewer.rpt_item i
       set (i.flood_zone, roof_type, sq_feet, trampoline, roof_year) =(select IPD.FLOOD_ZONE, IPD.ROOF_COVER, SUBSTR((REGEXP_REPLACE(TOT_SQR_FT,'[^[:digit:]]+',null)),1,7), UI.TRAMPOLINE,  GET_ROOF_YEAR(IAR.POLICY_NUMBER)
                                                               from new_apdev.item_at_risk iar,
                                                                    new_apdev.iar_personal_dwelling ipd,
                                                                    NEW_APDEV.UNDERWRITING_INFO ui
                                                              where iar.item_at_risk_id=ipd.item_at_risk_id
                                                                and i.policy_number=iar.policy_number
                                                                and iar.user_line_code IN( '24','22')
                                                                and ui.policy_number(+) = iar.policy_number
                                                                and i.item_seq=iar.wang_item_seq)
     where i.sds_line IN('24','22')
      AND POLICY_NUMBER IN(SELECT POLICY_NUMBER FROM RPTVIEWER.RPT_POLICY WHERE GROUP_LINE_CODE='24' OR(GROUP_LINE_CODE='22' AND POLICY_EFFECTIVE_DATE>=TO_DATE('01012019','MMDDYYYY') ))
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;

   -- ADDED Roof Age calculation for Dwelling Fire to support ISO STAT changes 8/1/2016 SHAYNES
     update rptviewer.rpt_item i
          set (i.roof_year) =(select GET_ROOF_YEAR(ri.POLICY_NUMBER)
                               from rptviewer.rpt_item ri
                              where RI.SDS_LINE = '22'
                                and ri.policy_number = i.policy_number
                                and ri.item_seq = i.item_seq
                                and ri.run_date = (select max(run_date) from rptviewer.rpt_policy))
     where i.sds_line='22'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;


v_err_loc:= 'Updating BOP Class Attributes';  --'Updating Flood Zone';

    update rptviewer.rpt_item i
       set (i.gross_srr,
            i.rate_number,
            i.class_group,
            i.liability_exposure_base,
            i.payroll)  = (select iarcbc.gross_annual_sales,
                                                  iarcbc.rate_number,
                                                  iarcbc.class_group,
                                                  iarcbc.liab_exp_base,  -- Added Fire Station Dist Band to include additional BOP data 2/10/2016 shaynes
                                                  iarcbc.payroll
                                             from new_apdev.item_at_risk iar,
                                                  new_apdev.iar_compak_bus_class iarcbc
                                            where iar.item_at_risk_id=iarcbc.item_at_risk_id
                                              and i.policy_number=iar.policy_number
                                              and iar.user_line_code = '77'
                                              and i.item_seq=iar.wang_item_seq)
     where i.sds_line='77'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

 commit;

---Added5/22/15
 v_err_loc:='Updating COASTAL';

update rptviewer.rpt_item i set (COASTAL,COASTAL_TRANSITION)=(
select ipd.COASTAL,ipd.COASTAL_TRANSITION
from
new_apdev.item_at_risk iar,
NEW_APDEV.IAR_PERSONAL_DWELLING  ipd
where   I.SDS_LINE IN ('24','22') AND
  I.POLICY_NUMBER = IAR.POLICY_NUMBER AND
  I.sds_line = IAR.USER_LINE_CODE AND
  I.ITEM_SEQ=IAR.WANG_ITEM_SEQ   and
    IAR.ITEM_AT_RISK_ID = ipd.ITEM_AT_RISK_ID
)
where sds_line IN('24','22')
and run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;


-- 26 line (Farmowner) load of Cause Of Loss for Coverage E Farm

v_err_loc:='Updating Cause_of_loss_e';


 update rptviewer.rpt_item i
       set (i.cause_of_loss_cov_e) =        (select acol.cause_of_loss_code
                                               from new_apdev.item_at_risk iar,
                                                    new_apdev.iar_farm_owners ifo,
                                                    RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                              where iar.item_at_risk_id=ifo.item_at_risk_id
                                                and i.policy_number=iar.policy_number
                                                and iar.user_line_code = '26'
                                                and i.item_seq=iar.wang_item_seq
                                                and IFO.USFPP_CAUSE_OF_LOSS                     = ACOL.CAUSE_OF_LOSS
                                                and NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_NA, 'N')    = ACOL.COL_EXL_NA
                                                and NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_HAIL, 'N')  = ACOL.COL_EXL_HAIL_D
                                                and NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_THEFT, 'N') = ACOL.COL_EXL_THEFT_A
                                                and NVL(IFO.USFPP_CAUSE_OF_LOSS_EXL_VAND, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='26'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;
-- 26 line (Farmowner) load of Cause Of Loss for Coverage B Home

v_err_loc:='Updating Cause_of_loss_b';

 update rptviewer.rpt_item i
       set (i.cause_of_loss_cov_b) =        (select acol.cause_of_loss_code
                                               from new_apdev.item_at_risk iar,
                                                    new_apdev.iar_farm_owners ifo,
                                                    RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                              where iar.item_at_risk_id=ifo.item_at_risk_id
                                                and i.policy_number=iar.policy_number
                                                and iar.user_line_code = '26'
                                                and i.item_seq=iar.wang_item_seq
                                                and IFO.USHHPP_CAUSE_OF_LOSS                     = ACOL.CAUSE_OF_LOSS
                                                and NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_NA, 'N')    = ACOL.COL_EXL_NA
                                                and NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_HAIL, 'N')  = ACOL.COL_EXL_HAIL_D
                                                and NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_THEFT, 'N') = ACOL.COL_EXL_THEFT_A
                                                and NVL(IFO.USHHPP_CAUSE_OF_LOSS_EXL_VAND, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='26'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

 commit;

-- 27 line (Farmowner Building Structure) load of Cause Of Loss

v_err_loc:='Updating Cause_of_loss_bldg_struct';

 update rptviewer.rpt_item i
       set (i.cause_of_loss)     =          (select acol.cause_of_loss_code
                                               from new_apdev.item_at_risk iar,
                                                    new_apdev.iar_farm_owners_bldg_st ifo,
                                                    RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                              where iar.item_at_risk_id=ifo.item_at_risk_id
                                                and i.policy_number=iar.policy_number
                                                and iar.user_line_code = '27'
                                                and i.item_seq=iar.wang_item_seq
                                                and IFO.CAUSE_OF_LOSS                          = ACOL.CAUSE_OF_LOSS
                                                and NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')         = ACOL.COL_EXL_NA
                                                and NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
                                                and NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
                                                and NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='27'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;
-- 70 line (Farmowner Commercial Inland Marine) load of Cause Of Loss

v_err_loc:='Updating Cause_of_loss_coml_im';

 update rptviewer.rpt_item i
       set (i.cause_of_loss)    =    (select acol.cause_of_loss_code
                                        from new_apdev.item_at_risk iar,
                                             new_apdev.IAR_COMMERCIAL_INLAND_MARINE ifo,
                                             (select policy_number from new_apdev.policy where group_line_code = '26') fo,
                                             RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                       where iar.item_at_risk_id=ifo.item_at_risk_id
                                         and iar.policy_number = fo.policy_number
                                         and i.policy_number=iar.policy_number
                                         and iar.user_line_code = '70'
                                         and i.item_seq=iar.wang_item_seq
                                         and IFO.CAUSE_OF_LOSS                          = ACOL.CAUSE_OF_LOSS
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')         = ACOL.COL_EXL_NA
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='70'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;
 -- 24 line (Farmowner Permanent Structure HO) load of Cause Of Loss

v_err_loc:='Updating Cause_of_loss_dwelling';

 update rptviewer.rpt_item i
       set (i.cause_of_loss)    =    (select acol.cause_of_loss_code
                                        from new_apdev.item_at_risk iar,
                                             new_apdev.IAR_PERSONAL_DWELLING ifo,
                                             (select policy_number from new_apdev.policy where group_line_code = '26') fo,
                                             RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                       where iar.item_at_risk_id=ifo.item_at_risk_id
                                         and i.policy_number=iar.policy_number
                                         and iar.policy_number = fo.policy_number
                                         and iar.user_line_code = '24'
                                         and i.item_seq=iar.wang_item_seq
                                         and IFO.CAUSE_OF_LOSS                          = ACOL.CAUSE_OF_LOSS
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')         = ACOL.COL_EXL_NA
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='24'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;
 -- 32 line (Farmowner Mobilehome) load of Cause Of Loss

v_err_loc:='Updating Cause_of_loss_mobilehome';

 update rptviewer.rpt_item i
       set (i.cause_of_loss)    =    (select acol.cause_of_loss_code
                                        from new_apdev.item_at_risk iar,
                                             new_apdev.IAR_MOBILEHOME ifo,
                                             (select policy_number from new_apdev.policy where group_line_code = '26') fo,
                                             RPTVIEWER.DIM_ARFO_CAUSE_OF_LOSS acol
                                       where iar.item_at_risk_id=ifo.item_at_risk_id
                                         and iar.policy_number = fo.policy_number
                                         and i.policy_number=iar.policy_number
                                         and iar.user_line_code = '32'
                                         and i.item_seq=iar.wang_item_seq
                                         and IFO.CAUSE_OF_LOSS                          = ACOL.CAUSE_OF_LOSS
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_NA, 'N')         = ACOL.COL_EXL_NA
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_HAIL_STORM, 'N') = ACOL.COL_EXL_HAIL_D
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_THEFT, 'N')      = ACOL.COL_EXL_THEFT_A
                                         and NVL(IFO.CAUSE_OF_LOSS_EXL_VANDALISM, 'N')  = ACOL.COL_EXL_VAND_B)
     where i.sds_line='32'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;

v_err_loc:='Updating Missouri Territory';

 -- Added Missouri territory code decode 1/30/2017 SHAYNES
       update rptviewer.rpt_item i
          set (i.TERR) = (select DECODE(LENGTH(TRIM(TRANSLATE(FTC.TERRITORY_CODE, 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', ' '))),
                                 NULL, FTC.TERRITORY_CODE,
                                 lpad(ftc.territory_code, 5, '0'))  -- if territory code is not alpha numeric pad with 0's
                            from rptviewer.rpt_item ri,
                                 (SELECT DISTINCT STATE_ALPHA_CODE, TERRITORY_CODE, WANG_TERRITORY_CODE
                                    FROM NEW_APDEV.R_FO_ZIP_TERRITORY_CODE
                                   WHERE STATE_ALPHA_CODE = 'MO'
                                 UNION
                                  SELECT DISTINCT STATE_ALPHA_CODE, TERRITORY_CODE, WANG_TERRITORY_CODE
                                    FROM NEW_APDEV.R_FO_TERRITORY_CODE
                                   WHERE STATE_ALPHA_CODE = 'MO') FTC
                         where ri.item_state    = 'MO'
                           and ri.policy_number = i.policy_number
                           and ri.item_seq      = i.item_seq
                           and ri.item_state    = ftc.state_alpha_code
                           and ri.terr          = ftc.wang_territory_code
                           and ri.terr          = lpad(ftc.wang_territory_code, 5, '0')
                           and ri.run_date = (select max(run_date) from rptviewer.rpt_policy))
     where i.ITEM_STATE = 'MO'
       and i.run_date=(select max(run_date) from rptviewer.rpt_policy);

commit;

          v_err_loc:='Updating IRPM Deviation';

-- Adding IRPM Deviation for CU  3/16/2018 VNG--Added 10 on 7/20/18
      update rptviewer.rpt_item i
         set (I.IRPM_DEVIATION) = (select sum(PI.IRPM_PCT)*.01
                                     from NEW_APDEV.POLICY_IRPM PI
                                    where i.policy_number = PI.POLICY_NUMBER
                                  )
       where I.USER_LINE in ('26', '46','10')
         and I.USER_LINE = I.SDS_LINE
         and i.run_date=(select max(run_date) from rptviewer.rpt_policy);
commit;


BEGIN
  APDEV.MA_PPA_COLL_SYMBOL_LOAD;
  COMMIT;

UPDATE RPTVIEWER.RPT_ITEM WI SET WI.COLL_SYMBOL=
(SELECT distinct A.COLL_SYMBOL
FROM APDEV.MA_PPA_COLL_SYMBOL A
WHERE WI.POLicy_NUMber=A.POLICY_NUMBER
AND WI.VEH_TYPE=A.VEH_TYPE
AND WI.IDENT_NUM=A.VIN)
where run_date=(select max(run_date) from rptviewer.rpt_policy);

COMMIT;
END;

EXCEPTION
    WHEN NO_DATA_FOUND  THEN
        NULL;
    WHEN OTHERS THEN
        V_ERR_MSG:='FAILED AT'||v_err_loc||SQLCODE||':'||SQLERRM(SQLCODE)||V_PROCNAME;
        RPTVIEWER.RPT_UTIL.WRITE_ERROR(V_PROCNAME,V_ERR_MSG);

END;
/
