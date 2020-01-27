CREATE OR REPLACE PROCEDURE RPTVIEWER.post_name_load IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       post_name_load
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        01/05/2010    chandu      1. Created this procedure.
   2.0        01/21/2010    chandu      2. added school and adv_dr_tr for update

   NOTES:

   Automatically available Auto Replace Keywords:
      Object Name:     post_name_load
      Sysdate:         12/30/2009
      Date and Time:   12/30/2009, 12:03:59 PM, and 12/30/2009 12:03:59 PM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
V_ERR_MSG   VARCHAR2(200) := '';
V_PROCNAME  VARCHAR2(20) := 'POST_name_LOAD';
V_err_loc   varchar2(40);
v_mssg  varchar2(5000):=null;
BEGIN
   tmpVar := 0;
   v_err_loc:='updating opr_sdip_status';

   update rpt_name pp set OPR_SDIP_STATUS =(
select distinct  I_N.SDIP_STEP
        from
       new_apdev.item_at_risk iar,
       new_apdev.item_name i_n,
       new_apdev.name n,
       new_apdev.policy p
       --,rpt_name pp
where IAR.ITEM_AT_RISK_ID=I_N.ITEM_AT_RISK_ID
and i_n.name_id=n.name_id and IAR.WANG_ITEM_SEQ = 0
and p.policy_number =iar.policy_number
and pp.policy_number=iar.policy_number
and pp.name_seq=I_N.WANG_NAME_SEQ
and i_n.item_name_type_code in ('DR','EX')
and p.group_line_code in ('01'))
where
 PP.NAME_TYPE in ('DR','EX')
 and PP.POLICY_NUMBER in(select policy_number
                           from rpt_policy
                           where group_line_code='01'
                             and state_alpha_code='NJ'
                             and run_date=(select max(run_date) from rpt_policy));

commit;


v_err_loc:='updating occupation details';

update rpt_name nn set (OCCUPATION,OCCUPATION_CODE_short,OCCUPATION_CODE_LONG)  =(
select distinct  OGC.DESCRIPTION occupation,
        OGC.DISPLAY_SEQUENCE occupation_code_SHORT,
        OGC.CODE OCCUPATION_CODE_LONG
               from
       new_apdev.item_at_risk iar,
       new_apdev.item_name i_n,
       new_apdev.name n,
       new_apdev.occupation_group_category ogc,
       new_apdev.policy p
       --,rpt_name nn
where iar.item_at_risk_id=i_n.item_at_risk_id
and ogc.code=n.occupation_group_category
and i_n.name_id=n.name_id
and p.policy_number =iar.policy_number
and nn.policy_number=iar.policy_number and nn.name_seq=I_n.wang_name_seq
and i_n.item_name_type_code in ('DR','EX') AND IAR.WANG_ITEM_SEQ <> 0)
   where
 nn.NAME_TYPE in ('DR','EX')
 and
 nn.POLICY_NUMBER in(select policy_number
                           from rpt_policy
                           where group_line_code='01'
                             and state_alpha_code='NJ'
                             and run_date=(select max(run_date) from rpt_policy));


                             commit;

  -- added on 01/21/2010 chandu

   v_err_loc:='updating sCHOOL details';

UPDATE RPT_NAME N
SET sCHOOL =
nvl((select distinct AWAy_AT_SCHOOL
       FROM
      (SELECT distinct iar.policy_number, I_N.WANG_NAME_SEQ, I_N.ITEM_NAME_TYPE_CODE name_type,I_N.NAME_ID, --N.SCH_15_DAYS_OP, N.SCHOOL, N.SCHOOL_DISTANCE
         case  WHEN school = 'Y' and sch_15_days_op <> 'Y' and school_distance > 100 then 'Y' ELSE 'N' END  AWAY_AT_SCHOOL
         from new_apdev.item_at_Risk iar,--, new_apdev.iar_auto iara,
              new_apdev.item_name i_n,
new_apdev.name n, rpt_policy p
where iar.iteM_at_risk_id = I_N.ITEM_AT_RISK_ID
and N.NAME_ID=I_N.NAME_ID
and IAR.USER_LINE_CODE = '01'
and IAR.ITEM_STATE = 'NJ'
and I_N.ITEM_NAME_TYPE_CODE in ('DR','EX')
and iar.policy_number=p.policy_number
and I_n.wang_item_seq <> 0)p
 where n.policy_number=p.policy_number and n.name_seq = p.wang_name_seq and n.name_type=p.name_type),n.school)
 where
 n.NAME_TYPE in ('DR','EX')
 and n.POLICY_NUMBER in(select policy_number
                           from rpt_policy
                           where group_line_code='01'
                             and state_alpha_code='NJ'
                             and run_date=(select max(run_date) from rpt_policy))
                             ;


                             commit;

-- added on 01/21/2010 chandu
v_err_loc:='updating DV_DR_TRAINING details';


UPDATE RPT_NAME N
SET N.ADV_DR_TRAINING=
nvl((select distinct ADV_DR_TRAINING FROM
(SELECT distinct iar.policy_number, I_N.WANG_NAME_SEQ, I_N.ITEM_NAME_TYPE_CODE name_type,I_N.NAME_ID, N.ADVANCED_TRAINING ADV_DR_TRAINING
from new_apdev.item_at_Risk iar,-- new_apdev.iar_auto iara,
new_apdev.item_name i_n,
new_apdev.name n, rpt_policy p
where iar.iteM_at_risk_id = I_N.ITEM_AT_RISK_ID
and N.NAME_ID=I_N.NAME_ID
and IAR.USER_LINE_CODE = '01'
and IAR.ITEM_STATE = 'NJ'
and I_N.ITEM_NAME_TYPE_CODE in ('DR','EX')
and iar.policy_number=p.policy_number
and I_n.wang_item_seq <> 0)/*
and iara.iteM_at_risk_id = iar.item_at_risk_id
and iara.assigned_driver = n.name_id)*/
p where n.policy_number=p.policy_number and n.name_seq = p.wang_name_seq and n.name_type=p.name_type),n.ADV_DR_TRAINING)
where
 n.NAME_TYPE in ('DR','EX')
 and n.POLICY_NUMBER in(select policy_number
                           from rpt_policy
                           where group_line_code='01'
                             and state_alpha_code='NJ'
                             and run_date=(select max(run_date) from rpt_policy))
                             ;


                             commit;

-- added on 05/09/2014 chandu
v_err_loc:='UPDATING FEIN FOR WORKPAK AI RECORDS ';

   UPDATE RPTVIEWER.RPT_NAME N
SET N.FEIN=(select NN.SOCIAL_SECURITY
from new_apdev.item_at_risk IAR,NEW_APDEV.ITEM_NAME I_N,NEW_APDEV.NAME NN
where IAR.policy_number=N.POLICY_NUMBER
AND I_N.WANG_NAME_SEQ=LTRIM(N.NAME_SEQ,'0')
AND IAR.ITEM_AT_RISK_ID=I_N.ITEM_AT_RISK_ID
AND I_N.ITEM_NAME_TYPE_CODE='AI'
AND I_N.NAME_ID=NN.NAME_ID)
WHERE POLICY_NUMBER IN(SELECT POLICY_NUMBER FROM RPTVIEWER.RPT_POLICY
WHERE GROUP_LINE_CODE='42'
--AND POLICY_STATUS_CODE='A'
AND RUN_DATE=(SELECT MAX(RUN_DATE) FROM RPTVIEWER.RPT_POLICY)
)
AND NAME_TYPE='AI';

COMMIT;

---- Send email if an employee added to payroll deduction list for the first time. Added7/13/18
v_err_loc:='New employees to payroll';

begin
for i in(select * from rptviewer.v_prd_new_file)
loop
v_mssg:=rpad(i.prd_emp_id,15,' ')||lpad(' ',15,' ')||i.name||chr(13)||v_mssg;
end loop;
--v_mssg:=rpad('0001',10,' ')||lpad(' ',15,' ')||'test'||chr(13)||v_mssg;
if length(v_mssg)>0 then
v_mssg:='Below File Numbers are newly added to payroll deduction list'||chr(13)||rpad('File No.',15,' ')||lpad(' ',15,' ')||'Employee Name'||chr(13)||v_mssg;
RPT_UTIL.SEND_MAIL('Payroll Deduct:First Time Employee list',MAIL_PKG.ARRAY('cveerabomma@ndgroup.com','hpettersen@ndgroup.com','hr@ndgroup.com'),v_mssg);
end if;
end;



   EXCEPTION
     WHEN NO_DATA_FOUND THEN
       NULL;
    when others then
            v_err_msg:='FAILED at:'||v_err_loc||':'||sqlcode||':'||sqlerrm(sqlcode)||v_procname;
            rptviewer.rpt_util.write_error(v_procname,v_err_msg);
       -- Consider logging the error and then re-raise
       RAISE;
END post_name_load;
/
