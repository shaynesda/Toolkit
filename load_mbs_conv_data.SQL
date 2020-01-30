CREATE OR REPLACE PROCEDURE BILLING.LOAD_MBS_CONV_DATA IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       LOAD_MBS_CONV_DATA
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        9/28/2018    SHAYNES      1. Created this procedure.
  
   NOTES:     9/28/2018                 Loads all required data objects 

******************************************************************************/
insert_count      NUMBER;
v_procname        VARCHAR2(30)                      := 'LOAD_MBS_CONV_DATA';
v_run_date        DATE;
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);

BEGIN

/*
v_err_loc:='Truncate Billing Interface Model..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);


-- Remove data from BILLING INTERFACE OBJECTS

execute immediate 'truncate table BILLING.BILLING_GLOBAL_ENTITY_ADDRESS';

execute immediate 'truncate table BILLING.BILLING_GLOBAL_ENTITY_ADDR_AUD';

execute immediate 'truncate table BILLING.BILLING_INSTRUMENT_DETAIL';

execute immediate 'truncate table BILLING.BILLING_INSTRUMENT_DETAIL_AUD';

execute immediate 'truncate table BILLING.BILLING_GLOBAL_POLICY_RELTN'; 

execute immediate 'truncate table BILLING.BILLING_GLOBAL_POLICY_RELT_AUD';

execute immediate 'truncate table BILLING.BILLING_GLOBAL_ENTITY_AUD';

--execute immediate 'truncate table BILLING.BILLING_GLOBAL_ENTITY';
delete from BILLING.BILLING_GLOBAL_ENTITY; 

commit;

execute immediate 'ALTER TABLE BILLING.BILLING_LOCAL_ENTITY DISABLE CONSTRAINT BILLING_LOCAL_ENTITY_R01';

execute immediate 'ALTER TABLE BILLING.BILLING_GLOBAL_POLICY_RELTN DISABLE CONSTRAINT BILLING_GLOBAL_POLICY_RELTN_FK';

execute immediate 'ALTER TABLE BILLING.BILLING_GLOBAL_POLICY_RELTN DISABLE CONSTRAINT GLOBAL_ENTITY_POL_RELTN_FK';

execute immediate 'truncate table BILLING.BILLING_LOCAL_ENTITY'; 

execute immediate 'truncate table BILLING.BILLING_LOCAL_ENTITY_AUD';

execute immediate 'truncate table BILLING.BILLING_POLICY_AUD';

execute immediate 'truncate table BILLING.BILLING_POLICY';

delete from BILLING.BILLING_GLOBAL_ENTITY; 

commit;
*/
v_err_loc:='Loading GLOBAL_ENTITY..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- Load GLOBAL_ENTITY
insert into BILLING.BILLING_GLOBAL_ENTITY  
select distinct ge.billing_account_no, entity_type global_entity_type,  NULL, NULL, NULL, NULL, NULL, NULL, rp.BILL_TO_CODE, rp.BILL_TYPE_CODE, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
      'USD' invoicing_currency, NULL, NULL, NULL, NULL, agency_master_number parent_entity_code, decode(payment_method, 'CHECK', 'CH', 'EFT', 'E') payment_method, NULL, NULL, NULL, 'CONV' SOURCE_SYSTEM, NULL, NULL, NULL, NULL, NULL, NULL, NULL, SYSDATE CREATED_DATE, SYSDATE UPDATED_DATE, 'SYSTEM'
  from ND_DC.vw_global_entity@billing ge,
       ND_DC.vw_policy_billing_accounts@billing ba,
       RPTVIEWER.RPT_POLICY  RP, 
       APDEV.AGENCY ag
where ba.billing_account_no = ge.billing_account_no
   and ba.policy_number = rp.policy_number
   and rp.agency_number = ag.agency_number; 

commit;

v_err_loc:='Loading GLOBAL ENTITY ADDRESS..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- Load GLOBAL ENTITY ADDRESS   
insert into BILLING.BILLING_GLOBAL_ENTITY_ADDRESS
select GLOBAL_ENTITY_ADDR_SEQ.nextval, ge.billing_account_no, ge.address_type, ge.address1, ge.address2, NULL, NULL, NULL, ge.city, ge.country, null, ge.first_name, ge.full_name, ge.last_name, null, null, null, ge.primary_address_yn, NULL, NULL, PRIMARY_PHONE_NO, ge.state, substr(ge.zip_code, 1, 5) zip_code, sysdate, sysdate, 'SYSTEM' 
  from 
(select distinct ge.*
 from ND_DC.vw_global_entity@billing ge,
      ND_DC.vw_policy_billing_accounts@billing ba,
      BILLING.BILLING_GLOBAL_ENTITY bge
where ba.billing_account_no = ge.billing_account_no 
  and BGE.SOURCE_SYSTEM_ENTITY_CODE = ge.billing_account_no ) ge;
   
commit;


v_err_loc:='Loading BILLING INSTRUMENT DETAIL..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- Load BILLING INSTRUMENT DETAIL
insert into BILLING.BILLING_INSTRUMENT_DETAIL
select INSTR_DETAIL_SEQ.nextval, ge.billing_account_no, ge.policy_number, null, null, ge.address1, ge.address2, ge.city, null, ge.state, substr(ge.zip_code, 1, 5) zip_code, ge.country, null, RP.BANK_NAME, ge.full_name, rp.bank_account_number, rp.bank_number, NULL, NULL, 'CURRENT', 'MONEY_MARKET', 'EFT', RP.WITHDRAW_DAY, ge.PRIMARY_PHONE_NO, null, null, sysdate, sysdate, 'SYSTEM'
  from (select distinct ge.*, ba.policy_number
          from ND_DC.vw_global_entity@billing ge,
               ND_DC.vw_policy_billing_accounts@billing ba,
               BILLING.BILLING_GLOBAL_ENTITY bge
         where ba.billing_account_no = ge.billing_account_no
           and BGE.SOURCE_SYSTEM_ENTITY_CODE = ge.billing_account_no
           and ba.pay_option_code = 'E') ge, rptviewer.rpt_policy  rp
  where ge.policy_number = rp.policy_number;
  
commit;  
 

v_err_loc:='Loading BILLING POLICY..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- Load BILLING POLICY  
 insert into BILLING.BILLING_POLICY
  select distinct le.policy_number, le.policy_effective_date, le.policy_expiration_date, le.billing_account_no, null, le.broker_code, null, null, null, audit_flag, null, null, le.bill_to_code, le.bill_type, null, null, null, null, commission_paid_basis, 'USA',
        crt_code, null, null, null, null, null, le.line_of_business, null, null, le.noncancellable_flag, null, null, oper_region, decode(payment_plan, 'E', 'E', 'CH'), payment_plan, null, null, null, null, product_code, null, null, null, null,     
        null, null, null, null, null, null, 'CONV', null, null, null, null, null, null, le.policy_state, null, null, null, null, null, null, sysdate, sysdate, 'SYSTEM'
  from ND_DC.vw_policy_local_entity@billing le; 
 
commit;

 
v_err_loc:='Loading BILLING GLOBAL POLICY RELTN..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- Load BILLING GLOBAL POLICY RELTN 
insert into BILLING.BILLING_GLOBAL_POLICY_RELTN
  select GLOBAL_POLICY_RELTN_SEQ.nextval, pb.BILLING_ACCOUNT_NO, pb.POLICY_NUMBER, pb.POLICY_EFFECTIVE_DATE, sysdate, sysdate, 'SYSTEM'  
   from ND_DC.vw_policy_billing_accounts@billing pb,
               BILLING.BILLING_GLOBAL_ENTITY bge
  where pb.BILLING_ACCOUNT_NO = BGE.SOURCE_SYSTEM_ENTITY_CODE;
 
commit;

v_err_loc:='Loading BILLING LOCAL ENTITY..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;
 
-- Load BILLING LOCAL ENTITY 
insert into BILLING.BILLING_LOCAL_ENTITY  
select local_entity_seq.nextval, ge.policy_number, ge.policy_effective_date, ge.policy_expiration_date, ge.entity_type, 
       row_number() OVER (PARTITION BY ge.policy_number ORDER BY ge.policy_number) entity_seq, -- sequence logic that breaks on policy number
       '1', '1', 'Y', 'Y', null, ge.address_type, ge.address1, ge.address2, null, null, null, ge.city, ge.country, null, null, null, ge.first_name, ge.full_name, null, ge.last_name, null, ge.primary_address_yn, null, null, ge.PRIMARY_PHONE_NO, ge.state, substr(ge.zip_code, 1, 5) zip_code, null, null, sysdate, sysdate, 'SYSTEM' 
  from 
(select distinct ge.*, ba.policy_number, ba.policy_effective_date, bp.policy_expiration_date
          from ND_DC.vw_global_entity@billing ge,
               ND_DC.vw_policy_billing_accounts@billing ba,
               BILLING.BILLING_POLICY bp
         where ba.billing_account_no = ge.billing_account_no
           and ba.policy_number = ba.policy_number
           and ba.policy_effective_date = ba.policy_effective_date
           and bp.policy_number = ba.policy_number
           and bp.policy_effective_date = ba.policy_effective_date) ge;
 
commit;       


v_err_loc:='Loading BILLING LOCAL ENTITY WITH PAYROLL DEDUCT POLICIES..';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

-- insert Pay Roll Deduct policies into BILLING_LOCAL_ENTITY
insert into BILLING.BILLING_LOCAL_ENTITY  
select local_entity_seq.nextval, ge.policy_number, ge.policy_effective_date, ge.policy_expiration_date, ge.entity_type, 
       row_number() OVER (PARTITION BY ge.policy_number ORDER BY ge.policy_number) entity_seq, -- sequence logic that breaks on policy number
       '1', '1', 'Y', 'Y', null, ge.address_type, ge.address1, ge.address2, null, null, null, ge.city, ge.country, null, null, null, ge.first_name, ge.full_name, null, ge.last_name, null, ge.primary_address_yn, null, null, ge.PRIMARY_PHONE_NO, ge.state, substr(ge.zip_code, 1, 5) zip_code, null, null, sysdate, sysdate, 'SYSTEM' 
  from 
(select distinct ge.name_type address_type, ge.street address1, null address2, ge.city, 'US' country, ge.name_first first_name, ge.name_last last_name, ge.name full_name, 'Y' primary_address_yn, ge.phone primary_phone_no, ge.st_abbr state, ge.zip1 zip_code,  
                ba.policy_number, ba.policy_effective_date, bp.policy_expiration_date, 'ACCOUNT' entity_type
          from rptviewer.rpt_name ge,--ND_DC.vw_global_entity@billing ge,
               ND_DC.vw_policy_billing_accounts@billing ba,
               BILLING.BILLING_POLICY bp
         where ba.policy_number = ge.policy_number
           and ge.name_type = 'NI'
           and bp.policy_number in (select DISTINCT POLICY_NUMBER  -- Payroll Deduct policies missing post load
                                      from BILLING.BILLING_POLICY
                                   MINUS
                                     select DISTINCT POLICY_NUMBER  -- Payroll Deduct policies missing post load
                                       from BILLING.BILLING_GLOBAL_POLICY_RELTN)
           --and ba.policy_number = ba.policy_number
           --and ba.policy_effective_date = ba.policy_effective_date
           and bp.policy_number = ba.policy_number
           and bp.policy_effective_date = ba.policy_effective_date) ge;

commit;

v_err_loc:='ENABLE CONSTRAINTS...';
insert into billing.load_log (event_date, event_routine, event_message, event_posted_by) VALUES (SYSDATE, v_procname, v_err_loc, v_procname);

commit;

execute immediate 'ALTER TABLE BILLING.BILLING_LOCAL_ENTITY ENABLE CONSTRAINT BILLING_LOCAL_ENTITY_R01';

execute immediate 'ALTER TABLE BILLING.BILLING_GLOBAL_POLICY_RELTN ENABLE CONSTRAINT BILLING_GLOBAL_POLICY_RELTN_FK';

execute immediate 'ALTER TABLE BILLING.BILLING_GLOBAL_POLICY_RELTN ENABLE CONSTRAINT GLOBAL_ENTITY_POL_RELTN_FK';

exception
        when no_data_found  then
            null;
        when others then
            v_err_msg:='FAILED:'||sqlcode||':'||sqlerrm(sqlcode)||v_procname||' at'||v_err_loc;    

END;
/
