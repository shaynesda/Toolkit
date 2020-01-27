CREATE OR REPLACE PROCEDURE APDEV.NTR_REQUEST_FILE_LOAD IS

/******************************************************************************
   NAME:       NTR_REQUEST_FILE_LOAD
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/26/2013          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     NTR_RESPONSE_FILE_LOAD
      Sysdate:         9/19/2013
      Date and Time:   9/19/2013, 3:49:33 PM, and 9/19/2013 3:49:33 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
REQ_CNT  NUMBER;
LOAD_CNT  NUMBER;

BEGIN


--  count of records in the source external table
SELECT COUNT(*) INTO REQ_CNT FROM STAGING.NTR_REQUEST_EXTERNAL;


-- load of records from the source external table
 INSERT INTO APDEV.NTR_REQUEST SELECT ntr.*, TRUNC(SYSDATE) FROM STAGING.NTR_REQUEST_EXTERNAL ntr;

 COMMIT;

-- count of records loaded during execution
 SELECT COUNT(*) INTO LOAD_CNT FROM APDEV.NTR_REQUEST WHERE MRB_FILE_POSTED_DATE = TRUNC(SYSDATE);


 IF  REQ_CNT=LOAD_CNT THEN
 RPTVIEWER.RPT_UTIL.SEND_MAIL('NTR REQUEST FILE LOAD SUCCESS:'||TO_CHAR(SYSDATE,'MM/DD/YYYY'),rptviewer.MAIL_PKG.ARRAY('cveerabomma@ndgroup.com; shaynes@ndgroup.com'),'FILE LOADED SUCESSFULLY. RECORD COUNT:'|| REQ_CNT);

 ELSE
 RPTVIEWER.RPT_UTIL.SEND_MAIL('NTR REQUEST FILE LOAD FAILED:'||TO_CHAR(SYSDATE,'MM/DD/YYYY'),rptviewer.MAIL_PKG.ARRAY('cveerabomma@ndgroup.com; shaynes@ndgroup.com'),'FILE LOADED FAILED. INQUIRE FILE RECORD COUNT:'||REQ_CNT||'. RESPONSE FILE RECORD COUNT:'||LOAD_CNT );

 END IF;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
     WHEN OTHERS THEN
       -- Consider logging the error and then re-raise
       RAISE;
END NTR_REQUEST_FILE_LOAD;
/
