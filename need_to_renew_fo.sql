/* Formatted on 5/1/2019 1:41:50 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NEED_TO_RENEW_FO
(
    POLICY_NUMBER,
    POLICY_EFFECTIVE_DATE
)
AS
    SELECT policy.policy_number, policy.policy_effective_date
      FROM new_apdev.policy, apdev.agency, rptviewer.rpt_policy rp
     WHERE     policy.policy_effective_date >
               TO_DATE ('12/31/2011', 'MM/DD/YYYY')
           AND policy.policy_expiration_date - SYSDATE < 40
           AND policy.policy_status_code = 'A'
           AND policy.group_line_code = '26'
           AND policy.state_alpha_code IN ('AR', 'MO')
           AND POLICY.policy_number NOT IN
                   (SELECT policy_number
                      FROM new_apdev.renewal
                     WHERE     renewal_status = 'OK'
                           AND renewal_date > SYSDATE - 30)
           AND policy.policy_number NOT IN
                   (SELECT policy_number
                      FROM apdev.paid_policy
                     WHERE last_bill_amount IS NULL OR last_bill_amount > 200)
           AND policy.policy_number = rp.policy_number
           AND rp.act_code_02 NOT IN ('60',
                                      '61',
                                      '62',
                                      '90',
                                      '91')
           AND policy.policy_number NOT IN
                   (SELECT policy_number
                      FROM apdev.paid_policy
                     WHERE next_activity_code IN ('14', '54'))
           AND policy.agency_number = agency.agency_number
           AND (   agency.status_code IN ('A', 'T')
                OR     agency.status_code = 'C'
                   AND agency.license_date >
                       policy.policy_effective_date + 365)
/
