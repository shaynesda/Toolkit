CREATE OR REPLACE PROCEDURE BILLING.MBS_REFRESH_POLL IS

/******************************************************************************
   NAME:       BILLING.MBS_REFRESH_POLL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/2/2019  SHAYNES        1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     BILLING.MBS_REFRESH_POLL
      Sysdate:         3/12/2019
      Date and Time:   10/07/2016, 3:00:00 PM, 
      
   DESCRIPTION:
   
  This procedure will continuously check APDEV.LOADMBS CYCLE WANG_RECAP Object step for completion.
  for 59 secs.  This was written to address the issue of locks on the APDEV.POLICY
  table while the Agency Load attempts to disable the constraint.    
    
******************************************************************************/

START_DATE  DATE := SYSDATE;
v_mbs_refresh_ready varchar2(1);

BEGIN

-- Latest Batch Number
/*select max(mbs_batch_no) 
  into v_max_batch_num
  from billing.wang_recap_mbs_detail;  */

BEGIN
  LOOP
    --IF SYSDATE>START_DATE+59/60/60/24 THEN   -- every 30 seconds +30/60/60/24
      
   -- DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_refresh_ready||' TIME'|| CURRENT_TIMESTAMP);
      
    select DECODE(COUNT(*), 1, 'Y', 'N') MBS_DATA_REFRESH
      into v_mbs_refresh_ready
      from APDEV.LOADS_FINISHED
     where LOAD_DATE = TRUNC(SYSDATE)
       and RPTVIEWER = 'OK'
        and TRUNC(RPTVIEWER_LOAD_DATE) = TRUNC(SYSDATE);
            --batch_status = 'SUCCESS'; 
            
     --    DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_refresh_ready||' TIME'|| CURRENT_TIMESTAMP);
    
   dbms_lock.sleep(10);
   
      IF v_mbs_refresh_ready = 'Y' THEN 
          REFRESH_MBSI_PI_DO();
       END IF;

      EXIT WHEN v_mbs_refresh_ready = 'Y'; 

END LOOP;

END;

END MBS_REFRESH_POLL;
/
