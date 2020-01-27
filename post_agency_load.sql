CREATE OR REPLACE PROCEDURE RPTVIEWER."POST_AGENCY_LOAD"    IS
/******************************************************************************
   NAME:       PRE_AGENCY_LOAD

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/19/2006      DJO               1. Created this procedure.
   1.1        12/23/2008     MJM               2. Extended the Where Clause on the
                                                  First Update to Only address the AG_NUMBERS
                                                  being Updated (In the WANG_AGENCY_RECORD) .

   OVERVIEW     Sets the expiration dates for changed agencies

******************************************************************************/

-- main body
BEGIN


UPDATE RPT_AGENCY A SET AG_VERS_EXP_DT =
(SELECT AG_VERS_EFF_DT-1 FROM RPT_AGENCY B WHERE AG_ACTIVE_F='Y'
AND A.AG_NUMBER=B.AG_NUMBER)
WHERE A.AG_ACTIVE_F='N'
AND A.AG_VERS_EXP_DT = TO_DATE('12312100','MMDDYYYY')
AND A.AG_NUMBER IN (SELECT AG_NUMBER FROM STAGING.WANG_AGENCY_RECORD);

COMMIT;


UPDATE RPTVIEWER.RPT_AGENCY
SET AG_LOAD_KEY = AG_NUMBER  ||  AG_NAME  || AG_STREET  || AG_CITY  ||  AG_STATE_ABBR  ||  AG_ZIP_CODE  ||  AG_PHONE ||  AG_STATUS_CODE ||
  TO_CHAR(AG_STATUS_NB_DATE,'MMDDYYYY')  ||  AG_PERS_UNDERW  ||  AG_COMM_UNDERW  || AG_SALES_MGR || AG_MASTER_NUM ||
    TO_CHAR(AG_VERS_EFF_DT,'MMDDYYYY') ||  SUB_MASTER||NVL(NOTEPAD_BANK_NUMBER,'')||NVL(NOTEPAD_BANK_ACCOUNT,'')|| NVL( AG_1825_CLUB ,'N')|| NVL( FIFTY_PERCENT_IND ,'N') || NVL( AGENT_CLUSTER_IND ,'N')||CONTACT_PERSON||
    NVL(TERMINATED_FOR_CAUSE,'N')||TERMINATION_NOTICE_DATE||STATE_NOTIFIED_DATE_ND||STATE_NOTIFIED_DATE_DM||STATE_NOTIFIED_DATE_FM||NVL(BUSINESS_EMAIL,'')||NVL(ASSIGNED_MAIP_AGENT_1,'')
where AG_ACTIVE_F='Y';


COMMIT;


    EXCEPTION
        WHEN OTHERS THEN
            NULL;  -- enter any exception code here
END;
/
