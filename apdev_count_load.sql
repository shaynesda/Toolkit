CREATE OR REPLACE PROCEDURE STAGING.APDEV_COUNT_LOAD
IS
     
/***************************************************
***                                              ***
***    SHAYNES   6/1/2016                        ***
***  Procedure that will load the counts of the  ***
*** staging tables NAME and POLICY               *** 
***                                              ***
****************************************************/

POLICY_LIST       VARCHAR2(3500);

polcount          NUMBER := 0;
namcount_diff     NUMBER := 0;
maa_driver_diff   NUMBER := 0;
missing_items_cnt NUMBER := 0;
pol_drv_cnt       NUMBER := 0;
missing_name_cnt  NUMBER := 0;

pr_date VARCHAR2(10);

BEGIN

select to_char(trunc(sysdate-1),'MM/DD/YYYY')
  into pr_date
  from dual;

-- Policy Records
select ap.cnt-sp.cnt  --Policy Mismatch check should always be zero.Check to see that all policies in STAGING.WF_WANG_POLICY were loaded into APDEV.POLICY (where the loaded took place within the last hour)
  into polcount
  from (select count(*) cnt from apdev.policy where user_entered = 'POLICY_LOAD_PKG' and date_entered >  (sysdate - .041667)) ap,  -- policies loaded within the last hour.
       (select count(*) cnt from staging.wf_wang_policy) sp;
     
-- Name Records
select (np.cnt+ni.cnt)-nm.cnt  -- Name count diff should always be zero this difference check is between a sum of name_person, name_institution and name.
  into namcount_diff  
  from (select count(*) cnt from apdev.name_person) np,  
       (select count(*) cnt from apdev.name_institution) ni,
       (select count(*) cnt from apdev.name) nm;

--MA Auto Driver
select count(*)   -- MA auto driver difference check should always zero. Checks to see what ma_auto_driver names are not in ma_auto_policy_driver.
  into maa_driver_diff
  from apdev.ma_auto_driver
 where name_id not in (select driver_name_id from apdev.ma_auto_policy_driver);

--Policy Driver
select count(*)  --MA auto policy driver check should always be zero.  Check to see that every MA Auto policy in staging has a MA_AUTO_POLICY_DRIVER record. 
  into pol_drv_cnt
  from staging.wf_wang_name
 where pol_num not in
      (select policy_number 
         from apdev.ma_auto_policy_driver)
   and pol_num in 
      (select pol_num 
         from staging.wf_wang_policy
        where group_line = '06');

--Missing Items
select count(*)   -- MA auto missing items check should always be zero.  Checks to see that every active MA AUTO policy has an item. 
  into missing_items_cnt
  from apdev.policy P
 where P.POLICY_STATUS_CODE = 'A'
   and not exists (select * from apdev.item_at_risk I where P.POLICY_NUMBER = I.POLICY_NUMBER)
   and P.GROUP_LINE_CODE = '06';

-- Missing Names
select count(*)   -- Missing name check should always be zero. Check to see that every Active MA Auto policy has a MA_AUTO_POICY_DRIVER record  
  into missing_name_cnt
  from apdev.policy
 where policy_number not in 
      (select policy_number 
         from apdev.ma_auto_policy_driver)
   and policy_status_code = 'A'
   and group_line_code = '06';

IF (polcount+namcount_diff+maa_driver_diff+pol_drv_cnt+missing_items_cnt+missing_name_cnt) <> 0
 
 THEN
 
     POLICY_LIST:='STAGING to APDEV Record count checks:'||chr(13)||chr(13)||
      rpad('Difference Count Check',30,' ')||rpad('Results (S/B Zero)',30,' ')||chr(13)||
                   chr(13)||rpad('Policy Records',30,' ')||polcount||
                   chr(13)||rpad('Name Records',30,' ')||namcount_diff||
                   chr(13)||rpad('MA Auto Driver',30,' ')||maa_driver_diff||
                   chr(13)||rpad('Policy Driver',30,' ')||pol_drv_cnt||
                   chr(13)||rpad('Missing Items',30,' ')||missing_items_cnt||
                   chr(13)||rpad('Missing Names',30,' ')||missing_name_cnt||
                   chr(13)||chr(13)||
           'Errors in the load from STAGING to APDEV'||chr(13)||
           'Please use STAGING.APDEV_COUNT_LOAD procedure to troubleshoot issues';
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD ALERT - STAGING TO APDEV '||pr_date,APDEV.MAIL_PKG.ARRAY('dbalerts@NDGroup.com','dgilmore@ndgroup.com','woconnell@ndgroup.com'),POLICY_LIST);
     --DBMS_OUTPUT.put_line('Difference counts staging to apdev');
  
 ELSE
 
    POLICY_LIST:='STAGING to APDEV Record count checks:'||chr(13)||chr(13)||
      rpad('Difference Count Check',30,' ')||rpad('Results (S/B Zero)',30,' ')||chr(13)||
                   chr(13)||rpad('Policy Records',30,' ')||polcount||
                   chr(13)||rpad('Name Records',30,' ')||namcount_diff||
                   chr(13)||rpad('MA Auto Driver',30,' ')||maa_driver_diff||
                   chr(13)||rpad('Policy Driver',30,' ')||pol_drv_cnt||
                   chr(13)||rpad('Missing Items',30,' ')||missing_items_cnt||
                   chr(13)||rpad('Missing Names',30,' ')||missing_name_cnt||
                   chr(13)||chr(13)||
           'No Errors in the load from STAGING to APDEV';
     APDEV.APDEV_UTIL.SEND_MAIL('LOAD STATUS - STAGING TO APDEV '||pr_date,APDEV.MAIL_PKG.ARRAY('dbalerts@NDGroup.com','dgilmore@ndgroup.com','woconnell@ndgroup.com'),POLICY_LIST);
    -- DBMS_OUTPUT.put_line('Difference counts staging to apdev');
 
END IF;  
 
     Begin
      rptviewer.update_loads_finished('APDEV');
     end;
 
END APDEV_COUNT_LOAD;
/
