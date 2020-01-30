CREATE OR REPLACE PROCEDURE BILLING.LOAD_MBSI_PREV_VERSION_DB IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       BILL_LOAD_PROC
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        12/14/2017    SHAYNES      1. Created this procedure.
   2.0        12/27/2017    SHAYNES      2. Updated prior version logic to apply rounding rules as defined by NPS.
   3.0        3/29/2018     SHAYNES     3. Change to support prior version as PTC transactions.

   NOTES:     12/14/2017                 Truncate & Loads table BILLING.MBSI_PREV_VERSION required for QA to read ORACLE1 STAGING.HISTORY_WANG_ITEM, STAGING.HISTORY_WANG_COVERAGE_RECORD
                                        previous version of changed, cancelled or reinstated policies for the current days cycle for Majesoc Billing Premium Interface.

******************************************************************************/
insert_count      NUMBER;
--v_procname        VARCHAR2(30)                      := 'BILL_LOAD_PROC';
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
BEGIN
v_err_loc:='At insert statement';

delete from BILLING.MBSI_PREV_VERSION_DB pv;

commit;



for pt in (select distinct wr.pol_num, ba.process_date, wr.run_date, wr.change_date, nvl(ba.ptc_ind, 'N') ptc,  -- Determine if the prior version is a PTC 
            ba.policy_expiration_date, ba.change_effective_date, ba.pro_rata_factor, ba.written_prem, ba.trans_type_code, ba.cancel_type, ba.policy_status_code, ba.group_line_code
             from billing.v_daily_billing_activity ba, apdev.wang_recap wr--  wr--, mbsi_prem_diff pd
            where ba.trans_type_code IN ('0', '2', '6')
              and (case when ba.TRANS_TYPE_CODE = '6' and ba.WRITTEN_PREM = 0 then 'N' ELSE ba.NEDR_FLG end) = 'N' -- added condition 1/4/2019 to handle ptc cancels where ProRata Factor < .01 but NEDR = 'Y'; need for correct PTC commission %
              --and ba.NEDR_FLG = 'N'
              and ba.policy_number = wr.pol_num
              and wr.addl_key = 0    --- changed 8/22/2018 to support multiple changes on the same day
              --and wr.trans_source_sw = 'A'
              and (case when nvl(ba.ptc_ind, 'N') = 'Y' then wr.eff_date else ba.policy_effective_date end) = wr.eff_date  --- -- added condition 1/4/2019 to handle ptc cancels where ProRata Factor < .01 but NEDR = 'Y'; need for correct PTC commission %; added 12/20/2018 to prevent duplicate retrieval of policies in mbs wang_recap (multiple policy terms in 1 cycle)
              --  and wr.eff_date = ba.policy_effective_date  --- added 12/20/2018 to prevent duplicate retrieval of policies in mbs wang_recap (multiple policy terms in 1 cycle)
              AND NVL (BA.TRANS_SOURCE_SW, 'A') <> 'M'
           --   and ba.policy_number  = '91766244A' --not in ('9831699','90897702A')
              and wr.run_date = billing.get_lst_chg_date (ba.policy_number, ba.change_effective_date))
  loop
begin
INSERT INTO BILLING.MBSI_PREV_VERSION_DB
(SELECT distinct pt.pol_num policy_number,
       pt.policy_expiration_date,
       pt.change_effective_date,
       hwi.sds_line user_line,
       NVL (hwi.total_item_prem, pt.written_prem) total_item_prem, -- if new business transaction we will not have previous premiums.
       hwi.item_seq,
       nvl(hwc.cov_code, hwc.end_num) coverage_code, 
       hwi.comm1_pct,
       hwc.cov_prem,        
       (pt.pro_rata_factor*-1) pro_rata_factor_prior,  --pro_rata factor to be applied to prior prem s/b (-) sign and rounded to 3 decimal spaces for MA PPA, Gen Liab else 6 decimal spaces  
       (case when pt.GROUP_LINE_CODE in ('06','07') and hwc.cov_code not in ('117', '118', '121', '122', '127', '167', '207','217') and nvl(ba.MMV_RATE_CLASS, hwi.mmv_rate_class)  = '15'
                 then round((hwc.cov_prem*(pt.pro_rata_factor*-1)),2)
             when pt.GROUP_LINE_CODE in ('06','07') and hwc.cov_code not in ('117', '118', '121', '122', '127', '167', '207','217','220') and nvl(ba.MMV_RATE_CLASS, hwi.mmv_rate_class)  <> '15'  
                then  round(round(hwc.cov_prem*(pt.pro_rata_factor*-1),2)) --round((hwc.cov_prem*(pt.pro_rata_factor*-1))) --decode(hwc.cov_code, '200', round(round((hwc.cov_prem*(ba.pro_rata_factor*-1)),1)),  round((hwc.cov_prem*(pt.pro_rata_factor*-1))))  --Added 2/15/2019 to address rounding on 200 cov
             --when pt.GROUP_LINE_CODE in ('06','07') and hwc.cov_code = '200'/* in ('117', '118', '121', '122', '127', '167', '207','217','220') */and nvl(ba.MMV_RATE_CLASS, hwi.mmv_rate_class)  <> '15' 
             --then round(round((hwc.cov_prem*(ba.pro_rata_factor*-1)),1))--round((hwc.cov_prem*(pt.pro_rata_factor*-1))) 
            -- when pt.GROUP_LINE_CODE in ('06','07') and hwc.cov_code not in ('109', '110', '120', '145', '160', '200', '210','230') and hwi.MMV_RATE_CLASS <> '15'    
              --   then round(hwc.cov_prem*(pt.pro_rata_factor*-1),2)
               /* when hwc.cov_code = '220'
                 then round(hwc.cov_prem*-1)*/
             when hwc.cov_code >= '990'
                 then round((hwc.cov_prem*(pt.pro_rata_factor*-1)),2)
             when pt.POLICY_STATUS_CODE = '6' and pt.CANCEL_TYPE = 'F' 
                 then ROUND((hwc.cov_prem*(pt.pro_rata_factor*-1)),2)
             -- when hwc.cov_code = '220' then  (hwc.cov_prem*-1)   
             else --round((hwc.cov_prem*(ba.pro_rata_factor*-1))) -- commented out on 10/8/2018
                ROUND(ROUND(hwc.cov_prem*(pt.pro_rata_factor*-1),2))   -- added on 10/8/2018
       end) pr_cov_prem_prior, --pro rata factor rounding rules 
        --round((hwc.cov_prem*(ba.pro_rata_factor*-1))) pr_cov_prem_prior,
       NVL (hwi.run_date, pt.process_date) run_date, --if new business transaction we will not have previous run dates
       SYSDATE date_entered
  FROM staging.history_wang_item  hwi,
       staging.history_wang_coverage_record  hwc,
        (select ba.policy_number, ri.sds_line, ri.item_seq, ri.total_item_prem, ri.mmv_rate_class, ba.pro_rata_factor, ba.cancel_type, ba.policy_status_code, ba.group_line_code,
               ba.policy_effective_date, ba.policy_expiration_date, ba.change_effective_date, ba.written_prem
          from billing.v_daily_billing_activity ba,
               rptviewer.rpt_item ri
         where ba.policy_number = ri.policy_number
          AND NVL (BA.TRANS_SOURCE_SW, 'A') <> 'M') ba
   --       billing.v_daily_billing_activity ba
 WHERE  pt.trans_type_code IN ('0', '2', '6')
       and hwi.pol_num  = pt.pol_num
       and ba.policy_number(+) = hwi.pol_num 
       and ba.item_seq(+) = hwi.item_seq
       --and ba.policy_number = pt.pol_num
       and hwi.run_date = pt.run_date--billing.get_lst_chg_date (ba.policy_number, ba.change_effective_date)  -- changed 12/22/2017 to include change date to the function for support of retreival of prior term data
       and pt.ptc = 'N'
       and hwi.pol_num  = hwc.pol_num
       and hwi.run_date = hwc.run_date
       and hwi.item_seq = hwc.item_seq
       and hwi.sds_line = hwc.sds_line
       and hwi.sds_line = hwc.sds_line);
      -- and ba.NEDR_FLG = 'N');
 /*UNION
 select ptcc.policy_number, ptcp.policy_expiration_date, ptcp.change_date, ptci.user_line, ptci.total_item_prem, ptci.item_seq, nvl(ptcc.cov_code, ptcc.end_num) cov_code, ptci.comm1_pct, ptcc.cov_prem,
              (ba.pro_rata_factor*-1) pro_rata_factor_prior,  --pro_rata factor to be applied to prior prem s/b (-) sign and rounded to 3 decimal spaces for MA PPA, Gen Liab else 6 decimal spaces  
      (case when ba.GROUP_LINE_CODE in ('06','07')  and ptcc.cov_code not in ('117', '118', '121', '122', '127', '167', '207','217') and ptci.MMV_RATE_CLASS = '15'
                 then round((ptcc.cov_prem*(ba.pro_rata_factor*-1)),2)
            when ba.GROUP_LINE_CODE in ('06','07') and ptcc.cov_code not in ('117', '118', '121', '122', '127', '167', '207','217','220') and ptci.MMV_RATE_CLASS <> '15'  
                 then round((ptcc.cov_prem*(ba.pro_rata_factor*-1))) 
           -- when ptcc.cov_code = '220'
            --     then round(ptcc.cov_prem*-1) 
            when ptcc.cov_code >= '990'
                 then round((ptcc.cov_prem*(ba.pro_rata_factor*-1)),2)
            when ba.POLICY_STATUS_CODE = '6' and BA.CANCEL_TYPE = 'F' 
                 then ROUND((ptcc.cov_prem*(ba.pro_rata_factor*-1)),2)
           -- when ptcc.cov_code = '220' then  (ptcc.cov_prem*-1)   
             else --round((ptcc.cov_prem*(ba.pro_rata_factor*-1)))        --  commented out on 10/9/2018
                 ROUND(ROUND(ptcc.cov_prem*(ba.pro_rata_factor*-1),2))   -- added on 10/9/2018
              end) pr_cov_prem_prior, --pro rata factor rounding rules 
             pt.run_date,
             trunc(sysdate)
        from rptviewer.ptc_coverage  ptcc, 
             rptviewer.ptc_item  ptci,
             rptviewer.ptc_policy  ptcp,
             billing.v_daily_billing_activity ba 
       where ptcp.policy_number = pt.pol_num
         and ptcp.policy_number = ba.policy_number
         and ptcp.policy_number = ptci.policy_number
         and ptcp.run_date      = pt.run_date
         and ptcp.policy_number = pt.pol_num
         and ptcp.run_date      = ptci.run_date
         and ptci.policy_number = ptcc.policy_number
         and ptci.item_seq      = ptcc.item_seq
         and ptci.sds_line      = ptcc.sds_line
         and ptci.run_date      = ptcc.run_date
         and pt.ptc = 'Y'); */    

COMMIT;

end;

end loop;
   
   EXCEPTION
     WHEN OTHERS THEN
     v_err_msg:=v_err_loc||' '||SQLERRM(SQLCODE);
     --apdev.apdev_util.write_error(v_procname,v_err_msg);
       -- Consider logging the error and then re-raise
       RAISE;
END LOAD_MBSI_PREV_VERSION_DB;
/
