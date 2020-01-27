DROP VIEW NEW_APDEV.NEED_TO_RENEW_CA_MA;

/* Formatted on 7/24/2019 11:51:50 AM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NEED_TO_RENEW_CA_MA
(
    POLICY_NUMBER,
    POLICY_EFFECTIVE_DATE
)
AS
    SELECT POLICY.policy_number, POLICY.policy_effective_date
      FROM POLICY, apdev.agency, rptviewer.rpt_policy rp
     WHERE     POLICY.policy_effective_date >
               TO_DATE ('03/14/2009', 'MM/DD/YYYY')
           AND POLICY.policy_number NOT IN
                   (SELECT policy_number
                      FROM new_apdev.renewal
                     WHERE     renewal_status = 'OK'
                           AND renewal_date > SYSDATE - 30)
           AND POLICY.policy_expiration_date - SYSDATE < 40
           AND POLICY.policy_status_code = 'A'
           AND POLICY.group_line_code = '07'
           AND POLICY.state_alpha_code = 'MA'
           -- below takes care of owing >= 200
           AND POLICY.policy_number NOT IN
                   (SELECT policy_number
                      FROM apdev.paid_policy
                     WHERE last_bill_amount IS NULL OR last_bill_amount > 200)
           -- Below takes care of pend codes
           AND POLICY.policy_number = rp.policy_number
           AND rp.act_code_02 NOT IN ('60',
                                      '61',
                                      '62',
                                      '90',
                                      '91')
           -- Below takes care of next activities
           AND POLICY.policy_number NOT IN
                   (SELECT policy_number
                      FROM apdev.paid_policy
                     WHERE next_activity_code IN ('14', '54'))
           AND POLICY.agency_number = agency.agency_number
           AND (   agency.status_code IN ('A', 'T')
                OR     agency.status_code = 'C'
                   AND agency.license_date >
                       POLICY.policy_effective_date + 365);


GRANT DELETE, INSERT, REFERENCES, SELECT, UPDATE, ON COMMIT REFRESH, QUERY REWRITE, READ, DEBUG, FLASHBACK, MERGE VIEW ON NEW_APDEV.NEED_TO_RENEW_CA_MA TO PSHELLIKERI;
