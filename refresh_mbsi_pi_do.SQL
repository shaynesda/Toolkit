CREATE OR REPLACE PROCEDURE BILLING.REFRESH_MBSI_PI_DO IS
/******************************************************************************
   NAME:       BILLING.REFRESH_MBSI_PI_DO
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        3/21/2019    SAH            1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     REFRESH_MBSI_PI_DO
      Sysdate:         3/21/2019
      Date and Time:   3/21/2019, 10:12:15 AM, and 3/21/2019 10:12:15 AM
******************************************************************************/

v_err_msg   varchar2(100) := '';
v_procname  varchar2(20)  := 'REFRESH_MBSI_PI_DO';
v_mssg      varchar2(5000):=null;
v_err_loc   varchar2(1000);

EM_BODY    varchar2(5000);

v_prem_trans_cnt number;
v_start_exec_dt  date;
v_end_exec_dt    date;
v_dur_exec_time  varchar2(50);
v_pr_date date;


BEGIN


-- Retain 5 days of logging
delete from load_log where event_date <
(select trunc(max(event_date))-5 from load_log);

v_err_loc:='Load previous version data for MBSI Data Objects';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;



BILLING.LOAD_MBSI_PREV_VERSION();


v_err_loc:='Refresh MBSI Account Object';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;


-- Refresh MBSI Account Object
DBMS_SNAPSHOT.REFRESH(
    LIST                 => 'BILLING.MBSI_GLOBAL_ENTITY'
   ,METHOD               => 'C'
   ,PUSH_DEFERRED_RPC    => TRUE
   ,REFRESH_AFTER_ERRORS => FALSE
   ,PURGE_OPTION         => 1
   ,PARALLELISM          => 4
   ,ATOMIC_REFRESH       => TRUE
   ,NESTED               => FALSE);

v_err_loc:='Refresh MBSI Prem Trans Object';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;

-- Refresh MBSI Prem Trans Object
DBMS_SNAPSHOT.REFRESH(
    LIST                 => 'BILLING.MBSI_PREMIUM_TRANS'
   ,METHOD               => 'C'
   ,PUSH_DEFERRED_RPC    => TRUE
   ,REFRESH_AFTER_ERRORS => FALSE
   ,PURGE_OPTION         => 1
   ,PARALLELISM          => 4
   ,ATOMIC_REFRESH       => TRUE
   ,NESTED               => FALSE);

v_err_loc:='Refresh BILLING.MBSI_LOCAL_ENTITY Object';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;

-- Refresh MBSI Prem Trans Address Object
 DBMS_SNAPSHOT.REFRESH(
    LIST                 => 'BILLING.MBSI_LOCAL_ENTITY'
   ,METHOD               => 'C'
   ,PUSH_DEFERRED_RPC    => TRUE
   ,REFRESH_AFTER_ERRORS => FALSE
   ,PURGE_OPTION         => 1
   ,PARALLELISM          => 4
   ,ATOMIC_REFRESH       => TRUE
   ,NESTED               => FALSE);

v_err_loc:='Refresh MBSI Receivable Commission Object';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;

-- Refresh MBSI Receivable Commission Object
  DBMS_SNAPSHOT.REFRESH(
    LIST                 => 'BILLING.MBSI_REC_COMMIS'
   ,METHOD               => 'C'
   ,PUSH_DEFERRED_RPC    => TRUE
   ,REFRESH_AFTER_ERRORS => FALSE
   ,PURGE_OPTION         => 1
   ,PARALLELISM          => 4
   ,ATOMIC_REFRESH       => TRUE
   ,NESTED               => FALSE);
   
v_err_loc:='Refresh MBSI Receivable Details Object';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

COMMIT;

--- end comment here to re execute Billing.MBSI_REC_DETAILS 

-- Refresh MBSI Receivable Details Object
  DBMS_SNAPSHOT.REFRESH(
    LIST                 => 'BILLING.MBSI_REC_DETAILS'
   ,METHOD               => 'C'
   ,PUSH_DEFERRED_RPC    => TRUE
   ,REFRESH_AFTER_ERRORS => FALSE
   ,PURGE_OPTION         => 1
   ,PARALLELISM          => 4
   ,ATOMIC_REFRESH       => TRUE
   ,NESTED               => FALSE);


v_err_loc:='Refresh MBS Premium Objects Completed';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);


-- Update Loads Finished 
rptviewer.update_loads_finished('MBS_DATA'); 

COMMIT;

-- Insert trigger record for MBS Upload exexution
 INSERT INTO BILLING.EVENT_MESSAGE_STORE
    VALUES (BILLING.EVENT_MESSAGE_SEQ.NEXTVAL, 'U', SYSDATE, null, null);
    
COMMIT;



-- 1.) Set number of premium transactions  
 select count(distinct policy_number)
   into v_prem_trans_cnt
   from BILLING.MBSI_PREMIUM_TRANS;
   
-- 2.) Set start and endtimes of Refresh of Premium Interface Objects
 select min(event_date), max(event_date), to_char(Round(24 * 60 * (max(event_date)-min(event_date)),2))|| ' minutes'  Duration
   into v_start_exec_dt, v_end_exec_dt, v_dur_exec_time
   from billing.load_log
  where event_routine = 'REFRESH_MBSI_PI_DO'
    and trunc(event_date) = trunc(sysdate);

-- 3.) Set Process Date
select max(process_date)
  into v_pr_date
  from apdev.wang_recap;
   

  -- "*** EAMIL LOAD STATUS - MBS DATA REFRESH ***"
    
  
     EM_BODY:='MBS Premium Interface Objects have been refreshed for process date ' ||to_char(v_pr_date, 'MM/DD/YYYY') ||chr(13)||chr(13)||
              'The refresh of the Premium Interface Objects took approximately '|| v_dur_exec_time ||'.'||chr(13)||
              'Started: '||to_char(v_start_exec_dt, 'MM/DD/YYYY HH:MI:SS')  ||chr(13)||
              'Ended:  '||to_char(v_end_exec_dt, 'MM/DD/YYYY HH:MI:SS') ||chr(13)||chr(13)||chr(13)||
               v_prem_trans_cnt ||' Premium Transations';  
     APDEV.APDEV_UTIL.SEND_MAIL('MBS Data Refresh '||to_char(v_pr_date, 'MM/DD/YYYY'),APDEV.MAIL_PKG.ARRAY('shaynes@ndgroup.com','cveerabomma@NDGroup.com','sayachitam@ndgroup.com','pdibenedetto@NDGroup.com','Pshellikeri@ndgroup.com','Jlobo@ndgroup.com','Rreddy@ndgroup.com'),EM_BODY);


exception
        when no_data_found  then
            null;
        when others then
            v_err_msg:='FAILED:'||sqlcode||':'||sqlerrm(sqlcode)||v_procname||' at'||v_err_loc;
            rptviewer.rpt_util.write_error(v_procname,v_err_msg);

END REFRESH_MBSI_PI_DO;
/