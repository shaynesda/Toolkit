CREATE OR REPLACE PACKAGE APDEV.ACCDT_FRGV_PKG
AS

TYPE ref_cur_type IS REF CURSOR;

    PROCEDURE IS_ACCDT_FRGV_ELIG 
    (acf_cur_arg         OUT      ref_cur_type,
     in_pol_num_arg       IN      staging.history_wang_policy.pol_num%TYPE,
     in_lic_num_arg       IN      apdev.driver_surcharge.license_number%TYPE,
     in_loss_date_arg     IN      apdev.driver_surcharge.incident_date%TYPE);
 
end;
/


CREATE OR REPLACE PACKAGE BODY APDEV.ACCDT_FRGV_PKG
IS


  PROCEDURE IS_ACCDT_FRGV_ELIG
(acf_cur_arg         OUT      ref_cur_type,
 in_pol_num_arg       IN      staging.history_wang_policy.pol_num%TYPE,
 in_lic_num_arg       IN      apdev.driver_surcharge.license_number%TYPE,
 in_loss_date_arg     IN      apdev.driver_surcharge.incident_date%TYPE)
/************************************************************************************************************
   NAME:       APDEV.ACCDT_FRGV_PKG
   REVISIONS:
   Ver        Date         Author           Description
   ---------  ----------  ---------------  ------------------------------------------------------------------
   1.0        10/10/2014    SAH              1. Created this procedure.
   2.0        10/17/2014    SAH              2. Replaced VS_CLAIMS.CLAIMS_MASTER_BASE with MRB_CLAIMS_SURCHARGES_RECV_ALL
                                                as the driver to look up License NUmber and Incident Date.
   3.0       2/24/2017      SAH              4. Corrected the point in time for DR Points by using the vers_run_date
   4.0       04/14/2017     SAH              3. Updated the policy_effective_data at the time of incident variable to source from
                                                vs_claims.claims_master_base

   OVERVIEW:
  This procedure services the MA PPA Rating Service and accepts a policy_number, license_number and loss date
  as input. Using the input parameters a lookup is performed to find the Driver, Driver Points and Vehicle relationship
  to the policy at the time of the loss. The results of the historical lookup along with an answer on if the Accident Forgiveness credit
  should apply is returned in the form of a ref cursor.
*************************************************************************************************************/
IS

TYPE acf_cur_list IS REF CURSOR;

V_EFF_DT               DATE;
V_VERS_RUN_DT          DATE;
V_DR_PTS_DT            DATE;
v_mrb_cnt number;
v_clm_cnt number;

v_procname        VARCHAR2(30)                      := 'IS_ACCDT_FRGV_ELIG';
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);

 acf_cur acf_cur_list;

 BEGIN

-- surcharge record exist for the policy_number, loss_date and license number passed in
select count(*)
  into v_mrb_cnt
  from RPTVIEWER.MRB_CLAIMS_SURCHARGES_RECV_ALL mrb
 where mrb.transaction = '41'
   and mrb.policy_number = IN_POL_NUM_ARG
   and mrb.incident_date = IN_LOSS_DATE_ARG
   and mrb.oper_lic_num  = IN_LIC_NUM_ARG;

-- claim exists for the loss_date & policy_number passed in
select eff_date, count(*)
  into v_eff_dt, v_clm_cnt
  from vs_claims.claims_master_base cmb
 where policy_number = in_pol_num_arg
   and loss_date     = in_loss_date_arg
 group by eff_date;

-- driver/vehicle history control version of the policy for the incident date passed
select max(run_date) run_date
  into  V_VERS_RUN_DT
  from STAGING.HISTORY_WANG_POLICY hp
      /*(select cmb.policy_number, cmb.eff_date, cmb.exp_date   -- changed to handle no data found condition 11/7/2014
         from vs_claims.claims_master_base cmb
        where policy_number = in_pol_num_arg
          and loss_date = in_loss_date_arg) eff */
 where hp.group_line = '06'
   and hp.run_date >= add_months(trunc(sysdate, 'MM'), -84)
   and hp.run_date < in_loss_date_arg
   and hp.pol_num = in_pol_num_arg
  -- and hp.pol_num = eff.policy_number   -- changed to handle no data found condition 11/7/2014
   and hp.eff_date = v_eff_dt
   and HP.CHANGE_DATE <> HP.exp_date
 group by hp.pol_num;


-- driver points history control (version of the driver points for the incident policy term)
select max(run_date)                   -- update to driver points for the term the loss happened can happen after the term has ended
  into V_DR_PTS_DT
  from STAGING.HISTORY_WANG_POLICY hp
 where hp.group_line = '06'
   and hp.pol_num = in_pol_num_arg
   and hp.eff_date = v_eff_dt
   and hp.run_date = V_VERS_RUN_DT     -- added 2/24/2017 in order to capture the correct point in time for DR Points
   and hp.change_date <> hp.exp_date   -- excluding pre-renewal changes
 group by hp.pol_num;

 BEGIN

IF v_mrb_cnt > 0 and v_clm_cnt > 0  THEN  -- Check condition if both surchargeable offense exist and claim exist
                                          -- Adjusted v_clm_cnt check to > 0 from >1 to support more than 1 claim in a day 1/26/2017 shaynes

   OPEN acf_cur FOR

 SELECT (CASE WHEN VEH.HWI_ITEM_SEQ IS NOT NULL             AND
                   VEH.HWI_ITEM_SEQ <> NVL(VEH_EXCLUDED, 0) AND -- Driver is not excluded on the accident vehicle
                   DEFERRED = 'N'                           AND -- Driver is not deferred
                   POINTS IN ('98','99')                    AND -- Driver points are either 98 or 99
                   ACCDT_VEH_ON_POLICY = 'Y'                AND -- Accident vehicle is on the policy
                   NVL(COMP_N_COLL, 'N') = 'Y'                  -- Comprehensive and Collision is on the vehicle
             THEN 'Y'
          ELSE 'N'
         END) AFC_ELIG, DR.CLAIM_NUMBER, VEH.VIN_NUM, DR.REPORTED_DATE, DRIVER_ON_POLICY, DEFERRED, POINTS, ACCDT_VEH_ON_POLICY,
              DECODE(VEH_EXCLUDED, VEH.HWI_ITEM_SEQ, 'Y','N') DRIVER_EXCL_ON_VEH, NVL(COMP_N_COLL, 'N') COMP_N_COLL, DR.POLICY_NUMBER, IN_LIC_NUM_ARG LICENSE_NUMBER, DR.LOSS_DATE, V_EFF_DT vers_eff_date, V_VERS_RUN_DT vers_run_date, V_DR_PTS_DT vers_dr_pts_date
FROM
(select clm_veh.policy_number, clm_veh.claim_number, clm_veh.item_seq, clm_veh.reported_date, clm_veh.loss_date, DECODE(HN.LIC_NUM,IN_LIC_NUM_ARG,'Y','N') DRIVER_ON_POLICY, POINTS, NVL(HN.DEFERRED, 'N') DEFERRED, HN.VEH_NUM,
       (CASE  WHEN HN.DR_EXCLUDED_V1  = 'Y' THEN '1'
              WHEN HN.DR_EXCLUDED_V2  = 'Y' THEN '2'
              WHEN HN.DR_EXCLUDED_V3  = 'Y' THEN '3'
              WHEN HN.DR_EXCLUDED_V4  = 'Y' THEN '4'
              WHEN HN.DR_EXCLUDED_V5  = 'Y' THEN '5'
              WHEN HN.DR_EXCLUDED_V6  = 'Y' THEN '6'
              WHEN HN.DR_EXCLUDED_V7  = 'Y' THEN '7'
              WHEN HN.DR_EXCLUDED_V8  = 'Y' THEN '8'
              WHEN HN.DR_EXCLUDED_V9  = 'Y' THEN '9'
              WHEN HN.DR_EXCLUDED_V10 = 'Y' THEN '10'
         END) veh_excluded            -- Driver History lookup
  from STAGING.HISTORY_WANG_NAME hn,
         (select HN.POL_NUM, HN.LIC_NUM, HN.OPR_SDIP_STATUS POINTS
            from staging.history_wang_name hn
           where hn.pol_num   = IN_POL_NUM_ARG
             and hn.run_date  = V_DR_PTS_DT  -- driver point hist control date
             and hn.name_type = 'DR'
             and hn.lic_num   = IN_LIC_NUM_ARG) DR_PTS,
     (select cmb.policy_number, cmi.claim_number, cmi.ident_num, cmb.reported_date, cmb.loss_date, ltrim(CMI.ITEM_SEQ_NUMBER, 0) item_seq, V_VERS_RUN_DT run_date, IN_LIC_NUM_ARG lic_num
        from VS_CLAIMS.CLAIMS_MASTER_BASE cmb, VS_CLAIMS.CLAIMS_MASTER_ITEM cmi
       where cmb.policy_number = IN_POL_NUM_ARG
         and cmb.loss_date     = IN_LOSS_DATE_ARG
         and cmb.claim_number  = cmi.claim_number) clm_veh
where HN.LIC_NUM(+)  = clm_veh.lic_num
  and HN.RUN_DATE(+) = clm_veh.run_date
  and HN.POL_NUM(+)  = clm_veh.policy_number
  and DR_PTS.POL_NUM(+) = HN.POL_NUM
  and DR_PTS.LIC_NUM(+) = HN.LIC_NUM) DR,  -- Driver History lookup
(select clm_veh.policy_number, clm_veh.claim_number, clm_veh.item_seq, HI.ITEM_SEQ HWI_ITEM_SEQ, hi.ident_num VIN_NUM, decode(hi.ident_num, null, 'N','Y') ACCDT_VEH_ON_POLICY, comp_n_coll -- Vehicle History lookup
   from STAGING.HISTORY_WANG_ITEM hi,
        (select pol_num, item_seq, decode(count(*),1,'Y','N') comp_n_coll   -- CHECK TO SEE IF COMP AND COLLISION EXISTS
           from STAGING.HISTORY_WANG_COVERAGE_RECORD comp
          where pol_num = IN_POL_NUM_ARG
            and cov_code IN ('210','211') -- COMPREHENSIVE
            and run_date = V_VERS_RUN_DT
            and exists (select 1
                         from STAGING.HISTORY_WANG_COVERAGE_RECORD coll
                        where cov_code IN ('200','201','205','206') -- COLLISION
                          and coll.pol_num = comp.pol_num
                          and coll.item_seq = comp.item_seq
                          and coll.RUN_DATE = comp.run_date)
                        group by pol_num, item_seq) cnc,
        (select mrb.policy_number, cmb.claim_number, MRB.VIN, cmb.eff_date, cmb.loss_date, cmb.reported_date, ltrim(CMI.ITEM_SEQ_NUMBER, 0) item_seq, V_VERS_RUN_DT run_date, IN_LIC_NUM_ARG lic_num
           from VS_CLAIMS.CLAIMS_MASTER_ITEM cmi, VS_CLAIMS.CLAIMS_MASTER_BASE cmb,
                 (select distinct mrb.policy_number, mrb.claim_number, mrb.vin, mrb.oper_lic_num, mrb.incident_date
                    from RPTVIEWER.MRB_CLAIMS_SURCHARGES_RECV_ALL mrb
                   where mrb.transaction = '41' /* first payment*/) mrb
          where mrb.policy_number = IN_POL_NUM_ARG
            and mrb.incident_date = IN_LOSS_DATE_ARG
            and mrb.oper_lic_num  = IN_LIC_NUM_ARG
            and mrb.policy_number = cmb.policy_number
            and mrb.claim_number  = cmb.claim_number
            and cmb.claim_number  = cmi.claim_number) clm_veh
  where HI.IDENT_NUM(+) = clm_veh.vin
    and HI.RUN_DATE(+)  = clm_veh.run_date
    and HI.POL_NUM(+)   = clm_veh.policy_number
    and cnc.pol_num(+)  = HI.POL_NUM
    and cnc.item_seq(+) = HI.ITEM_SEQ) VEH   -- Vehicle History lookup
WHERE DR.POLICY_NUMBER = VEH.POLICY_NUMBER
  AND DR.CLAIM_NUMBER  = VEH.CLAIM_NUMBER;

ELSE IF v_mrb_cnt > 1 and v_clm_cnt = 0  THEN    -- Check condition if both surchargeable offense exist and claim does not exist

   OPEN acf_cur FOR


          select distinct 'N' AFC_ELIG, mrb.claim_number, mrb.vin, null reported_date, null driver_on_policy, null deferred, null points, null accdt_veh_on_policy, null driver_excl_on_veh, null comp_n_coll, MRB.POLICY_NUMBER, mrb.oper_lic_num, mrb.incident_date, null vers_eff_date, null vers_dr_pts_date
            from RPTVIEWER.MRB_CLAIMS_SURCHARGES_RECV_ALL mrb
           where mrb.transaction = '41'
             and mrb.POLICY_NUMBER = in_pol_num_arg
             and MRB.INCIDENT_DATE = in_loss_date_arg
             and MRB.OPER_LIC_NUM = in_lic_num_arg;

ELSE IF v_mrb_cnt = 0  THEN   -- Check condition if neither surchargeable offense exist nor claim exist

   OPEN acf_cur FOR

    select distinct 'N' AFC_ELIG, null claim_number, null vin, null reported_date, null driver_on_policy, null deferred, null points, null accdt_veh_on_policy, null driver_excl_on_veh, null comp_n_coll, in_pol_num_arg policy_number, in_lic_num_arg oper_lic_num, in_loss_date_arg incident_date, null vers_eff_date, null vers_dr_pts_date
     from dual;

  END IF;
 END IF;
END IF;
acf_cur_arg := acf_cur;



END;
  EXCEPTION
      WHEN OTHERS
      THEN
         IF acf_cur%ISOPEN
         THEN
            CLOSE acf_cur;
         END IF;

         raise_application_error (-20000, 'IS_ACCDT_FRGV_ELIG:' || SQLERRM);

END IS_ACCDT_FRGV_ELIG;

END ACCDT_FRGV_PKG;
/
