CREATE OR REPLACE PROCEDURE RPTVIEWER.AP_REFERRALS_LOAD IS
/******************************************************************************
   NAME:       AP_REFERRALS_LOAD
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/01/2016     SHAYNES     1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     AP_REFERRALS_LOAD
      Sysdate:         11/01/2016
      Date and Time:   11/01/2016, 12:12:00 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
v_procname        VARCHAR2(30)                      := 'AP_REFERRALS_LOAD';
v_err_loc         VARCHAR2(300);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
max_date          date;
ref_create_date   date;
BEGIN
 v_err_loc:='At insert NON MA PPA REFERRALS';  

Select max(load_date), max(ref_created_date) into max_date, ref_create_date from RPTVIEWER.AP_REFERRALS_DETAIL;  -- Load the referrals since the last load date




---NON MA PPA NWS UNDERWRITER REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
 select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, nvl(pt.policy_status, 'END') policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON, 
                APC.DESCRIPTION RPT_REF_REASON, (CASE WHEN wr.policy_number is null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  a_policy_number_referred policy_number, r.a_lob_code lob, a_underwriter UW, a_description ref_reason, pi.a_create_time created, R.A_AGENCY_NUMBER_REFERRED agency_number
                 from  QCONNECT.TB_PT_UNDERWRITER_REFERRAL r, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, a_create_time, A_TITLE
                                                                 from (select '. '||a_description||'. ' I, oid,  A_CREATE_TIME, A_TITLE from qconnect.tb_process_instance where A_TITLE = 'UNDERWRITER REFERRAL' and A_CREATE_TIME >= to_date('1/1/2014','MM/DD/YYYY')) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '. ', 1, level )+1, instr(i,'. ',1,level+1)-instr(i,'. ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'. ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null
                                                                  and A_CREATE_TIME > ref_create_date)  pi  -- this sql takes the qconnect.tb_process_instance table and creates seperate records by for each '. ' string in A_DESCRIPTION column.
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME > ref_create_date
                  and R.A_LOB_CODE NOT IN ('01','06','75')
                  and R.A_AGENCY_NUMBER_REFERRED NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, RPTVIEWER.AP_REFERRAL_CODE APC, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where process_date >= max_date
            --and trans_type = '6'   -- commented out 7/13/2018
            ) wr, 
            (select  policy_number, 
                   (case when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED not like '%RENEWAL' then 'END'
                         when policy_status_code in ('I','F','R','V','U')     and USER_ENTERED not like '%RENEWAL' then 'NB'
                         when policy_status_code = 'C' then 'CAN'
                         when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED like '%RENEWAL' then 'REN'
                     end) policy_status,
              date_entered, 
              LAG(date_entered, 1) OVER (ORDER BY policy_number, date_entered) AS DATE_ENTERED_st  
              from NEW_APDEV.POLICY_TRACK
              where date_entered > max_date) pt 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   --and ref.created <= wr.process_date(+)    -- commented this out in order to accurately assign is a referred policy is ACTIVE or NOT. 7/13/2018
   and ref.lob = RLH.GROUP_LINE_CODE
   and pt.policy_number(+) = ref.policy_number
   and ref.created between pt.date_entered_st(+) and pt.date_entered(+)
   and ref.lob = APC.lob
   and NVL(UPPER((REGEXP_SUBSTR(ref.ref_REASON, 'RENO|ALL FO|A LIMIT BELOW|A LIMIT EXCEED|COV C|IS NOT AC|IS NOT AV|MOD|LIQ|TERM DATES|QUESTION 1|QUESTION 2|QUESTION 3|QUESTION 4|QUESTION 5|QUESTION 6|QUESTION 7|QUESTION 8|QUESTION 9|QUESTION 10|QUESTION 11|QUESTION 12|QUESTION 13|QUESTION 14|QUESTION 15|QUESTION 16|QUESTION 17|90 D|CONVICTED|S AUTH|FILL-IN|RISK|CREDIT/DEBIT|75000|FAMILIES|SNOW|ELIG|declined|EXTRA|COASTAL|APLUS|UMBRELLA|COMPANY|HO 04 42|OIL TA|LIMITS EXCEED|INLAND|GEO|AGENCY HAS|RISK|FILL-IN|SUMP|by User'))), 'UNDERWRITER REVIEW') = REF_CODE
   and ref.policy_number = pol.policy_number;
   
  COMMIT; 

  v_err_loc:='At insert NJ PPA REFERRALS'; 

-- NJ PPA REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
  select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, nvl(pt.policy_status, 'END') policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON, 
                  APC.DESCRIPTION RPT_REF_REASON, (CASE WHEN wr.policy_number is not null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  a_policy_number_referred policy_number, r.a_lob_code lob, a_underwriter UW, a_description ref_reason, pi.a_create_time created, R.A_AGENCY_NUMBER_REFERRED agency_number
                 from  QCONNECT.TB_PT_UNDERWRITER_REFERRAL r, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, a_create_time, A_TITLE
                                                                 from (select '. '||a_description||'. ' I, oid,  A_CREATE_TIME, A_TITLE from qconnect.tb_process_instance where A_TITLE = 'UNDERWRITER REFERRAL' and A_CREATE_TIME >= to_date('1/1/2014','MM/DD/YYYY')) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '. ', 1, level )+1, instr(i,'. ',1,level+1)-instr(i,'. ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'. ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null
                                                                  and A_CREATE_TIME > ref_create_date)  pi  -- this sql takes the qconnect.tb_process_instance table and creates seperate records by for each '. ' string in A_DESCRIPTION column.
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME > ref_create_date
                  and R.A_LOB_CODE = '01'
                  and R.A_AGENCY_NUMBER_REFERRED NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, RPTVIEWER.AP_REFERRAL_CODE APC, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where process_date > max_date
            and trans_type = '6'
            and WR.GROUP_LINE = '01') wr, 
            (select  policy_number, 
                   (case when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED not like '%RENEWAL' then 'END'
                         when policy_status_code in ('I','F','R','V','U')     and USER_ENTERED not like '%RENEWAL' then 'NB'
                         when policy_status_code = 'C' then 'CAN'
                         when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED like '%RENEWAL' then 'REN'
                     end) policy_status,
              date_entered, 
              LAG(date_entered, 1) OVER (ORDER BY policy_number, date_entered) AS DATE_ENTERED_st  
              from NEW_APDEV.POLICY_TRACK
              where date_entered > max_date) pt 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   and ref.created <= wr.process_date(+)
   and ref.lob = RLH.GROUP_LINE_CODE
   and pt.policy_number(+) = ref.policy_number
   and ref.created between pt.date_entered_st(+) and pt.date_entered(+)
   and ref.lob = APC.lob
   and NVL(UPPER((REGEXP_SUBSTR(ref.ref_REASON, 'PRIOR CARR|QUOTED PREM|60 OR|MORE VEH|DUI|CONVICTED|S AUTH|FILL-IN|RISK|CREDIT/DEBIT|75000|FAMILIES|SNOW|ELIG|declined|EXTRA|COASTAL|APLUS|UMBRELLA|COMPANY|HO 04 42|OIL TA|LIMITS EXCEED|INLAND|GEO|AGENCY HAS|RISK|FILL-IN|Driver Step|SUMP|by User|# OF VEHS|out of sta|PRIOR BI|LOSSES|VIOL'))), 'UNDERWRITER REVIEW') = REF_CODE
   and ref.policy_number = pol.policy_number;
   
  COMMIT;  

  v_err_loc:='At insert COMPAK REFERRALS'; 

--COMPAK REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
select TO_CHAR(DATE_ENTERED, 'YYYY') YEAR, ref.policy_number, REF.GROUP_LINE, REF.POLICY_STATUS, ref.state, ref.message ref_reason, ref.reason rpt_ref_reason,  
       decode(rp.policy_number, null, 'N/A', 'ACTIVE') EVENTUAL_STATUS, ref.GROUP_LINE_CODE, ref.AG_COMM_UNDERW, ref.AGENCY_NUMBER, ref.date_entered, trunc(sysdate)
from (select distinct pol.policy_number, pol.group_line_code, AGY.AG_COMM_UNDERW, (case when pm.policy_status in ('A','E','D','S','W','Y') and pm.USER_ENTERED not like '%RENEWAL' then 'END'
                                                                                        when pm.policy_status in ('I','F','R','V','U')     and pm.USER_ENTERED not like '%RENEWAL' then 'NB'
                                                                                        when pm.policy_status = 'C' then 'CAN'
                                                                                        when pm.policy_status in ('A','E','D','S','W','Y') and pm.USER_ENTERED like '%RENEWAL' then 'REN'
                                                                                    end) policy_status, 
    pol.state_alpha_code STATE, PM.MESSAGE, APC.DESCRIPTION REASON,  PM.DATE_ENTERED, RLH.DESCRIPTION GROUP_LINE, PS.DESCRIPTION POLICY_STATUS_CODE, POL.AGENCY_NUMBER
from NEW_APDEV.POLICY_MESSAGE_TRACK PM, NEW_APDEV.POLICY POL, RPTVIEWER.V_AGENCY AGY, AP_REFERRAL_CODE APC, RPTVIEWER.RPT_LOB_HIERARCHY RLH, NEW_APDEV.POLICY_STATUS PS
where pol.group_line_code = '75' 
  and POL.AGENCY_NUMBER not like '%TST%'
  and pm.message_type = 'REFUW'
  and pm.policy_status in ('R','S','U','Y')
  and pm.policy_number = pol.policy_number
  and pol.agency_number = agy.ag_number
  and pm.date_entered > max_date
  and pol.group_line_code = apc.lob
  and pol.group_line_code = RLH.GROUP_LINE_CODE
  and pm.policy_status = ps.code
  and NVL((UPPER(REGEXP_SUBSTR(PM.MESSAGE, 'TERR|OPEN OCEAN|OF STORIES|ADD/CHANGE OF|DEPOSIT PREMIUM|CONSTRUCTION TYPE|PROX|ALARM TYPE|BREAKFAST|ROOF REPAIRED|CLASS CODE|REINSURANCE LIMIT|REINSURANCE PREM|WIRING YR|PROTECTION CLASS|FLOOR AREA|LOSS HISTORY|LOWER DEDUCT
|% OCCUPIED BY|100 FT OF|25 YRS BEFORE|PROTECT|TENANTS SIGN|NUMBER OF APART|IRPM|ROOF FLAT|# OF LOSSES|REASON NON PAY|REASON OTHER
|LESS THAN 85%|CENTRAL HEAT|VACANCY > 25%|NOT OTHERWISE CLASS|>10%|BLANK|SUMP|PRIOR TO|NAMED|SPRIN|LIMIT >|RENO|ACCUR|GE/ADD|250, A'))), 'UNDERWRITER REVIEW') = apc.REF_CODE) ref, rptviewer.rpt_policy rp
where rp.policy_number(+) = ref.policy_number
  and ref.date_entered > (SELECT MAX(REF_CREATED_DATE) FROM RPTVIEWER.AP_REFERRALS_DETAIL WHERE GROUP_LINE_CODE = '75')
  and not exists (select 1 
                    from RPTVIEWER.AP_REFERRALS_DETAIL afd
                   where afd.policy_number = ref.POLICY_NUMBER 
                     and afd.policy_status = ref.policy_status_code
                     and afd.nws_ref_reason = ref.message
                     and afd.ref_created_date = ref.date_entered);

  COMMIT; 

  v_err_loc:='At insert MA PPA REFERRALS'; 

--APDEV   
--MA PPA NWS UNDERWRITER REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
      select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, nvl(pt.policy_status, 'END') policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON,
                      APC.DESCRIPTION RPT_REF_REASON, (CASE WHEN wr.policy_number is not null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  a_policy_number_referred policy_number, r.a_lob_code lob, a_underwriter UW, a_description ref_reason, pi.a_create_time created, R.A_AGENCY_NUMBER_REFERRED agency_number
                 from  QCONNECT.TB_PT_UNDERWRITER_REFERRAL r, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, a_create_time, A_TITLE
                                                                 from (select '. '||a_description||'. ' I, oid,  A_CREATE_TIME, A_TITLE from qconnect.tb_process_instance where A_TITLE = 'UNDERWRITER REFERRAL' and A_CREATE_TIME >= to_date('1/1/2014','MM/DD/YYYY')) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '. ', 1, level )+1, instr(i,'. ',1,level+1)-instr(i,'. ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'. ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null
                                                                  and A_CREATE_TIME > ref_create_date)  pi  -- this sql takes the qconnect.tb_process_instance table and creates seperate records by for each '. ' string in A_DESCRIPTION column.
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME > ref_create_date
                  and R.A_LOB_CODE = '06'
                  and R.A_AGENCY_NUMBER_REFERRED NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, RPTVIEWER.AP_REFERRAL_CODE APC, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where process_date > max_date
            and trans_type = '6') wr, 
            (select  policy_number, 
                   (case when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED not like '%RENEWAL' then 'END'
                         when policy_status_code in ('I','F','R','V','U')     and USER_ENTERED not like '%RENEWAL' then 'NB'
                         when policy_status_code = 'C' then 'CAN'
                         when policy_status_code in ('A','E','D','S','W','Y') and USER_ENTERED like '%RENEWAL' then 'REN'
                     end) policy_status,
              date_entered, 
              LAG(date_entered, 1) OVER (ORDER BY policy_number, date_entered) AS DATE_ENTERED_st  
              from APDEV.POLICY_TRACK) pt 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   and ref.created <= wr.process_date(+)
   and ref.lob = RLH.GROUP_LINE_CODE
   and pt.policy_number(+) = ref.policy_number
   and ref.created between pt.date_entered_st(+) and pt.date_entered(+)
   and ref.lob = APC.lob
   AND NVL((UPPER(REGEXP_SUBSTR(ref_reason, 'Mailing Address|not match garag|Registration|Polk Base|MAIP|SDIP|sdip|Risk|DUI|Garaging location|Garaging|Licensed|Customized Equipment|CUSTOMIZED EQUIPMENT|Driver Step|low mileage|CRIB|MERITFACTOR|ANNIVERSARY|COMP|
symbol|experience|CONVICTED|FILL-IN|out of state|manually rate|75000|# OF VEHS|SNOWPLOWING|NOT COVERED|MC DFL|declined|MC Permit|plate number|youthful driver|Inspection|HEAVY/EXTRA'))), 'UNDERWRITER REVIEW') = REF_CODE  
    and ref.policy_number = pol.policy_number; 

 COMMIT; 

 v_err_loc:='At insert NON MA PPA RENEWAL BATCH REFERRALS'; 

--NON MA PPA NWS UNDERWRITER RENEWAL BATCH REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
  select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, 'REN' policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON, APC.DESCRIPTION RPT_REF_REASON, 
                  (CASE WHEN wr.policy_number is not null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  pin.a_policy_number policy_number, r.a_lob_code lob, a_underwriter UW, r.a_description ref_reason, pi.a_create_time created, ci.A_AGENCY_NUMBER agency_number
                 from  qconnect.tb_process_instance pi, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER
                                                                    from (select '; '||a_reason||'; ' I, oid,  R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER from QCONNECT.TB_PT_REVIEW_REF_TRIG_RENEWAL) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '; ', 1, level )+1, instr(i,'; ',1,level+1)-instr(i,'; ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'; ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null)  r,  -- this sql takes the qconnect.tb_pt_review_ref_trig_renewal table and creates seperate records by for each '; ' string in A_REASON column.
                      QCONNECT.TB_NB_CASE_INFO ci, QCONNECT.TB_NB_POLICY_INFO pin
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME    > ref_create_date
                  and pi.R_NB_CASE_INFO    = ci.oid
                  and ci.R_NB_POLICY_INFO  = pin.oid
                  and pi.A_TITLE = 'REFERRAL RENEWAL'
                  and R.A_LOB_CODE <> '06'
                  and ci.A_AGENCY_NUMBER NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, RPTVIEWER.AP_REFERRAL_CODE APC, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where wr.process_date > max_date
            and wr.trans_type = '6'
            and wr.group_line <> '06'  ) wr 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   and ref.created <= wr.process_date(+)
   and ref.lob = RLH.GROUP_LINE_CODE
   and ref.lob = APC.lob
   and NVL(UPPER((REGEXP_SUBSTR(ref.ref_REASON, 'RENO|ALL FO|A LIMIT BELOW|A LIMIT EXCEED|COV C|IS NOT AC|IS NOT AV|MOD|LIQ|TERM DATES|QUESTION 1|QUESTION 2|QUESTION 3|QUESTION 4|QUESTION 5|QUESTION 6|QUESTION 7|QUESTION 8|QUESTION 9|QUESTION 10|QUESTION 11|QUESTION 12|QUESTION 13|QUESTION 14|QUESTION 15|QUESTION 16|QUESTION 17|90 D|CONVICTED|S AUTH|FILL-IN|RISK|CREDIT/DEBIT|75000|FAMILIES|SNOW|ELIG|declined|EXTRA|COASTAL|APLUS|UMBRELLA|COMPANY|HO 04 42|OIL TA|LIMITS EXCEED|INLAND|GEO|AGENCY HAS|RISK|FILL-IN|Driver Step|SUMP|by User|# OF VEHS|out of sta'))), 'UNDERWRITER REVIEW') = REF_CODE
   and ref.policy_number = pol.policy_number
   -- make sure the referral was not added to the detail table already
   and not exists (select 1 from RPTVIEWER.AP_REFERRALS_DETAIL ard where ard.policy_number = ref.policy_number and ref.created = ARD.REF_CREATED_DATE and ref.ref_reason = ARD.NWS_REF_REASON);             
   
   COMMIT;      
     
   v_err_loc:='At insert RENEWAL MA PPA BATCH REFERRALS'; 
   
 -- MA PPA NWS UNDERWRITER RENEWAL BATCH REFERRALS
INSERT INTO AP_REFERRALS_DETAIL
  select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, 'REN' policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON, APC.DESCRIPTION RPT_REF_REASON, 
                  (CASE WHEN wr.policy_number is not null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  pin.a_policy_number policy_number, r.a_lob_code lob, a_underwriter UW, r.a_description ref_reason, pi.a_create_time created, ci.A_AGENCY_NUMBER agency_number
                 from  qconnect.tb_process_instance pi, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER
                                                                    from (select '; '||a_reason||'; ' I, oid,  R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER from QCONNECT.TB_PT_REVIEW_REF_TRIG_RENEWAL) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '; ', 1, level )+1, instr(i,'; ',1,level+1)-instr(i,'; ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'; ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null)  r,  -- this sql takes the qconnect.tb_pt_review_ref_trig_renewal table and creates seperate records by for each '; ' string in A_REASON column.
                      QCONNECT.TB_NB_CASE_INFO ci, QCONNECT.TB_NB_POLICY_INFO pin
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME     > ref_create_date
                  and pi.R_NB_CASE_INFO    = ci.oid
                  and ci.R_NB_POLICY_INFO  = pin.oid
                  and pi.A_TITLE = 'REFERRAL RENEWAL'
                  and R.A_LOB_CODE = '06'
                  and ci.A_AGENCY_NUMBER NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, RPTVIEWER.AP_REFERRAL_CODE APC, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where wr.process_date > max_date
            and wr.trans_type = '6'
            and wr.GROUP_LINE = '06') wr 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   and ref.created <= wr.process_date(+)
   and ref.lob = RLH.GROUP_LINE_CODE
   and ref.lob = APC.lob
   and NVL((UPPER(REGEXP_SUBSTR(ref_reason, 'Mailing Address|not match garag|Registration|Polk Base|MAIP|SDIP|sdip|Risk|DUI|Garaging location|Garaging|Licensed|Customized Equipment|CUSTOMIZED EQUIPMENT|Driver Step|low mileage|CRIB|MERITFACTOR|ANNIVERSARY|COMP|
symbol|experience|CONVICTED|FILL-IN|out of state|manually rate|75000|# OF VEHS|SNOWPLOWING|NOT COVERED|MC DFL|declined|MC Permit|plate number|youthful driver|Inspection|HEAVY/EXTRA|5 YRS|12 MOS'))), 'UNDERWRITER REVIEW') = REF_CODE  
   and ref.policy_number = pol.policy_number; 
   
   COMMIT; 
      
   v_err_loc:='At insert NON MA PPA REINSURANCE REFERRALS'; 
   
-- NWS UNDERWRITER REINSURANCE BATCH REFERRALS (NON MA PPA)
INSERT INTO AP_REFERRALS_DETAIL   
   select distinct TO_CHAR(CREATED, 'YYYY') YEAR, ref.policy_number, rlh.description group_line, 'REN' policy_status, POL.STATE_ALPHA_CODE, ref.ref_reason NWS_REF_REASON, ref.ref_reason RPT_REF_REASON, 
                   (CASE WHEN wr.policy_number is not null  THEN 'N/A' ELSE 'ACTIVE' END) EVENTUAL_STATUS,  ref.lob,  ref.UW,  ref.agency_number, created, trunc(sysdate) 
         from (select  pin.a_policy_number policy_number, r.a_lob_code lob, a_underwriter UW, r.a_description ref_reason, pi.a_create_time created, ci.A_AGENCY_NUMBER agency_number
                 from  qconnect.tb_process_instance pi, (select oid, ltrim(rtrim(COLUMN_VALUE)) a_description, R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER
                                                                    from (select '; '||a_reason||'; ' I, oid,  R_PROCESS_INSTANCE, A_LOB_CODE, A_UNDERWRITER from QCONNECT.TB_PT_REINSURANCE_REFERRAL) t,
                                                                          table(
                                                                              cast(
                                                                                 multiset( select substr( i, instr( i, '; ', 1, level )+1, instr(i,'; ',1,level+1)-instr(i,'; ',1,level)-1 )
                                                                             from dual
                                                                         connect by level < length(i)-length(replace(i,'; ','')) )
                                                                         as sys.odciVarchar2List))
                                                                where ltrim(rtrim(column_value)) is not null)  r,  -- this sql takes the qconnect.tb_pt_reinsurance_referral table and creates seperate records by for each '; ' string in A_REASON column.
                      QCONNECT.TB_NB_CASE_INFO ci, QCONNECT.TB_NB_POLICY_INFO pin
                where R.R_PROCESS_INSTANCE = pi.oid
                  and pi.A_CREATE_TIME     > ref_create_date
                  and pi.R_NB_CASE_INFO    = ci.oid
                  and ci.R_NB_POLICY_INFO  = pin.oid
                  and R.A_LOB_CODE <> '06'
                  and ci.A_AGENCY_NUMBER NOT LIKE '%TST%') ref, RPTVIEWER.RPT_LOB_HIERARCHY RLH, NEW_APDEV.POLICY POL,
        (select pol_num policy_number, WR.EFF_DATE, WR.EXP_DATE, process_date
           from APDEV.WANG_RECAP wr
          where wr.process_date > max_date
            and wr.trans_type = '6'
            and wr.group_line <> '06'  ) wr 
 where wr.policy_number(+) = ref.policy_number
   and ref.CREATED between wr.eff_date(+) and wr.exp_date(+)
   and ref.created <= wr.process_date(+)
   and ref.lob = RLH.GROUP_LINE_CODE
    and ref.policy_number = pol.policy_number; 
    
    
COMMIT;
  

   EXCEPTION
     
     WHEN OTHERS THEN
      v_err_number := SQLCODE;
         v_err_msg := SQLERRM(SQLCODE);
         v_err_msg :=
            'FAILED: ' || v_err_number || ' * ' || v_err_loc || ' * '
            || v_err_msg;
          DBMS_OUTPUT.put_line(v_err_msg);
          rptviewer.rpt_util.write_error(v_procname,v_err_msg);
          
END AP_REFERRALS_LOAD;
/
