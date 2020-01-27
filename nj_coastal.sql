/* Formatted on 5/1/2019 1:41:51 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW NEW_APDEV.NJ_COASTAL
(
    POLICY_COUNT,
    AGENCY_NUMBER,
    AGENCY_NAME,
    COASTAL_ALLOTMENT
)
AS
      SELECT COUNT (CST.POLICY_NUMBER)          POLICY_COUNT,
             agt.agency_number,
             agt.agency_name,
             NVL (agt.COASTAL_ALLOTMENT, 0)     COASTAL_ALLOTMENT
        FROM (SELECT agy.agency_number,
                     agency_name,
                     agy.coastal_allotment,
                     na.state_alpha_code
                FROM apdev.agency agy, apdev.name nm, apdev.name_address na
               WHERE     agy.name_id = nm.name_id
                     AND na.name_id = nm.name_id
                     AND na.STATE_ALPHA_CODE = 'NJ') agt,
             (SELECT pol.policy_number,
                     agy.agency_number,
                     agy.agency_name,
                     agy.COASTAL_ALLOTMENT
                FROM policy               pol,
                     item_at_risk         iar,
                     iar_personal_dwelling ipd,   /*item_name itn, name nm, */
                     apdev.agency         agy
               WHERE     pol.policy_number = iar.policy_number
                     AND pol.policy_effective_date >=
                         TO_DATE ('6/1/2009', 'MM/DD/YYYY')
                     -- and iar.item_at_risk_id = itn.item_at_risk_id
                     AND iar.item_at_risk_id = ipd.item_at_risk_id
                     -- and itn.name_id = nm.name_id
                     --and itn.item_name_type_code = '24'
                     AND pol.policy_status_code IN ('F',
                                                    'D',
                                                    'E',
                                                    'A',
                                                    'S')
                     AND pol.STATE_ALPHA_CODE = 'NJ'
                     AND agy.AGENCY_NUMBER = pol.AGENCY_NUMBER
                     AND ipd.WIND_ZONE BETWEEN '1' AND '4'
                     --SA - should not hardcode territories with single zeros and double zeros. This is failing when territory is without zeros
                     --AND ipd.TERRITORY_CODE IN ('01','05','13','15','22','001','005','013','015','022')) CST
                     AND TO_NUMBER (ipd.TERRITORY_CODE) IN (1,
                                                            5,
                                                            13,
                                                            15,
                                                            22)) CST
       WHERE cst.agency_number(+) = agt.agency_number
    GROUP BY agt.agency_number, agt.agency_name, agt.COASTAL_ALLOTMENT
/
