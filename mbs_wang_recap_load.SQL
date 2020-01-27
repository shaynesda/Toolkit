CREATE OR REPLACE PROCEDURE BILLING.MBS_WANG_RECAP_LOAD    IS
/******************************************************************************
   NAME:       MBS_WANG_RECAP_LOAD

   REVISIONS:
   VER        DATE        AUTHOR           DESCRIPTION
   ---------  ----------  --------------- ------------------------------------
   1.0       4/6/2018    SAH             1. INITIAL RELEASE
  
   PURPOSE      Loads WANG_RECAP data from the Majesco Billing System

******************************************************************************/

V_ERR_MSG   VARCHAR2(1000) := '';
V_PROCNAME  VARCHAR2(20) := 'MBS_WANG_RECAP_LOAD';
v_msg       VARCHAR2(5000):=null;
v_run_date        DATE;
v_err_number      NUMBER;

v_err_loc  varchar2(2000);

v_mx_pr_date date;  -- Variable for max process date to be assigned as the wang reap process date
v_nd_rn_date date;  -- Variable for run date
v_dy0_date   date;  -- Variable for Day 0 Process Date 
v_batch_no   number;  -- Variable for latest batch no

-- Count variables for all sources and transformation points
     
v_mbs_count        number;     -- MBS WANG_RECAP COUNT
v_stg_count        number;     -- MBS_WANG_RECAP STAGING COUNT
v_wr_dtl_count     number;     -- WANG_RECAP_MBS_DETAIL COUNT
v_wr_dtl_dst_count number;     -- DISTINCT COUNT OF WANG_RECAP_MBS_DETAIL
v_wr_dst_count     number;     -- DISTINCT COUNT OF WANG_RECAP

EM_BODY       varchar2(3500); 



    CURSOR mbs_wang_recap_read  -- cursor which reads inbound Majesco Billing System source data
    IS
       select mbs_wr.POL_NUM, 
              mbs_wr.PROCESS_DATE, 
              mbs_wr.ADDL_KEY, 
              mbs_wr.AGENT_NUM, 
              mbs_wr.EFF_DATE, 
              mbs_wr.EXP_DATE, 
              mbs_wr.TOTAL_PREM, 
              mbs_wr.CHANGE_DATE, 
              mbs_wr.GROUP_LINE, 
              mbs_wr.BILL_TYPE, 
              mbs_wr.PAY_OPTION, 
              mbs_wr.EXT_INT_SW, 
              mbs_wr.WRITTEN_PREM, 
              mbs_wr.STATE_CD, 
              mbs_wr.COMPANY, 
              mbs_wr.ACT_CODE, 
              mbs_wr.ACT_DATE, 
              mbs_wr.NAME, 
              mbs_wr.INT_DATE, 
              mbs_wr.CANCEL_REAS, 
              mbs_wr.BILL_FORM1, 
              mbs_wr.RET_CK_REAS, 
              mbs_wr.AMOUNT_DUE, 
              mbs_wr.CASH_AMT, 
              mbs_wr.SERVICE_CHARGE, 
              mbs_wr.PREV_AMT_DUE, 
              mbs_wr.RET_CK_AMT, 
              mbs_wr.TIMES_BILLED, 
              mbs_wr.TOT_TO_BILL, 
              mbs_wr.INST_SVC_CHG, 
              mbs_wr.INST_AMT, 
              mbs_wr.TERMINAL_USER, 
              mbs_wr.REP_UNPAID_AMT, 
              mbs_wr.DUE_DATE, 
              mbs_wr.ARREARS_AMT, 
              mbs_wr.ARREARS_SVC_CHG, 
              mbs_wr.PROC_CENTER, 
              mbs_wr.EARNED_PREM_RLETTER_SW, 
              mbs_wr.RUN_DATE, 
              -- MBS Specific Data
              mbs_wr.ACCOUNT_NUMBER, 
              mbs_wr.MBS_TRANS_TYPE, 
              mbs_wr.MBS_BILL_SEND_DATE, 
              mbs_wr.MBS_BILL_DUE_DATE, 
              mbs_wr.MBS_CANC_CHECK_DATE, 
              mbs_wr.MBS_CANC_REASON, 
              mbs_wr.MBS_AUDIT_FLAG, 
              mbs_wr.MBS_NUM_DEMAND_NOTICES, 
              mbs_wr.MBS_NUM_NSFS, 
              mbs_wr.MBS_NUM_EP_INVOICE, 
              mbs_wr.MBS_NUM_NOC, 
              mbs_wr.MBS_POLICY_STATUS, 
              mbs_wr.POLICY_HOLD, 
              mbs_wr.ACCOUNT_HOLD, 
              mbs_wr.NOC_HOLD, 
              mbs_wr.MBS_SYSTEM_ACTIVITY_NO, 
              mbs_wr.MBS_SOURCE_TRANSACTION_SEQ, 
              mbs_wr.OUTPUTSEQ, mbs_wr.PAYMENT_ID, 
              mbs_wr.MBS_TRANSACTION_REASON, 
              mbs_wr.MBS_PAYMENT_METHOD, 
              mbs_wr.MBS_POLICY_TERM_ID, 
              mbs_wr.MBS_ACCOUNT_SYSTEM_CODE,
              mbs_wr.MBS_SOURCE_SYSTEM_PROCESS_DATE,
              mbs_wr.MBS_BATCH_NO
         from BILLING.MBS_WANG_RECAP mbs_wr
         where --mbs_wr.pol_num = 'U002147'
          --and mbs_wr.process_date = to_date('4/10/2018','MM/DD/YYYY')
           mbs_wr.eff_date is not null
          order by pol_num, eff_date, mbs_source_transaction_seq, addl_key; -- eff_date, mbs_trans_type;
           --and mbs_wr.mbs_trans_type = 'NEW'; --in ('914230345A','918145994A');

    wr_rec              mbs_wang_recap_read%ROWTYPE;


--- Procedural variables ---
    
    v_TRANS_TYPE            APDEV.WANG_RECAP.TRANS_TYPE%TYPE;    -- Transaction type variable used in N assignment 
    v_BILL_TYPE_CODE        APDEV.WANG_RECAP.BILL_TYPE%TYPE;     -- Bill type code variable used in N assignment
    v_BILL_FORM             APDEV.WANG_RECAP.BILL_FORM1%TYPE;    -- Bill form variable used in N assignment
    v_COMPANY               APDEV.WANG_RECAP.COMPANY%TYPE;       -- Company variable used in N assignment
    v_RET_CK_REAS           APDEV.WANG_RECAP.RET_CK_REAS%TYPE;   -- Return Check Reason variable used in N assignment
    v_CANC_REAS             APDEV.WANG_RECAP.CANCEL_REAS%TYPE;   -- Cancel Reason variable used in N assignment
    v_NSF_IND               APDEV.WANG_RECAP.NSF_IND%TYPE;       -- NSF Indicator variable used in N assignment
    v_ACT_CODE              APDEV.WANG_RECAP.ACT_CODE%TYPE;      -- Activity Code variable used in N assignment
    v_ND_PR_DATE            APDEV.WANG_RECAP.PROCESS_DATE%TYPE;  -- N PROCESS DATE
    

BEGIN

-- Identify and set the latest Batch Number from MBS

  select max(batch_no)
    into v_batch_no
    from BILLING_CONTENT.wang_recap_batch_header@MBS_PROD
   where success_failure = 'SUCCESS';


-- Assign the process_date for Day 0 
   select max(process_date) -- Day 0 condition setting the process_date
     into v_dy0_date
     from apdev.wang_recap;



-- Truncate  staging data from the AzureQA Cloud DB and Private Cload DB
v_err_loc:='Delete MBS_WANG_RECAP...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);


-- Delete the WANG_RECAP Staging Data.
DELETE FROM MBS_WANG_RECAP;

-- Delete the WANG_RECAP Merge Data table.
DELETE FROM BILLING.WANG_RECAP_MBS;

v_err_loc:='Load MBS_WANG_RECAP for Batch #'||v_batch_no||'';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);



--N Process Date assigned as the Min MBS_SOURCE_SYSTEM_PROCESS_DATE
-- N Process Date returned by function that considers all process date scenarios (End of Week; Month End etc.) 
  
--BEGIN

select DECODE(min(BATCH_NO), '1', v_dy0_date, BILLING.GET_ND_PR_DATE(min(PROCESS_DATE))), min(PROCESS_DATE)
     into v_ND_PR_DATE, v_ND_RN_DATE
    from BILLING_CONTENT.ND_WANG_RECAP_HISTORY@MBS_PROD
   where BATCH_NO = v_batch_no; 
   

-- Load the WANG_RECAP Staging Data.
INSERT INTO BILLING.MBS_WANG_RECAP
 select distinct stg.POL_NUM, 
        v_ND_PR_DATE PROCESS_DATE, 
        stg.ADDL_KEY, 
        stg.AGENT_NUM, 
        stg.EFF_DATE, 
        stg.EXP_DATE, 
        stg.TOTAL_PREM, 
        BILLING.GET_CHG_DT(stg.POL_NUM, stg.EFF_DATE) CHANGE_DATE,   -- Added 2/1/2019 to preserve the correct change date (historical segment) within WANG_RECAP
        stg.GROUP_LINE, 
        stg.BILL_TYPE, 
        case when stg.PAY_OPTION is null and stg.MBS_PAYMENT_METHOD = 'EFT' then 'E'
            when  to_char(stg.PAY_OPTION) is not null then to_char(stg.PAY_OPTION) end PAY_OPTION, 
        stg.EXT_INT_SW, 
        stg.WRITTEN_PREM, 
        stg.STATE_CD, 
        stg.COMPANY, 
        stg.ACT_CODE, 
        stg.ACT_DATE, 
        substr(stg.NAME, 1, 50), 
        stg.INT_DATE, 
        stg.CANCEL_REAS, 
        stg.BILL_FORM1, 
        stg.RET_CK_REAS, 
        stg.AMOUNT_DUE, 
        stg.CASH_AMT, 
        stg.SERVICE_CHARGE, 
        stg.PREV_AMT_DUE, 
        stg.RET_CK_AMT, 
        stg.TIMES_BILLED, 
        stg.TOT_TO_BILL, 
        stg.INST_SVC_CHG, 
        stg.INST_AMT, 
        substr(stg.TERMINAL_USER, 1, 3), 
        stg.REP_UNPAID_AMT, 
        stg.DUE_DATE, 
        stg.ARREARS_AMT, 
        stg.ARREARS_SVC_CHG, 
        substr(stg.PROC_CENTER, 1, 2), 
        stg.EARNED_PREM_RLETTER_SW, 
        v_ND_RN_DATE RUN_DATE, 
        stg.ACCOUNT_NUMBER, 
        stg.MBS_TRANS_TYPE, 
        stg.MBS_BILL_SEND_DATE, 
        stg.MBS_BILL_DUE_DATE, 
        stg.MBS_CANC_CHECK_DATE, 
        stg.MBS_CANC_REASON, 
        stg.MBS_AUDIT_FLAG, 
        stg.MBS_NUM_DEMAND_NOTICES, 
        stg.MBS_NUM_NSFS, 
        stg.MBS_NUM_EP_INVOICE, 
        stg.MBS_NUM_NOC, 
        stg.MBS_POLICY_STATUS, 
        stg.POLICY_HOLD, 
        stg.ACCOUNT_HOLD, 
        stg.NOC_HOLD, 
        stg.MBS_SYSTEM_ACTIVITY_NO, 
        stg.MBS_SOURCE_TRANSACTION_SEQ, 
        stg.OUTPUTSEQ, 
        stg.PAYMENT_ID, 
        stg.MBS_TRANSACTION_REASON, 
        stg.MBS_PAYMENT_METHOD, 
        stg.MBS_POLICY_TERM_ID, 
        stg.MBS_ACCOUNT_SYSTEM_CODE,
        BILLING.GET_ND_PR_DATE(stg.SOURCE_SYSTEM_PROCESS_DATE),
        stg.BATCH_NO
   FROM BILLING_CONTENT.ND_WANG_RECAP_HISTORY@MBS_PROD stg
  WHERE BATCH_NO = v_batch_no
    --AND POL_NUM = 'WE164169A'
   -- AND MBS_TRANS_TYPE <> 'RELEASE'
    --AND PAY_OPTION <> 'P'    
--    AND RUN_DATE = TO_DATE('10/29/2018','MM/DD/YYYY')
 --and pol_num not in (select pol_num
  --                   FROM (select pol_num, process_date, addl_key, mbs_source_transaction_seq, count(*)
  --                    from BILLING_CONTENT.ND_WANG_RECAP_HISTORY@MBS_PROD 
  --                   where batch_no ='2'
  --                   group by pol_num, process_date, addl_key, mbs_source_transaction_seq
  --                   having count(*) > 1))
order by pol_num, stg.process_date, stg.eff_date, stg.ADDL_KEY;

COMMIT;

-- Analyze MBS_WANG_RECAP Table  (especailly important for Day 0)
DBMS_STATS.gather_table_stats('BILLING', 'MBS_WANG_RECAP');


--- Record processing ---
    
    
    OPEN mbs_wang_recap_read;

    LOOP
        
        FETCH mbs_wang_recap_read INTO wr_rec;
        EXIT WHEN mbs_wang_recap_read%NOTFOUND;
        
DBMS_OUTPUT.PUT_LINE('Policy Number, Trans Type = ' || wr_rec.pol_num ||' '|| wr_rec.MBS_TRANS_TYPE);

-- N value assignement

    -- Set the N Trans Code from MBS
    v_err_loc:='mbs_wang_recap_read. Collecting Transtype Pol#'|| wr_rec.pol_num||'trans type-'||wr_rec.mbs_trans_type;
   select nd_code
     into v_trans_type 
     from billing.r_mbs_lov_mbs_transactions mtt
    where mtt.mj_code = wr_rec.mbs_trans_type;


v_err_loc:='mbs_wang_recap_read. Collecting bill_type_code  Pol#'|| wr_rec.pol_num||'Bill Type-'||wr_rec.bill_type;
  -- Set the N Bill Type Code from MBS
   select nd_code
     into v_bill_type_code 
     from billing.r_mbs_lov_bill_type mbt
    where mbt.mj_code = nvl(wr_rec.bill_type , 'ACCOUNT');


v_err_loc:='mbs_wang_recap_read. Collecting Company  Pol#'|| wr_rec.pol_num||'company-'||wr_rec.company ;
  -- Set the N Company
   select nd_code
     into v_company
     from billing.r_mbs_lov_operating_company loc
    where loc.mj_code = wr_rec.company;


    v_err_loc:='mbs_wang_recap_read. Collecting cancel reason Pol#'|| wr_rec.pol_num||'cancel reason-'||wr_rec.mbs_canc_reason ;
  -- Set the Cancel Reason
  select decode(wr_rec.mbs_trans_type,'CANCELLATION', nd_code, null)  -- decode to handle non cancellations
     into v_canc_reas
     from billing.r_mbs_lov_cancellation_reason cr
    where (case when wr_rec.mbs_trans_type = 'CANCELLATION' then upper(nvl(wr_rec.mbs_canc_reason,'ALL OTHER'))  -- case statement to handle non cancellations
             else 'ALL OTHER' end) = cr.description
       and nd_code <> 'UR';


        -- upper(wr_rec.mbs_canc_reason) = cr.description;
v_err_loc:='mbs_wang_recap_read. Collecting N activity Pol#'|| wr_rec.pol_num ;
  -- Set the N Activity Code
  
     select 
         case when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'E' and wr_rec.AMOUNT_DUE > 0 then '18'    -- New Business for a EDP No Payment         Next Activity = EDP Withdrawal
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE = 0 then '50'    -- New Business for a Full Pay Full Payment: Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE > 0 then '16'    -- New Business for a Full Pay No Payment    Next Activity = Installment    
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE < 0 then '11'    -- New Business for a Full Pay Over Payment  Next Activity = Refund
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE = 0 then '50'    -- New Business for a Ten Pay Full Payment:  Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE > 0 then '16'    -- New Business for a Ten Pay No Payment     Next Activity = Installment
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE < 0 then '11'    -- New Business for a Ten Pay Over Payment   Next Activity = Refund
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE = 0 then '50'    -- New Business for a 4 Pay Full Payment:    Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE > 0 then '16'    -- New Business for a 4 Pay No Payment       Next Activity = Installment
              when wr_rec.MBS_TRANS_TYPE = 'NEW' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE < 0 then '11'    -- New Business for a Ten Pay Over Payment   Next Activity = Refund
              when wr_rec.MBS_TRANS_TYPE = 'RENEWAL' and wr_rec.PAY_OPTION = 'E' and wr_rec.AMOUNT_DUE > 0 then '18'-- Renewal for a EDP No Payment              Next Activity = EDP Withdrawal
              when wr_rec.MBS_TRANS_TYPE = 'RENEWAL' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE > 0 then '16'-- Renewal for a Full Pay No Payment         Next Activity = Installment -- changed 5/9/2019
              when wr_rec.MBS_TRANS_TYPE = 'RENEWAL' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE > 0 then '16'-- Renewal for a Ten Pay No Payment          Next Activity = Installment -- changed 5/9/2019
              when wr_rec.MBS_TRANS_TYPE = 'RENEWAL' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE > 0 then '16'-- Renewal for a 4 Pay No Payment            Next Activity = Installment -- changed 5/9/2019
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.MBS_POLICY_STATUS = 'UNDERNOTICE' and wr_rec.AMOUNT_DUE = '0' then '50' -- Full Payment while Under Notice = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.MBS_POLICY_STATUS = 'UNDERNOTICE' and wr_rec.CASH_AMT < wr_rec.AMOUNT_DUE then '14' --Short Payment while Under Notice = Cancel
              --when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.MBS_POLICY_STATUS = 'UNDERNOTICE' and wr_rec.AMOUNT_DUE = '0' then '50' --Full Payment while Under Notice = Installment
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'E' and wr_rec.AMOUNT_DUE > 0  and wr_rec.CASH_AMT < wr_rec.AMOUNT_DUE then '18'--  Short Payment for a EDP  Next Activity = EDP Withdrawal
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'E' and wr_rec.AMOUNT_DUE = 0  and wr_rec.CASH_AMT > 0 then '50'                --  Full Payment for a EDP  Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE > 0  and wr_rec.CASH_AMT < wr_rec.AMOUNT_DUE then '52'--  Short Payment for a Full Pay Next Activity = Cancellation Notice
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'F' and wr_rec.AMOUNT_DUE = 0  and wr_rec.CASH_AMT > 0 then '50'                --  Full Payment for a Full Pay  Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.ACT_CODE = 'INVOICE' then '16' 
              --when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE > 0  and wr_rec.CASH_AMT < wr_rec.AMOUNT_DUE then '12'--  Short Payment for a Ten Pay  Next Activity = Cancellation Notice
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = 'T' and wr_rec.AMOUNT_DUE = 0  and wr_rec.CASH_AMT > 0 then '50'                --  Full Payment for a Ten Pay   Next Activity = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.AMOUNT_DUE < 0  then '11'                                                                    -- Overpayment Next Activity = Return Premium
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE > 0  and wr_rec.CASH_AMT < wr_rec.AMOUNT_DUE then '12'--  Short Payment for a Ten Pay   Next Activity = Cancellation Notice
              when wr_rec.MBS_TRANS_TYPE = 'PAYMENT' and wr_rec.PAY_OPTION = '4' and wr_rec.AMOUNT_DUE = 0  and wr_rec.CASH_AMT > 0 then '50'                --  Full Payment for a Ten Pay    Next Activity = Renewal
              when wr_rec.MBS_POLICY_STATUS = 'UNDERNOTICE' and wr_rec.MBS_TRANS_TYPE != 'PAYMENT' then '14'                               -- Under Notice any transction other than a Payment Next Activity = Cancelled
              when wr_rec.MBS_TRANS_TYPE = 'ENDORSEMENT' and wr_rec.AMOUNT_DUE < 0 then '11'                                               -- Endorsement for a credit where Amount Due < 0    Next Activity = Return Premium
              when wr_rec.MBS_TRANS_TYPE = 'ENDORSEMENT' and wr_rec.PAY_OPTION  = 'E' and wr_rec.AMOUNT_DUE > wr_rec.PREV_AMT_DUE then '18'-- Endorsement for Addl Premium on an EDP           Next Activity = Bank Withdrawal
              when wr_rec.MBS_TRANS_TYPE = 'ENDORSEMENT' and wr_rec.PAY_OPTION != 'E' and wr_rec.ACT_CODE = 'INVOICE' then '16'            -- Endorsement for on a NON EDP (the Invoice is sent out) Next Activity = Installment Notice
              when wr_rec.MBS_TRANS_TYPE = 'ENDORSEMENT' and wr_rec.PAY_OPTION != 'E' and wr_rec.ACT_CODE = 'POLICY EXPIRY' then '50'      -- Endorsement for on a NON EDP (the Invoice is sent out) Next Activity assigned by MBS = Renewal
              when wr_rec.MBS_TRANS_TYPE = 'ENDORSEMENT' and wr_rec.PAY_OPTION != 'E' and wr_rec.ACT_CODE = 'CANCELLATION NOTICE' then '12'-- Endorsement for on a NON EDP (the Invoice is sent out) Next Activity assigned by MBS = Cancellation Notice
              when wr_rec.MBS_TRANS_TYPE = 'AUDIT' and wr_rec.MBS_POLICY_STATUS = 'CANCELLED'  and wr_rec.WRITTEN_PREM < 0 THEN '11' -- AUDIT transaction resulting in return premium
              -- EP is a new activity code indicating Earned Premium bill
              when wr_rec.MBS_TRANS_TYPE = 'AUDIT' and wr_rec.MBS_POLICY_STATUS = 'CANCELLED' and wr_rec.WRITTEN_PREM >= 0 THEN 'EP' -- AUDIT transaction resulting in additional premium
              -- CL is a new activity code indicating Collection
              when wr_rec.MBS_TRANS_TYPE = 'EARNED_BILL'  then 'CL' -- EARNED BILL transaction should result in a next activity of Collection
              when wr_rec.ACT_CODE = 'EARNED PREMIUM BILL' then 'EP' -- MBS Assigned Next Activity = Earned Premium
              when wr_rec.ACT_CODE = 'CANCELLATION NOTICE' then '12' -- MBS Assigned Next Activity = Cancellation Notice
              when wr_rec.ACT_CODE = 'EDP WITHDRAWAL' then '18'      -- MBS Assigned Next Activity = Bank Withdrawal
              when wr_rec.ACT_CODE = 'CANCEL' then '14'              -- MBS Assigned Next Activity = Cancel
              when wr_rec.ACT_CODE = 'INVOICE' then '16'             -- MBS Assigned Next Activity = Invoice
              when wr_rec.ACT_CODE = 'POLICY EXPIRY' then '50'       -- MBS Assigned Next Activity = Renewal Offer
              when wr_rec.ACT_CODE = 'REFUND' then '11'       -- MBS Assigned Next Activity = Refund
           else '50'
          end
        into v_ACT_CODE
       from dual;

       

      
  -- Set the N Bill Form Code from MBS
  -- select nd_code
  --   into v_bill_form
  --   from billing.r_mbs_lov_nd_bill_form nbf
  --  where nbf.mj_code = wr_rec.bill_form1;
    
v_err_loc:='mbs_wang_recap_read. Collecting v_ret_ck_reas Pol#'|| wr_rec.pol_num ;    
  
 -- Set the N Return Check Reason from MBS
   select case when wr_rec.MBS_TRANS_TYPE in ('RETURNED_PAYMENT','REFUND') and wr_rec.MBS_POLICY_STATUS = 'CANCELLED'   then 'C' 
               when wr_rec.MBS_TRANS_TYPE in ('RETURNED_PAYMENT','REFUND') and wr_rec.MBS_POLICY_STATUS = 'UNDERNOTICE' then 'C'
               when wr_rec.MBS_TRANS_TYPE in ('RETURNED_PAYMENT','REFUND') and wr_rec.MBS_POLICY_STATUS = 'INFORCE' and wr_rec.CASH_AMT > wr_rec.PREV_AMT_DUE  then 'O'
               when wr_rec.MBS_TRANS_TYPE in ('RETURNED_PAYMENT','REFUND') and wr_rec.MBS_POLICY_STATUS = 'INFORCE' and wr_rec.AMOUNT_DUE = 0 and wr_rec.PREV_AMT_DUE < 0 then 'E'
             else null 
          end 
     into v_ret_ck_reas  
     from dual;

   
  --  select nd_code
  --   into v_ret_ck_reas7
  --   from billing.r_mbs_lov_refund_reason rr
  --  where rr.mj_code = wr_rec.RET_CK_REAS;   

v_err_loc:='mbs_wang_recap_read. Collecting v_nsf_ind Pol#'|| wr_rec.pol_num ;
  -- Set the N NSF_IND from MBS
   select case when wr_rec.MBS_TRANS_TYPE = 'RETURNED_PAYMENT' then 'R' 
               when wr_rec.MBS_TRANS_TYPE = 'PAYMENT_ADJUSTMENT' then 'A'
               when wr_rec.MBS_TRANS_TYPE = 'WRITEOFF' then 'W' else null end  -- All MBS Returned Payments are defined as NSF's (there are 68 different Returned Payment types)
     into v_nsf_ind
     from dual;


v_err_loc:='Load WANG_RECAP_MBS_DETAIL...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

v_err_loc:='mbs_wang_recap_read. inserting WANG_RECAP_MBS_DETAIL Pol#'|| wr_rec.pol_num ;

INSERT INTO BILLING.WANG_RECAP_MBS_DETAIL
( 
             POL_NUM,
             PROCESS_DATE,
             HISTORY_KEY,
             ADDL_KEY,
             AGENT_NUM,
             EFF_DATE,
             EXP_DATE,
             MBS_TOTAL_WRITTEN_PREM,
             CHANGE_DATE,
             GROUP_LINE,
             BILL_TYPE,
             PAY_OPTION,
             TRANS_TYPE,
             EXT_INT_SW,
             WRITTEN_PREM,
             STATE_CD,
             DPP_INST_NUM,
             DPP_TOT_INST,
             ASSUMED,
             COMPANY,
             AUDIT_CODE,
             ACT_CODE,
             ACT_DATE,
             NAME,
             TRANS_SOURCE_SW,
             INT_WHO,
             INT_REAS,
             INT_DATE,
             EXT_TRANS_DESC,
             REASON_DUE,
             CANCEL_REAS,
             BILL_FORM1,
             BILL_FORM2,
             BILL_FORM3,
             BILL_FORM4,
             BILL_FORM5,
             RET_CK_REAS,
             AMOUNT_DUE,
             CASH_AMT,
             SERVICE_CHARGE,
             PREV_AMT_DUE,
             RET_CK_AMT,
             TIMES_BILLED,
             TOT_TO_BILL,
             COMPANY_CHECK_NUM,
             COMPANY_CHECK_DATE,
             COMPANY_CHECK_DATE_S,
             COMPANY_CHECK_REAS,
             INST_SVC_CHG,
             INST_AMT,
             TERMINAL_USER,
             REAS_FORM,
             POLICY_TYPE,
             REP_UNPAID_AMT,
             NSF_IND,
             REASON,
             REAS_SPEC1_7,
             DUE_DATE,
             ARREARS_AMT,
             ARREARS_SVC_CHG,
             CANC_NOTICE_OVERRIDE_SW,
             CANC_COUNT_OVERRIDE_SW,
             PTC_IND,
             PROC_CENTER,
             EFT_OFFER_IND,
             AGINTER_WIP,
             NEXT_ACT_CODE,
             REAS_SPEC8_13,
             EARNED_PREM_RLETTER_SW,
             RUN_DATE,
             ACCOUNT_NUMBER,
             MBS_TRANS_TYPE,
             MBS_BILL_SEND_DATE,
             MBS_BILL_DUE_DATE,
             MBS_CANC_CHECK_DATE,
             MBS_CANC_REASON,
             MBS_AUDIT_FLAG,
             MBS_NUM_DEMAND_NOTICES,
             MBS_NUM_NSFS,
             MBS_NUM_EP_INVOICE,
             MBS_NUM_NOC,
             MBS_POLICY_STATUS,
             MBS_POLICY_HOLD,
             MBS_ACCOUNT_HOLD,
             MBS_NOC_HOLD,
             MBS_SYSTEM_ACTIVITY_NO,
             MBS_SOURCE_TRANSACTION_SEQ,
             MBS_OUTPUTSEQ,
             MBS_PAYMENT_ID,
             MBS_TRANSACTION_REASON,
             MBS_PAYMENT_METHOD,
             MBS_POLICY_TERM_ID,
             MBS_ACCOUNT_SYSTEM_CODE,
             MBS_POLICY_NUMBER,
             MBS_SOURCE_SYSTEM_PROCESS_DATE,
             MBS_BATCH_NO
             )
            VALUES
           (--select 
            substr(wr_rec.POL_NUM, 1, 10),  -- Policies numbers from MBS can be greater than 10. Apply substr of 10 to policy number
            wr_rec.process_date,
            null, --wr_rec.HISTORY_KEY,
            wr_rec.ADDL_KEY,
            wr_rec.AGENT_NUM,
            wr_rec.EFF_DATE,
            wr_rec.EXP_DATE,
            wr_rec.TOTAL_PREM,
            wr_rec.CHANGE_DATE,
            wr_rec.GROUP_LINE,
            v_BILL_TYPE_CODE,  
            wr_rec.PAY_OPTION,
            v_TRANS_TYPE,
            null, --wr_rec.EXT_INT_SW,
            wr_rec.WRITTEN_PREM,
            wr_rec.STATE_CD,
            null, --wr_rec.DPP_INST_NUM,
            null, --wr_rec.DPP_TOT_INST,
            null, --wr_rec.ASSUMED,
            v_company,
            null, --wr_rec.AUDIT_CODE,
            v_ACT_CODE, --substr(wr_rec.ACT_CODE, 1, 2),
            wr_rec.ACT_DATE,
            substr(wr_rec.NAME, 1, 10),
            null, --wr_rec.TRANS_SOURCE_SW,
            null, --wr_rec.INT_WHO,
            case when wr_rec.MBS_TRANS_TYPE = 'CANCELLATION' and wr_rec.GROUP_LINE in ('06','07') then '14' end, --null, --INT_REAS,          -- 11/15/2019 change to assign int reas
            case when wr_rec.MBS_TRANS_TYPE = 'CANCELLATION' and wr_rec.GROUP_LINE in ('06','07') then wr_rec.process_date end, --INT_DATE,  -- 11/15/2019 change to assign int reas
            null, --wr_rec.EXT_TRANS_DESC,
            null, --wr_rec.REASON_DUE,
                v_CANC_REAS, --null, --decode(wr_rec.CANCEL_REAS, 'Non-Payment of Premium', 'NP', wr_rec.CANCEL_REAS),
            case when wr_rec.BILL_FORM1 = 'ACCOUNT_INVOICE'   and wr_rec.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'
                 when wr_rec.BILL_FORM1 = 'BILL'              and wr_rec.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'
                 when wr_rec.BILL_FORM1 = 'MORTGAGEE_INVOICE' and wr_rec.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'
                 when wr_rec.BILL_FORM1 = 'CANCELLATION_NOTICE' then 'A3'
                 --when wr_rec.BILL_FORM1 = 'RENEWAL'             then 'A7'
                 when wr_rec.BILL_FORM1 = 'RESCISSION_NOTICE'   then 'A6'
                 when wr_rec.MBS_TRANS_TYPE = 'REINSTATEMENT'   then 'A6'
                 when wr_rec.MBS_TRANS_TYPE = 'RESCISSION'   then 'A6'  -- Updated 9/27/2019 to support MBS not assigning Manual Rescission
                 when wr_rec.MBS_TRANS_TYPE = 'CANCELLATION' and wr_rec.GROUP_LINE in ('06','07') then 'A4'
             else null 
            end, --           V_BILL_FORM,
            null, --wr_rec.BILL_FORM2,
            null, --wr_rec.BILL_FORM3,
            null, --wr_rec.BILL_FORM4,
            null, --wr_rec.BILL_FORM5,
               v_RET_CK_REAS,
            wr_rec.AMOUNT_DUE,
            wr_rec.CASH_AMT,
            wr_rec.SERVICE_CHARGE,
            wr_rec.PREV_AMT_DUE,
            wr_rec.RET_CK_AMT, 
            wr_rec.TIMES_BILLED,
            wr_rec.TOT_TO_BILL,
            null, --wr_rec.COMPANY_CHECK_NUM,
            null, --wr_rec.COMPANY_CHECK_DATE,
            null, --wr_rec.COMPANY_CHECK_DATE_S,
            null, --wr_rec.COMPANY_CHECK_REAS,
            wr_rec.INST_SVC_CHG,
            wr_rec.INST_AMT,
            substr(wr_rec.TERMINAL_USER, 1, 3), --wr_rec.TERMINAL_USER,
            null, --wr_rec.REAS_FORM,
            null, --wr_rec.POLICY_TYPE,
            wr_rec.REP_UNPAID_AMT, 
               v_NSF_IND, 
            null, --wr_rec.REASON,
            null, --wr_rec.REAS_SPEC1_7,
            wr_rec.DUE_DATE,
            wr_rec.ARREARS_AMT,
            wr_rec.ARREARS_SVC_CHG,
            null, --wr_rec.CANC_NOTICE_OVERRIDE_SW,
            null, --wr_rec.CANC_COUNT_OVERRIDE_SW,
            null, --wr_rec.PTC_IND,
            substr(wr_rec.PROC_CENTER, 1, 2),
            null, --wr_rec.EFT_OFFER_IND,
            null, --wr_rec.AGINTER_WIP,
            null, --wr_rec.NEXT_ACT_CODE,
            null, --wr_rec.REAS_SPEC8_13,
            wr_rec.EARNED_PREM_RLETTER_SW,
            wr_rec.RUN_DATE,
            wr_rec.ACCOUNT_NUMBER,
            wr_rec.MBS_TRANS_TYPE,
            wr_rec.MBS_BILL_SEND_DATE,
            wr_rec.MBS_BILL_DUE_DATE,
            wr_rec.MBS_CANC_CHECK_DATE,
            wr_rec.MBS_CANC_REASON,
            wr_rec.MBS_AUDIT_FLAG,
            wr_rec.MBS_NUM_DEMAND_NOTICES,
            wr_rec.MBS_NUM_NSFS,
            wr_rec.MBS_NUM_EP_INVOICE,
            wr_rec.MBS_NUM_NOC,
            wr_rec.MBS_POLICY_STATUS,
            wr_rec.POLICY_HOLD,
            wr_rec.ACCOUNT_HOLD,
            wr_rec.NOC_HOLD,
            wr_rec.MBS_SYSTEM_ACTIVITY_NO,
            wr_rec.MBS_SOURCE_TRANSACTION_SEQ,
            wr_rec.OUTPUTSEQ,
            wr_rec.PAYMENT_ID,
            wr_rec.MBS_TRANSACTION_REASON,
            wr_rec.MBS_PAYMENT_METHOD,
            wr_rec.MBS_POLICY_TERM_ID,
            wr_rec.MBS_ACCOUNT_SYSTEM_CODE,
            wr_rec.POL_NUM,
            nvl(wr_rec.MBS_SOURCE_SYSTEM_PROCESS_DATE, wr_rec.process_date),  --Assignment of source system process process date for non premium bearing changes
            wr_rec.MBS_BATCH_NO);
           -- from dual);
            
       COMMIT;

 
v_err_loc:='Merge data into WANG_RECAP_MBS... ' || wr_rec.pol_num ;
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

--DBMS_OUTPUT.PUT_LINE('mbs_source_transaction_seq, Amount_Due = ' || wr_rec.mbs_source_transaction_seq || ' ' || wr_rec.amount_due);

--v_err_loc:='Merge of MBS WANG_RECAP Data';

--DBMS_OUTPUT.PUT_LINE('Policy Number, Trans Type = ' || wr_rec.pol_num ||' '|| wr_rec.MBS_TRANS_TYPE||' '||wr_rec.eff_date||' '||wr_rec.addl_key);
--v_err_loc:='mbs_wang_recap_read. inserting WANG_RECAP_MBS Pol#'|| wr_rec.pol_num ;

          MERGE INTO BILLING.WANG_RECAP_MBS trg
            USING (select * 
                     from billing.mbs_wang_recap 
                    where process_date               = wr_rec.process_date 
                      and pol_num                    = wr_rec.pol_num 
                      and eff_date                   = wr_rec.eff_date 
                      and addl_key                   = wr_rec.addl_key
                      and MBS_TRANS_TYPE <> 'RELEASE'
                      --and pol_num = '913088395A'
                      and nvl(mbs_source_transaction_seq, 1) = nvl(wr_rec.mbs_source_transaction_seq, 1)) src
            ON  (trg.pol_num      = substr(src.pol_num, 1, 10)
             and trg.process_date = src.process_date 
            -- and trg.eff_date     = src.eff_date --(case when src.mbs_trans_type = 'PAYMENT' then trg.eff_date else src.eff_date end)
             )
             --and trg.addl_key     = src.addl_key)
             --and trg.mbs_source_transaction_seq = src.mbs_source_transaction_seq)
             --and trg.pol_num      = wr_rec.pol_num)

            -- Record key is policy number, process_date, eff_date, account_number, 
 
            WHEN MATCHED THEN UPDATE
            
            set
 
            --trg.POL_NUM       =            src.POL_NUM,
            --trg.PROCESS_DATE  =            src.PROCESS_DATE,
            trg.HISTORY_KEY   =            null,
            trg.ADDL_KEY      =            trg.ADDL_KEY,
            trg.AGENT_NUM     =            src.AGENT_NUM,
            trg.EFF_DATE      =            case when src.MBS_TRANS_TYPE = 'RENEWAL' then  src.EFF_DATE 
                                                when trg.TRANS_TYPE = '5' and src.EFF_DATE > trg.EFF_DATE then  src.EFF_DATE -- Payment applied to prior term set eff_date to current term
                                                when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') then src.EFF_DATE -- PayPlan or Billing Endorsement merge don't overwrite
                                             else trg.EFF_DATE end,
            trg.EXP_DATE      =            case when src.MBS_TRANS_TYPE = 'RENEWAL' then  src.EXP_DATE 
                                                when trg.TRANS_TYPE = '5' and src.EXP_DATE > trg.EXP_DATE then  src.EXP_DATE -- Payment applied to prior term set exp_date to current term
                                                when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') then src.EXP_DATE -- PayPlan or Billing Endorsement merge don't overwrite
                                             else trg.EXP_DATE end,
            trg.TOTAL_PREM    =            case when src.MBS_TRANS_TYPE = 'ENDORSEMENT' then src.TOTAL_PREM
                                                when src.MBS_TRANS_TYPE = 'PAYMENT' then src.TOTAL_PREM
                                                when src.MBS_TRANS_TYPE = 'RENEWAL' then src.TOTAL_PREM
                                                when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') then src.TOTAL_PREM -- PayPlan or Billing Endorsement merge don't overwrite
                                              else trg.TOTAL_PREM
                                            end,
            trg.CHANGE_DATE   =            case when trg.MBS_TRANS_TYPE = 'ENDORSEMENT' then trg.CHANGE_DATE 
                                              else src.CHANGE_DATE
                                            end,
            trg.GROUP_LINE    =            src.GROUP_LINE,
            trg.BILL_TYPE     =            v_BILL_TYPE_CODE,
            trg.PAY_OPTION    =            case when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') and trg.PAY_OPTION IS NULL then src.PAY_OPTION        -- 11/14/2019 Updated Pay Option to assign a value when null
                                                when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') and trg.PAY_OPTION IS NOT NULL then trg.PAY_OPTION    -- 11/14/2019 Updated Pay Option to assign a value when null
                                                when trg.PAY_OPTION IS NULL then src.PAY_OPTION
                                              else src.PAY_OPTION end, -- PayPlan or Billing Endorsement merge don't overwrite
            trg.TRANS_TYPE    =            case when src.GROUP_LINE = '95' and V_TRANS_TYPE in ('4','R') then trg.TRANS_TYPE         -- 9/6/2019 Case added to remove assignment of trans type 4  for CPP policies Ticket #112063
                                                when V_TRANS_TYPE = '5' and trg.TRANS_TYPE = '4' then trg.TRANS_TYPE                 -- New Business w/ Payment Trans Type assignment
                                                when trg.TRANS_TYPE = 'R' then trg.TRANS_TYPE                                        -- Renewal Transaction Type assignment
                                                when V_TRANS_TYPE = '5' and trg.TRANS_TYPE = '5' then trg.TRANS_TYPE 
                                                when src.MBS_TRANS_TYPE = 'RESCISSION' and trg.TRANS_TYPE = '5' then trg.TRANS_TYPE  -- Recission Trans Type assignment
                                                when trg.TRANS_TYPE = '4' and V_TRANS_TYPE = '6' then V_TRANS_TYPE
                                                when trg.TRANS_TYPE = '4' then trg.TRANS_TYPE
                                                when src.MBS_TRANS_TYPE = 'PAYMENT_TRANSFER_INTERNAL'                                -- Payment transfers without Account # change assign as cash trans
                                                     and trg.ACCOUNT_NUMBER =  src.ACCOUNT_NUMBER then V_TRANS_TYPE 
                                                when src.MBS_TRANS_TYPE = 'PAYMENT_TRANSFER_INTERNAL'                                -- Payment transfers with Account # change assign as change trans
                                                     and trg.ACCOUNT_NUMBER <> src.ACCOUNT_NUMBER then '2' 
                                                when trg.TRANS_TYPE = '2' and trg.MBS_TRANS_TYPE not in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') and src.MBS_TRANS_TYPE not in ('NEW','RENEWAL','CANCELLATION') then trg.TRANS_TYPE    -- Endorsement coupled with Another Trans assignment; Endorsement is assigned as long as not coupled w/ New Business, Renewal or Cancellation
                                                when V_TRANS_TYPE = '6' then V_TRANS_TYPE 
                                                when trg.TRANS_TYPE = '6' then trg.TRANS_TYPE                                                    -- Cancellation coupled with any other transaction
                                             else V_TRANS_TYPE end, 
            trg.EXT_INT_SW    =            src.EXT_INT_SW,
            trg.WRITTEN_PREM  =            case when src.MBS_TRANS_TYPE = 'NEW' and trg.MBS_TRANS_TYPE = 'ENDORSEMENT' then src.WRITTEN_PREM+trg.WRITTEN_PREM          -- Sum Written Prem if endorsement is compounded with a nb transaction
                                                when src.MBS_TRANS_TYPE = 'NEW' and trg.MBS_TRANS_TYPE = 'PAYMENT' then src.WRITTEN_PREM                               -- Payment trans prior to New Business
                                                when src.MBS_TRANS_TYPE = 'ENDORSEMENT' and trg.MBS_TRANS_TYPE = 'ENDORSEMENT' then src.WRITTEN_PREM+trg.WRITTEN_PREM  -- Sum Written Prem if endorsement is compounded with a endorsement transaction
                                                when src.MBS_TRANS_TYPE = 'CANCELLATION' and trg.MBS_TRANS_TYPE = 'NEW' then src.WRITTEN_PREM+trg.WRITTEN_PREM         -- Sum Written Prem if nb is compounded with a cancellation transaction
                                                when src.MBS_TRANS_TYPE = 'CANCELLATION'  then src.WRITTEN_PREM
                                                when src.MBS_TRANS_TYPE = 'REINSTATEMENT' then src.WRITTEN_PREM
                                                when src.MBS_TRANS_TYPE = 'ENDORSEMENT' then src.WRITTEN_PREM
                                                when src.MBS_TRANS_TYPE = 'PAYMENT' then trg.WRITTEN_PREM
                                                when src.MBS_TRANS_TYPE = 'RENEWAL' then src.WRITTEN_PREM
                                                when src.MBS_TRANS_TYPE = 'EARNED_BILL' then trg.WRITTEN_PREM
                                              else trg.WRITTEN_PREM
                                           end,
            trg.STATE_CD      =            src.STATE_CD,
            trg.DPP_INST_NUM  =            null,
            trg.DPP_TOT_INST  =            null,
            trg.ASSUMED       =            null, --src.ASSUMED,
            trg.COMPANY       =            trg.COMPANY,
            trg.AUDIT_CODE    =            null,
            trg.ACT_CODE      =            v_ACT_CODE, --substr(src.ACT_CODE, 1, 2),
            trg.ACT_DATE      =            case when src.PAY_OPTION != 'E' and src.MBS_TRANS_TYPE = 'RENEWAL' and src.AMOUNT_DUE > 0 then src.MBS_BILL_SEND_DATE
                                                when src.PAY_OPTION = 'E' and src.MBS_TRANS_TYPE = 'RENEWAL' and src.AMOUNT_DUE > 0 then src.MBS_BILL_DUE_DATE
                                                when src.PAY_OPTION = 'E' and src.MBS_TRANS_TYPE = 'NEW' and src.AMOUNT_DUE > 0 then src.MBS_BILL_DUE_DATE
                                             else src.ACT_DATE end,
            trg.NAME          =            UPPER(substr(src.NAME, 1, 10)),
            trg.TRANS_SOURCE_SW  =         'A', 
            trg.INT_WHO        =           null,
            INT_REAS           =           case when  src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then '14' 
                                                when  trg.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then '14' end,               -- 9/4/2019 change to assign int reas Ticket #111860
            trg.INT_DATE       =           case when  src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then src.process_date 
                                                when  trg.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then src.process_date end,   -- 9/4/2019 change to assign int reas Ticket #111860
            trg.EXT_TRANS_DESC =           null,
            trg.REASON_DUE     =           null,
            trg.CANCEL_REAS    =           v_CANC_REAS,-- null, --src.CANCEL_REAS,
            trg.BILL_FORM1     =           case when trg.BILL_FORM1 is null and src.BILL_FORM1 in ('ACCOUNT_INVOICE', 'BILL', 'MORTGAGEE_INVOICE')  and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'  --Assign billing from for bills on "Inforce" status only
                                                --when src.BILL_FORM1 = 'BILL'              and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'  --Assign billing from for bills on "Inforce" status only
                                                --when src.BILL_FORM1 = 'MORTGAGEE_INVOICE' and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'  --Assign billing from for bills on "Inforce" status only
                                                when trg.BILL_FORM1 = 'A6' and src.MBS_TRANS_TYPE = 'CANCELLATION' then null   -- Removal of the Rescission Form assignment if coupled with a Cancellation 11/6/2019 Ticket # 112014
                                                when trg.BILL_FORM1 is null and src.BILL_FORM1 = 'CANCELLATION_NOTICE' then 'A3'
                                                when trg.BILL_FORM1 is null and trg.BILL_FORM1 = 'A3' then trg.BILL_FORM1          -- Added on 6/24/2019                                    
                                                when trg.BILL_FORM1 is null and src.BILL_FORM1 = 'RESCISSION_NOTICE'   then 'A6'
                                                when trg.BILL_FORM1 is null and src.MBS_TRANS_TYPE = 'REINSTATEMENT'   then 'A6'
                                                when trg.BILL_FORM1 is null and trg.MBS_TRANS_TYPE = 'PAYMENT' and src.BILL_FORM1 = 'RESCISSION_NOTICE' then 'A6'
                                                when trg.BILL_FORM1 is null and src.MBS_TRANS_TYPE = 'RESCISSION' then 'A6'  -- Updated 9/27/2019 to support MBS not assigning Manual Rescission
                                                when trg.BILL_FORM1 is null and src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07') and v_CANC_REAS in ('01','AP') THEN 'A4'
                                                when src.BILL_FORM1 is null and trg.BILL_FORM1 is not null then trg.BILL_FORM1
                                             else trg.BILL_FORM1 end, --V_BILL_FORM,
            trg.BILL_FORM2     =            case when trg.BILL_FORM2 = 'A6' and src.MBS_TRANS_TYPE = 'CANCELLATION' then null   -- Removal of the Rescission Form assignment if coupled with a Cancellation 11/6/2019 Ticket # 112014
                                                 when trg.BILL_FORM1 is not null and trg.BILL_FORM1 <> 'A6' and src.BILL_FORM1 in ('RESCISSION_NOTICE','REINSTATEMENT') then 'A6' -- Added 7/16/2019 
                                                 when trg.BILL_FORM1 is not null and trg.BILL_FORM1 <> 'A3' and src.BILL_FORM1 = 'CANCELLATION_NOTICE' then 'A3'                  -- Added 7/16/2019 
                                                 when trg.BILL_FORM1 is not null and trg.BILL_FORM1 <> 'A10' and src.BILL_FORM1 in ('ACCOUNT_INVOICE', 'BILL', 'MORTGAGEE_INVOICE')  and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10' -- Added 7/16/2019 
                                                 when trg.BILL_FORM1 is not null and src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07') and v_CANC_REAS in ('01','AP') THEN 'A4' -- Added 7/16/2019 
                                               else trg.BILL_FORM2 end,     --- Assignment of A6 form to BILL_FORM2 4/23/2019
            trg.BILL_FORM3     =            null,
            trg.BILL_FORM4     =            null,
            trg.BILL_FORM5     =            null,
            trg.RET_CK_REAS    =            v_RET_CK_REAS,
            trg.AMOUNT_DUE     =            case when trg.MBS_TRANS_TYPE = 'BILL_DUE' then trg.AMOUNT_DUE   -- Case to support correct Amount Due if there are any late fees applied.
                                                 when trg.MBS_TRANS_TYPE = 'BILL' then trg.AMOUNT_DUE       -- If the record updated is a Bill retain that amount due 
                                                 when trg.MBS_TRANS_TYPE = 'PAYMENT' and src.MBS_TRANS_TYPE = 'NEW' then trg.AMOUNT_DUE    -- Case to support correct Amount Due if there was a payment in prior trans.
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' and trg.MBS_TRANS_TYPE = 'NEW' then src.AMOUNT_DUE 
                                                 --when trg.MBS_TRANS_TYPE in ('PAYPLAN_ENDORSEMENT','BILLING_ENDORSEMENT') then src.TOTAL_PREM -- PayPlan or Billing Endorsement merge don't overwrite
                                              else src.AMOUNT_DUE
                                             end,
            trg.CASH_AMT       =            case when src.MBS_TRANS_TYPE = 'WRITEOFF' and trg.CASH_AMT <> src.CASH_AMT then trg.CASH_AMT + src.CASH_AMT  -- Case to support 2 WRITEOFF's in the same day.
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' and trg.MBS_TRANS_TYPE = 'PAYMENT' then trg.CASH_AMT + src.CASH_AMT  -- Case to support 2 Payments in the same day 
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' and trg.MBS_TRANS_TYPE = 'RESCISSION' then trg.CASH_AMT + src.CASH_AMT  
                                                 when src.MBS_TRANS_TYPE = 'REFUND' then trg.CASH_AMT
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' and trg.CASH_AMT > 0 then trg.CASH_AMT + src.CASH_AMT   -- Case to support more than 1 payment in the same cycle.
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' then src.CASH_AMT
                                                 when src.MBS_TRANS_TYPE = 'REVERSE_TRANSFER_PREMIUM' then src.CASH_AMT -- Case to support amount which is transferred.
                                                 when src.MBS_TRANS_TYPE = 'TRANSFER_PREMIUM' then src.CASH_AMT         -- Case to support amount which is transferred.
                                              else trg.CASH_AMT
                                            end,
            trg.SERVICE_CHARGE =            src.SERVICE_CHARGE,
            trg.PREV_AMT_DUE   =            case when src.MBS_TRANS_TYPE = 'REINSTATEMENT' then  src.PREV_AMT_DUE 
                                                 when trg.MBS_TRANS_TYPE = 'BILL_DUE'      then src.PREV_AMT_DUE            -- Case to support correct Previous Amount Due if there are any late fees applied.
                                                 when src.MBS_TRANS_TYPE = 'TRANSFER_PREMIUM' then src.PREV_AMT_DUE         -- Case to support amount of the previous amount due which is transferred.
                                                 when src.MBS_TRANS_TYPE = 'REVERSE_TRANSFER_PREMIUM' then src.PREV_AMT_DUE -- Case to support amount of the previous amount due which is transferred.
                                                 when src.MBS_TRANS_TYPE = 'PAYMENT' then src.PREV_AMT_DUE
                                                 when trg.MBS_TRANS_TYPE = 'NEW'     then trg.PREV_AMT_DUE                  -- Case to support correct assignment of Previous Amt Due when New Business and a Bill
                                                 when trg.MBS_TRANS_TYPE = 'RENEWAL' then trg.PREV_AMT_DUE                  -- Case to support correct assignment of Previous Amt Due when Renewal and a Bill
                                              else trg.PREV_AMT_DUE
                                            end,
            trg.RET_CK_AMT     =            decode(nvl(trg.RET_CK_AMT, 0), 0, nvl(trg.RET_CK_AMT, 0), src.RET_CK_AMT),     -- Returned Payment merge rule updated 3/27/2019
            trg.TIMES_BILLED   =            DECODE(trg.TRANS_TYPE, '4', trg.TIMES_BILLED, src.TIMES_BILLED),
            trg.TOT_TO_BILL    =            src.TOT_TO_BILL,
            trg.COMPANY_CHECK_NUM    =      null, 
            trg.COMPANY_CHECK_DATE   =      null,
            trg.COMPANY_CHECK_DATE_S =      null,
            trg.COMPANY_CHECK_REAS   =      null,
            trg.INST_SVC_CHG         =      case when src.MBS_TRANS_TYPE <> 'BILL' and trg.MBS_TRANS_TYPE in ('BILL','BILL_DUE') then trg.INST_SVC_CHG 
                                              else src.INST_SVC_CHG
                                            end,
            trg.INST_AMT             =      case when src.MBS_TRANS_TYPE <> 'BILL' and trg.MBS_TRANS_TYPE = 'BILL' then trg.INST_AMT 
                                              else src.INST_AMT
                                            end,
            trg.TERMINAL_USER        =      trg.TERMINAL_USER,
            trg.REAS_FORM            =      null, --src.REAS_FORM,
            trg.POLICY_TYPE          =      null,
            trg.REP_UNPAID_AMT       =      src.REP_UNPAID_AMT, 
            trg.NSF_IND              =      decode(trg.NSF_IND, NULL, v_NSF_IND, trg.NSF_IND),         -- Returned Payment merge rule updated 3/27/2019
            trg.REASON               =      null,
            trg.REAS_SPEC1_7         =      null,
            trg.DUE_DATE             =      case when src.BILL_FORM1 = 'CANCELLATION_NOTICE' then src.MBS_CANC_CHECK_DATE
                                                 when trg.DUE_DATE is null and src.DUE_DATE is not null then src.DUE_DATE
                                                else trg.DUE_DATE
                                              end,  -- Updated to case 5/23/2019; changed 5/15/2019 to keep the Due Date assigned if there is a bill in the cycle
            trg.ARREARS_AMT          =       case when src.MBS_TRANS_TYPE <> 'BILL' and trg.MBS_TRANS_TYPE in ('BILL','BILL_DUE') then trg.ARREARS_AMT 
                                              else src.ARREARS_AMT
                                            end,
            trg.ARREARS_SVC_CHG      =      case when src.MBS_TRANS_TYPE <> 'BILL' and trg.MBS_TRANS_TYPE = 'BILL' then trg.ARREARS_SVC_CHG 
                                              else src.ARREARS_SVC_CHG
                                            end,
            trg.CANC_NOTICE_OVERRIDE_SW  =  null,
            trg.CANC_COUNT_OVERRIDE_SW   =  null,
            trg.PTC_IND                  =  null,
            trg.PROC_CENTER              =  substr(src.PROC_CENTER, 1, 2),
            trg.EFT_OFFER_IND            =  null,
            trg.AGINTER_WIP              =  null,
            trg.NEXT_ACT_CODE            =  null,
            trg.REAS_SPEC8_13            =  null,
            trg.EARNED_PREM_RLETTER_SW   =  DECODE(src.MBS_TRANS_TYPE, 'EARNED_BILL', src.EARNED_PREM_RLETTER_SW, trg.EARNED_PREM_RLETTER_SW),
            trg.RUN_DATE                 =  src.RUN_DATE,
            trg.ACCOUNT_NUMBER           =  src.ACCOUNT_NUMBER,
            trg.MBS_TRANS_TYPE           =  src.MBS_TRANS_TYPE,
            trg.MBS_BILL_SEND_DATE       =  DECODE(trg.MBS_BILL_SEND_DATE, null, trg.MBS_BILL_SEND_DATE, src.MBS_BILL_SEND_DATE), -- changed 5/15/2019 to keep the Bill Send Date assigned if there is a bill in the cycle
            trg.MBS_BILL_DUE_DATE        =  DECODE(trg.MBS_BILL_DUE_DATE, null, trg.MBS_BILL_DUE_DATE, src.MBS_BILL_DUE_DATE),   -- changed 5/15/2019 to keep the Bill Due Date assigned if there is a bill in the cycle  
            trg.MBS_CANC_CHECK_DATE      =  src.MBS_CANC_CHECK_DATE,
            trg.MBS_CANC_REASON          =  src.MBS_CANC_REASON,
            trg.MBS_AUDIT_FLAG           =  src.MBS_AUDIT_FLAG,
            trg.MBS_NUM_DEMAND_NOTICES   =  src.MBS_NUM_DEMAND_NOTICES,
            trg.MBS_NUM_NSFS             =  src.MBS_NUM_NSFS,
            trg.MBS_NUM_EP_INVOICE       =  src.MBS_NUM_EP_INVOICE,
            trg.MBS_NUM_NOC              =  src.MBS_NUM_NOC,
            trg.MBS_POLICY_STATUS        =  src.MBS_POLICY_STATUS,
            trg.MBS_POLICY_HOLD          =  src.POLICY_HOLD,
            trg.MBS_ACCOUNT_HOLD         =  src.ACCOUNT_HOLD,
            trg.MBS_NOC_HOLD             =  src.NOC_HOLD,
            trg.MBS_SYSTEM_ACTIVITY_NO   =  src.MBS_SYSTEM_ACTIVITY_NO,
            trg.MBS_SOURCE_TRANSACTION_SEQ  =         src.MBS_SOURCE_TRANSACTION_SEQ,
            trg.MBS_OUTPUTSEQ               =         src.OUTPUTSEQ,
            trg.MBS_PAYMENT_ID              =         src.PAYMENT_ID,
            trg.MBS_TRANSACTION_REASON      =         src.MBS_TRANSACTION_REASON,
            trg.MBS_PAYMENT_METHOD          =         src.MBS_PAYMENT_METHOD,
            trg.MBS_POLICY_TERM_ID          =         src.MBS_POLICY_TERM_ID,
            trg.MBS_ACCOUNT_SYSTEM_CODE     =         src.MBS_ACCOUNT_SYSTEM_CODE,
            trg.MBS_SOURCE_SYSTEM_PROCESS_DATE  = least(trg.MBS_SOURCE_SYSTEM_PROCESS_DATE, nvl(src.MBS_SOURCE_SYSTEM_PROCESS_DATE, src.process_date)) -- Added 8/9/2019 to address MBS_SOURCE_SYSTEM_DATE assignment (used in last merge)


          WHEN NOT MATCHED THEN INSERT
            
           ( 
             POL_NUM,
             PROCESS_DATE,
             HISTORY_KEY,
             ADDL_KEY,
             AGENT_NUM,
             EFF_DATE,
             EXP_DATE,
             TOTAL_PREM,
             CHANGE_DATE,
             GROUP_LINE,
             BILL_TYPE,
             PAY_OPTION,
             TRANS_TYPE,
             EXT_INT_SW,
             WRITTEN_PREM,
             STATE_CD,
             DPP_INST_NUM,
             DPP_TOT_INST,
             ASSUMED,
             COMPANY,
             AUDIT_CODE,
             ACT_CODE,
             ACT_DATE,
             NAME,
             TRANS_SOURCE_SW,
             INT_WHO,
             INT_REAS,
             INT_DATE,
             EXT_TRANS_DESC,
             REASON_DUE,
             CANCEL_REAS,
             BILL_FORM1,
             BILL_FORM2,
             BILL_FORM3,
             BILL_FORM4,
             BILL_FORM5,
             RET_CK_REAS,
             AMOUNT_DUE,
             CASH_AMT,
             SERVICE_CHARGE,
             PREV_AMT_DUE,
             RET_CK_AMT,
             TIMES_BILLED,
             TOT_TO_BILL,
             COMPANY_CHECK_NUM,
             COMPANY_CHECK_DATE,
             COMPANY_CHECK_DATE_S,
             COMPANY_CHECK_REAS,
             INST_SVC_CHG,
             INST_AMT,
             TERMINAL_USER,
             REAS_FORM,
             POLICY_TYPE,
             REP_UNPAID_AMT,
             NSF_IND,
             REASON,
             REAS_SPEC1_7,
             DUE_DATE,
             ARREARS_AMT,
             ARREARS_SVC_CHG,
             CANC_NOTICE_OVERRIDE_SW,
             CANC_COUNT_OVERRIDE_SW,
             PTC_IND,
             PROC_CENTER,
             EFT_OFFER_IND,
             AGINTER_WIP,
             NEXT_ACT_CODE,
             REAS_SPEC8_13,
             EARNED_PREM_RLETTER_SW,
             RUN_DATE,
             ACCOUNT_NUMBER,
             MBS_TRANS_TYPE,
             MBS_BILL_SEND_DATE,
             MBS_BILL_DUE_DATE,
             MBS_CANC_CHECK_DATE,
             MBS_CANC_REASON,
             MBS_AUDIT_FLAG,
             MBS_NUM_DEMAND_NOTICES,
             MBS_NUM_NSFS,
             MBS_NUM_EP_INVOICE,
             MBS_NUM_NOC,
             MBS_POLICY_STATUS,
             MBS_POLICY_HOLD,
             MBS_ACCOUNT_HOLD,
             MBS_NOC_HOLD,
             MBS_SYSTEM_ACTIVITY_NO,
             MBS_SOURCE_TRANSACTION_SEQ,
             MBS_OUTPUTSEQ,
             MBS_PAYMENT_ID,
             MBS_TRANSACTION_REASON,
             MBS_PAYMENT_METHOD,
             MBS_POLICY_TERM_ID,
             MBS_ACCOUNT_SYSTEM_CODE,
             MBS_POLICY_NUMBER,
             MBS_SOURCE_SYSTEM_PROCESS_DATE
             )
            VALUES
            ( 
            substr(src.POL_NUM, 1, 10),  -- Policies numbers from MBS can be greater than 10. Apply substr of 10 to policy number
            src.PROCESS_DATE,--v_ND_PR_DATE,  -- N assigned process_date  --src.PROCESS_DATE,
            null, --src.HISTORY_KEY,
            src.ADDL_KEY,
            src.AGENT_NUM,
            src.EFF_DATE,
            src.EXP_DATE,
            src.TOTAL_PREM,
            src.CHANGE_DATE,
            src.GROUP_LINE,
               v_BILL_TYPE_CODE,  
            src.PAY_OPTION,
             case when src.GROUP_LINE = '95' and v_TRANS_TYPE in ('4','R') then null else v_TRANS_TYPE end,   -- 9/6/2019 Case added to remove assignment of trans type 4  for CPP policies Ticket #112063
            null, --src.EXT_INT_SW,
            src.WRITTEN_PREM,
            src.STATE_CD,
            null, --src.DPP_INST_NUM,
            null, --src.DPP_TOT_INST,
            null, --src.ASSUMED,
            v_company,
            null, --src.AUDIT_CODE,
                v_ACT_CODE, --substr(src.ACT_CODE, 1, 2),
            case when src.PAY_OPTION != 'E' and src.MBS_TRANS_TYPE = 'RENEWAL' and src.AMOUNT_DUE > 0 then src.MBS_BILL_SEND_DATE
                 when src.PAY_OPTION = 'E'  and src.MBS_TRANS_TYPE = 'RENEWAL' and src.AMOUNT_DUE > 0 then src.MBS_BILL_DUE_DATE
                 when src.PAY_OPTION = 'E'  and src.MBS_TRANS_TYPE = 'NEW'     and src.AMOUNT_DUE > 0 then src.MBS_BILL_DUE_DATE
             else src.ACT_DATE end,  -- Changed 5/10/2019 to support correct assignment of ACT_DATE on RENEWAL 
            substr(src.NAME, 1, 10),
            'A', --TRANS_SOURCE_SW,
            null, --src.INT_WHO,
            case when  src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then '14' end,               -- 9/4/2019 change to assign int reas,  Ticket #111860
            case when  src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07')  then src.process_date end,   -- 9/4/2019 change to assign int date,  Ticket #111860
            null, --src.EXT_TRANS_DESC,
            null, --src.REASON_DUE,
                v_CANC_REAS, --null, --decode(src.CANCEL_REAS, 'Non-Payment of Premium', 'NP', src.CANCEL_REAS),
            case when src.BILL_FORM1 = 'ACCOUNT_INVOICE'   and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'     --Assign billing from for bills on "Inforce" status only
                 when src.BILL_FORM1 = 'BILL'              and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'     --Assign billing from for bills on "Inforce" status only
                 when src.BILL_FORM1 = 'MORTGAGEE_INVOICE' and src.MBS_POLICY_STATUS NOT IN ('UNDERNOTICE','REQ_CANCELLATION') then 'A10'     --Assign billing from for bills on "Inforce" status only
                 when src.BILL_FORM1 = 'CANCELLATION_NOTICE' then 'A3'
                -- when src.BILL_FORM1 = 'RENEWAL' AND  src.PAY_OPTION != 'E' then 'A7'
                 when src.BILL_FORM1 = 'RESCISSION_NOTICE'   then 'A6'
                 when src.MBS_TRANS_TYPE = 'REINSTATEMENT'   then 'A6'
                 when src.BILL_FORM1 is null and src.MBS_TRANS_TYPE = 'RESCISSION' then 'A6'  -- Updated 9/27/2019 to support MBS not assigning Manual Rescission
                 when src.MBS_TRANS_TYPE = 'CANCELLATION' and src.GROUP_LINE in ('06','07') and v_CANC_REAS in ('01','AP') THEN 'A4'
             else null 
            end, --           V_BILL_FORM,
            null, --src.BILL_FORM2,
            null, --src.BILL_FORM3,
            null, --src.BILL_FORM4,
            null, --src.BILL_FORM5,
               v_RET_CK_REAS,
            src.AMOUNT_DUE,
            src.CASH_AMT,
            src.SERVICE_CHARGE,
            src.PREV_AMT_DUE,
            src.RET_CK_AMT, 
            src.TIMES_BILLED,
            src.TOT_TO_BILL,
            null, --src.COMPANY_CHECK_NUM,
            null, --src.COMPANY_CHECK_DATE,
            null, --src.COMPANY_CHECK_DATE_S,
            null, --src.COMPANY_CHECK_REAS,
            src.INST_SVC_CHG,
            src.INST_AMT,
            substr(src.TERMINAL_USER, 1, 3), --src.TERMINAL_USER,
            null, --src.REAS_FORM,
            null, --src.POLICY_TYPE,
            case when src.REP_UNPAID_AMT is null and src.MBS_TRANS_TYPE = 'EARNED_BILL' then (src.ARREARS_AMT+src.ARREARS_SVC_CHG)
                else src.REP_UNPAID_AMT
              end,          -- Updated REP_UNPAID_AMT assignemant when MBS fails to correctly assign 11/6/2019 Ticket #113495
               v_NSF_IND, 
            null, --src.REASON,
            null, --src.REAS_SPEC1_7,
            decode(src.BILL_FORM1, 'CANCELLATION_NOTICE', src.MBS_CANC_CHECK_DATE, src.DUE_DATE),  -- Assign Cancellation Date to due date if Cancellation notice 5/23/2019
            src.ARREARS_AMT,
            src.ARREARS_SVC_CHG,
            null, --src.CANC_NOTICE_OVERRIDE_SW,
            null, --src.CANC_COUNT_OVERRIDE_SW,
            null, --src.PTC_IND,
            substr(src.PROC_CENTER, 1, 2),
            null, --src.EFT_OFFER_IND,
            null, --src.AGINTER_WIP,
            null, --src.NEXT_ACT_CODE,
            null, --src.REAS_SPEC8_13,
            case when src.EARNED_PREM_RLETTER_SW is null and src.MBS_TRANS_TYPE = 'EARNED_BILL' then 2
                else src.EARNED_PREM_RLETTER_SW
              end,                             -- Updated EARNED_PREM_RLETTER_SW assignemant when MBS fails to correctly assign 11/6/2019 Ticket #113495
            src.RUN_DATE,           -- Removed 1/15/2019  subtracting 1 day in order to be in sync with NPS WANG_RECAP records.
            src.ACCOUNT_NUMBER,
            src.MBS_TRANS_TYPE,
            src.MBS_BILL_SEND_DATE,
            src.MBS_BILL_DUE_DATE,
            src.MBS_CANC_CHECK_DATE,
            src.MBS_CANC_REASON,
            src.MBS_AUDIT_FLAG,
            src.MBS_NUM_DEMAND_NOTICES,
            src.MBS_NUM_NSFS,
            src.MBS_NUM_EP_INVOICE,
            src.MBS_NUM_NOC,
            src.MBS_POLICY_STATUS,
            src.POLICY_HOLD,
            src.ACCOUNT_HOLD,
            src.NOC_HOLD,
            src.MBS_SYSTEM_ACTIVITY_NO,
            src.MBS_SOURCE_TRANSACTION_SEQ,
            src.OUTPUTSEQ,
            src.PAYMENT_ID,
            src.MBS_TRANSACTION_REASON,
            src.MBS_PAYMENT_METHOD,
            src.MBS_POLICY_TERM_ID,
            src.MBS_ACCOUNT_SYSTEM_CODE,
            src.POL_NUM,
            nvl(src.MBS_SOURCE_SYSTEM_PROCESS_DATE, src.process_date));  --Assignment of source system process process date for non premium bearing changes
          

commit;            
      

  END LOOP;

    CLOSE mbs_wang_recap_read;


v_err_loc:='Merge data into WANG_RECAP...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);    
  --- MERGE INTO APDEV.WANG_RECAP

commit;
-- Analyze WANG_RECAP_MPS Table  (especailly important for Day 0)
--DBMS_STATS.gather_table_stats('BILLING', 'WANG_RECAP_MBS');

 MERGE INTO APDEV.WANG_RECAP trg
            USING (select * 
                     from billing.wang_recap_mbs
                   -- where PROCESS_DATE = TO_DATE('10/26/2018','MM/DD/YYYY')
                   --   AND RUN_DATE = TO_DATE('10/29/2018','MM/DD/YYYY')) src
                   where process_date = v_ND_PR_DATE) src
                      --and run_date = v_mx_pr_date) src  -- adjusted to handle mbsi internal dates that are process_date+1
                      --and pol_num in ('P012002884','P012002885','P012002886')) src 
                      --and nvl(mbs_source_transaction_seq, 1) = nvl(wr_rec.mbs_source_transaction_seq, 1)) src
            ON  (trg.pol_num      = substr(src.pol_num, 1, 10)
             and trg.process_date = (case when src.BILL_FORM1 is null then 
                                        decode(src.process_date, nvl(src.mbs_source_system_process_date, src.process_date), src.process_date, src.mbs_source_system_process_date)
                                         else src.process_date
                                     end)
             --src.process_date
             and trg.eff_date     = src.eff_date)
            
            WHEN MATCHED THEN UPDATE
            
            set
 
            --trg.POL_NUM       =            src.POL_NUM,
            --trg.PROCESS_DATE  =            src.PROCESS_DATE,
            --trg.HISTORY_KEY   =            null,
            trg.ADDL_KEY      =            trg.ADDL_KEY,
            --trg.AGENT_NUM     =            trg.AGENT_NUM,
           -- trg.EFF_DATE      =            src.EFF_DATE,
           -- trg.EXP_DATE      =            src.EXP_DATE,
            --trg.TOTAL_PREM    =            src.TOTAL_PREM,
            --trg.CHANGE_DATE   =            src.CHANGE_DATE,
            trg.GROUP_LINE    =            src.GROUP_LINE,
            trg.BILL_TYPE     =            src.BILL_TYPE,
            trg.PAY_OPTION    =            src.PAY_OPTION,
            trg.TRANS_TYPE    =            case when trg.TRANS_TYPE is null then src.TRANS_TYPE
                                             else trg.TRANS_TYPE
                                            end,
            trg.EXT_INT_SW    =            src.EXT_INT_SW,
            --trg.WRITTEN_PREM  =            src.WRITTEN_PREM,
            trg.STATE_CD      =            src.STATE_CD,
            --trg.DPP_INST_NUM  =            null,
            --trg.DPP_TOT_INST  =            null,
            --trg.ASSUMED       =            null, --src.ASSUMED,
            trg.COMPANY       =            trg.COMPANY,
            --trg.AUDIT_CODE    =            null,
            trg.ACT_CODE      =            case when trg.ACT_CODE in ('60','62') then trg.ACT_CODE 
                                              else src.ACT_CODE
                                             end, --substr(src.ACT_CODE, 1, 2),
            trg.ACT_DATE      =            src.ACT_DATE,
            trg.NAME          =            UPPER(substr(src.NAME, 1, 10)),
            trg.TRANS_SOURCE_SW  =         trg.TRANS_SOURCE_SW, 
            --trg.INT_WHO        =           null,
            trg.INT_REAS       =           src.INT_REAS,   -- Added on 11/15/2019 to address assigment of MAPPA & Coml Auto Cancellations
            trg.INT_DATE       =           src.INT_DATE,    -- Added on 11/15/2019 to address assigment of MAPPA & Coml Auto Cancellations
           -- trg.EXT_TRANS_DESC =           null,
            --trg.REASON_DUE     =           null,
            trg.CANCEL_REAS    =           src.CANCEL_REAS,
            trg.BILL_FORM1     =           src.BILL_FORM1,
            trg.BILL_FORM2     =           src.BILL_FORM2,
            --trg.BILL_FORM3     =           null,
            --trg.BILL_FORM4     =           null,
            --trg.BILL_FORM5     =           null,
            trg.RET_CK_REAS    =           src.RET_CK_REAS,
            trg.AMOUNT_DUE     =           src.AMOUNT_DUE,
            trg.CASH_AMT       =           src.CASH_AMT,  
            trg.SERVICE_CHARGE =           src.SERVICE_CHARGE,
            trg.PREV_AMT_DUE   =           src.PREV_AMT_DUE,
            trg.RET_CK_AMT     =           src.RET_CK_AMT, 
            trg.TIMES_BILLED   =           src.TIMES_BILLED,
            trg.TOT_TO_BILL    =           src.TOT_TO_BILL,
            --trg.COMPANY_CHECK_NUM    =      null, 
            --trg.COMPANY_CHECK_DATE   =      null,
            --trg.COMPANY_CHECK_DATE_S =      null,
            --trg.COMPANY_CHECK_REAS   =      null,
            trg.INST_SVC_CHG         =     src.INST_SVC_CHG,
            trg.INST_AMT             =     src.INST_AMT,
            trg.TERMINAL_USER        =     trg.TERMINAL_USER,
            --trg.REAS_FORM            =      null, --src.REAS_FORM,
            --trg.POLICY_TYPE          =      null,
            trg.REP_UNPAID_AMT       =      src.REP_UNPAID_AMT, 
            trg.NSF_IND              =      src.NSF_IND, 
           -- trg.REASON               =      null,
           -- trg.REAS_SPEC1_7         =      null,
            trg.DUE_DATE             =      src.DUE_DATE,
            trg.ARREARS_AMT          =      src.ARREARS_AMT,
            trg.ARREARS_SVC_CHG      =      src.ARREARS_SVC_CHG,
            --trg.CANC_NOTICE_OVERRIDE_SW  =  null,
            --trg.CANC_COUNT_OVERRIDE_SW   =  null,
            trg.PTC_IND                  =  trg.PTC_IND,
            trg.PROC_CENTER              =  src.PROC_CENTER,
            --trg.EFT_OFFER_IND            =  null,
            --trg.AGINTER_WIP              =  null,
            --trg.NEXT_ACT_CODE            =  null,
            --trg.REAS_SPEC8_13            =  null,
            trg.EARNED_PREM_RLETTER_SW   =  src.EARNED_PREM_RLETTER_SW,
            trg.RUN_DATE                 =  trg.RUN_DATE,
            trg.ACCOUNT_NUMBER           =  src.ACCOUNT_NUMBER,
            trg.MBS_TRANS_TYPE           =  src.MBS_TRANS_TYPE,
            trg.MBS_BILL_SEND_DATE       =  src.MBS_BILL_SEND_DATE,
            trg.MBS_BILL_DUE_DATE        =  src.MBS_BILL_DUE_DATE,
            trg.MBS_CANC_CHECK_DATE      =  src.MBS_CANC_CHECK_DATE,
            trg.MBS_CANC_REASON          =  src.MBS_CANC_REASON,
            trg.MBS_AUDIT_FLAG           =  src.MBS_AUDIT_FLAG,
            trg.MBS_NUM_DEMAND_NOTICES   =  src.MBS_NUM_DEMAND_NOTICES,
            trg.MBS_NUM_NSFS             =  src.MBS_NUM_NSFS,
            trg.MBS_NUM_EP_INVOICE       =  src.MBS_NUM_EP_INVOICE,
            trg.MBS_NUM_NOC              =  src.MBS_NUM_NOC,
            trg.MBS_POLICY_STATUS        =  src.MBS_POLICY_STATUS,
            trg.MBS_POLICY_HOLD          =  src.MBS_POLICY_HOLD,
            trg.MBS_ACCOUNT_HOLD         =  src.MBS_ACCOUNT_HOLD,
            trg.MBS_NOC_HOLD             =  src.MBS_NOC_HOLD,
            trg.MBS_SYSTEM_ACTIVITY_NO   =  src.MBS_SYSTEM_ACTIVITY_NO,
            trg.MBS_SOURCE_TRANSACTION_SEQ  =         src.MBS_SOURCE_TRANSACTION_SEQ,
            trg.MBS_OUTPUTSEQ               =         src.MBS_OUTPUTSEQ,
            trg.MBS_PAYMENT_ID              =         src.MBS_PAYMENT_ID,
            trg.MBS_TRANSACTION_REASON      =         src.MBS_TRANSACTION_REASON,
            trg.MBS_PAYMENT_METHOD          =         src.MBS_PAYMENT_METHOD,
            trg.MBS_POLICY_TERM_ID          =         src.MBS_POLICY_TERM_ID,
            trg.MBS_ACCOUNT_SYSTEM_CODE     =         src.MBS_ACCOUNT_SYSTEM_CODE,
            trg.MBS_POLICY_NUMBER           =         src.MBS_POLICY_NUMBER,
            trg.MBS_SOURCE_SYSTEM_PROCESS_DATE =      src.MBS_SOURCE_SYSTEM_PROCESS_DATE,
            trg.MBS_PROCESS_DATE               =      src.PROCESS_DATE,
            trg.NPS_FLG                        =      trg.NPS_FLG,
            trg.NPS_LOAD_DATE                  =      trg.NPS_LOAD_DATE,
            trg.MBS_FLG                        =      'Y',
            trg.MBS_LOAD_DATE                  =      SYSDATE,
            trg.MBS_TOTAL_WRITTEN_PREM         =      src.TOTAL_PREM
  
          WHEN NOT MATCHED THEN INSERT
            
           ( 
             POL_NUM,
             PROCESS_DATE,
             HISTORY_KEY,
             ADDL_KEY,
             AGENT_NUM,
             EFF_DATE,
             EXP_DATE,
             TOTAL_PREM,
             CHANGE_DATE,
             GROUP_LINE,
             BILL_TYPE,
             PAY_OPTION,
             TRANS_TYPE,
             EXT_INT_SW,
             WRITTEN_PREM,
             STATE_CD,
             DPP_INST_NUM,
             DPP_TOT_INST,
             ASSUMED,
             COMPANY,
             AUDIT_CODE,
             ACT_CODE,
             ACT_DATE,
             NAME,
             TRANS_SOURCE_SW,
             INT_WHO,
             INT_REAS,
             INT_DATE,
             EXT_TRANS_DESC,
             REASON_DUE,
             CANCEL_REAS,
             BILL_FORM1,
             BILL_FORM2,
             BILL_FORM3,
             BILL_FORM4,
             BILL_FORM5,
             RET_CK_REAS,
             AMOUNT_DUE,
             CASH_AMT,
             SERVICE_CHARGE,
             PREV_AMT_DUE,
             RET_CK_AMT,
             TIMES_BILLED,
             TOT_TO_BILL,
             COMPANY_CHECK_NUM,
             COMPANY_CHECK_DATE,
             COMPANY_CHECK_DATE_S,
             COMPANY_CHECK_REAS,
             INST_SVC_CHG,
             INST_AMT,
             TERMINAL_USER,
             REAS_FORM,
             POLICY_TYPE,
             REP_UNPAID_AMT,
             NSF_IND,
             REASON,
             REAS_SPEC1_7,
             DUE_DATE,
             ARREARS_AMT,
             ARREARS_SVC_CHG,
             CANC_NOTICE_OVERRIDE_SW,
             CANC_COUNT_OVERRIDE_SW,
             PTC_IND,
             PROC_CENTER,
             EFT_OFFER_IND,
             AGINTER_WIP,
             NEXT_ACT_CODE,
             REAS_SPEC8_13,
             EARNED_PREM_RLETTER_SW,
             RUN_DATE,
             ACCOUNT_NUMBER,
             MBS_TRANS_TYPE,
             MBS_BILL_SEND_DATE,
             MBS_BILL_DUE_DATE,
             MBS_CANC_CHECK_DATE,
             MBS_CANC_REASON,
             MBS_AUDIT_FLAG,
             MBS_NUM_DEMAND_NOTICES,
             MBS_NUM_NSFS,
             MBS_NUM_EP_INVOICE,
             MBS_NUM_NOC,
             MBS_POLICY_STATUS,
             MBS_POLICY_HOLD,
             MBS_ACCOUNT_HOLD,
             MBS_NOC_HOLD,
             MBS_SYSTEM_ACTIVITY_NO,
             MBS_SOURCE_TRANSACTION_SEQ,
             MBS_OUTPUTSEQ,
             MBS_PAYMENT_ID,
             MBS_TRANSACTION_REASON,
             MBS_PAYMENT_METHOD,
             MBS_POLICY_TERM_ID,
             MBS_ACCOUNT_SYSTEM_CODE,
             MBS_POLICY_NUMBER,
             MBS_SOURCE_SYSTEM_PROCESS_DATE,
             MBS_PROCESS_DATE,
             NPS_FLG,
             NPS_LOAD_DATE,
             MBS_FLG,
             MBS_LOAD_DATE,
             MBS_TOTAL_WRITTEN_PREM             
             )
            VALUES
            ( 
            src.POL_NUM,
            src.PROCESS_DATE,
            src.HISTORY_KEY,
            src.ADDL_KEY,
            src.AGENT_NUM,
            src.EFF_DATE,
            src.EXP_DATE,
            TOTAL_PREM,
            src.CHANGE_DATE,
            src.GROUP_LINE,
            src.BILL_TYPE,  
            src.PAY_OPTION,
            CASE WHEN src.TRANS_TYPE IN ('4','6','R') THEN NULL ELSE src.TRANS_TYPE END, -- 10/23/2019 Removed assignment of trans type from MBS to WANG_RECAP when trans_type in ('4','6','R') NPS should drive assignment 
            src.EXT_INT_SW,
            0, --src.WRITTEN_PREM,  -- commented out written premium on 7/232019
            src.STATE_CD,
            src.DPP_INST_NUM,
            src.DPP_TOT_INST,
            src.ASSUMED,
            src.COMPANY,
            src.AUDIT_CODE,
            src.ACT_CODE,
            src.ACT_DATE,
            src.NAME,
            src.TRANS_SOURCE_SW,
            src.INT_WHO,
            src.INT_REAS,
            src.INT_DATE,
            src.EXT_TRANS_DESC,
            src.REASON_DUE,
            src.CANCEL_REAS,
            src.BILL_FORM1,
            src.BILL_FORM2,
            src.BILL_FORM3,
            src.BILL_FORM4,
            src.BILL_FORM5,
            src.RET_CK_REAS,
            src.AMOUNT_DUE,
            src.CASH_AMT,
            src.SERVICE_CHARGE,
            src.PREV_AMT_DUE,
            src.RET_CK_AMT, 
            src.TIMES_BILLED,
            src.TOT_TO_BILL,
            src.COMPANY_CHECK_NUM,
            src.COMPANY_CHECK_DATE,
            src.COMPANY_CHECK_DATE_S,
            src.COMPANY_CHECK_REAS,
            src.INST_SVC_CHG,
            src.INST_AMT,
            src.TERMINAL_USER,
            src.REAS_FORM,
            src.POLICY_TYPE,
            src.REP_UNPAID_AMT, 
            src.NSF_IND, 
            src.REASON,
            src.REAS_SPEC1_7,
            src.DUE_DATE,
            src.ARREARS_AMT,
            src.ARREARS_SVC_CHG,
            src.CANC_NOTICE_OVERRIDE_SW,
            src.CANC_COUNT_OVERRIDE_SW,
            src.PTC_IND,
            src.PROC_CENTER,
            src.EFT_OFFER_IND,
            src.AGINTER_WIP,
            src.NEXT_ACT_CODE,
            src.REAS_SPEC8_13,
            src.EARNED_PREM_RLETTER_SW,
            src.RUN_DATE,
            src.ACCOUNT_NUMBER,
            src.MBS_TRANS_TYPE,
            src.MBS_BILL_SEND_DATE,
            src.MBS_BILL_DUE_DATE,
            src.MBS_CANC_CHECK_DATE,
            src.MBS_CANC_REASON,
            src.MBS_AUDIT_FLAG,
            src.MBS_NUM_DEMAND_NOTICES,
            src.MBS_NUM_NSFS,
            src.MBS_NUM_EP_INVOICE,
            src.MBS_NUM_NOC,
            src.MBS_POLICY_STATUS,
            src.MBS_POLICY_HOLD,
            src.MBS_ACCOUNT_HOLD,
            src.MBS_NOC_HOLD,
            src.MBS_SYSTEM_ACTIVITY_NO,
            src.MBS_SOURCE_TRANSACTION_SEQ,
            src.MBS_OUTPUTSEQ,
            src.MBS_PAYMENT_ID,
            src.MBS_TRANSACTION_REASON,
            src.MBS_PAYMENT_METHOD,
            src.MBS_POLICY_TERM_ID,
            src.MBS_ACCOUNT_SYSTEM_CODE,
            src.MBS_POLICY_NUMBER,
            nvl(src.MBS_SOURCE_SYSTEM_PROCESS_DATE, src.process_date),
            src.PROCESS_DATE,
            NULL,
            NULL,
            'Y',
            SYSDATE,
            src.TOTAL_PREM);       

COMMIT;


v_err_loc:='Update WANG RECAP w/ RPTVIEWER.RPT_POLICY.TOTAL_PREMIUM...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);    


-- UPDATE WANG RECAP records loaded from MBS exclusively w/ RPTVIEWER.RPT_POLICY.TOTAL_PREMIUM 
update apdev.wang_recap wru
    set total_prem = 
        (select nvl(rp.total_prem, wr.total_prem)
           from APDEV.WANG_RECAP wr,
                RPTVIEWER.RPT_POLICY rp
          where wr.run_date =  v_ND_RN_DATE 
            and wr.mbs_flg = 'Y'
            and wr.nps_flg is null
            and rp.policy_number(+) = wr.pol_num
            and wru.pol_num = wr.pol_num 
            and wru.eff_date = wr.eff_date
            and wru.run_date = wr.run_date
            and wru.total_prem <> rp.total_prem)
   where exists (select 1
                   from APDEV.WANG_RECAP wr,
                        RPTVIEWER.RPT_POLICY rp
                  where wr.run_date = v_ND_RN_DATE
                    and wr.mbs_flg = 'Y'
                    and wr.nps_flg is null
                    and wru.pol_num = wr.pol_num 
                    and wru.eff_date =  wr.eff_date
                    and wru.run_date = wr.run_date
                    and rp.policy_number(+) = wr.pol_num
                    and wr.total_prem <> rp.total_prem);
  
COMMIT;



v_err_loc:='Update Non Prem Bearing WANG_RECAP records with Billing Attributes...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);    
 

-- UPDATE whihch applies the latest billing attributes to Non-Monetary transactions.  
-- The billing attributes are retrieved from a view which has collected the latest billing transactions from WANG_RECAP

--DBMS_OUTPUT.PUT_LINE('MBS Process Date = ' || v_ND_PR_DATE);


UPDATE APDEV.WANG_RECAP wru
   SET (wru.AMOUNT_DUE, 
        wru.CASH_AMT, 
        wru.SERVICE_CHARGE, 
        wru.PREV_AMT_DUE, 
        wru.RET_CK_AMT, 
        wru.TIMES_BILLED, 
        wru.TOT_TO_BILL, 
        wru.INST_SVC_CHG,
        wru.INST_AMT, 
        wru.REP_UNPAID_AMT, 
        wru.DUE_DATE, 
        wru.ARREARS_AMT, 
        wru.ARREARS_SVC_CHG, 
        wru.NEXT_ACT_CODE,
        wru.MBS_TOTAL_WRITTEN_PREM) =    
       (select distinct mba.AMOUNT_DUE, 
               mba.CASH_AMT, 
               mba.SERVICE_CHARGE,
               mba.PREV_AMT_DUE, 
               mba.RET_CK_AMT, 
               mba.TIMES_BILLED, 
               mba.TOT_TO_BILL, 
               mba.INST_SVC_CHG, 
               mba.INST_AMT,
               mba.REP_UNPAID_AMT, 
               mba.DUE_DATE, 
               mba.ARREARS_AMT, 
               mba.ARREARS_SVC_CHG, 
               mba.NEXT_ACT_CODE,
               mba.MBS_TOTAL_WRITTEN_PREM            
  from V_MAX_BILL_ACTIVITY mba,
       APDEV.WANG_RECAP wr
 where wr.pol_num = mba.policy_number
   and wr.PROCESS_DATE = v_ND_PR_DATE
   and wr.pol_num = wru.pol_num
   and mba.EFF_DATE = wr.EFF_DATE
   and wr.addl_key = 0
   and wr.nps_flg = 'Y' and wr.mbs_flg is null)
where wru.nps_flg = 'Y' 
  and wru.mbs_flg is null
  and wru.addl_key = 0
  and wru.process_date = v_ND_PR_DATE;
           
COMMIT; 

-- Update Loads Finished 
rptviewer.update_loads_finished('MBS_RECAP');

commit;

v_err_loc:='Update RPTVIEWER.RPT_POLICY records with Billing Attributes...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);    
 -- Update RPTVIEWER with Billing Attributes

update rptviewer.rpt_policy rp
   set (amount_due,
       cash_amt,
       arrears_amt,  
       arrears_svc_chg,   
       inst_amt,
       inst_serv_chg, 
       rp.times_billed, 
       tot_to_bill,
       due_date,
       num_nsf_checks,
       num_notices,
       last_install_date,
       prior_install_date,
       act_code_01,         -- added act_code and act date 5/6/2019 to address assignment of activity code and activity date
       act_date_01) =        
       (select wr.amount_due, wr.cash_amt, wr.arrears_amt, wr.arrears_svc_chg, wr.inst_amt, wr.inst_svc_chg, 
               wr.times_billed, wr.tot_to_bill, wr.due_date, wr.mbs_num_nsfs, wr.mbs_num_noc, 
               decode(wr.bill_form1, 'A10', wr.process_date, nvl(last_install_date, wr.process_date)) last_install_date,   -- advancing of last installment date for billing recent activity  - 3/27/2019
               decode(wr.bill_form1, 'A10',  nvl(rpp.last_install_date, wr.process_date), prior_install_date) prior_install_date,  -- advancing of prior installment date for billing recent activity
               wr.act_code, wr.act_date  -- added act_code and act date 5/6/2019 to address assignment of activity code and activity date
          from APDEV.WANG_RECAP wr, RPTVIEWER.rpt_policy rpp
         where wr.run_date = v_ND_RN_DATE    
           and wr.eff_date = rp.policy_effective_date
           and nvl(wr.trans_source_sw, 'A') <> 'M'          -- Exclude Manual Transactions
           and wr.pol_num = rp.policy_number
           and wr.pol_num = rpp.policy_number   -- 3/27/2019
           and wr.eff_date = rpp.policy_effective_date)  -- Added to join on most current term when there are 2 terms in cycle 5/22/2019
 where exists (select 1
                 from apdev.wang_recap wr
                 where wr.pol_num = rp.policy_number
                   and wr.eff_date = rp.policy_effective_date
                   and nvl(wr.trans_source_sw, 'A') <> 'M'   -- Exclude Manual Transactions
                   and wr.run_date = v_ND_RN_DATE);
   --and rp.times_billed = '0000'
   --and rp.tot_to_bill = '0000'
   --and rp.due_date is null
   --and rp.amount_due = '0'
  -- and rp.run_date = v_ND_RN_DATE;   --- Update only the most recent (Current RUN_DATE) RPTVIEWER.RPT_POILCY records

COMMIT;

-- Generic Cancellation Notice update
update RPTVIEWER.RPT_POLICY rp
   set (due_date, amount_due, arrears_amt, arrears_svc_chg)  =
       (select md.due_date, md.arrears_amt+md.arrears_svc_chg can_due, md.arrears_amt, md.arrears_svc_chg 
          from BILLING.WANG_RECAP_MBS_DETAIL md
         where md.bill_form1 = 'A3'
           and md.run_date = v_ND_RN_DATE
     and rp.policy_number =  md.pol_num)
where exists (select 1 
                from BILLING.WANG_RECAP_MBS_DETAIL md
               where rp.policy_number = md.pol_num
                 and md.bill_form1 = 'A3'
                 and md.run_date = v_ND_RN_DATE);
commit;


--Generic Invoice Notice update
update RPTVIEWER.RPT_POLICY rp
   set (due_date, amount_due, arrears_amt, arrears_svc_chg)  =
       (select md.due_date, md.arrears_amt+md.arrears_svc_chg can_due, md.arrears_amt, md.arrears_svc_chg 
          from BILLING.WANG_RECAP_MBS_DETAIL md
         where md.bill_form1 = 'A10'
           and md.run_date = v_ND_RN_DATE
           and rp.policy_number =  md.pol_num)
where exists (select 1 
                from BILLING.WANG_RECAP_MBS_DETAIL md
               where rp.policy_number = md.pol_num
                 and md.bill_form1 = 'A10'
                 and md.run_date = v_ND_RN_DATE);
                 
                commit;

-- Update Loads Finished 
rptviewer.update_loads_finished('MBS_RPT_UPD');

COMMIT;

v_err_loc:='Update STAGING.HISTORY_WANG_POLICY records with Billing Attributes...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);    
 -- Update HISTORY_WANG_POLICY with Billing Attributes

update staging.history_wang_policy hp 
   set (amount_due,
       cash_amt,
       arrears_amt,  
       arrears_svc_chg,   
       inst_amt,
       inst_serv_chg, 
       times_billed, 
       tot_to_bill,
       due_date,
       num_nsf_checks,
       num_notices) =
(select rp.AMOUNT_DUE, 
        rp.CASH_AMT, 
        rp.ARREARS_AMT, 
        rp.ARREARS_SVC_CHG,  
        rp.INST_AMT,             
        rp.INST_SERV_CHG,
        rp.TIMES_BILLED, 
        rp.TOT_TO_BILL,              
        rp.DUE_DATE,
        rp.NUM_NSF_CHECKS,
        rp.NUM_NOTICES
  from RPTVIEWER.RPT_POLICY rp
 where hp.pol_num = rp.policy_number
   and hp.RUN_DATE = rp.RUN_DATE
   and rp.RUN_DATE = v_ND_RN_DATE
   and hp.EFF_DATE = rp.POLICY_EFFECTIVE_DATE)
WHERE HP.RUN_DATE = v_ND_RN_DATE
  AND EXISTS (select 1
                from rptviewer.rpt_policy rp
               where rp.RUN_DATE = v_ND_RN_DATE
                 and rp.RUN_DATE = hp.RUN_DATE
                 and rp.policy_number = hp.POL_NUM);

COMMIT;                 

/*  -- Old Hist Update 
update staging.history_wang_policy hp 
   set (amount_due,
       cash_amt,
       arrears_amt,  
       arrears_svc_chg,   
       inst_amt,
       inst_serv_chg, 
       times_billed, 
       tot_to_bill,
       due_date,
       num_nsf_checks,
       num_notices) =
(select distinct mba.AMOUNT_DUE, 
                mba.CASH_AMT, 
                mba.ARREARS_AMT, 
                mba.ARREARS_SVC_CHG,  
                mba.INST_AMT,             
                mba.INST_SVC_CHG, 
                mba.TIMES_BILLED, 
                mba.TOT_TO_BILL,              
                mba.DUE_DATE,
                mba.NUM_NSFS,
                mba.NUM_NOTICES
  from V_MAX_BILL_ACTIVITY mba,
       APDEV.WANG_RECAP wr
 where hp.pol_num = mba.policy_number
   and hp.RUN_DATE = v_ND_RN_DATE
   and wr.mbs_flg = 'Y'
   --mba.RUN_DATE
   and mba.policy_number = wr.pol_num 
   and wr.RUN_DATE = v_ND_RN_DATE
   and hp.EFF_DATE = mba.EFF_DATE
   and wr.addl_key = 0)
where exists
(select 1
from V_MAX_BILL_ACTIVITY mba,
       APDEV.WANG_RECAP wr
 where hp.pol_num = mba.policy_number
   and hp.RUN_DATE =  v_ND_RN_DATE --mba.RUN_DATE
   and wr.RUN_DATE = v_ND_RN_DATE
   and wr.mbs_flg = 'Y'
   and mba.policy_number = wr.pol_num 
   and hp.EFF_DATE = mba.EFF_DATE
   and wr.addl_key = 0);
*/
   
 -- Update Loads Finished 
rptviewer.update_loads_finished('MBS_HIST_UPD');

commit;  

/*
update staging.history_wang_policy hp
   set (amount_due,
       cash_amt,
       arrears_amt,  
       arrears_svc_chg,   
       inst_amt,
       inst_serv_chg, 
       hp.times_billed, 
       tot_to_bill,
       due_date,
       num_nsf_checks,
       num_notices) =
       (select  wr.amount_due, wr.cash_amt, wr.arrears_amt, wr.arrears_svc_chg, wr.inst_amt, wr.inst_svc_chg, 
               wr.times_billed, wr.tot_to_bill, wr.due_date, wr.mbs_num_nsfs, wr.mbs_num_noc
          from APDEV.WANG_RECAP wr
         where wr.run_date = v_ND_RN_DATE    
           and wr.eff_date = hp.eff_date
           and nvl(wr.trans_source_sw, 'A') <> 'M'          -- Exclude Manual Transactions
           --and wr.pol_num = 'R1650319A'
           and wr.pol_num = hp.pol_num)
 where exists (select 1
                 from apdev.wang_recap wr
                 where wr.pol_num = hp.pol_num
                   and wr.eff_date = hp.eff_date
                   and nvl(wr.trans_source_sw, 'A') <> 'M'   -- Exclude Manual Transactions
                  -- and hp.pol_num = 'R1650319A'
                   and wr.run_date = v_ND_RN_DATE)
    and hp.run_date = v_ND_RN_DATE;
  */  

-- Analyze WANG_RECAP_MPS_DETAIL Table  (especailly important for Day 0)
--DBMS_STATS.gather_table_stats('BILLING', 'WANG_RECAP_MBS_DETAIL');


-- Set counts and email status of the WANG_RECAP LOAD

-- 1.) SET MBS WANG_RECAP COUNT
select count(*)
  into v_mbs_count
  from BILLING_CONTENT.nd_wang_recap_history@MBS_PROD
 where batch_no = v_batch_no;
 
-- 2.) SET STAGING MBS_WANG_RECAP COUNT
 select count(*)
   into v_stg_count
   from billing.mbs_wang_recap;
   
-- 3.) SET WANG_RECAP_MBS_DETAIL  
 select count(pol_num)
   into v_wr_dtl_count
   from BILLING.WANG_RECAP_MBS_DETAIL
  where mbs_batch_no = v_batch_no; 
   
-- 4.) SET DISTINCT COUNT WANG_RECAP_MBS_DETAIL  
 select count(distinct pol_num)
   into v_wr_dtl_dst_count
   from BILLING.WANG_RECAP_MBS_DETAIL
  where mbs_batch_no = v_batch_no;
   
-- 5.) SET DISTINCT COUNT OF WANG_RECAP    
 select count(distinct pol_num)
   into v_wr_dst_count
   from apdev.WANG_RECAP
  where process_date = v_ND_PR_DATE 
    and mbs_flg = 'Y';

  
  -- "*** EAMIL LOAD STATUS - MBS to APDEV WANG RECAP ***"
    
  
     EM_BODY:='The following counts are for the MBS WANG RECAP to APDEV WANG_RECAP Load.'||chr(13)||
              'MBS WANG_RECAP, STAGING and WANG_RECAP_MBS_DETAIL counts should match.'||chr(13)||
              'The distinct count of WANG_RECAP_MBS_DETAIL and WANG_RECAP should match.'||chr(13)||chr(13)||
               rpad('MBS WANG_RECAP Counts',30,' ')||rpad('STAGING Counts',30,' ')||rpad('WANG_RECAP_MBS_DETAIL Counts',30,' ')||
                   chr(13)||rpad(v_mbs_count,52,' ')||rpad(v_stg_count,41,' ')||rpad(v_wr_dtl_count,45,' ')||
                   chr(13)||
                rpad('WANG_RECAP_MBS_DETAIL Distinct Counts',50,' ')||rpad('WANG_RECAP MBS RECORDS Count',30,' ')||
                   chr(13)||rpad(v_wr_dtl_dst_count,86,' ')||rpad(v_wr_dst_count,45,' ');
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD STATUS - MBS TO APDEV WANG_RECAP'||'-'||to_char(v_ND_PR_DATE, 'MM/DD/YYYY'),APDEV.MAIL_PKG.ARRAY('shaynes@ndgroup.com','cveerabomma@NDGroup.com','sayachitam@ndgroup.com','Pshellikeri@ndgroup.com','Jude.Lobo@mindtree.com','Ramabhupal.Lingala@mindtree.com','batch_group@majesco.com','nnd_offshore_team@majesco.com','NDBatch.Support@mindtree.com','ProdSupport@NDGroup.com'),EM_BODY);
     -- Decode above will assign the correct process date (s/b the Friday date if Monday (2nd day of the week) else s/b -1)
    -- DBMS_OUTPUT.put_line('Record counts do not agree between file and staging tables');
    

exception
       
        when others then
            v_err_msg:='FAILED:'||sqlcode||':'||sqlerrm(sqlcode)||v_procname||' at'||v_err_loc;

       insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_msg, v_procname);    
        commit;

END;
/
