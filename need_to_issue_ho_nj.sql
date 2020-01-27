/* Formatted on 5/1/2019 1:41:49 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NEED_TO_ISSUE_HO_NJ
(
    POLICY_NUMBER,
    POLICY_EFFECTIVE_DATE,
    TOTAL_PREMIUM,
    WANG_OLD_POLICY_NUMBER
)
AS
    SELECT POLICY.policy_number,
           POLICY.policy_effective_date,
           total_prem,
           wang_old_policy_number
      FROM POLICY
     WHERE     TO_CHAR (POLICY.policy_effective_date, 'YYYYMMDD') >
               '20080514'
           AND POLICY_NUMBER LIKE 'H08%'
           AND user_entered = 'HONJLOADER'
           AND POLICY_STATUS_CODE IN ('I', 'R')
/
