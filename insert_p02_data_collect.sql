SET DEFINE OFF;
CREATE OR REPLACE TRIGGER NEW_APDEV.INSERT_P02_DATA_COLLECT
    AFTER INSERT ON NEW_APDEV.DC_P02
	REFERENCING NEW AS NEW_DC_P02
    FOR EACH ROW
BEGIN
        INSERT INTO DATA_COLLECT_RECORDS
		SELECT
		:NEW_DC_P02.DATE_ENTERED,
		RTRIM(:NEW_DC_P02.POLICY_NUMBER),
		(
		:NEW_DC_P02.STATUS ||
		:NEW_DC_P02.TRANSACTION_TYPE ||
		:NEW_DC_P02.POLICY_NUMBER ||
		:NEW_DC_P02.HISTORY_CODE ||
		:NEW_DC_P02.ITEM_NUMBER ||
		:NEW_DC_P02.MAP_NAME ||
		:NEW_DC_P02.RECORD_NUMBER ||
		:NEW_DC_P02.FILLER_0025_0030 ||
		:NEW_DC_P02.POL_NO ||
		:NEW_DC_P02.ACTION_1 ||
		:NEW_DC_P02.SEQ_1 ||
		:NEW_DC_P02.N_A_1 ||
		:NEW_DC_P02.STREET_1 ||
		:NEW_DC_P02.CITY_1 ||
		:NEW_DC_P02.STATE_1 ||
		:NEW_DC_P02.ZIP_1 ||
		:NEW_DC_P02.ACTION_2 ||
		:NEW_DC_P02.SEQ_2 ||
		:NEW_DC_P02.NAME_2 ||
		:NEW_DC_P02.N_A_2 ||
		:NEW_DC_P02.STREET_2 ||
		:NEW_DC_P02.CITY_2 ||
		:NEW_DC_P02.STATE_2 ||
		:NEW_DC_P02.ZIP_2 ||
		:NEW_DC_P02.LOAN_NO_2 ||
		:NEW_DC_P02.ACTION_3 ||
		:NEW_DC_P02.SEQ_3 ||
		:NEW_DC_P02.NAME_3 ||
		:NEW_DC_P02.N_A_3 ||
		:NEW_DC_P02.STREET_3 ||
		:NEW_DC_P02.CITY_3 ||
		:NEW_DC_P02.STATE_3 ||
		:NEW_DC_P02.ZIP_3 ||
		:NEW_DC_P02.INT_3 ||
		:NEW_DC_P02.ACTION_4 ||
		:NEW_DC_P02.SEQ_4 ||
		:NEW_DC_P02.NAME_4 ||
		:NEW_DC_P02.NM_TYP_4 ||
		:NEW_DC_P02.N_A_4 ||
		:NEW_DC_P02.STREET_4 ||
		:NEW_DC_P02.CITY_4 ||
		:NEW_DC_P02.STATE_4 ||
		:NEW_DC_P02.ZIP_4 ||
		:NEW_DC_P02.DESC_CODE ||
		:NEW_DC_P02.NM_ALIAS_LST ||
		:NEW_DC_P02.NM_ALIAS_FST ||
		:NEW_DC_P02.RES_TERR ||
		:NEW_DC_P02.USE_OF_B28_1 ||
		:NEW_DC_P02.USE_OF_B28_2 ||
		:NEW_DC_P02.USE_OF_B28_3 ||
		:NEW_DC_P02.USE_OF_B28_4 ||
		:NEW_DC_P02.ALTERNATE_2 ||
		:NEW_DC_P02.ALTERNATE_4 ||
		:NEW_DC_P02.FILLER_01
		)
		
		FROM DUAL;

END INSERT_P02_DATA_COLLECT;
/
