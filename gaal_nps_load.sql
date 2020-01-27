CREATE OR REPLACE PROCEDURE RPTVIEWER.gaal_nps_load IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       gaal_nps_load
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        11/5/2010     chandu     1. Create the file for NPS with GAAL values

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     gaal_nps_load
      Sysdate:         11/5/2010
      Date and Time:   11/5/2010, 11:19:27 AM, and 11/5/2010 11:19:27 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/

v_rc                NUMBER;
v_filename          VARCHAR2(30) := 'gaal.DAT';
v_extract_type     VARCHAR2(20):= 'GAAL_NPS_LOAD';
v_procname        VARCHAR2(30)                      := 'GAAL_NPS_LOAD';
v_err_loc         VARCHAR2(300);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
v_log_msg         load_log.event_message%TYPE;
FILE_ERR          EXCEPTION;
v_start_date_time DATE := SYSDATE; 

BEGIN
   tmpVar := 0;
   
   v_rc := write_extract_file('select * from V_GAAL_NPS','GAAL_OUT',v_filename, v_extract_type);
    rptviewer.rpt_util.update_status(v_procname,'COMPLETED SUCCESSFULLY',v_start_date_time,'S');
   
   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
     rptviewer.rpt_util.update_status(v_procname,'** PROCEDURE FAILED (see load_log)',v_start_date_time,'F');
     v_err_number := SQLCODE;
         v_err_msg := SQLERRM(SQLCODE);
         v_err_msg := 'FAILED: ' || v_err_number || ' * ' || v_err_msg || ' * ';
      rptviewer.rpt_util.write_error(v_procname,v_err_msg);
       -- Consider logging the error and then re-raise
       RAISE;
END gaal_nps_load;
/
