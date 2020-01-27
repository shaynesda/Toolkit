CREATE OR REPLACE PROCEDURE RPTVIEWER.POST_POLICY_LOAD    IS
/*****************************************************************************
   NAME:       PRE_AGENCY_LOAD

   REVISIONS:
   VER        DATE        AUTHOR           DESCRIPTION
   ---------  ----------  --------------- -------------------------------------
   1.0       5/11/2009    MJM              1. INITIAL RELEASE
   2.0       12/10/2009   chandu           2. added policy type the existing code.
   3.0       07/23/2010   chandu           3. added the block to sent mails to hr if new employee added to payroll deduction list.
   4.0       09/02/2011   chandu           4. Add the block to update cru_threshold and removed the statements to update polic type
   5.0       4/19/2013    CV               5.  added the cru column to update from apdev.policy_detail table
   6.0       11/22/2013   SH               6.  added additional MAIP columns for MAIP Rule 28/29 loaded from apdev.POLICY_DETAIL
   7.0       9/4/2015     CV               7. Added COMPANION_POLICY_COUNT , POLICY_CHAR_SCORE and POLICY_CHAR_CATEGORY
   8.0       3/15/2016    shaynes          8. added load of book_roll_id
   9.0       06/25/2019   Pavan Shellikeri 9. Ticket# 108922 - MA PPA PAPERLESS DISCOUNT
   PURPOSE      SETS THE CRU AND CRU_DT FROM APDEV.POLICY

******************************************************************************/

V_ERR_MSG   VARCHAR2(100) := '';
V_PROCNAME  VARCHAR2(20) := 'POST_POLICY_LOAD';
v_mssg  varchar2(5000):=null;

v_err_loc  varchar2(1000);

BEGIN

v_err_loc:='Updating Cru';

    -- Load RPT_POLICY CRU and CRU_DT FROM APDEV.POLICY  MJM    5/11/2009

    UPDATE RPTVIEWER.RPT_POLICY A
    SET (A.CRU, A.CRU_DT) =
        (SELECT  AP.CRU,AP.DATE_ENTERED
         FROM  APDEV.POLICY AP
         WHERE AP.POLICY_NUMBER = A.POLICY_NUMBER
         AND   AP.GROUP_LINE_CODE = A.GROUP_LINE_CODE
         and   AP.POLICY_STATUS_CODE <> 'C'
         AND   AP.CRU IS NOT NULL)
    WHERE A.POLICY_NUMBER IN (SELECT AP1.POLICY_NUMBER  FROM APDEV.POLICY AP1 WHERE AP1.GROUP_LINE_CODE = '06'
                    AND AP1.CRU IS NOT NULL AND AP1.POLICY_STATUS_CODE <> 'C')
    AND A.GROUP_LINE_CODE = '06'
    AND A.CRU IS NULL --10/16/18 cv
    AND A.POLICY_NUMBER IN (SELECT I.POL_NUM  FROM STAGING.STG_WF_WANG_POLICY I WHERE I.GROUP_LINE = '06');


    COMMIT;

/* added by chandu 12/10/2009 collecting policy_type information for NJPPA*/
/* modified by keriann 12/22/2009 collecting additional fields for NJPPA*/
/* added by Shawn 12/24/2015 including the SCORE_EFF_DATE for NJPPA*/

v_err_loc:='Updating policy type,group,ins score';

        UPDATE RPTVIEWER.RPT_POLICY P set ( POLICY_GROUP, INSURANCE_SCORE_GROUP, INSURANCE_SCORE, RATE_GROUP, HOMEOWNER, WITH_AGENT_FROM_DATE, SCORE_EFF_DATE)=
                                  (select  POLICY_GROUP, INSURANCE_SCORE_GROUP, INSURANCE_SCORE, RATE_GROUP, HOMEOWNER, WITH_AGENT_FROM_DATE, SCORE_EFF_DATE
                                                from new_apdev.policy
                                                where policy_number=p.policy_number
                                                  and policy_effective_date=p.policy_effective_date)
                               Where run_date=(select max(run_date) from rpt_policy)
                               and group_line_code='01'
                               and state_alpha_code='NJ';

                   commit;

/*  added to post load YEAR_BUSINESS_STARTED DATA from NEW_APDEV.POLICY shaynes - 12/05/2012   */

 v_err_loc:='At Updating Year Business Started';

  UPDATE RPTVIEWER.RPT_POLICY P
     SET YEAR_BUSINESS_STARTED = (select YEAR_BUSINESS_STARTED
                                    from new_apdev.policy
                                   where policy_number=p.policy_number
                                     and policy_effective_date=p.policy_effective_date)
   WHERE run_date=(select max(run_date) from rpt_policy)
     AND group_line_code='42';

  commit;

/*  added to post load ACCOUNT_NUMBER DATA from NEW_APDEV.POLICY_ACCOUNTS  shaynes - 1/08/2013   */

 v_err_loc:='At Updating Account Number';

 UPDATE RPTVIEWER.RPT_POLICY P
    SET P.ACCOUNT_NUMBER = (select PA.ACCOUNT_NUMBER
                              from NEW_APDEV.POLICY_ACCOUNTS PA
                             where PA.policy_number=P.policy_number)
  WHERE run_date=(select max(run_date) from rpt_policy);

  commit;

 v_err_loc:='At Updating cru threshold';

 update RPTVIEWER.RPT_POLICY A
    SET (cru_threshold,maip_vol_quote_policy, maip_vol_quote_obtained, maip_reapplicant,WITH_AGENT_FROM_DATE) = (
    select CRU_THRESHOLD, MAIP_VOL_QUOTE_POLICY, MAIP_VOL_QUOTE_OBTAINED, MAIP_REAPPLICANT,WITH_AGENT_FROM_DATE
                                                                                              from APDEV.POLICY_DETAIL ap
                                                                                             where AP.POLICY_NUMBER=A.POLICY_NUMBER)
    where group_line_code='06'
      and run_date=(select max(run_date) from rpt_policy);

/* added MAIP_VOL_QUOTE_POLICY, MAIP_VOL_QUOTE_OBTAINED, MAIP_REAPPLICANT by shaynes 11/22/2013
/* added by keriann 12/30/2009 collecting additional covered insured information for NJPPA*/

v_err_loc:='Updating addl_covered';

          UPDATE RPTVIEWER.RPT_POLICY P set (ADDL_COVERED)= (SELECT ADDL_COVERED FROM(
                                  (SELECT IAR.POLICY_NUMBER, COUNT(*) ADDL_COVERED
                                   FROM NEW_APDEV.ITEM_AT_RISK IAR, NEW_APDEV.ITEM_NAME I_N
                                   WHERE IAR.ITEM_AT_RISK_ID = I_N.ITEM_AT_RISK_ID AND IAR.WANG_ITEM_SEQ = 0 AND
                                   ITEM_NAME_TYPE_CODE = 'C' GROUP BY IAR.POLICY_NUMBER))i
                                   where i.policy_number=p.policy_number
                                   )
                               Where run_date=(select max(run_date) from rpt_policy)
                               and group_line_code='01'
                               and state_alpha_code='NJ';

                   commit;


/* added by keriann 12/30/2009 collecting additional covered insured information for NJPPA*/

v_err_loc:='Updating FIRST_ISSUED_DATE';

          UPDATE RPTVIEWER.RPT_POLICY P set (FIRST_ISSUED_DATE,ROLLOVER_TYPE,BOOK_TRANSITION_GROUP,PRIOR_CARRIER_PREMIUM)= (SELECT i.FIRST_ISSUED_DATE,i.ROLLOVER_TYPE,i.BOOK_TRANSITION_GROUP,i.PRIOR_CARRIER_PREMIUM
                                                    from APDEV.POLICY_DETAIL i
                                   where i.policy_number=p.policy_number
                                   )
                               Where run_date=(select max(run_date) from rpt_policy);

                   commit;


                   v_err_loc:='Updating MAIP and ND Premium';

                   ---Updating Maip and Nd premium for MA PPA
                   -- adding cru columns to the existing maip columns
                   update rptviewer.rpt_policy p set (maip_premium,nd_premium,CRU_ACTION,CRU_POINTS,CRU_DRIVER_TYPE,CRU_LOW,CRU_high,COMPANION_POLICY_COUNT,POLICY_CHAR_SCORE,POLICY_CHAR_CATEGORY)
                                                    =(select maip_premium,nd_premium,d.CRU_ACTION,d.CRU_POINTS,d.CRU_DRIVER_TYPE,d.CRU_LOW,d.CRU_high,d.COMPANION_POLICY_COUNT,d.POLICY_CHAR_SCORE,d.POLICY_CHAR_CATEGORY
                                                             from APDEV.POLICY_DETAIL d
                                                             where d.policy_number=p.policy_number)
where run_date=(select max(run_date) from rpt_policy)
and group_line_code='06';

commit;


v_err_loc:='Updating Paperless column';
------------------Updating paperless column----------------
UPDATE RPTVIEWER.RPT_POLICY p             --V9.0
   SET paperless =(SELECT paperless 
                    FROM APDEV.POLICY w 
                    WHERE w.policy_number=p.policy_number)
 WHERE run_date=(SELECT MAX(run_date) 
                   FROM RPTVIEWER.RPT_POLICY);

COMMIT;



-------------------Update TERM_PAY_OPTION_CODE from Apdev
update rpt_policy r set TERM_PAY_OPTION_CODE =(select TERM_PAY_OPTION_CODE
                                        from apdev.policy a
                                      where   A.POLICY_NUMBER=r.policy_number)
where
 run_date=(select max(run_date) from rpt_policy)
 and group_line_code='06';

commit;


----- Book Transfer updates from apdev----------------
update rpt_policy r set book_transfer =(select rollover
                                        from apdev.policy a
                                      where   A.POLICY_NUMBER=r.policy_number)
where
nvl(book_transfer,'N')='N'
and  run_date=(select max(run_date) from rpt_policy);

commit;

----- Book Transfer updates from new_apdev----------------
update rptviewer.rpt_policy r set book_transfer =(select BOOK_TRANSFER
                                        from new_apdev.UNDERWRITING_INFO a
                                      where   A.POLICY_NUMBER=r.policy_number)
                                      where nvl(book_transfer,'N')='N'
                                      and run_date=(select max(run_date) from rpt_policy);

                                      commit;

------------------Updating upload_source column----------------
update rptviewer.rpt_policy p set upload_source=(select distinct substr(guid, 1,instr(guid,'_')-1)
from APDEV.XMLSTORE x
where trim(substr(guid, 1,instr(guid,'_')-1)) in('EZLYNX','SILVERPLUME','WINRATER')
and X.POLICY_NUMBER=P.POLICY_NUMBER)
where trans_type='4'
and run_date=(select max(run_date) from rpt_policy);

commit;

-- Book Roll Id Load from NEW_APDEV.POLICY and NEW_APDEV.MONOLINE_POLICY_PRIOR

  UPDATE RPTVIEWER.RPT_POLICY P
     SET P.BOOK_ROLL_ID = (select book_roll_id
                             from (select policy_number, book_roll_id
                                     from new_apdev.policy
                                    where book_roll_id is not null
                                  union
                                   select nd_policy_number, book_roll_id
                                     from new_apdev.monoline_policy_prior
                                    where form = 'DF'
                                      and nd_policy_number is not null) bk
                            where bk.policy_number=p.policy_number)
   WHERE run_date=(select max(run_date) from rpt_policy)
     AND group_line_code in ('22','24')
     AND EXISTS (select 1
                   from (select policy_number, book_roll_id
                           from new_apdev.policy
                          where book_roll_id is not null
                        union
                         select nd_policy_number, book_roll_id
                           from new_apdev.monoline_policy_prior
                          where form = 'DF'
                            and nd_policy_number is not null) bk
                   where bk.policy_number = p.policy_number);

commit;

UPDATE RPTVIEWER.RPT_POLICY P
     SET P.BOOK_ROLL_ID = (select DISTINCT book_roll_id
                                     from APDEV.POLICY_DETAIL  BK
                                    where NVL(BK.BOOK_ROLL_ID,'null')<>'null'
                            AND bk.policy_number=p.policy_number)
   WHERE run_date=(select max(run_date) from RPTVIEWER.rpt_policy)
     AND group_line_code in ('06')
     AND EXISTS (select policy_number, book_roll_id
                           from APDEV.POLICY_DETAIL BK
                          where NVL(BK.BOOK_ROLL_ID,'null')<>'null'
                 AND BK.POLICY_NUMBER = p.policy_number);

COMMIT;

----- BOOK TRANSFER UPDATE FOR DWELLING FIRE POLICIES VG:--11/14/2018
UPDATE RPTVIEWER.RPT_POLICY
SET BOOK_TRANSFER = 'Y'
WHERE GROUP_LINE_CODE = '22'
AND BOOK_ROLL_ID IS NOT NULL
AND POLICY_EFFECTIVE_DATE<TO_DATE('01012019','MMDDYYYY')
AND RUN_DATE=(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

COMMIT;
---- Send email if an employee added to payroll deduction list for the first time.Disabled 7/13/18  Need to call from post_name_load
v_err_loc:='New employees to payroll';

--begin
--for i in(select * from rptviewer.v_prd_new_file)
--loop
--v_mssg:=rpad(i.prd_emp_id,15,' ')||lpad(' ',15,' ')||i.name||chr(13)||v_mssg;
--end loop;
----v_mssg:=rpad('0001',10,' ')||lpad(' ',15,' ')||'test'||chr(13)||v_mssg;
--if length(v_mssg)>0 then
--v_mssg:='Below File Numbers are newly added to payroll deduction list'||chr(13)||rpad('File No.',15,' ')||lpad(' ',15,' ')||'Employee Name'||chr(13)||v_mssg;
--RPT_UTIL.SEND_MAIL('Payroll Deduct:First Time Employee list',MAIL_PKG.ARRAY('cveerabomma@ndgroup.com','hpettersen@ndgroup.com','DOSULLIVAN@NDGROUP.COM','hr@ndgroup.com'),v_mssg);
--end if;
--end;

    exception
        when no_data_found  then
            null;
        when others then
            v_err_msg:='FAILED:'||sqlcode||':'||sqlerrm(sqlcode)||v_procname||' at'||v_err_loc;
            rptviewer.rpt_util.write_error(v_procname,v_err_msg);

END;
/
