CREATE MATERIALIZED VIEW BILLING.MBSI_PREMIUM_TRANS 
    (POLICY_NUMBER,PROCESS_DATE,POLICY_EFFECTIVE_DATE,AUDIT_FLAG,AUDIT_SUB_TYPE,
     BILL_TYPE_CODE,AGENCY_NUMBER,CANCEL_REASON,CANCEL_TYPE,COMMISSION_PAID_BASIS,
     COUNTRY_CODE,CRT_CODE,NON_CANCELLABLE_FLAG,ISSUE_COMPANY,OPERATING_REGION,
     PAYMENT_OPTION,PAYMENT_PLAN,SOURCE_SYSTEM_CODE,SOURCE_SYSTEM_PROCESS_DATE,SOURCE_ACCOUNTING_MONTH,
     TRANSACTION_EFF_DATE,TRANSACTION_EXP_DATE,TRANS_TYPE_CODE,GROUP_LINE_CODE,STATE_ALPHA_CODE,
     UNDERWRITING_COMPANY,NON_RENEWAL_FLAG,NEDR_FLAG,POLICY_INCEPTION_DATE,MAIP_FLAG,
     SDIP_RATING_PLAN,CHANGE_REASON_CODE)
NOCACHE
NOLOGGING
NOCOMPRESS
NOPARALLEL
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
WITH PRIMARY KEY
AS 
SELECT DISTINCT
       BAI.POLICY_NUMBER,
       BA.PROCESS_DATE,
       BA.POLICY_EFFECTIVE_DATE,
       -- BILLING.IS_AUDIT_TRANS (BAI.POLICY_NUMBER, BA.POLICY_EFFECTIVE_DATE),
       NVL (AUD.AUDIT_FLAG, 'N')
        AUDIT_FLAG, -- AUDIT_FLAG, -- Function which returns if a policy transaction is an audit
       (CASE
         WHEN     P.GROUP_LINE_CODE = '42'
              AND P.POLICY_STATUS_CODE <> 'C'
              AND WR.TRANS_SOURCE_SW = 'M'
              AND WR.CHANGE_DATE < P.POLICY_EFFECTIVE_DATE
              AND WR.TRANS_TYPE = '2' --- Added 3/5/2019  Jira Ticket # NDBL-896
         THEN
          'F'         -- Changed to "F" Final Audit from "I" Interim 2/26/2018
         WHEN     P.GROUP_LINE_CODE = '42'
              AND P.POLICY_STATUS_CODE = 'C'
              AND WR.TRANS_SOURCE_SW = 'M'
              AND WR.TRANS_TYPE = '2' --- Added 3/5/2019  Jira Ticket # NDBL-896
         THEN
          'F'         -- Changed to "F" Final Audit from "I" Interim 2/26/2018
         ELSE
          NULL
        END)
        AUDIT_SUB_TYPE,
       WR.BILL_TYPE,
       BAI.AGENCY_NUMBER,
       NVL (WR.CANCEL_REAS, '13')
        CANCEL_REAS,      -- Included NVL condition to assign default 1/9/2018
       BA.CANCEL_TYPE,
       'WRITTEN'
        COMMISSION_PAID_BASIS,
       CASE WHEN BAI.COUNTRY_CODE = 'USA' THEN 'US' ELSE BAI.COUNTRY_CODE END
        COUNTRY_CODE,
       '0001'
        CRT_CODE,
       'N'
        NON_CANCELLABLE_FLAG,
       CASE WHEN WR.COMPANY = '99' THEN '01' ELSE WR.COMPANY END
        COMPANY,
       '01'
        OPERATING_REGIION,
       DECODE (BA.PTC_IND,
               'Y', NVL (PT.BILL_TYPE, WR.BILL_TYPE),
               WR.BILL_TYPE)
        PAYMENT_OPTION,        -- Assign prior term pay option if a PTC CHANGE
       DECODE (BA.PTC_IND,
               'Y', NVL (PT.PAY_OPTION, BAI.PAY_OPTION_CODE),
               BAI.PAY_OPTION_CODE)
        PAYMENT_PLAN,
       CASE
        WHEN WR.GROUP_LINE = '95'
        THEN
         'MAJ'
        WHEN WR.GROUP_LINE = '22'
        THEN
         'NPS'
        WHEN WR.GROUP_LINE IN ('24', '46', '75') AND WR.STATE_CD = 'NH'
        THEN
         'NPS'
        ELSE
         'APAK'
       END
        SOURCE_SYSTEM_CODE,
       WR.RUN_DATE
        SOURCE_SYSTEM_PROCESS_DATE,
       /* (CASE
            WHEN WR.CHANGE_DATE <
                    ADD_MONTHS ( (LAST_DAY (WR.RUN_DATE) + 1), -1)
            THEN
               TO_CHAR (WR.RUN_DATE, 'MM')
            ELSE
               TO_CHAR (WR.CHANGE_DATE, 'MM')
         END)*/
       TO_CHAR (GREATEST (WR.CHANGE_DATE, WR.PROCESS_DATE), 'YYYYMM') -- Updated 10/3/2019 to redefine source accounting year month to the latest of 2  date (change or process dates)
       SOURCE_ACCOUNTING_MONTH,
       WR.CHANGE_DATE
        TRANSACTION_EFF_DATE,
       WR.EXP_DATE
        TRANSACTION_EXP_DATE,
       (CASE
         WHEN     P.GROUP_LINE_CODE = '42'
              AND P.POLICY_STATUS_CODE <> 'C'
              AND WR.TRANS_SOURCE_SW = 'M'
              AND WR.CHANGE_DATE < P.POLICY_EFFECTIVE_DATE
              AND WR.TRANS_TYPE = '2' --- Added 3/5/2019  Jira Ticket # NDBL-896
         THEN
          'A'
         WHEN     P.GROUP_LINE_CODE = '42'
              AND P.POLICY_STATUS_CODE = 'C'
              AND WR.TRANS_SOURCE_SW = 'M'
              AND WR.TRANS_TYPE = '2' --- Added 3/5/2019  Jira Ticket # NDBL-896
         THEN
          'A'
         ELSE
          WR.TRANS_TYPE
        END)
        TRANS_TYPE,
       WR.GROUP_LINE,
       WR.STATE_CD,
       CASE WHEN WR.COMPANY = '99' THEN '01' ELSE WR.COMPANY END
        UNDERWRITING_COMPANY,
       DECODE (WR.ACT_CODE, '60', 'Y', 'N')
        NON_RENEWAL_FLAG,
       BA.NEDR_FLG,
       BAI.ORIGINAL_EFFECTIVE_DATE
        POLICY_INCEPTION_DATE,
       DECODE (SUBSTR (BAI.AGENCY_NUMBER, 1, 2), '21', 'Y', 'N')
        MAIP_FLAG,
       P.MMV_BILL_STEP
        SDIP_RATING_PLAN,
       DECODE (BA.TRANS_TYPE_CODE, '6', BA.CHANGE_REASON_CODE, NULL)
        CHANGE_REASON_CODE
  FROM BILLING.MBSI_GLOBAL_ENTITY           BAI,
       BILLING.V_DAILY_BILLING_ACTIVITY     BA,
       APDEV.WANG_RECAP                     WR,
       BILLING.R_MBS_LOV_PAYMENT_PLAN       PP,
       RPTVIEWER.RPT_POLICY                 P,
       (SELECT ptp.policy_number,
               ptp.policy_effective_date,
               ptp.change_date,
               ptp.bill_type,
               ptp.bill_to,
               ptp.pay_option,
               ptp.eft_pay_day
          FROM RPTVIEWER.PTC_POLICY ptp, BILLING.V_DAILY_BILLING_ACTIVITY ba
         WHERE     ba.policy_number = ptp.policy_number
               AND ba.change_effective_date = ptp.change_date
               AND ba.run_date = ptp.run_date
               AND ba.change_effective_date < ba.POLICY_EFFECTIVE_DATE
               AND ba.PTC_IND = 'Y') PT,                    -- Prior Term Data
       BILLING.VW_MBSI_AUDIT_PREMIUM_TRANS  AUD --Added in order to support Audit Flag assignment
 WHERE     BAI.POLICY_NUMBER = WR.POL_NUM
       AND BA.POLICY_NUMBER = WR.POL_NUM
       AND P.POLICY_NUMBER = WR.POL_NUM
       AND BA.POLICY_EFFECTIVE_DATE = WR.EFF_DATE
       AND BA.PROCESS_DATE = WR.RUN_DATE -- Changed from process_date to run_date to support change in DAILY_BILLING_ACTIVITY
       AND BAI.PAY_OPTION_CODE = PP.MJ_CODE
       -- AND BA.ADDL_KEY = 0
       AND BA.ADDL_KEY = WR.ADDL_KEY
       AND PT.POLICY_NUMBER(+) = BA.POLICY_NUMBER
       AND AUD.POLICY_NUMBER(+) = BA.POLICY_NUMBER --Added in order to support Audit Flag assignment
       AND AUD.POLICY_EFFECTIVE_DATE(+) = BA.POLICY_EFFECTIVE_DATE --Added in order to support Audit Flag assignment
;


COMMENT ON MATERIALIZED VIEW BILLING.MBSI_PREMIUM_TRANS IS 'snapshot table for snapshot BILLING.MBSI_PREMIUM_TRANS';
