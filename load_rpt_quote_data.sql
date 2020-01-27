CREATE OR REPLACE PROCEDURE RPTVIEWER.LOAD_RPT_QUOTE_DATA IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       LOAD_RPT_QUOTE_DATA
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/11/2012    SHAYNES      1. Created this procedure.

   NOTES:     4/11/2012                 Loads table RPT_QUOTE_DATA daily.
   
******************************************************************************/
insert_count      NUMBER;
v_procname        VARCHAR2(30)                      := 'LOAD_RPT_QUOTE_DATA';
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
v_max_date        DATE;


v_start_date_time        DATE := SYSDATE;
err_fl            number:=0;

BEGIN

select max(quoted_date)
  into v_max_date
  from rptviewer.rpt_quote_data;

--v_max_date:=to_date('12312016','mmddyyyy');

v_err_loc:='Insert daily quotes info into RPT_QUOTE_DATA table';


INSERT INTO RPT_QUOTE_DATA
SELECT DISTINCT
       qd.policy_number quoted_policy_number,
       rp.policy_number active_policy_number,
       qd.policy_effective_date,
       qd.agency_number,
       DECODE (c_or_p, 'P', va.ag_pers_underw, va.ag_comm_underw) uw,
       qd.state_alpha_code,
       qd.group_line_code,
       lh.c_or_p,
       lh.description lob_description,
       lh.lob_rollup7,
       qd.source_system,
       DECODE (rp.policy_number, NULL, 'N', 'Y') quote_written,
       DECODE (rp.policy_number, NULL, 0, 1) quote_writ_num,
       (CASE
           WHEN quoted_date < NVL (active_date, TRUNC (SYSDATE)) THEN 'NBQ'
           ELSE 'IFQ'
        END)
          quote_type, -- NBQ:New Business Quote, IFQ:Inforce Quote   should only be NBQ
       TO_CHAR (qd.quoted_date, 'YYYY') quoted_year,
       qd.quoted_date,
       qd.policy_status_code,
       qd.vin,
       qd.current_license_number,
       qd.business_type,
       qd.key_sequence,
       SYSDATE date_entered       
  FROM (SELECT DISTINCT ppa.policy_number,
                        ppa.agency_number,
                        ppa.state_alpha_code,
                        ppa.group_line_code,               -- MAPPA QUOTE DATA
                        ppa.source_system,
                        ppa.original_effective_date,
                        ppa.policy_effective_date,
                        ppa.ap_quote_date,
                        ppa.quoted_date,
                        ppa.active_date,
                        ppa.policy_status_code, 
                        ppa.vin,
                        ppa.current_license_number,
                        ppa.business_type,
                        ppa.key_sequence
          FROM (SELECT DISTINCT p.policy_number,
                       p.agency_number,
                       p.state_alpha_code,
                       p.group_line_code,
                       p.vin,
                       p.current_license_number,         -- MAPPA QUOTE DATA
                       NVL (xm.source_system, 'AGENTPAK') source_system,
                       p.original_effective_date,
                       pt.policy_effective_date,
                       TRUNC (nb.quote_date) ap_quote_date,
                       NVL (TRUNC (xm.last_update), TRUNC (pt.date_entered))
                          quoted_date,
                       TRUNC (ad.active_date) active_date,
                       pt.policy_status_code, 
                       ' ' business_type,
                       key_sequence
               FROM (select p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, mapp.vehicle_identification_number vin, mad.current_license_number, p.original_effective_date,  
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, mapp.vehicle_identification_number, mad.current_license_number) key_sequence     
                         from apdev.policy p,
                              apdev.item_at_risk iar,
                              apdev.item_at_risk_ma_auto iarma,
                              apdev.ma_auto_driver mad,
                              apdev.iar_ma_auto_private_passenger mapp
                        where p.date_entered > v_max_date
                          AND p.group_line_code = '06'
                          AND agency_number NOT LIKE '%TST%'
                          AND p.policy_number = iar.policy_number
                          and iar.item_at_risk_id = iarma.item_at_risk_id
                          AND iarma.item_at_risk_id = mapp.item_at_risk_id
                          AND mapp.assigned_driver = mad.name_id
                          AND mapp.vehicle_identification_number is not null
                          AND mad.current_license_number is not null
                          UNION
                          select p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, null vin , mad.current_license_number, p.original_effective_date, 
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, null, mad.current_license_number) key_sequence     
                         from apdev.policy p,
                              apdev.item_at_risk iar,
                              apdev.item_at_risk_ma_auto iarma,
                              apdev.ma_auto_driver mad,
                              APDEV.IAR_MA_AUTO_NAMED_NON_OWNER   mapp
                        where p.date_entered > v_max_date
                          AND p.group_line_code = '06'
                          AND agency_number NOT LIKE '%TST%'
                          AND p.policy_number = iar.policy_number
                          and iar.item_at_risk_id = iarma.item_at_risk_id
                          AND iarma.item_at_risk_id = mapp.item_at_risk_id
                          AND mapp.assigned_driver = mad.name_id
                          union
                         select p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, mapp.vehicle_identification_number vin, mad.current_license_number, p.original_effective_date, 
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, mapp.vehicle_identification_number, mad.current_license_number) key_sequence     
                         from apdev.policy p,
                              apdev.item_at_risk iar,
                              apdev.item_at_risk_ma_auto iarma,
                              apdev.ma_auto_driver mad,
                              APDEV.IAR_MA_AUTO_ANTIQUE mapp
                        where p.date_entered > v_max_date
                          AND p.group_line_code = '06'
                          AND agency_number NOT LIKE '%TST%'
                          AND p.policy_number = iar.policy_number
                          and iar.item_at_risk_id = iarma.item_at_risk_id
                          AND iarma.item_at_risk_id = mapp.item_at_risk_id
                          AND mapp.assigned_driver = mad.name_id
                          union
                          select p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, mapp.vehicle_identification_number vin, mad.current_license_number, p.original_effective_date, 
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, mapp.vehicle_identification_number, mad.current_license_number) key_sequence     
                         from apdev.policy p,
                              apdev.item_at_risk iar,
                              apdev.item_at_risk_ma_auto iarma,
                              apdev.ma_auto_driver mad,
                              APDEV.IAR_MA_AUTO_MOTORCYCLE   mapp
                        where p.date_entered > v_max_date
                          AND p.group_line_code = '06'
                          AND agency_number NOT LIKE '%TST%'
                          AND p.policy_number = iar.policy_number
                          and iar.item_at_risk_id = iarma.item_at_risk_id
                          AND iarma.item_at_risk_id = mapp.item_at_risk_id
                          AND mapp.assigned_driver = mad.name_id
                          union                          
                          select p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, mapp.vehicle_identification_number vin, mad.current_license_number, p.original_effective_date, 
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, mapp.vehicle_identification_number, mad.current_license_number) key_sequence     
                         from apdev.policy p,
                              apdev.item_at_risk iar,
                              apdev.item_at_risk_ma_auto iarma,
                              apdev.ma_auto_driver mad,
                              APDEV.IAR_MA_AUTO_MOtorhome   mapp
                        where p.date_entered > v_max_date
                          AND p.group_line_code = '06'
                          AND agency_number NOT LIKE '%TST%'
                          AND p.policy_number = iar.policy_number
                          and iar.item_at_risk_id = iarma.item_at_risk_id
                          AND iarma.item_at_risk_id = mapp.item_at_risk_id
                          AND mapp.assigned_driver = mad.name_id
                          ) p,
                       (SELECT policy_number, MIN (date_entered) quote_date -- get the min date_entered from policy_track to retrieve the initial quote date
                          FROM RPTVIEWER.RPT_POLICY_TRACK pt
                         WHERE date_entered > v_max_date  --required to cap quotes to yesterday
                           AND LOAD_DATE > v_max_date 
                           AND policy_number like '9%'        
                        GROUP BY policy_number) nb,            -- New Business
                       (  SELECT policy_number, MIN (date_entered) active_date -- get the min date_entered from policy_track to retrieve the initial active date
                            FROM RPTVIEWER.RPT_POLICY_TRACK pt
                           WHERE date_entered > v_max_date
                             AND policy_status_code = 'A'
                             AND policy_number like '9%'
                             AND LOAD_DATE > v_max_date
                        GROUP BY policy_number) ad,             -- Active Date
                       (SELECT policy_number,
                               trunc(policy_effective_date) policy_effective_date,
                               max(policy_status_code) policy_status_code, 
                               TRUNC (date_entered) date_entered
                          FROM rptviewer.rpt_policy_track
                         WHERE policy_status_code not in ('A','C','D','E','S','W','Y','Z')
                           AND policy_number like '9%'
                           AND date_entered > v_max_date
                         GROUP BY policy_number, policy_effective_date, TRUNC(date_entered)) pt,
                       apdev.xmlstore xm
                 WHERE p.policy_number = pt.policy_number
                       AND p.policy_number = nb.policy_number
                       AND xm.last_update > v_max_date
                       AND xm.policy_number = p.policy_number
                       AND xm.agency = p.agency_number
                       AND TRUNC (xm.last_update) =
                              TRUNC (pt.date_entered)
                       AND pt.date_entered > v_max_date
                       AND ad.policy_number(+) = p.policy_number
                       AND pt.date_entered  < NVL (ad.active_date, TRUNC (SYSDATE))) ppa /*this qualifies NBQ's (New Business Quotes only); this change came after first version that included IFQ's (Inforce Quotes)*/
           UNION      --  Standard PPA Quotes (Group Line Code 01) */
               SELECT DISTINCT ppa.policy_number,
                        ppa.agency_number,
                        ppa.state_alpha_code,
                        ppa.group_line_code,               
                        ppa.source_system,
                        ppa.original_effective_date,
                        ppa.policy_effective_date,
                        ppa.ap_quote_date,
                        ppa.quoted_date,
                        ppa.active_date,
                        ppa.policy_status_code, 
                        ppa.vin,
                        ppa.license_number,
                        ppa.business_type,
                        ppa.key_sequence
          FROM (SELECT DISTINCT p.policy_number,
                       p.agency_number,
                       p.state_alpha_code,
                       p.group_line_code,
                       p.vin,
                       p.license_number,         -- MAPPA QUOTE DATA
                       NVL (xm.source_system, 'AGENTPAK') source_system,
                       p.original_effective_date,
                       pt.policy_effective_date,
                       TRUNC (nb.quote_date) ap_quote_date,
                       NVL (TRUNC (xm.last_update), TRUNC (pt.date_entered))
                          quoted_date,
                       TRUNC (ad.active_date) active_date,
                       pt.policy_status_code, --MAX(pt.policy_status_code) policy_status_code,
                       ' ' business_type,
                       p.key_sequence
               FROM (select distinct p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, ia.vehicle_identification_number vin, nm.license_number, P.ORIGINAL_EFFECTIVE_DATE,  
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, ia.vehicle_identification_number, nm.license_number) key_sequence     
                         from new_apdev.policy p,
                              new_apdev.item_at_risk iar,
                              new_apdev.iar_auto ia,
                              new_apdev.item_name itn,
                              new_apdev.name nm,
                              RPTVIEWER.RPT_LOB_HIERARCHY lh
                        where p.policy_number     = iar.policy_number
                          and iar.item_at_risk_id = ia.item_at_risk_id
                          and iar.item_at_risk_id = itn.item_at_risk_id 
                          and itn.item_name_type_code = 'DR'
                          and itn.name_id = nm.name_id
                          and p.group_line_code = lh.group_line_code
                          and LH.LOB_ROLLUP2 = 'PPA'
                          and p.agency_number NOT LIKE '%TST%'
                          and p.group_line_code = '01' --!= '06'
                          --and p.policy_number = 'A1786533A'   
                          and p.date_entered > v_max_date
                          --AND p.original_effective_date > trunc(sysdate-30)
                          and ia.vehicle_identification_number is not null
                          and nm.license_number is not null) p,
                       (SELECT policy_number, MIN (date_entered) quote_date -- get the min date_entered from policy_track to retrieve the initial quote date
                          FROM RPTVIEWER.RPT_POLICY_TRACK pt
                         WHERE date_entered > v_max_date --required to cap quotes to yesterday
                           AND LOAD_DATE > v_max_date
                           --AND policy_number not like '9%'        
                        GROUP BY policy_number) nb,            -- New Business
                       (  SELECT policy_number, MIN (date_entered) active_date -- get the min date_entered from policy_track to retrieve the initial active date
                            FROM RPTVIEWER.RPT_POLICY_TRACK pt
                           WHERE date_entered > v_max_date
                                 AND policy_status_code = 'A'
                                 AND policy_number not like '9%'
                                 AND LOAD_DATE > v_max_date
                        GROUP BY policy_number) ad,             -- Active Date
                       (SELECT policy_number,
                               trunc(policy_effective_date) policy_effective_date,
                               max(policy_status_code) policy_status_code, 
                               TRUNC (date_entered) date_entered
                          FROM rptviewer.rpt_policy_track
                         WHERE policy_status_code  not in ('A','C','D','E','S','W','Y','Z')
                           AND policy_number not like '9%'
                           AND date_entered > v_max_date
                         GROUP BY policy_number, policy_effective_date, TRUNC(date_entered)) pt,
                       apdev.xmlstore xm
                 WHERE p.policy_number = pt.policy_number  --and 1=0
                       AND p.policy_number = nb.policy_number
                       AND xm.last_update(+) > v_max_date
                       AND xm.policy_number(+) = p.policy_number
                       AND xm.agency(+) = p.agency_number
                       AND TRUNC (xm.last_update(+)) =
                              TRUNC (pt.date_entered)
                       AND pt.date_entered  > v_max_date
                       AND ad.policy_number(+) = p.policy_number
                       AND pt.date_entered  < NVL (ad.active_date, TRUNC (SYSDATE))) ppa
          UNION  -----lINE 10
                    SELECT DISTINCT ppa.policy_number,
                        ppa.agency_number,
                        ppa.state_alpha_code,
                        ppa.group_line_code,               
                        ppa.source_system,
                        ppa.original_effective_date,
                        ppa.policy_effective_date,
                        ppa.ap_quote_date,
                        ppa.quoted_date,
                        ppa.active_date,
                        ppa.policy_status_code, 
                        ppa.vin,
                        ppa.license_number,
                        ppa.business_type,
                        ppa.key_sequence
          FROM (SELECT DISTINCT p.policy_number,
                       p.agency_number,
                       p.state_alpha_code,
                       p.group_line_code,
                       p.vin,
                       p.license_number,         -- MAPPA QUOTE DATA
                       NVL (xm.source_system, 'AGENTPAK') source_system,
                       p.original_effective_date,
                       pt.policy_effective_date,
                       TRUNC (nb.quote_date) ap_quote_date,
                       NVL (TRUNC (xm.last_update), TRUNC (pt.date_entered))
                          quoted_date,
                       TRUNC (ad.active_date) active_date,
                       pt.policy_status_code, --MAX(pt.policy_status_code) policy_status_code,
                       ' ' business_type,
                       p.key_sequence
               FROM (select distinct p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, ia.vehicle_identification_number vin,
 NVL(nm.license_number,
 (select max(N.LICENSE_NUMBER) --DISTINCT IAR.WANG_ITEM_SEQ,IAR.USER_LINE_CODE ,COUNT(*)
from 
--new_apdev.policy p,
NEW_APDEV.ITEM_AT_RISK iar,
NEW_APDEV.ITEM_NAME i_n,
NEW_APDEV.NAME N
where 
 P.POLICY_NUMBER=IAR.POLICY_NUMBER
AND IAR.ITEM_AT_RISK_ID=I_N.ITEM_AT_RISK_ID
AND I_N.ITEM_NAME_TYPE_CODE='DR'
AND IAR.USER_LINE_CODE='XX'
AND I_N.NAME_ID=N.NAME_ID) ) license_number
 , P.ORIGINAL_EFFECTIVE_DATE,  
                            rptviewer.get_hr_key_seq(p.policy_number, p.agency_number, ia.vehicle_identification_number, nm.license_number) key_sequence     
                         from new_apdev.policy p,
                              new_apdev.item_at_risk iar,
                              new_apdev.iar_auto ia,
                              new_apdev.item_name itn,
                              new_apdev.name nm,
                              RPTVIEWER.RPT_LOB_HIERARCHY lh
                        where p.policy_number     = iar.policy_number
                          and iar.item_at_risk_id = ia.item_at_risk_id
                          and iar.item_at_risk_id = itn.item_at_risk_id(+) 
                          and itn.item_name_type_code(+) = 'DR'
                          and itn.name_id = nm.name_id(+)
                          and p.group_line_code = lh.group_line_code
                          and trim(LH.LOB_ROLLUP2) = 'COMMERCIAL AUTO'
                          and p.agency_number NOT LIKE '%TST%'
                          and p.group_line_code ='10'--in('01','10')--= '01' --!= '06'
                          --and p.policy_number = 'A1786533A'   
                          and p.date_entered > v_max_date
                          --AND p.original_effective_date > trunc(sysdate-30)
                         and ia.vehicle_identification_number is not null
                          --and nm.license_number is not null
                          ) p,
                       (SELECT policy_number, MIN (date_entered) quote_date -- get the min date_entered from policy_track to retrieve the initial quote date
                          FROM RPTVIEWER.RPT_POLICY_TRACK pt
                         WHERE date_entered >v_max_date--required to cap quotes to yesterday
                           AND LOAD_DATE >v_max_date
                           --AND policy_number not like '9%'        
                        GROUP BY policy_number) nb,            -- New Business
                       (  SELECT policy_number, MIN (date_entered) active_date -- get the min date_entered from policy_track to retrieve the initial active date
                            FROM RPTVIEWER.RPT_POLICY_TRACK pt
                           WHERE date_entered > v_max_date
                                 AND policy_status_code = 'A'
                                 AND policy_number not like '9%'
                                 AND LOAD_DATE > v_max_date
                        GROUP BY policy_number) ad,             -- Active Date
                       (SELECT policy_number,
                               trunc(policy_effective_date) policy_effective_date,
                               max(policy_status_code) policy_status_code, 
                               TRUNC (date_entered) date_entered
                          FROM rptviewer.rpt_policy_track
                         WHERE policy_status_code  not in ('A','C','D','E','S','W','Y','Z')
                           AND policy_number not like '9%'
                           AND date_entered > v_max_date
                         GROUP BY policy_number, policy_effective_date, TRUNC(date_entered)) pt,
                       apdev.xmlstore xm
                 WHERE p.policy_number = pt.policy_number  --and 1=0
                       AND p.policy_number = nb.policy_number
                       AND xm.last_update(+) > v_max_date
                       AND xm.policy_number(+) = p.policy_number
                       AND xm.agency(+) = p.agency_number
                       AND TRUNC (xm.last_update(+)) =
                              TRUNC (pt.date_entered)
                       AND pt.date_entered  > v_max_date
                       AND ad.policy_number(+) = p.policy_number
                       AND pt.date_entered  < NVL (ad.active_date, TRUNC (SYSDATE))) ppa             
          UNION        
             SELECT p.policy_number,
               p.agency_number,
               p.state_alpha_code,
               p.group_line_code,     --null vin, null current_license_number,
               NVL (xm.source_system, 'AGENTPAK') source_system,
               p.original_effective_date,
               pt.policy_effective_date,
               TRUNC (nb.quote_date) ap_quote_date,
               NVL (xm.last_update, TRUNC (pt.date_entered)) quoted_date,
               TRUNC (ad.active_date) active_date,
               max(pt.policy_status_code) policy_status_code,
               --cc.business_type_code,
               ' ' vin,
               ' 'current_license_number,
                cc.business_type_code,
               rptviewer.get_hr_key_seq(p.policy_number, '2222222','7777777777777','9999999') key_sequence
          FROM new_apdev.policy p,
               (SELECT policy_number, MIN (date_entered) quote_date -- get the min date_entered from policy_track to retrieve the initial quote date
                          FROM RPTVIEWER.RPT_POLICY_TRACK pt
                         WHERE date_entered > v_max_date  --required to cap quotes to yesterday
                           AND LOAD_DATE > v_max_date 
                           --AND policy_number not like '9%'    -- removed qualifier 12/29/2017
                        GROUP BY policy_number) nb,            -- New Business
                       (  SELECT policy_number, MIN (date_entered) active_date -- get the min date_entered from policy_track to retrieve the initial active date
                            FROM RPTVIEWER.RPT_POLICY_TRACK pt
                           WHERE date_entered > v_max_date
                                 AND policy_status_code = 'A'
                                 --AND policy_number not like '9%'   -- removed qualifier 12/29/2017
                                 AND LOAD_DATE > v_max_date
                        GROUP BY policy_number) ad,             -- Active Date                   -- Active Date
               (SELECT policy_number,
                       trunc(policy_effective_date) policy_effective_date,
                       max(policy_status_code) policy_status_code, 
                       TRUNC (date_entered) date_entered
                          FROM rptviewer.rpt_policy_track
                         WHERE policy_status_code not in ('A','C','D','E','S','W','Y','Z')
                          -- AND policy_number not like '9%'  -- removed qualifier 12/29/2017
                           AND date_entered > v_max_date
                           --AND POLICY_NUMBER = '916661004A'
                         GROUP BY policy_number, policy_effective_date, TRUNC(date_entered)) pt,
               apdev.xmlstore xm,
               NEW_APDEV.R_BO_BUSINESS_CLASS_CODE cc
         WHERE p.date_entered > v_max_date  --and 1=0
               AND p.original_effective_date > v_max_date
               AND p.group_line_code not in('06','01','10')-- <> '06'
               AND agency_number NOT LIKE '%TST%'
               AND p.state_alpha_code IS NOT NULL
               AND p.policy_number = pt.policy_number
               AND pt.date_entered > v_max_date
               AND TRUNC (xm.last_update(+)) = trunc(pt.date_entered)
               AND xm.policy_number(+) = p.policy_number
               AND xm.agency(+) = p.agency_number
               AND p.policy_number = nb.policy_number
               AND ad.policy_number(+) = p.policy_number
               AND cc.class_code(+) = p.master_class_code 
               AND pt.date_entered < NVL(ad.active_date, TRUNC (SYSDATE)) /*this qualifies NBQ's (New Business Quotes only); this change came after first version that included IFQ's (Inforce Quotes)*/
         group by p.policy_number, p.agency_number, p.state_alpha_code, p.group_line_code, xm.source_system, p.original_effective_date, pt.policy_effective_date,
               nb.quote_date, xm.last_update, trunc(pt.date_entered), trunc(ad.active_date), cc.business_type_code) qd,
               RPTVIEWER.V_AGENCY va,
               RPTVIEWER.RPT_LOB_HIERARCHY lh,
               RPTVIEWER.RPT_POLICY rp
 WHERE qd.agency_number = va.ag_number
   AND qd.group_line_code = lh.group_line_code
   AND rp.policy_number(+) = qd.policy_number;

COMMIT;

v_err_loc:='Update quotes in RPT_QUOTE_DATA table with Active Policy Numbers';

-- Update Quotes in RPT_QUOTE_DATA with Active Policy Numbers based on policies that have gone active since the last load   
UPDATE RPT_QUOTE_DATA RQD
   SET (ACTIVE_POLICY_NUMBER) = 
       (select policy_number  
          from (select distinct pt.policy_number
                  from rptviewer.rpt_policy_track pt,
                       rptviewer.rpt_policy rp
                 where pt.load_date > v_max_date
                   and pt.policy_status_code = 'F'
                   and pt.policy_number = rp.policy_number) ap
         where rqd.quoted_policy_number = ap.policy_number)
 WHERE RQD.ACTIVE_POLICY_NUMBER IS NULL
   AND EXISTS (SELECT 1
                 FROM (select distinct pt.policy_number
                         from rptviewer.rpt_policy_track pt,
                              rptviewer.rpt_policy rp
                        where pt.load_date > v_max_date
                          and pt.policy_status_code = 'F'
                          and pt.policy_number = rp.policy_number) ap
                WHERE RQD.QUOTED_POLICY_NUMBER = AP.POLICY_NUMBER);
   
COMMIT;


v_err_loc:='Update quotes in RPT_QUOTE_DATA table with Active Policy Numbers on lic num/vin key';

-- Update PPA Quotes in RPT_QUOTE_DATA with Active Policy Numbers based on Agency Number, Vin, License Number   
UPDATE RPT_QUOTE_DATA RQD
   SET (ACTIVE_POLICY_NUMBER) = 
       (select distinct policy_number
          from (select distinct pt.policy_number, pt.date_entered, pt.policy_status_code, RP.AGENCY_NUMBER, vh.vin, vh.lic_num
                  from rptviewer.rpt_policy_track pt,
                       rptviewer.rpt_policy rp,
                       rptviewer.rpt_lob_hierarchy lh,
                      (select distinct RI.POLICY_NUMBER, RI.IDENT_NUM vin, RN.LIC_NUM
                         from rptviewer.rpt_item ri, rptviewer.rpt_name rn
                        where ri.policy_number = rn.policy_number
                          and RN.NAME_TYPE = 'DR'
                          and ri.run_date > v_max_date) vh
                where pt.load_date > v_max_date
                  and pt.policy_status_code = 'F'
                  AND RP.POLICY_STATUS_CODE='A'
                  and rp.group_line_code = lh.group_line_code
                  and LH.LOB_ROLLUP2 = 'PPA'
                  and pt.policy_number = rp.policy_number
                  and vh.policy_number(+) = rp.policy_number) vh
          where vh.agency_number = rqd.agency_number
            and vh.vin           = rqd.vin 
            and vh.lic_num       = rqd.license_number)
 WHERE RQD.ACTIVE_POLICY_NUMBER IS NULL
   AND EXISTS (SELECT 1
                 FROM (select distinct pt.policy_number, pt.date_entered, pt.policy_status_code, RP.AGENCY_NUMBER, vh.vin, vh.lic_num
                         from rptviewer.rpt_policy_track pt,
                              rptviewer.rpt_policy rp,
                              rptviewer.rpt_lob_hierarchy lh,
                             (select distinct RI.POLICY_NUMBER, RI.IDENT_NUM vin, RN.LIC_NUM
                                from rptviewer.rpt_item ri, rptviewer.rpt_name rn
                               where ri.policy_number = rn.policy_number
                                 and RN.NAME_TYPE = 'DR'
                                 and ri.run_date > v_max_date) vh
                            where pt.load_date > v_max_date
                              and pt.policy_status_code = 'F'
                              AND RP.POLICY_STATUS_CODE='A'
                              and pt.policy_number = rp.policy_number
                              and rp.group_line_code = lh.group_line_code
                              and LH.LOB_ROLLUP2 = 'PPA'
                              and vh.policy_number(+) = rp.policy_number) vh
                    WHERE VH.AGENCY_NUMBER = RQD.AGENCY_NUMBER
                      AND VH.VIN           = RQD.VIN 
                      AND VH.LIC_NUM       = RQD.LICENSE_NUMBER);      
        
  COMMIT; 

v_err_loc:='Update quotes in RPT_QUOTE_DATA table with Cancelled Policy Numbers on lic num/vin key';

UPDATE RPT_QUOTE_DATA RQD
   SET (ACTIVE_POLICY_NUMBER) = 
       (select distinct policy_number
          from (select distinct pt.policy_number, pt.date_entered, pt.policy_status_code, RP.AGENCY_NUMBER, vh.vin, vh.lic_num
                  from rptviewer.rpt_policy_track pt,
                       rptviewer.rpt_policy rp,
                       rptviewer.rpt_lob_hierarchy lh,
                      (select distinct RI.POLICY_NUMBER, RI.IDENT_NUM vin, RN.LIC_NUM
                         from rptviewer.rpt_item ri, rptviewer.rpt_name rn
                        where ri.policy_number = rn.policy_number
                          and RN.NAME_TYPE = 'DR'
                          and ri.run_date > v_max_date) vh
                where pt.load_date > v_max_date
                  and pt.policy_status_code = 'F'
                  AND RP.POLICY_STATUS_CODE='C'
                  and rp.group_line_code = lh.group_line_code
                  and LH.LOB_ROLLUP2 = 'PPA'
                  and pt.policy_number = rp.policy_number
                  and vh.policy_number(+) = rp.policy_number) vh
          where vh.agency_number = rqd.agency_number
            and vh.vin           = rqd.vin 
            and vh.lic_num       = rqd.license_number)
 WHERE RQD.ACTIVE_POLICY_NUMBER IS NULL
   AND EXISTS (SELECT 1
                 FROM (select distinct pt.policy_number, pt.date_entered, pt.policy_status_code, RP.AGENCY_NUMBER, vh.vin, vh.lic_num
                         from rptviewer.rpt_policy_track pt,
                              rptviewer.rpt_policy rp,
                              rptviewer.rpt_lob_hierarchy lh,
                             (select distinct RI.POLICY_NUMBER, RI.IDENT_NUM vin, RN.LIC_NUM
                                from rptviewer.rpt_item ri, rptviewer.rpt_name rn
                               where ri.policy_number = rn.policy_number
                                 and RN.NAME_TYPE = 'DR'
                                 and ri.run_date > v_max_date) vh
                            where pt.load_date > v_max_date
                              and pt.policy_status_code = 'F'
                              AND RP.POLICY_STATUS_CODE='C'
                              and pt.policy_number = rp.policy_number
                              and rp.group_line_code = lh.group_line_code
                              and LH.LOB_ROLLUP2 = 'PPA'
                              and vh.policy_number(+) = rp.policy_number) vh
                    WHERE VH.AGENCY_NUMBER = RQD.AGENCY_NUMBER
                      AND VH.VIN           = RQD.VIN 
                      AND VH.LIC_NUM       = RQD.LICENSE_NUMBER);      
        
  COMMIT; 


-- Assignment of key sequence on large record set using BULK COLLECT
/*

DECLARE   -- Declare Cursor of data to be inserted
    CURSOR lrate_q_data IS
    select policy_number, agency_number, vin, license_number
      from shaynes.raw_quote_data
     where --quoted_date between ADD_MONTHS (trunc(sysdate), -33) and ADD_MONTHS (trunc(sysdate), -30)
        key_sequence = 0;
  

  -- Define PL/SQL Table types
  
  TYPE t_POLICY_NUMBER  IS TABLE OF SHAYNES.RAW_QUOTE_DATA.POLICY_NUMBER%TYPE;
  TYPE t_AGENCY_NUMBER  IS TABLE OF SHAYNES.RAW_QUOTE_DATA.AGENCY_NUMBER%TYPE;
  TYPE t_VIN            IS TABLE OF SHAYNES.RAW_QUOTE_DATA.VIN%TYPE;
  TYPE t_LICENSE_NUMBER IS TABLE OF SHAYNES.RAW_QUOTE_DATA.LICENSE_NUMBER%TYPE;
  
  -- Declare PL/SQL tables  
  c_POLICY_NUMBER     t_POLICY_NUMBER;
  c_AGENCY_NUMBER     t_AGENCY_NUMBER;
  c_VIN               t_VIN;
  c_LICENSE_NUMBER    t_LICENSE_NUMBER;
    
  
   BEGIN
    IF lrate_q_data%ISOPEN THEN
      CLOSE lrate_q_data;
    END IF;
    
    OPEN lrate_q_data;
    LOOP
      FETCH lrate_q_data BULK COLLECT INTO
       c_POLICY_NUMBER,
       c_AGENCY_NUMBER,
       c_VIN,
       c_LICENSE_NUMBER
      LIMIT 100;  
      
      IF c_POLICY_NUMBER.COUNT = 0 
      THEN
        EXIT;
      END IF;
      
      FORALL  i IN c_POLICY_NUMBER.FIRST..c_POLICY_NUMBER.LAST
      update shaynes.raw_quote_data rqd
         set key_sequence = rptviewer.get_hr_key_seq(c_POLICY_NUMBER(i)  , c_AGENCY_NUMBER(i), c_VIN(i), c_LICENSE_NUMBER(i))
       where rqd.policy_number  = c_POLICY_NUMBER(i)
         and rqd.agency_number  = c_AGENCY_NUMBER(i)
         and rqd.vin            = c_VIN(i)
         and rqd.license_number = c_LICENSE_NUMBER(i);
      
      COMMIT;
      
      EXIT WHEN lrate_q_data%NOTFOUND;

    END LOOP;

    CLOSE lrate_q_data;
      
  END;
  
*/
 


   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       v_err_number := SQLCODE;
         v_err_msg := SQLERRM(SQLCODE);
         v_err_msg :=
            'FAILED: ' ||v_err_loc||'-' ||v_err_number || ' * ' || v_err_msg;
          DBMS_OUTPUT.put_line(v_err_msg);
      rptviewer.rpt_util.write_error(v_procname,v_err_msg);
END LOAD_RPT_QUOTE_DATA;
/
