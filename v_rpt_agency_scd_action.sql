/* Formatted on 5/1/2019 12:40:40 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW RPTVIEWER.V_RPT_AGENCY_SCD_ACTION
(
    AGENCY_NUMBER,
    ACTION
)
AS
    SELECT STG.AG_NUMBER, DECODE (AGY.MATCH_KEY, NULL, 'I', 'U') ACTION
      FROM (SELECT STG.AG_NUMBER,
                      STG.AG_NUMBER
                   || STG.AG_NAME
                   || STG.AG_STREET
                   || STG.AG_CITY
                   || STG.AG_STATE_ABBR
                   || STG.AG_ZIP_CODE
                   || STG.AG_PHONE
                   || STG.AG_STATUS_CODE
                   || TO_CHAR (STG.AG_STATUS_DATE, 'MMDDYYYY')
                   || STG.AG_PERS_UNDERW
                   || STG.AG_COMM_UNDERW
                   || STG.AG_SALES_MGR
                   || STG.AG_MASTER_NUM
                   || STG.SUB_MASTER
                   || NVL (STG.NOTEPAD_BANK_NUMBER, '')
                   || NVL (STG.NOTEPAD_BANK_ACCOUNT, '')
                   || NVL (STG.AG_1825_CLUB, 'N')
                   || NVL (STG.FIFTY_PERCENT_IND, 'N')
                   || NVL (STG.AGENT_CLUSTER_IND, 'N')
                   || STG.AGENCY_CONTACT_NAME
                   || NVL (STG.TERMINATED_FOR_CAUSE, 'N')
                   || STG.TERMINATION_NOTICE_DATE
                   || STG.STATE_NOTIFIED_DATE_ND
                   || STG.STATE_NOTIFIED_DATE_DM
                   || STG.STATE_NOTIFIED_DATE_FM
                   || NVL (STG.BUSINESS_EMAIL, '')
                   || NVL (STG.ASSIGNED_MAIP_AGENT_1, '')
                       MATCH_KEY
              FROM STAGING.WANG_AGENCY_RECORD STG) STG,
           (SELECT AG.AG_NUMBER,
                      AG.AG_NUMBER
                   || AG.AG_NAME
                   || AG.AG_STREET
                   || AG.AG_CITY
                   || AG.AG_STATE_ABBR
                   || AG.AG_ZIP_CODE
                   || AG.AG_PHONE
                   || AG.AG_STATUS_CODE
                   || TO_CHAR (AG.AG_STATUS_NB_DATE, 'MMDDYYYY')
                   || AG.AG_PERS_UNDERW
                   || AG.AG_COMM_UNDERW
                   || AG.AG_SALES_MGR
                   || AG.AG_MASTER_NUM
                   || AG.SUB_MASTER
                   || NVL (AG.NOTEPAD_BANK_NUMBER, '')
                   || NVL (AG.NOTEPAD_BANK_ACCOUNT, '')
                   || NVL (AG.AG_1825_CLUB, 'N')
                   || NVL (AG.FIFTY_PERCENT_IND, 'N')
                   || NVL (AG.AGENT_CLUSTER_IND, 'N')
                   || AG.CONTACT_PERSON
                   || NVL (AG.TERMINATED_FOR_CAUSE, 'N')
                   || AG.TERMINATION_NOTICE_DATE
                   || AG.STATE_NOTIFIED_DATE_ND
                   || AG.STATE_NOTIFIED_DATE_DM
                   || AG.STATE_NOTIFIED_DATE_FM
                   || NVL (AG.BUSINESS_EMAIL, '')
                   || NVL (AG.ASSIGNED_MAIP_AGENT_1, '')
                       MATCH_KEY
              FROM RPT_AGENCY AG
             WHERE AG_VERS_EXP_DT = TO_DATE ('12312100', 'MMDDYYYY')) AGY
     WHERE     AGY.AG_NUMBER(+) = STG.AG_NUMBER
           AND AGY.MATCH_KEY(+) = STG.MATCH_KEY
    UNION
    SELECT STG.AG_NUMBER, DECODE (AG.AG_NUMBER, NULL, 'I', 'U') ACTION
      FROM STAGING.WANG_AGENCY_RECORD STG, RPT_AGENCY AG
     WHERE AG.AG_NUMBER(+) = STG.AG_NUMBER AND AG.AG_NUMBER IS NULL
/
