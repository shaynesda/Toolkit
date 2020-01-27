CREATE OR REPLACE PROCEDURE STAGING.HIST_LOG_LOAD
IS
     
polcount NUMBER := 0;
namcount NUMBER := 0;
itmcount NUMBER := 0;
surcount NUMBER := 0;
covcount NUMBER := 0;

BEGIN
 SELECT COUNT(*) INTO polcount FROM STG_WF_WANG_POLICY;
 SELECT COUNT(*) INTO namcount FROM STG_WF_WANG_NAME;
 SELECT COUNT(*) INTO itmcount FROM STG_WF_WANG_ITEM;
 SELECT COUNT(*) INTO surcount FROM STG_WF_WANG_MREC_VIOL;
 SELECT COUNT(*) INTO covcount FROM STG_WF_WANG_COVERAGE_RECORD;
 INSERT INTO history_LOG
 VALUES (sysdate, polcount, namcount, itmcount, surcount, covcount);
END; 
/
