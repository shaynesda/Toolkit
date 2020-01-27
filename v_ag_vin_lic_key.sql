/* Formatted on 5/1/2019 12:40:00 PM (QP5 v5.326) */
CREATE OR REPLACE FORCE VIEW RPTVIEWER.V_AG_VIN_LIC_KEY
(
    AGENCY_NUMBER,
    VIN,
    LIC_NUM,
    AG_VIN_LIC_KEY
)
AS
    SELECT ky.agency_number,
           ky.vin,
           ky.lic_num,
           ms.key_sequence + ROWNUM     ag_vin_lic_key
      FROM (SELECT DISTINCT -- Get distinct agency_number, vin, and license number combinations for PPA lines other than MA
                   p.agency_number,
                   ia.vehicle_identification_number     vin,
                   nm.license_number                    lic_num
              FROM new_apdev.policy             p,
                   new_apdev.item_at_risk       iar,
                   new_apdev.iar_auto           ia,
                   new_apdev.item_name          itn,
                   new_apdev.name               nm,
                   RPTVIEWER.RPT_LOB_HIERARCHY  lh,
                   (SELECT MAX (TRUNC (quoted_date))     mx_date
                      FROM rptviewer.rpt_quote_data) m
             WHERE     p.policy_number = iar.policy_number
                   AND iar.item_at_risk_id = ia.item_at_risk_id
                   AND iar.item_at_risk_id = itn.item_at_risk_id
                   AND itn.item_name_type_code = 'DR'
                   AND itn.name_id = nm.name_id
                   AND p.group_line_code = lh.group_line_code
                   AND LH.LOB_ROLLUP2 = 'PPA'
                   AND p.agency_number NOT LIKE '%TST%'
                   AND p.group_line_code != '06'
                   AND p.date_entered > m.mx_date
                   AND ia.vehicle_identification_number IS NOT NULL
                   AND nm.license_number IS NOT NULL
                   AND p.date_entered > m.mx_date
            UNION
            SELECT DISTINCT -- Get distinct agency_number, vin, and license number combinations for MA PPA
                   p.agency_number,
                   mapp.vehicle_identification_number     vin,
                   mad.current_license_number             lic_num
              FROM apdev.policy                         p,
                   apdev.item_at_risk                   iar,
                   apdev.item_at_risk_ma_auto           iarma,
                   apdev.ma_auto_driver                 mad,
                   apdev.iar_ma_auto_private_passenger  mapp,
                   (SELECT MAX (TRUNC (quoted_date))     mx_date
                      FROM rptviewer.rpt_quote_data) m
             WHERE     p.policy_number = iar.policy_number
                   AND iar.item_at_risk_id = iarma.item_at_risk_id
                   AND iarma.item_at_risk_id = mapp.item_at_risk_id
                   AND mapp.assigned_driver = mad.name_id
                   AND p.date_entered > m.mx_date) ky,
           (SELECT MAX (key_sequence)     key_sequence
              FROM rptviewer.rpt_quote_data) ms
     WHERE NOT EXISTS
               (SELECT 1 -- Only assign sequences to those keys that DO NOT already exist in RPT_QUOTE_DATA
                  FROM rptviewer.AG_VIN_LIC_LKUP vl
                 WHERE     ky.agency_number = vl.agency_number
                       AND ky.vin = vl.vin
                       AND ky.lic_num = vl.lic_num)
/
