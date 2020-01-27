CREATE OR REPLACE PROCEDURE RPTVIEWER.RPT_AGENCY_LOAD IS
/******************************************************************************
   NAME:       RPT_AGENCY_LOAD
   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/10/2017      SAH           1. Created this procedure.
                                           2. Added logic so can run more than once a day.
   2.0        3/28/2017                    3. Changed format of stg.AG_STATUS_DATE; Source column redefined as DATE in WANG_AGENCY_RECORD_EXT table.  TO_CHAR(stg.AG_STATUS_DATE, 'MMDDYYYY')
   3.0        5/26/2017      PSHETTY       4. Changed mapping of CONTACT_PERSON from stg.CONTACT_PERSON to stg.AGENCY_CONTACT_NAME to display contact info of the Agency.

   OVERVIEW
   Loads RPTVIEWER.RPT_AGENCY data to reporting table.  
  The RPTVIEWER.RPT_AGENCY is a slowly changing dimension all history is retained.Runs daily.
******************************************************************************/
v_build_flag           LOAD_STATUS.BUILD_FL%TYPE;
v_start_date_time        DATE := SYSDATE;
v_vers_eff               DATE;
-- debugging/exception variables
v_procname               VARCHAR2(25) := 'RPT_AGENCY_LOAD';
v_err_loc                VARCHAR2(100);
v_err_number             NUMBER;
v_err_msg                VARCHAR2(1500);
v_log_msg                load_log.event_message%TYPE;

TYPE agy_cur_list IS REF CURSOR;


CURSOR agency_changes IS
   select stg.*, asa.action  -- Action 'I'= new version.
     from STAGING.WANG_AGENCY_RECORD_EXT stg, RPTVIEWER.V_RPT_AGENCY_SCD_ACTION asa  -- this view was created to match determine if records inbound differ from what exists in RPT_AGENCY
    where STG.AG_NUMBER = ASA.AGENCY_NUMBER
      and asa.ACTION = 'I';

BEGIN

  
    rptviewer.rpt_util.update_status(v_procname,'Proc Started...',v_start_date_time);
    v_log_msg := 'Procedure Started...';
    rptviewer.rpt_util.write_log(v_procname,v_log_msg);
    
    v_err_loc := 'RPT_AGENCY_LOAD Loading from RPTVIEWER ';
    
    
     FOR stg in agency_changes  
  
  LOOP
    
     v_err_loc := 'RPT_AGENCY_LOAD retire previous versions ';    
  
    -- Retire latest version in RPT_AGENCY of agency record to receive a new version
    
     update RPTVIEWER.RPT_AGENCY ra
        set ag_vers_exp_dt = TO_DATE(stg.RUN_DATE,'YYYYMMDD'), 
            ag_active_f = 'N'
      where ra.ag_number = stg.ag_number      
        and RA.AG_ACTIVE_F = 'Y';
       
      v_err_loc := 'RPT_AGENCY_LOAD insert latest version '; 
    
    -- Insert latest version from staging 
    
      insert into RPTVIEWER.RPT_AGENCY ra  
         (AG_V_ID, 
          AG_NUMBER, 
          AG_NAME, 
          AG_NAME_ADDR, 
          AG_STREET, 
          AG_CITY, 
          AG_STATE_ABBR, 
          AG_ZIP_CODE, 
          AG_PHONE, 
          AG_SOC_SEC_BUS, 
          AG_SOC_SEC, 
          AG_STATUS_REN_DATE, 
          AG_STATUS_CODE, 
          AG_STATUS_NB_DATE, 
          AG_TRANSFER_NUM, 
          AG_APPT_DATE, 
          AG_PERS_UNDERW, 
          AG_COMM_UNDERW, 
          AG_SALES_MGR, 
          AG_SPEC_AGT, 
          CONTACT_PERSON, 
          AG_MASTER_NUM, 
          AG_COMMISSION_TYPE, 
          NUM_OF_LABELS, 
          ALPHA_INDEX_NAME, 
          AG_MIN_PREMIUM, 
          AG_CHG_DATE, 
          AG_LEGAL_INDICATOR, 
          AG_PUP_AGENT, 
          AG_1825_CLUB, 
          AG_DB_ALL_POLS, 
          AG_ND_AVE_COMMIS, 
          AG_WN_AVE_COMMIS, 
          AG_DAYS_TO_PAY, 
          AG_MMV_CAR_CODE, 
          TRI_BAL, 
          SPEED_NO, 
          MESG_IND, 
          AG_CC_IND, 
          AG_DM_POA_CODE, 
          EMAIL_ADDR, 
          NOTEPAD_BANK_NUMBER, 
          NOTEPAD_BANK_ACCOUNT, 
          PRTSW, 
          TRANS_DESC, 
          PRTDATE, 
          NOTES_1, 
          NOTES_2, 
          NOTES_3, 
          NOTES_4, 
          FAX_NUMBER, 
          PRTCOP, 
          MESSAGE_1, 
          MESSAGE_2, 
          MESSAGE_3, 
          MESSAGE_4, 
          MESSAGE_5, 
          MESSAGE_6, 
          MESSAGE_7, 
          MESSAGE_8, 
          MESSAGE_9, 
          MESSAGE_10, 
          MESSAGE_11, 
          MESSAGE_12, 
          MESSAGE_13, 
          MESSAGE_14, 
          AG_VERS_EFF_DT, 
          AG_VERS_EXP_DT, 
          AG_ACTIVE_F, 
          AG_LOAD_KEY, 
          SUB_MASTER, 
          COASTAL_ALLOTMENT, 
          PRINT_AGENT_COPY, 
          AGENT_CLUSTER_IND, 
          FIFTY_PERCENT_IND, 
          AGENT_CLUSTER_NAME1, 
          AGENT_CLUSTER_NAME2, 
          TERMINATED_FOR_CAUSE, 
          TERMINATION_NOTICE_DATE, 
          STATE_NOTIFIED_DATE_ND, 
          STATE_NOTIFIED_DATE_DM, 
          STATE_NOTIFIED_DATE_FM, 
          BUSINESS_EMAIL, 
          ASSIGNED_MAIP_AGENT_1, 
          AG_LICENSE_NUMBER)
      VALUES 
        (rpt_agency_seq.nextval, 
         stg.AG_NUMBER, 
         stg.AG_NAME, 
         stg.AG_NAME_ADDR, 
         stg.AG_STREET, 
         stg.AG_CITY, 
         stg.AG_STATE_ABBR, 
         stg.AG_ZIP_CODE, 
         stg.AG_PHONE, 
         stg.AG_SOC_SEC_BUS, 
         stg.AG_SOC_SEC, 
         to_date(stg.AG_LIC_DATE, 'YYYYMMDD'), 
         stg.AG_STATUS_CODE, 
         stg.AG_STATUS_DATE,  
         stg.AG_TRANSFER_NUM, 
         to_date(stg.AG_APPT_DATE, 'YYYYMMDD'), 
         stg.AG_PERS_UNDERW, 
         stg.AG_COMM_UNDERW, 
         stg.AG_SALES_MGR, 
         stg.AG_SPEC_AGT, 
         stg.AGENCY_CONTACT_NAME,
         stg.AG_MASTER_NUM, 
         stg.AG_COMMISSION_TYPE, 
         stg.NUM_OF_LABELS, 
         stg.ALPHA_INDEX_NAME, 
         stg.AG_MIN_PREMIUM, 
         to_date(stg.AG_CHG_DATE, 'YYYYMMDD'), 
         stg.AG_LEGAL_INDICATOR, 
         stg.AG_PUP_AGENT, 
         stg.AG_1825_CLUB, 
         stg.AG_DB_ALL_POLS, 
         stg.AG_ND_AVE_COMMIS, 
         stg.AG_WN_AVE_COMMIS, 
         stg.AG_DAYS_TO_PAY, 
         stg.AG_MMV_CAR_CODE, 
         stg.TRI_BAL, 
         stg.SPEED_NO, 
         stg.MESG_IND, 
         stg.AG_CC_IND, 
         stg.AG_DM_POA_CODE, 
         stg.EMAIL_ADDR, 
         stg.NOTEPAD_BANK_NUMBER, 
         stg.NOTEPAD_BANK_ACCOUNT, 
         stg.PRTSW, 
         stg.TRANS_DESC, 
         stg.PRTDATE, 
         stg.NOTES_1, 
         stg.NOTES_2, 
         stg.NOTES_3, 
         stg.NOTES_4, 
         stg.FAX_NUMBER, 
         stg.PRTCOP, 
         stg.MESSAGE_1, 
         stg.MESSAGE_2, 
         stg.MESSAGE_3, 
         stg.MESSAGE_4, 
         stg.MESSAGE_5, 
         stg.MESSAGE_6, 
         stg.MESSAGE_7, 
         stg.MESSAGE_8, 
         stg.MESSAGE_9, 
         stg.MESSAGE_10, 
         stg.MESSAGE_11, 
         stg.MESSAGE_12, 
         stg.MESSAGE_13, 
         stg.MESSAGE_14, 
         --TO_DATE(stg.RUN_DATE+1,'YYYYMMDD'),      --AG_VERS_EFF_DT 
         TO_DATE(stg.RUN_DATE,'YYYYMMDD')+1,      --AG_VERS_EFF_DT
         TO_DATE('12312100','MMDDYYYY'),          --AG_VERS_EXP_DT
         'Y',                                     --AG_ACTIVE_F, 
         stg.AG_NUMBER  ||  stg.AG_NAME  ||  stg.AG_STREET  ||  stg.AG_CITY  ||  stg.AG_STATE_ABBR  ||  stg.AG_ZIP_CODE  ||  stg.AG_PHONE ||  stg.AG_STATUS_CODE  || TO_CHAR(stg.AG_STATUS_DATE, 'MMDDYYYY') ||  stg.AG_PERS_UNDERW  ||  stg.AG_COMM_UNDERW  ||  stg.AG_SALES_MGR ||  stg.AG_MASTER_NUM ||  GET_AGT_EFF_DATE(stg.ag_number) /*stg.AG_VERS_EFF_DT*/  ||stg.SUB_MASTER|| NVL(stg.NOTEPAD_BANK_NUMBER,'') || NVL(stg.NOTEPAD_BANK_ACCOUNT,'')||
         NVL(  stg.AG_1825_CLUB ,'N')|| NVL( stg.FIFTY_PERCENT_IND ,'N') || NVL( stg.AGENT_CLUSTER_IND ,'N')|| stg.AGENCY_CONTACT_NAME||NVL( stg.TERMINATED_FOR_CAUSE ,'N') || TO_DATE(stg.TERMINATION_NOTICE_DATE, 'YYYYMMDD') || TO_DATE(stg.STATE_NOTIFIED_DATE_ND, 'YYYYMMDD') || TO_DATE(stg.STATE_NOTIFIED_DATE_DM, 'YYYYMMDD') || TO_DATE(stg.STATE_NOTIFIED_DATE_FM, 'YYYYMMDD') || NVL( stg.BUSINESS_EMAIL  ,'')||NVL( stg.ASSIGNED_MAIP_AGENT_1 ,''), 
         stg.SUB_MASTER, 
         stg.COASTAL_ALLOTMENT, 
         stg.PRINT_AGENT_COPY, 
         stg.AGENT_CLUSTER_IND, 
         stg.FIFTY_PERCENT_IND, 
         stg.AGENT_CLUSTER_NAME1, 
         stg.AGENT_CLUSTER_NAME2, 
         stg.TERMINATED_FOR_CAUSE, 
         stg.TERMINATION_NOTICE_DATE, 
         stg.STATE_NOTIFIED_DATE_ND, 
         stg.STATE_NOTIFIED_DATE_DM, 
         stg.STATE_NOTIFIED_DATE_FM, 
         stg.BUSINESS_EMAIL, 
         stg.ASSIGNED_MAIP_AGENT_1, 
         stg.LICENSE_NUMBER);
    
    COMMIT;
    
   END LOOP;
   
   rptviewer.rpt_util.update_status(v_procname,'COMPLETED SUCCESSFULLY',v_start_date_time,'S');
   rptviewer.rpt_util.WRITE_LOG(v_procname,v_err_loc);

   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
      v_err_MSG:='FAILED:'||SQLCODE||':'||SQLERRM(SQLCODE)||' ' ||v_err_loc||' '||v_procname;
     DBMS_OUTPUT.PUT_LINE(V_ERR_MSG);
     rptviewer.rpt_util.write_error(v_procname,V_ERR_MSG);
     rptviewer.rpt_util.update_status(v_procname,v_err_MSG,v_start_date_time,'F');
       -- Consider logging the error and then re-raise
       RAISE;
   
  END RPT_AGENCY_LOAD;
/
