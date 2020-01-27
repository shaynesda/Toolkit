CREATE OR REPLACE PACKAGE BILLING.GET_NEW_BILLING_ACCT_PKG
AS
    TYPE bill_acct_num_ref_cur_ty IS REF CURSOR;

    PROCEDURE read_new_billing_acct_number (
        bill_acct_num_arg   OUT BILLING.BILLING_GLOBAL_ENTITY.SOURCE_SYSTEM_ENTITY_CODE%TYPE,
        source_sys_arg IN     VARCHAR2);
        
END GET_NEW_BILLING_ACCT_PKG;
/


CREATE OR REPLACE PACKAGE BODY BILLING.GET_NEW_BILLING_ACCT_PKG
AS

/*
  Reads in the source system and assigns the next Billing Account number
  Source Systems:
  A - AgentPak 
  C - Conversion
  M - Majesco PAS      
*/

PROCEDURE read_new_billing_acct_number(
   bill_acct_num_arg  OUT  BILLING.BILLING_GLOBAL_ENTITY.SOURCE_SYSTEM_ENTITY_CODE%TYPE, 
   source_sys_arg    IN    VARCHAR2)

IS 

bill_acct_num varchar2(10);
v_src_sys varchar2(1) := upper(substr(source_sys_arg, 1, 1));  -- extracts the first position of the source system passed in and assigns that as the first byte of the billing acct number - shaynes


BEGIN


SELECT v_src_sys || lpad(bill_acct_seq.nextval,9,0)
INTO bill_acct_num
FROM DUAL;

bill_acct_num_arg := bill_acct_num;

END read_new_billing_acct_number;

END GET_NEW_BILLING_ACCT_PKG;
/
