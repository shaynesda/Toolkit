CREATE OR REPLACE PROCEDURE STAGING.POST_POLICY_LOAD
IS
    /*
    *****************************************************************************
       NAME:       STAGING.POST_POLICY_LOAD

       REVISIONS:
       VER        DATE        AUTHOR           DESCRIPTION
       ---------  ----------  --------------- ------------------------------------
       1.0       8/24/2018    Vasudha            INITIAL RELEASE
       1.1       06/25/2019   Pavan Shellikeri   Ticket# 108922 - MA PPA PAPERLESS DISCOUNT                                               

       PURPOSE      SETS THE CRU AND CRU_DT FROM APDEV.POLICY

    ******************************************************************************/

    V_ERR_MSG    VARCHAR2 (100) := '';
    V_PROCNAME   VARCHAR2 (20) := 'POST_POLICY_LOAD';
    v_mssg       VARCHAR2 (5000) := NULL;

    v_err_loc    VARCHAR2 (1000);
    V_RUN_DATE  VARCHAR2(8);
BEGIN

SELECT to_char(MAX (RUN_DATE),'MMDDYYYY') into v_run_date FROM STAGING.HISTORY_WANG_policy;

    v_err_loc := 'Updating Cru';

    -- Load RPT_POLICY CRU and CRU_DT FROM APDEV.POLICY   --

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (P.CRU, P.CRU_DT) =
               (SELECT AP.CRU, AP.DATE_ENTERED
                  FROM APDEV.POLICY AP
                 WHERE     AP.POLICY_NUMBER = P.POL_NUM
                       AND AP.GROUP_LINE_CODE = P.GROUP_LINE
                       AND AP.POLICY_STATUS_CODE <> 'C'
                       AND AP.CRU IS NOT NULL)
     WHERE     P.POL_NUM IN
                   (SELECT AP1.POLICY_NUMBER
                      FROM APDEV.POLICY AP1
                     WHERE     AP1.GROUP_LINE_CODE = '06'
                           AND AP1.CRU IS NOT NULL
                           AND AP1.POLICY_STATUS_CODE <> 'C')
           AND P.GROUP_LINE = '06'
           -- AND P.POL_NUM IN (SELECT I.POL_NUM  FROM STAGING.STG_WF_WANG_POLICY I WHERE I.GROUP_LINE = '06')
           AND P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);


    COMMIT;

   v_err_loc:='Updating Paperless column';
    ------------------Updating paperless column----------------
    UPDATE STAGING.HISTORY_WANG_POLICY w            --V1.1
       SET paperless = (SELECT paperless
                 	 FROM APDEV.POLICY p
                 	WHERE p.policy_number = w.pol_num
                   	)
       WHERE w.run_date = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (run_date)  FROM RPTVIEWER.RPT_POLICY);

    COMMIT;

    /* added  collecting policy_type information for NJPPA*/
    /* modified collecting additional fields for NJPPA*/
    /* added  including the SCORE_EFF_DATE for NJPPA*/

    v_err_loc := 'Updating policy type,group,ins score';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (POLICY_GROUP,
            INSURANCE_SCORE_GROUP,
            INSURANCE_SCORE,
            RATE_GROUP,
            HOMEOWNER,
            WITH_AGENT_FROM_DATE,
            SCORE_EFF_DATE) =
               (SELECT POLICY_GROUP,
                       INSURANCE_SCORE_GROUP,
                       INSURANCE_SCORE,
                       RATE_GROUP,
                       HOMEOWNER,
                       WITH_AGENT_FROM_DATE,
                       SCORE_EFF_DATE
                  FROM NEW_APDEV.POLICY
                 WHERE     POLICY_NUMBER = P.POL_NUM
                       AND POLICY_EFFECTIVE_DATE = P.EFF_DATE)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY')--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE = '01'
           AND P.STATE_CD = 'NJ';

    COMMIT;

    /*  added to post load YEAR_BUSINESS_STARTED DATA from NEW_APDEV.POLICY    */

    v_err_loc := 'At Updating Year Business Started';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET YEAR_BUSINESS_STARTED =
               (SELECT YEAR_BUSINESS_STARTED
                  FROM NEW_APDEV.POLICY
                 WHERE     POLICY_NUMBER = P.POL_NUM
                       AND POLICY_EFFECTIVE_DATE = P.EFF_DATE)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY') --(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE = '42';

    COMMIT;

    /*  added to post load ACCOUNT_NUMBER DATA from NEW_APDEV.POLICY_ACCOUNTS  */

    v_err_loc := 'At Updating Account Number';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.ACCOUNT_NUMBER =
               (SELECT PA.ACCOUNT_NUMBER
                  FROM NEW_APDEV.POLICY_ACCOUNTS PA
                 WHERE PA.POLICY_NUMBER = P.POL_NUM)
     WHERE P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    COMMIT;

    v_err_loc := 'At Updating cru threshold';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (CRU_THRESHOLD,
            MAIP_VOL_QUOTE_POLICY,
            MAIP_VOL_QUOTE_OBTAINED,
            MAIP_REAPPLICANT,
            WITH_AGENT_FROM_DATE) =
               (SELECT CRU_THRESHOLD,
                       MAIP_VOL_QUOTE_POLICY,
                       MAIP_VOL_QUOTE_OBTAINED,
                       MAIP_REAPPLICANT,
                       WITH_AGENT_FROM_DATE
                  FROM APDEV.POLICY_DETAIL ap
                 WHERE AP.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.GROUP_LINE = '06'
           AND P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    /* added MAIP_VOL_QUOTE_POLICY, MAIP_VOL_QUOTE_OBTAINED, MAIP_REAPPLICANT
    /* added collecting additional covered insured information for NJPPA*/

    v_err_loc := 'Updating addl_covered';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (ADDL_COVERED) =
               (SELECT ADDL_COVERED
                  FROM ((  SELECT IAR.POLICY_NUMBER, COUNT (*) ADDL_COVERED
                             FROM NEW_APDEV.ITEM_AT_RISK IAR,
                                  NEW_APDEV.ITEM_NAME   I_N
                            WHERE     IAR.ITEM_AT_RISK_ID = I_N.ITEM_AT_RISK_ID
                                  AND IAR.WANG_ITEM_SEQ = 0
                                  AND ITEM_NAME_TYPE_CODE = 'C'
                         GROUP BY IAR.POLICY_NUMBER)) i
                 WHERE i.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY')--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE = '01'
           AND P.STATE_CD = 'NJ';

    COMMIT;

    /*  collecting additional covered insured information for NJPPA*/

    v_err_loc := 'Updating FIRST_ISSUED_DATE';

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (FIRST_ISSUED_DATE,
            ROLLOVER_TYPE,
            BOOK_TRANSITION_GROUP,
            PRIOR_CARRIER_PREMIUM) =
               (SELECT i.FIRST_ISSUED_DATE,
                       i.ROLLOVER_TYPE,
                       i.BOOK_TRANSITION_GROUP,
                       i.PRIOR_CARRIER_PREMIUM
                  FROM APDEV.POLICY_DETAIL i
                 WHERE i.POLICY_NUMBER = P.POL_NUM)
     WHERE P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    COMMIT;


    v_err_loc := 'Updating MAIP and ND Premium';

    ---Updating Maip and Nd premium for MA PPA
    -- adding cru columns to the existing maip columns
    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET (MAIP_PREMIUM,
            ND_PREMIUM,
            CRU_ACTION,
            CRU_POINTS,
            CRU_DRIVER_TYPE,
            CRU_LOW,
            CRU_HIGH,
            COMPANION_POLICY_COUNT,
            POLICY_CHAR_SCORE,
            POLICY_CHAR_CATEGORY) =
               (SELECT d.MAIP_PREMIUM,
                       d.ND_PREMIUM,
                       d.CRU_ACTION,
                       d.CRU_POINTS,
                       d.CRU_DRIVER_TYPE,
                       d.CRU_LOW,
                       d.CRU_HIGH,
                       d.COMPANION_POLICY_COUNT,
                       d.POLICY_CHAR_SCORE,
                       d.POLICY_CHAR_CATEGORY
                  FROM APDEV.POLICY_DETAIL d
                 WHERE d.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY')--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE = '06';

    COMMIT;

    -------------------Update TERM_PAY_OPTION_CODE from Apdev
    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET TERM_PAY_OPTION_CODE =
               (SELECT TERM_PAY_OPTION_CODE
                  FROM APDEV.POLICY a
                 WHERE A.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY') --(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE = '06';

    COMMIT;

    ----- Book Transfer updates from apdev----------------
    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.BOOK_TRANSFER =
               (SELECT a.ROLLOVER
                  FROM APDEV.POLICY a
                 WHERE A.POLICY_NUMBER = P.POL_NUM)
     WHERE     NVL (BOOK_TRANSFER, 'N') = 'N'
           AND P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');-- (SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    COMMIT;

    ----- Book Transfer updates from new_apdev----------------
    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.BOOK_TRANSFER =
               (SELECT a.BOOK_TRANSFER
                  FROM NEW_APDEV.UNDERWRITING_INFO a
                 WHERE A.POLICY_NUMBER = P.POL_NUM)
     WHERE     NVL (P.BOOK_TRANSFER, 'N') = 'N'
           AND P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    COMMIT;

    ------------------Updating upload_source column----------------
    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.UPLOAD_SOURCE =
               (SELECT DISTINCT SUBSTR (GUID, 1, INSTR (GUID, '_') - 1)
                  FROM APDEV.XMLSTORE x
                 WHERE     TRIM (SUBSTR (GUID, 1, INSTR (GUID, '_') - 1)) IN
                               ('EZLYNX', 'SILVERPLUME', 'WINRATER')
                       AND X.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.TRANS_TYPE = '4'
           AND P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY');--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY);--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY);

    COMMIT;

    -- Book Roll Id Load from NEW_APDEV.POLICY and NEW_APDEV.MONOLINE_POLICY_PRIOR

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.BOOK_ROLL_ID =
               (SELECT BOOK_ROLL_ID
                  FROM (SELECT POLICY_NUMBER, BOOK_ROLL_ID
                          FROM NEW_APDEV.POLICY
                         WHERE BOOK_ROLL_ID IS NOT NULL
                        UNION
                        SELECT ND_POLICY_NUMBER, BOOK_ROLL_ID
                          FROM NEW_APDEV.MONOLINE_POLICY_PRIOR
                         WHERE FORM = 'DF' AND ND_POLICY_NUMBER IS NOT NULL)
                       bk
                 WHERE bk.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY')--(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND GROUP_LINE IN ('22', '24')
           AND EXISTS
                   (SELECT 1
                      FROM (SELECT POLICY_NUMBER, BOOK_ROLL_ID
                              FROM NEW_APDEV.POLICY
                             WHERE BOOK_ROLL_ID IS NOT NULL
                            UNION
                            SELECT ND_POLICY_NUMBER, BOOK_ROLL_ID
                              FROM NEW_APDEV.MONOLINE_POLICY_PRIOR
                             WHERE     FORM = 'DF'
                                   AND ND_POLICY_NUMBER IS NOT NULL) bk
                     WHERE bk.POLICY_NUMBER = P.POL_NUM);

    COMMIT;

    UPDATE STAGING.HISTORY_WANG_POLICY P
       SET P.BOOK_ROLL_ID =
               (SELECT DISTINCT BOOK_ROLL_ID
                  FROM APDEV.POLICY_DETAIL BK
                 WHERE     NVL (BK.BOOK_ROLL_ID, 'null') <> 'null'
                       AND bk.POLICY_NUMBER = P.POL_NUM)
     WHERE     P.RUN_DATE = TO_DATE(v_run_date,'MMDDYYYY') --(SELECT MAX (RUN_DATE) FROM STAGING.HISTORY_WANG_POLICY)--(SELECT MAX (RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
           AND P.GROUP_LINE IN ('06')
           AND EXISTS
                   (SELECT POLICY_NUMBER, BOOK_ROLL_ID
                      FROM APDEV.POLICY_DETAIL BK
                     WHERE     NVL (BK.BOOK_ROLL_ID, 'null') <> 'null'
                           AND BK.POLICY_NUMBER = P.POL_NUM);

    COMMIT;

   
---- Send email if an employee added to payroll deduction list for the first time.
--v_err_loc:='New employees to payroll';
--
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

EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
        NULL;
    WHEN OTHERS
    THEN
        v_err_msg :=
               'FAILED:'
            || SQLCODE
            || ':'
            || SQLERRM (SQLCODE)
            || v_procname
            || ' at'
            || v_err_loc;
        rptviewer.rpt_util.write_error (v_procname, v_err_msg);
END;
/
