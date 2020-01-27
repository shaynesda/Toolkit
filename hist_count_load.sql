CREATE OR REPLACE PROCEDURE STAGING.HIST_COUNT_LOAD
IS
     
/***************************************************
***                                              ***
***    SHAYNES   7/15/2016                       ***
***  Procedure that will load the counts of the  ***
*** staging tables STAGING.HISTORY_WANG          *** 
***                                              ***
****************************************************/

POLICY_LIST       VARCHAR2(3500);

polcount NUMBER := 0;
namcount NUMBER := 0;
itmcount NUMBER := 0;
surcount NUMBER := 0;
covcount NUMBER := 0;

polcount_ext NUMBER := 0;
namcount_ext NUMBER := 0;
itmcount_ext NUMBER := 0;
surcount_ext NUMBER := 0;
covcount_ext NUMBER := 0;

pr_date VARCHAR2(10);
ld_date date;

-- Read from the staging_load_log table for the previous days counts. 

   TYPE StagingLoadType  IS RECORD (
       load_date staging_load_log.load_date%type,
             pol staging_load_log.pol%type,
             nam staging_load_log.nam%type, 
             itm staging_load_log.itm%type, 
             cov staging_load_log.cov%type, 
             sur staging_load_log.sur%type
   );          
   
   slt StagingLoadType;

BEGIN

-- set process date for email

select to_char(trunc(sysdate-1),'MM/DD/YYYY')
  into pr_date
  from dual;
  
-- set load date for history table where clause  

select max(run_date)
  into ld_date
  from STAGING.WF_WANG_POLICY_EXT;

-- load the previous days record into the slt record type
    
   select load_date, pol, nam, itm, cov, sur into slt
     from STAGING.STAGING_LOAD_LOG;


-- load the current acu file counts (read thru external tables) into variables

 SELECT COUNT(*) into polcount_ext  FROM wf_wang_pol_rec_ext;   --WF_WANG_POLICY_EXT;
 SELECT COUNT(*) into namcount_ext  FROM wf_wang_name_rec_ext;  --WF_WANG_NAME_EXT;
 SELECT COUNT(*) into itmcount_ext  FROM wf_wang_item_rec_ext;  --WF_WANG_ITEM_EXT;
 SELECT COUNT(*) into surcount_ext  FROM wf_wang_viol_rec_ext;  --WF_WANG_MREC_VIOL_EXT;
 SELECT COUNT(*) into covcount_ext  FROM wf_wang_cov_rec_ext;   --WF_WANG_COVERAGE_RECORD_EXT;

-- load the staging table records loaded into variables

 SELECT COUNT(*) INTO polcount FROM STAGING.HISTORY_WANG_POLICY WHERE RUN_DATE = LD_DATE;
 SELECT COUNT(*) INTO namcount FROM STAGING.HISTORY_WANG_NAME WHERE RUN_DATE = LD_DATE;
 SELECT COUNT(*) INTO itmcount FROM STAGING.HISTORY_WANG_ITEM WHERE RUN_DATE = LD_DATE;
 SELECT COUNT(*) INTO surcount FROM STAGING.HISTORY_WANG_MREC_VIOL WHERE RUN_DATE = LD_DATE;
 SELECT COUNT(*) INTO covcount FROM STAGING.HISTORY_WANG_COVERAGE_RECORD WHERE RUN_DATE = LD_DATE;


 IF   --Check Files are same as the last load
    polcount = slt.pol and
    itmcount = slt.itm and
    covcount = slt.cov and
    namcount = slt.nam and
    surcount = slt.sur     
   
  
  -- "*** LOAD ALERT - ACU TO APDEV STAGING ***"
  --"Record counts same as prior day."
    
   THEN
     POLICY_LIST:='Record counts same as prior day:'||chr(13)||chr(13)||
      rpad('Current Record Counts',30,' ')||rpad('Previous Record Counts',30,' ')||
                   chr(13)||rpad('Policy',13,' ')||rpad(polcount,17,' ')||slt.pol||
                   chr(13)||rpad('Item',13,' ')||rpad(itmcount,17,' ')||slt.itm||
                   chr(13)||rpad('Coverage',13,' ')||rpad(covcount,17,' ')||slt.cov||
                   chr(13)||rpad('Name',13,' ')||rpad(namcount,17,' ')||slt.nam||
                   chr(13)||rpad('Surcharge',13,' ')||rpad(surcount,17,' ')||slt.sur;
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD ALERT - ACU TO HISTORY '||pr_date,APDEV.MAIL_PKG.ARRAY('dbalerts@ndgroup.com','dgilmore@ndgroup.com','woconnell@ndgroup.com'),POLICY_LIST);
     -- Decode above will assign the correct process date (s/b the Friday date if Monday (2nd day of the week) else s/b -1)
     --DBMS_OUTPUT.put_line('Record counts same as prior day');
     
   END IF;
  
  
 
 IF   --Check to see if Files were loaded into the staging tables
 
    polcount != polcount_ext or
    itmcount != itmcount_ext or
    covcount != covcount_ext or
    namcount != namcount_ext or
    surcount != surcount_ext     
   
  
  -- "*** LOAD ALERT - ACU TO APDEV STAGING ***"
  --"Record counts same as prior day."
    
   THEN
     POLICY_LIST:='Record counts do not agree.'||chr(13)||
                  'Check g:\AgentPak\ALL'||chr(13)||
                  'for the records that did not load.'||chr(13)||
                  'THESE RECORDS MUST BE FIXED AND LOADED MANUALLY.'||chr(13)||chr(13)||
                   rpad('File Record Counts',30,' ')||rpad('History Record Counts',30,' ')||
                   chr(13)||rpad('Policy',13,' ')||rpad(polcount_ext,17,' ')||polcount||
                   chr(13)||rpad('Item',13,' ')||rpad(itmcount_ext,17,' ')||itmcount||
                   chr(13)||rpad('Coverage',13,' ')||rpad(covcount_ext,17,' ')||covcount||
                   chr(13)||rpad('Name',13,' ')||rpad(namcount_ext,17,' ')||namcount||
                   chr(13)||rpad('Surcharge',13,' ')||rpad(surcount_ext,17,' ')||surcount;
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD ALERT - ACU TO HISTORY '||pr_date,APDEV.MAIL_PKG.ARRAY('dbalerts@ndgroup.com','dgilmore@ndgroup.com','woconnell@ndgroup.com'),POLICY_LIST);
     -- Decode above will assign the correct process date (s/b the Friday date if Monday (2nd day of the week) else s/b -1)
    -- DBMS_OUTPUT.put_line('Record counts do not agree between file and staging tables');
    ELSE
     POLICY_LIST:='No error conditions occurred:'||chr(13)||chr(13)||
                   rpad('File Record Counts',30,' ')||rpad('History Record Counts',30,' ')||
                   chr(13)||rpad('Policy',13,' ')||rpad(polcount_ext,17,' ')||polcount||
                   chr(13)||rpad('Item',13,' ')||rpad(itmcount_ext,17,' ')||itmcount||
                   chr(13)||rpad('Coverage',13,' ')||rpad(covcount_ext,17,' ')||covcount||
                   chr(13)||rpad('Name',13,' ')||rpad(namcount_ext,17,' ')||namcount||
                   chr(13)||rpad('Surcharge',13,' ')||rpad(surcount_ext,17,' ')||surcount;
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD STATUS - ACU TO HISTORY '||pr_date,APDEV.MAIL_PKG.ARRAY('dbalerts@ndgroup.com','dgilmore@ndgroup.com','woconnell@ndgroup.com'),POLICY_LIST);
     -- Decode above will assign the correct process date (s/b the Friday date if Monday (2nd day of the week) else s/b -1)
     --DBMS_OUTPUT.put_line('No error conditions occurred');
   
   
     Begin
      rptviewer.update_loads_finished('history');
     end;
   
   
   END IF;
     
   
   
   
   --"Record counts do not agree." & vbCrLf & _
   --"Check g:\agentpak\!daily_load\errors"
   
  DELETE FROM STAGING.STAGING_LOAD_LOG WHERE LOAD_DATE < trunc(sysdate);   --- REMOVE PRIOR DAYS COUNTS ONLY IF COUNTS ARE PRIOR DAY 
  COMMIT;
 
 INSERT INTO STAGING.STAGING_LOAD_LOG
 select sysdate, polcount, namcount, itmcount, surcount, covcount
   from dual
  where  0 = (select count(*) from staging.staging_load_log);    
 COMMIT;
 
END HIST_COUNT_LOAD;
/
