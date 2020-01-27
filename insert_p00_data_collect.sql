--
-- Create Schema Script
--   Database Version            : 12.1.0.2.0
--   Database Compatible Level   : 11.2.0.3
--   Script Compatible Level     : 11.2.0.3
--   Toad Version                : 13.0.0.80
--   DB Connect String           : ORACLE1
--   Schema                      : NEW_APDEV
--   Script Created by           : NEW_APDEV
--   Script Created at           : 1/17/2020 9:20:07 AM
--   Notes                       : 
--

-- Object Counts: 
--   Triggers: 1 


CREATE OR REPLACE TRIGGER NEW_APDEV.INSERT_P00_DATA_COLLECT
AFTER INSERT
ON NEW_APDEV.DC_P00 
REFERENCING NEW AS NEW_DC_P00 OLD AS OLD
FOR EACH ROW
BEGIN
        INSERT INTO DATA_COLLECT_RECORDS
        SELECT
        :NEW_DC_P00.DATE_ENTERED,
        RTRIM(:NEW_DC_P00.POLICY_NUMBER),
        (
:NEW_DC_P00.STATUS ||
:NEW_DC_P00.TRANSACTION_TYPE ||
:NEW_DC_P00.POLICY_NUMBER ||
:NEW_DC_P00.HISTORY_CODE ||
:NEW_DC_P00.ITEM_NUMBER ||
:NEW_DC_P00.MAP_NAME ||
:NEW_DC_P00.RECORD_NUMBER ||
:NEW_DC_P00.FILLER_0025_0030 ||
:NEW_DC_P00.NAME ||
:NEW_DC_P00.NAME_ADDR ||
:NEW_DC_P00.STREET ||
:NEW_DC_P00.CITY ||
:NEW_DC_P00.STATE ||
:NEW_DC_P00.STATE_CD ||
:NEW_DC_P00.ZIP1 ||
:NEW_DC_P00.ZIP2 ||
:NEW_DC_P00.MDESCR_CODE ||
:NEW_DC_P00.POL_NO ||
:NEW_DC_P00.PRODUCER_8 ||
:NEW_DC_P00.COMP_CD ||
:NEW_DC_P00.EFF_DATE ||
:NEW_DC_P00.EXP_DATE ||
:NEW_DC_P00.TERM ||
:NEW_DC_P00.BILL_TYPE ||
:NEW_DC_P00.BILL_TO ||
:NEW_DC_P00.PAY_PLAN ||
:NEW_DC_P00.DEPOSIT ||
:NEW_DC_P00.EST_TOTAL ||
:NEW_DC_P00.CHG_DATE ||
:NEW_DC_P00.REAS_FORM ||
:NEW_DC_P00.SUSPEND ||
:NEW_DC_P00.PHONE_NUMBER ||
:NEW_DC_P00.ADDTNL_HO_POLICY ||
:NEW_DC_P00.PTC_IND ||
:NEW_DC_P00.RES_TERR ||
:NEW_DC_P00.USE_OF_B28 ||
:NEW_DC_P00.AL3_NM_CODE ||
:NEW_DC_P00.AL3_NM_PREFIX ||
:NEW_DC_P00.AL3_NM_FIRST ||
:NEW_DC_P00.AL3_NM_MIDDLE ||
:NEW_DC_P00.AL3_NM_LAST ||
:NEW_DC_P00.AL3_NM_SUFFIX ||
:NEW_DC_P00.EFT_BANK_NAME ||
:NEW_DC_P00.EFT_BANK_NO ||
:NEW_DC_P00.EFT_ACCT_NO ||
:NEW_DC_P00.EFT_PAY_DAY ||
:NEW_DC_P00.REN_PAY_PLAN ||
:NEW_DC_P00.NAME_SHORT ||
:NEW_DC_P00.NAME_ASTER ||
:NEW_DC_P00.AL3_NAME_ASTER ||
:NEW_DC_P00.AI_LOB ||
:NEW_DC_P00.PARSED_NAME_FIRST ||
:NEW_DC_P00.PARSED_NAME_LAST ||
:NEW_DC_P00.NAME_LAST_LENGTH ||
:NEW_DC_P00.INS_EMAIL ||
:NEW_DC_P00.INS_SOC_SEC ||
:NEW_DC_P00.SPOUSE_SOC_SEC ||
:NEW_DC_P00.REAS_ACT ||
:NEW_DC_P00.REAS_MOD ||
:NEW_DC_P00.REAS_SPEC ||
:NEW_DC_P00.EFT_IND ||
:NEW_DC_P00.ACCT_TYPE_CD ||   -- Renamed on 1/15/2020 - shaynes
:NEW_DC_P00.DEPOSIT_TYPE_CODE ||
:NEW_DC_P00.EMP_ID ||
:NEW_DC_P00.FILLER_0554_1000)
from dual;

end INSERT_P00_DATA_COLLECT;
/
SHOW ERRORS;
/