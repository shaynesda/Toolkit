CREATE OR REPLACE PROCEDURE APDEV.NPS_EFT_CONF_LOAD IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       NPS_eft_change_load
   PURPOSE:    

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/11/2012          1. Created this procedure.

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     NPS_eft_change_load
      Sysdate:         4/11/2012
      Date and Time:   4/11/2012, 9:39:09 AM, and 4/11/2012 9:39:09 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
insert_count      NUMBER;
v_procname        VARCHAR2(30)                      := 'NPS_EFT_CONF_LOAD';
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
BEGIN
v_err_loc:='At insert statement';

 INSERT INTO APDEV.NPS_EFT_CHANGE(RUN_DATE,
BANK_NUMBER,
BANK_ACCT,
ITEM_NUM,
POLICY_NUMBER,
PRIOR_BALANCE,
CHANGE_BALANCE,
REMAINING_BALANCE,
WD_REVISED,
WD_AMT,
NUM_REMAINING,
WD_NUM,
DUE_DAY,
SC_STAR,
BANK_NAME,
EFT_DAY,
COR_EFF,
COR_EXP,
POL_TYPE,
ITEM_LINE1,
ITEM_LINE2,
ITEM_LINE3,
ITEM_LINE4,
ITEM_LINE5,
ITEM_LINE6,
ITEM_LINE7,
ITEM_LINE8,
ITEM_LINE9,
DATE_ENTERED,
SOURCE)
select S.RUN_DATE,S.BANK_NUMBER,S.BANK_ACCT,S.ITEM_NUM,trim(S.POLICY_NUMBER) POLICY_NUMBER
,to_number(replace(ltrim(trim(S.PRIOR_BALANCE),'$'),',','')) PRIOR_BALANCE
,to_number(replace(ltrim(trim(S.CHANGE_BALANCE ),'$'),',','')) CHANGE_BALANCE
,to_number(replace(ltrim(trim(S.REMAINING_BALANCE ),'$'),',','')) REMAINING_BALANCE
,to_number(replace(ltrim(trim(S.WD_AMT ),'$'),',','')) WD_AMT
,to_number(replace(ltrim(trim(S.WD_AMT ),'$'),',','')) WD_AMT
,to_number(replace(ltrim(trim(S.WD_NUM ),'$'),',','')) WD_NUM
,to_number(replace(ltrim(trim(S.WD_NUM ),'$'),',','')) WD_NUM
,S.DUE_DAY DUE_DAY
,S.SC_STAR SC_STAR
,S.BANK_NAME BANK_NAME
,TRIM(S.EFT_DAY) EFT_DAY
,S.COR_EFF COR_EFF
,S.COR_EXP COR_EXP
,S.POL_TYPE POL_TYPE
,S.ITEM_LINE1 ITEM_LINE1
,S.ITEM_LINE2 ITEM_LINE2
,S.ITEM_LINE3 ITEM_LINE3
,S.ITEM_LINE4 ITEM_LINE4
,S.ITEM_LINE5 ITEM_LINE5
,S.ITEM_LINE6 ITEM_LINE6
,S.ITEM_LINE7 ITEM_LINE7
,S.ITEM_LINE8 ITEM_LINE8
,S.ITEM_LINE9 ITEM_LINE9
,SYSDATE DATE_ENTERED ,
'CONFIRM'
from STAGING.STG_NPS_EFT_CONF s;

insert_count:=SQL%ROWCOUNT;

COMMIT;

RPTVIEWER.RPT_UTIL.SEND_MAIL(v_procname,RPTVIEWER.mail_pkg.array( 'Ora_LoadAlerts@NDGROUP.COM'),' INSERTED '||insert_count||' ROWS INTO APDEV.NPS_EFT_CHANGE TABLE INTO ORACLE1');


   EXCEPTION
     WHEN OTHERS THEN
     v_err_msg:=v_err_loc||' '||SQLERRM(SQLCODE);
     rptviewer.rpt_util.write_error(v_procname,v_err_msg);
       -- Consider logging the error and then re-raise
       RAISE;
END NPS_eft_CONF_load; 
/
