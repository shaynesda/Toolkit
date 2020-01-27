/* Formatted on 5/1/2019 1:41:50 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NEED_TO_RENEW_CU
(
    POLICY_NUMBER,
    POLICY_EFFECTIVE_DATE
)
AS
    SELECT P.POLICY_NUMBER, P.POLICY_EFFECTIVE_DATE
      FROM NEW_APDEV.POLICY P, APDEV.AGENCY A
     WHERE     TO_CHAR (P.POLICY_EFFECTIVE_DATE, 'YYYYMMDD') > '20090630'
           AND P.policy_number NOT IN
                   (SELECT policy_number
                      FROM new_apdev.renewal
                     WHERE     renewal_status = 'OK'
                           AND renewal_date > SYSDATE - 30)
           AND P.POLICY_EXPIRATION_DATE - SYSDATE < 36
           AND P.POLICY_STATUS_CODE = 'A'
           AND EXISTS
                   (SELECT 1
                      FROM NEW_APDEV.POLICY POL
                     WHERE     POL.POLICY_NUMBER = P.POLICY_NUMBER
                           AND GROUP_LINE_CODE = '46'
                           AND CCI_IND = 'Y')
           AND P.GROUP_LINE_CODE = '46'
           AND P.POLICY_NUMBER NOT IN (SELECT POLICY_NUMBER
                                         FROM APDEV.PAID_POLICY
                                        WHERE NEXT_ACTIVITY_CODE IN ('14',
                                                                     '54',
                                                                     '60',
                                                                     '61',
                                                                     '62',
                                                                     '90',
                                                                     '91'))
           AND P.AGENCY_NUMBER = A.AGENCY_NUMBER
           AND (   A.STATUS_CODE IN ('A', 'T')
                OR (    A.STATUS_CODE = 'C'
                    AND A.LICENSE_DATE > P.POLICY_EXPIRATION_DATE))
           AND P.POLICY_NUMBER NOT IN
                   (SELECT POLICY_NUMBER
                      FROM APDEV.PAID_POLICY
                     WHERE    (    TOTAL_PREMIUM <= 4999
                               AND LAST_BILL_AMOUNT >= 200)
                           OR (    TOTAL_PREMIUM > 4999
                               AND (   LAST_BILL_AMOUNT / TOTAL_PREMIUM > .05
                                    OR LAST_BILL_AMOUNT > 1000)))
/
