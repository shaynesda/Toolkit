CREATE OR REPLACE PROCEDURE BILLING.MBS_CYCLE_POLL IS

/******************************************************************************
   NAME:       BILLING.MBS_CYCLE_POLL
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        3/12/2019  SHAYNES        1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     BILLING.MBS_CYCLE_POLL
      Sysdate:         3/12/2019
      Date and Time:   10/07/2016, 3:00:00 PM, 
      
   DESCRIPTION:
   
  This procedure will continuously check MBS CYCLE WANG_RECAP Object step for completion.
  for 59 secs.  This was written to address the issue of locks on the APDEV.POLICY
  table while the Agency Load attempts to disable the constraint.    
    
******************************************************************************/

START_DATE  DATE := SYSDATE;
v_mbs_etl_ready varchar2(1);
v_max_batch_num number;

BEGIN

-- Latest Batch Number
select max(mbs_batch_no) 
  into v_max_batch_num
  from billing.wang_recap_mbs_detail; 

BEGIN
  LOOP
    --IF SYSDATE>START_DATE+59/60/60/24 THEN   -- every 30 seconds +30/60/60/24
      
   -- DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_wr_ready||' TIME'|| CURRENT_TIMESTAMP);
      
    select decode(count(*),0,'N','Y') 
           into v_mbs_etl_ready
           from BILLING_CONTENT.WANG_RECAP_BATCH_HEADER@MBS_PROD    --billing.batch_header_test
          where batch_no > v_max_batch_num
            and success_failure = 'SUCCESS';
            --batch_status = 'SUCCESS'; 
            
    -- DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_etl_ready||' TIME'|| CURRENT_TIMESTAMP);
    
   dbms_lock.sleep(10);
   
        IF v_mbs_etl_ready = 'Y' THEN 
          MBS_ETL_EXECUTE();
       END IF;

      EXIT WHEN v_mbs_etl_ready = 'Y'; 

END LOOP;



    /*BEGIN
         select decode(count(*),0,'N','Y') 
           into v_mbs_wr_ready
           from billing.batch_header_test
          where batch_no > v_max_batch_num
            and batch_status = 'SUCCESS';
       
        IF v_mbs_wr_ready = 'Y' THEN RAISE;    
            DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_wr_ready);
            
      */      
    
  
/*       
        DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_wr_ready);
        
      END IF;
     */         
   
       --Execute Immediate 'alter table APDEV.POLICY disable constraint POLICY_AGENCY_FK'; 
 /*    EXIT;
    EXCEPTION WHEN OTHERS THEN
      IF v_mbs_wr_ready = 'Y' THEN
        DBMS_OUTPUT.PUT_LINE('Execute Load '||v_mbs_wr_ready);
       -- RAISE;
      END IF;
    END;
   END LOOP;  */
END;

END MBS_CYCLE_POLL;
/
