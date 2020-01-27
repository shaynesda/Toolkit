CREATE OR REPLACE PROCEDURE APDEV.MRB_NTR_RESPONSE_OUT
AS

/******************************************************************************
   NAME:       MRB_NTR_RESPONSE_OUT

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
      1.0        09/18/2013    chandu            1. Created the procedure to create file for MRB with NTR request data. to inquire SDIP.

   OVERVIEW
             Builds the Broadspire update file.

******************************************************************************/

v_run_date       DATE;
v_rc                NUMBER:=2;
--v_filename          VARCHAR2(30) := 'norfolk_dedham_'||TO_CHAR(SYSDATE,'MMDDYYYY');
v_filename          VARCHAR2(30) := 'SIN'||SUBSTR(TO_CHAR(SYSDATE,'YYMMDD'),2)||'.txt';
v_extract_type     VARCHAR2(20):= 'MRB_NTR_OUT';--RPTVIEWER.EXTRACT_HISTORY.EXTRACT_TYPE%TYPE := 'MILLENNIUM_POLICY';
-- debugging/exception variables
v_procname        VARCHAR2(30)                      := 'MRB_NTR_RESPONSE_OUT';
v_err_loc         VARCHAR2(300);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
v_log_msg         load_log.event_message%TYPE;
v_start_date_time DATE := SYSDATE;
cnt  number;
REQUEST_CNT NUMBER;
v_recent_file_flag  number;
--exception
Not_recent_file        EXCEPTION;
BEGIN

select sysdate-(SELECT   MAX (MRB_FILE_POSTED_DATE)
                                  FROM   APDEV.NTR_REQUEST) into v_recent_file_flag from dual;

if v_recent_file_flag>6 then
RAISE Not_recent_file;
end if;
                                  

--dbms_output.put_line('BROADSPIRE_DAILY_BUILD Start: ' || P_RUN_DATE);
rptviewer.rpt_util.update_status(v_procname,'Proc Started...',v_start_date_time);
v_err_loc := 'Proc started';

select count(*) into cnt from APDEV.VW_MRB_REQUEST_NTR;

select count(*) into REQUEST_CNT from APDEV.NTR_REQUEST
                    WHERE   MRB_FILE_POSTED_DATE =
                               (SELECT   MAX (MRB_FILE_POSTED_DATE)
                                  FROM   APDEV.NTR_REQUEST);

IF CNT=REQUEST_CNT THEN

if cnt>0 then
v_err_loc := '(1) Writing to file: ' || v_filename;
v_rc := rptviewer.write_extract_file('SELECT INQUIRY_FILE FROM APDEV.VW_MRB_REQUEST_NTR','MRB_NTR_OUT',v_filename, v_extract_type);

end if;

 RPTVIEWER.RPT_UTIL.WRITE_LOG(v_procname, 'No. of policies:' || to_char(v_rc));
 RPTVIEWER.RPT_UTIL.SEND_MAIL('NTR Inquiry File:'||TO_CHAR(SYSDATE,'MM/DD/YYYY'),rptviewer.MAIL_PKG.ARRAY('cveerabomma@ndgroup.com','ftp-confirm@ndgroup.com','dosullivan@ndgroup.com','hpettersen@ndgroup.com','sayachitam@ndgroup.com','woconnell@ndgroup.com'),'Generated NTR INQUIRY file with '||cnt||' records.');
 
 else

 rptviewer.rpt_util.write_error(v_procname,'MRB Inquiry file has issues. First request files has '||REQUEST_CNT||' records. inquiry file has only '||cnt||' records.');

 END IF;

rptviewer.rpt_util.update_status(v_procname,'COMPLETED SUCCESSFULLY',v_start_date_time,'S');

------------------------------------------------------------------------------------------------------------
   EXCEPTION
   when Not_recent_file then
      rptviewer.rpt_util.update_status(v_procname,'** PROCEDURE FAILED ',v_start_date_time,'F');
      rptviewer.rpt_util.write_error(v_procname,'APDEV.NTR_REQUEST has the data older than a week. No recent data found.');
   
      WHEN OTHERS THEN
      v_err_number := SQLCODE;
         v_err_msg := SQLERRM(SQLCODE);
         v_err_msg :=
            'FAILED: ' || v_err_number || ' * ' || v_err_loc || ' * '
            || v_err_msg;
          DBMS_OUTPUT.put_line(v_err_msg);
      rptviewer.rpt_util.update_status(v_procname,'** PROCEDURE FAILED ',v_start_date_time,'F');
      rptviewer.rpt_util.write_error(v_procname,v_err_msg);

END MRB_NTR_RESPONSE_OUT;
/
