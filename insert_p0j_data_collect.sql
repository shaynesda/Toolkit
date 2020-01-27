SET DEFINE OFF;
CREATE OR REPLACE TRIGGER NEW_APDEV.INSERT_P0J_DATA_COLLECT
    AFTER INSERT ON NEW_APDEV.DC_P0J     REFERENCING NEW AS NEW_DC_P0J
    FOR EACH ROW
BEGIN
        INSERT INTO DATA_COLLECT_RECORDS
        SELECT
        :NEW_DC_P0J.DATE_ENTERED,
        RTRIM(:NEW_DC_P0J.POLICY_NUMBER),
        (
:NEW_DC_P0J.STATUS ||
:NEW_DC_P0J.TRANSACTION_TYPE ||
:NEW_DC_P0J.POLICY_NUMBER ||
:NEW_DC_P0J.HISTORY_CODE ||
:NEW_DC_P0J.ITEM_NUMBER ||
:NEW_DC_P0J.MAP_NAME ||
:NEW_DC_P0J.RECORD_NUMBER ||
:NEW_DC_P0J.FILLER_0025_0030 ||
:NEW_DC_P0J.USER_LINE ||
:NEW_DC_P0J.POL_NO ||
:NEW_DC_P0J.VEHICLE_NUMBER ||
:NEW_DC_P0J.STATE_CODE ||
:NEW_DC_P0J.LIABILITY_LIMIT ||
:NEW_DC_P0J.LIABILITY_PREMIUM ||
:NEW_DC_P0J.BODILY_INJURY_LIMIT_01 ||
:NEW_DC_P0J.BODILY_INJURY_LIMIT_02 ||
:NEW_DC_P0J.BODILY_INJURY_PREMIUM ||
:NEW_DC_P0J.PROPERTY_DAMAGE_LIMIT ||
:NEW_DC_P0J.PROPERTY_DAMAGE_PREMIUM ||
:NEW_DC_P0J.MEDICAL_LIMIT_01 ||
:NEW_DC_P0J.MEDICAL_LIMIT_02 ||
:NEW_DC_P0J.BRB_PREMIUM ||
:NEW_DC_P0J.PIP_MEDICAL_LIMIT_01 ||
:NEW_DC_P0J.PIP_MEDICAL_LIMIT_02 ||
:NEW_DC_P0J.PIP_MEDICAL_PREMIUM ||
:NEW_DC_P0J.PIP_EL_LIMIT_01 ||
:NEW_DC_P0J.PIP_EL_LIMIT_02 ||
:NEW_DC_P0J.PIP_EL_PREMIUM ||
:NEW_DC_P0J.MED_PAYMENTS_LIMIT ||
:NEW_DC_P0J.MED_PAYMENTS_PREMIUM ||
:NEW_DC_P0J.UNINSURED_CSL_BI_LIMIT_01 ||
:NEW_DC_P0J.UNINSURED_CSL_BI_LIMIT_02 ||
:NEW_DC_P0J.UNINSURED_CSL_BI_PREMIUM ||
:NEW_DC_P0J.UNINSURED_PD_LIMIT ||
:NEW_DC_P0J.UNINSURED_PD_PREMIUM ||
:NEW_DC_P0J.UNDERINSURED_CSL_BI_LIMIT_01 ||
:NEW_DC_P0J.UNDERINSURED_CSL_BI_LIMIT_02 ||
:NEW_DC_P0J.UNDERINSURED_CSL_BI_PREMIUM ||
:NEW_DC_P0J.UNDERINSURED_PD_LIMIT ||
:NEW_DC_P0J.UNDERINSURED_PD_PREMIUM ||
:NEW_DC_P0J.COMP_DEDUCTIBLE_AMOUNT ||
:NEW_DC_P0J.COMP_DEDUCTIBLE_TYPE ||
:NEW_DC_P0J.COMP_STATED_AMOUNT ||
:NEW_DC_P0J.COMP_PREMIUM ||
:NEW_DC_P0J.COLL_DEDUCTIBLE_AMOUNT ||
:NEW_DC_P0J.COLL_DEDUCTIBLE_TYPE ||
:NEW_DC_P0J.COLL_STATED_AMOUNT ||
:NEW_DC_P0J.COLL_PREMIUM ||
:NEW_DC_P0J.TOWING_LABOR_LIMIT ||
:NEW_DC_P0J.TOWING_LABOR_PREMIUM ||
:NEW_DC_P0J.RATE_INDICATOR ||
:NEW_DC_P0J.ENDORSEMENT_NUMBER_01 ||
:NEW_DC_P0J.ENDORSEMENT_LIMIT_01 ||
:NEW_DC_P0J.ENDORSEMENT_PREMIUM_01 ||
:NEW_DC_P0J.ENDORSEMENT_01_COV_PREMIUM_01 ||
:NEW_DC_P0J.ENDORSEMENT_01_COV_PREMIUM_02 ||
:NEW_DC_P0J.ENDORSEMENT_01_COV_PREMIUM_03 ||
:NEW_DC_P0J.ENDORSEMENT_01_COV_PREMIUM_04 ||
:NEW_DC_P0J.ENDORSEMENT_01_COV_PREMIUM_05 ||
:NEW_DC_P0J.ENDORSEMENT_DATE_01 ||
:NEW_DC_P0J.ENDORSEMENT_TYPE_01 ||
:NEW_DC_P0J.ENDORSEMENT_NUMBER_02 ||
:NEW_DC_P0J.ENDORSEMENT_LIMIT_02 ||
:NEW_DC_P0J.ENDORSEMENT_PREMIUM_02 ||
:NEW_DC_P0J.ENDORSEMENT_02_COV_PREMIUM_01 ||
:NEW_DC_P0J.ENDORSEMENT_02_COV_PREMIUM_02 ||
:NEW_DC_P0J.ENDORSEMENT_02_COV_PREMIUM_03 ||
:NEW_DC_P0J.ENDORSEMENT_02_COV_PREMIUM_04 ||
:NEW_DC_P0J.ENDORSEMENT_02_COV_PREMIUM_05 ||
:NEW_DC_P0J.ENDORSEMENT_DATE_02 ||
:NEW_DC_P0J.ENDORSEMENT_TYPE_02 ||
:NEW_DC_P0J.ACTION_AUTO ||
:NEW_DC_P0J.ACTION_01 ||
:NEW_DC_P0J.ACTION_02 ||
:NEW_DC_P0J.ACTION_S_LIMIT ||
:NEW_DC_P0J.ACTION_BI ||
:NEW_DC_P0J.ACTION_PD ||
:NEW_DC_P0J.ACTION_PIP_MED ||
:NEW_DC_P0J.ACTION_PIP_EL ||
:NEW_DC_P0J.ACTION_MED_PAY ||
:NEW_DC_P0J.ACTION_UM_BI ||
:NEW_DC_P0J.ACTION_UM_PD ||
:NEW_DC_P0J.ACTION_UIM_BI ||
:NEW_DC_P0J.ACTION_UIM_PD ||
:NEW_DC_P0J.ACTION_COMPREHENSIVE ||
:NEW_DC_P0J.ACTION_COLLISION ||
:NEW_DC_P0J.ACTION_TOWING_LABOR ||
:NEW_DC_P0J.ACTION_RENT_REIM ||
:NEW_DC_P0J.ACTION_BRB ||
:NEW_DC_P0J.ACTION_COORD ||
:NEW_DC_P0J.ACTION_DEATH ||
:NEW_DC_P0J.RENTAL_REIMB_LIMIT ||
:NEW_DC_P0J.RENTAL_REIMB_PREMIUM ||
:NEW_DC_P0J.COORD_BENEFITS ||
:NEW_DC_P0J.DEATH_BENEFIT ||
:NEW_DC_P0J.BFPB_CODE ||
:NEW_DC_P0J.MC_CODE ||
:NEW_DC_P0J.WL_CODE ||
:NEW_DC_P0J.FE_CODE ||
:NEW_DC_P0J.AD_CODE ||
:NEW_DC_P0J.CC_CODE ||
:NEW_DC_P0J.BFPB_PREMIUM ||
:NEW_DC_P0J.ACTION_BFPB_CODE ||
:NEW_DC_P0J.ACTION_MC_CODE ||
:NEW_DC_P0J.ACTION_WL_CODE ||
:NEW_DC_P0J.ACTION_FE_CODE ||
:NEW_DC_P0J.ACTION_AD_CODE ||
:NEW_DC_P0J.ACTION_CC_CODE ||
:NEW_DC_P0J.UMC_PD ||
:NEW_DC_P0J.PIP_TYPE ||
:NEW_DC_P0J.FILLER_0478_1000
)
from dual;

end INSERT_P0J_DATA_COLLECT;
/
