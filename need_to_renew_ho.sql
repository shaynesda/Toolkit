DROP VIEW NEW_APDEV.NEED_TO_RENEW_HO;
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NEED_TO_RENEW_HO
(
 POLICY_NUMBER,
 POLICY_EFFECTIVE_DATE
)
AS
 SELECT POLICY.policy_number, POLICY.policy_effective_date
   FROM new_apdev.POLICY, apdev.agency, rptviewer.rpt_policy rpt
  WHERE     POLICY.policy_expiration_date - SYSDATE < 40
        AND POLICY.policy_status_code = 'A'
        AND NOT EXISTS
             (SELECT 1
                FROM new_apdev.item_at_risk iar
               WHERE     iar.policy_number = POLICY.policy_number
                     AND IAR.USER_LINE_CODE = '44'
                     AND IAR.POLICY_NUMBER NOT IN
                          (SELECT POLICY_NUMBER FROM new_apdev.nws_umb_renew))
        AND POLICY.group_line_code = '24'
        AND POLICY.state_alpha_code = 'MA'
        AND POLICY.policy_number = rpt.policy_number
        AND rpt.act_code_02 NOT IN ('60',
                                    '61',
                                    '62',
                                    '90',
                                    '91')
        AND POLICY.policy_number NOT IN
             (SELECT pp.policy_number
                FROM apdev.paid_policy pp, new_apdev.policy p2
               WHERE     pp.policy_number = p2.policy_number
                     AND pp.next_activity_code IN ('14', '54')
                     AND p2.pay_option_code != 'P')
        AND POLICY.agency_number = agency.agency_number
        AND (   agency.status_code IN ('A', 'T')
             OR     agency.status_code = 'C'
                AND agency.license_date > POLICY.policy_effective_date + 365)
        AND POLICY.policy_number NOT IN
             (SELECT pp.policy_number
                FROM apdev.paid_policy pp, new_apdev.policy p2
               WHERE        pp.policy_number = p2.policy_number
                        AND p2.pay_option_code != 'P'
                        AND (    total_premium <= 4999
                             AND last_bill_amount >= 200)
                     OR (    total_premium > 4999
                         AND (   last_bill_amount / total_premium > .05
                              OR last_bill_amount > 1000)));
/