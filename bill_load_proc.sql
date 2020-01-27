CREATE OR REPLACE PROCEDURE APDEV.BILL_LOAD_PROC IS
tmpVar NUMBER;
/******************************************************************************
   NAME:       BILL_LOAD_PROC
   PURPOSE:

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        4/11/2012    SHAYNES      1. Created this procedure.

   NOTES:     4/11/2012                 Loads table AGENTPAK_INVOICE daily from view VW_AGENTPAK_INVOICE.
                                        AGENTPAK_INVOICE represents the bill data for  E-Bills and PDF Bills
                                        generated daily.  This table is appended to daily.
              6/15/2012  SHAYNES       2. Change added rebill insert.
              4/11/2013  SHAYNES       Updated the DELAY BILL logic to look at the NEW_APDEV.UNDERWRITING_INFO table for correct Delay bill application.
                                        Correctly delay bills if one agent has more than one book transfer program.
             12/10/2013  SHAYNES       Updated case statement for delayed bill run dates avoiding weekends.
             3/14/2016   SHAYNES       Updated Delayed Bill logic to exclusively look at the 2016 Arbella Monoline Book Roll.

   Automatically available Auto Replace Keywords:
      Object Name:     BILL_LOAD_PRCO
      Sysdate:         4/11/2012
      Date and Time:   4/11/2012, 9:39:09 AM, and 4/11/2012 9:39:09 AM
      Username:         (set in TOAD Options, Procedure Editor)
      Table Name:       (set in the "New PL/SQL Object" dialog)

******************************************************************************/
insert_count      NUMBER;
v_procname        VARCHAR2(30)                      := 'BILL_LOAD_PROC';
v_err_loc         VARCHAR2(100);
v_err_number      NUMBER;
v_err_msg         VARCHAR2(1500);
BEGIN
v_err_loc:='At insert statement';

 INSERT INTO APDEV.AGENTPAK_INVOICE
(PROCESS_DATE,
DUE_DATE,
AMOUNT_DUE,
ISSUE_COMPANY_CODE,
POLICYHOLDER,
POLICY_NUMBER,
EFF_DATE,
EXP_DATE,
POLICY_TYPE,
ANNUAL_PREM,
BILL_DATE,
BALANCE,
AGENCY_NUMBER,
BILL_TYPE_CODE,
BILL_TO_CODE,
BILL_TO_NAME,
BILL_TO_NAMEADD,
BILL_TO_STREET,
BILL_TO_CITY,
BILL_TO_STATE,
BILL_TO_ZIP,
LOAN_NUMBER,
ARREARS_SVC_CHG,
PAY_OPTION,
GROUP_LINE,
STATE,
RUN_DATE,
USER_ENTERED,
DATE_ENTERED,
ORIG_RUN_DATE)
SELECT
AI.PROCESS_DATE,
AI.DUE_DATE,
AI.AMOUNT_DUE,
AI.ISSUE_COMPANY_CODE,
AI.POLICYHOLDER,
AI.POLICY_NUMBER,
AI.EFF_DATE,
AI.EXP_DATE,
AI.POLICY_TYPE,
AI.ANNUAL_PREM,
DECODE(DB.DELAY_BILL, 'Y', DB.BILL_DATE, AI.RUN_DATE) BILL_DATE,  -- UPDATED BILL DATE FOR DELAYED BILLS SPECIAL BOOK ROLL 2016
AI.BALANCE,
AI.AGENCY_NUMBER,
AI.BILL_TYPE_CODE,
AI.BILL_TO_CODE,
AI.BILL_TO_NAME,
AI.BILL_TO_NAMEADD,
AI.BILL_TOSTREET,
AI.BILL_TOCITY,
AI.BILL_TOSTATE,
AI.BILL_TO_ZIP,
AI.LOAN_NUMBER,
AI.ARREARS_SVC_CHG,
AI.PAY_OPTION,
AI.GROUP_LINE,
AI.STATE_CD,
DECODE(DB.DELAY_BILL, 'Y', DB.BILL_DATE, AI.RUN_DATE), -- UPDATED BILL DATE FOR DELAYED BILLS SPECIAL BOOK ROLL 2016
'BILL_LOAD_PRC' USER_ENTERED,
TRUNC(SYSDATE)  DATE_ENTERED,
AI.RUN_DATE ORIG_RUN_DATE
FROM APDEV.VW_AGENTPAK_INVOICE AI,
(SELECT AI.POLICY_NUMBER, AI.AGENCY_NUMBER, 'Y' DELAY_BILL,
       (CASE WHEN WR.EFF_DATE-TRUNC(SYSDATE) > 40 THEN WR.EFF_DATE-40
           ELSE AI.RUN_DATE END) BILL_DATE                 -- UPDATED BILL DATE FOR DELAYED BILLS SPECIAL BOOK ROLL 2016
   FROM APDEV.VW_AGENTPAK_INVOICE AI, NEW_APDEV.AGENT_BOOK_TRANSFER ABT,
        APDEV.WANG_RECAP WR, NEW_APDEV.POLICY POL
  WHERE AI.POLICY_NUMBER = POL.POLICY_NUMBER
    AND AI.GROUP_LINE = '24'
    AND AI.AGENCY_NUMBER =  ABT.AGENCY_NUMBER
    AND WR.EFF_DATE BETWEEN ABT.EFFECTIVE_DATE AND ABT.EXPIRATION_DATE
    AND AI.POLICY_NUMBER = WR.POL_NUM
    AND AI.RUN_DATE = WR.RUN_DATE
    AND WR.TRANS_TYPE = '4'
    AND ABT.DELAY_BILLS = 'Y'
    AND ABT.BOOK_ROLL_ID = POL.BOOK_ROLL_ID
    AND ABT.BOOK_ROLL_ID = 'BK0001') DB
WHERE DB.POLICY_NUMBER(+) = AI.POLICY_NUMBER
  AND DB.AGENCY_NUMBER(+) = AI.AGENCY_NUMBER;


-- RE BILL BILLING RECORD INSERT
INSERT INTO APDEV.AGENTPAK_INVOICE
(select rb.PROCESS_DATE, rb.DUE_DATE,
   case
     when pp.pay_plan not in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL then ltrim(to_char(pp.TOTAL_DUE,'9,999,999.99'),' ')
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL then ltrim(to_char(pp.TOTAL_DUE,'9,999,999.99'),' ')
     when pp.pay_plan not in ('L','E') and rb.TIMES_BILLED != rb.TOT_TO_BILL then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED != rb.TOT_TO_BILL then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM = pp.TOTAL_DUE
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM = pp.TOTAL_DUE
      then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE and to_char(rb.PROCESS_DATE, 'DD') < pp.EFT_PAY_DAY
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE and to_char(rb.PROCESS_DATE, 'DD') < pp.EFT_PAY_DAY
      then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE
      then ltrim(to_char(pp.TOTAL_DUE,'9,999,999.99'),' ')
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED != rb.TOT_TO_BILL then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
    -- when pp.pay_plan = 'E' and rb.TIMES_BILLED != rb.TOT_TO_BILL then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
   end amount_due,
ai.ISSUE_COMPANY_CODE, ai.POLICYHOLDER, ai.POLICY_NUMBER, ai.EFF_DATE, ai.EXP_DATE, ai.POLICY_TYPE, ai.ANNUAL_PREM, ai.BILL_DATE,
   case
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM = pp.TOTAL_DUE
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM = pp.TOTAL_DUE
      then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     when pp.pay_plan in ('L','E') and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE and to_char(rb.PROCESS_DATE, 'DD') < pp.EFT_PAY_DAY
     --when pp.pay_plan = 'E' and rb.TIMES_BILLED = rb.TOT_TO_BILL and pp.LAST_PAY_AMOUNT + pp.LAST_BILL_MINIMUM <> pp.TOTAL_DUE and to_char(rb.PROCESS_DATE, 'DD') < pp.EFT_PAY_DAY
         then ltrim(to_char(pp.LAST_BILL_MINIMUM,'9,999,999.99'),' ')
     else
       ltrim(to_char(pp.TOTAL_DUE,'9,999,999.99'),' ')
   end balance,
ai.AGENCY_NUMBER,
rp.bill_type_code ,
   rp.bill_to_code,
    case when rp.bill_to_code in ('A','I','H') then rp.name
         when rp.bill_to_code = 'P'  then nvl(ap.name, rp.name)
         when rp.bill_to_code = 'M' then nvl(mt.name, rp.name)
           else null end bill_to_name ,
     case when rp.bill_to_code in ('A','I','H') then rp.name_addr
            when rp.bill_to_code = 'P' then nvl(ap.name_addr, rp.name_addr)
           when rp.bill_to_code = 'M' then nvl(mt.name_addr, rp.name_addr)
           else null end bill_to_nameadd,
     case when rp.bill_to_code in ('A','I','H') then rp.street
            when rp.bill_to_code = 'P' then nvl(ap.street, rp.street)
           when rp.bill_to_code = 'M' then nvl(mt.street, rp.street)
           else null end bill_tostreet,
     case when rp.bill_to_code in ('A','I','H') then rp.city
            when rp.bill_to_code = 'P' then nvl(ap.city, rp.city)
           when rp.bill_to_code = 'M' then nvl(mt.city, rp.city)
           else null end bill_tocity,
     case when rp.bill_to_code in ('A','I','H') then rp.st_abbr
            when rp.bill_to_code = 'P' then nvl(ap.st_abbr, rp.st_abbr)
           when rp.bill_to_code = 'M' then nvl(mt.st_abbr, rp.st_abbr)
        else null end bill_tostate,
     case when rp.bill_to_code in ('A','I','H') and rn.zip2 is not null then rn.zip1 ||' - '|| rn.zip2
           when rp.bill_to_code in ('A','I','H') and rn.zip2 is null then rn.zip1
            when rp.bill_to_code = 'P' then nvl(ap.zip1, rn.zip1)
           when rp.bill_to_code = 'M' then nvl(mt.zip1, rn.zip1)
        else null end bill_to_zip,
     case  when rp.bill_to_code = 'M' then mt.loan_num
            when rp.bill_to_code = 'P' then ap.loan_num
         else null end loan_number,
ai.ARREARS_SVC_CHG, ai.PAY_OPTION, ai.GROUP_LINE, ai.STATE, rb.RUN_DATE, 'BILL_LOAD_PRC_REBILL' USER_ENTERED, TRUNC(SYSDATE), rb.RUN_DATE
from agentpak_invoice ai, rptviewer.rpt_policy rp, rptviewer.rpt_name rn, apdev.paid_policy pp,  (select policy_number, max(run_date) run_date from agentpak_invoice ai group by policy_number) mx,
(select wr.POL_NUM, wr.PROCESS_DATE, wr.DUE_DATE, wr.AMOUNT_DUE, wr.TIMES_BILLED, wr.TOT_TO_BILL, wr.RUN_DATE
  from apdev.wang_recap wr, (select max(run_date) run_date from rptviewer.rpt_policy) mx
 where wr.RUN_DATE = mx.run_date
   and wr.BILL_FORM1 = 'RB') rb,
(select distinct rp.policy_number,  rn.name, rn.name_addr, rn.street, rn.
          city, rn.st_abbr,
          case when rn.zip2 is not null
          then rn.zip1 ||' - '|| rn.zip2
          else rn.zip1
          end zip1, rn.loan_num
        from rptviewer.rpt_policy rp, rptviewer.rpt_name rn
        where rp.policy_number = RN.POLICY_NUMBER
        and rn.name_type = 'MT'
        and rp.bill_to_code = 'M'
        and rn.name_seq = (select min(rn1.name_seq) from rptviewer.rpt_name rn1
          where rn1.policy_number = rn.policy_number
          and rn1.name_type = 'MT')) MT,
        (select distinct rp.policy_number, rn.name, rn.name_addr, rn.street, rn.
          city, rn.st_abbr,
          case when rn.zip2 is not null
          then rn.zip1 ||'-'|| rn.zip2
          else rn.zip1
          end zip1, rn.loan_num
            from rptviewer.rpt_policy rp, rptviewer.rpt_name rn
            where rp.policy_number = RN.POLICY_NUMBER
            and rn.name_type = 'AP'
            and rp.bill_to_code = 'P') AP
where rb.pol_num = ai.POLICY_NUMBER
  and rb.pol_num = mx.policy_number
  and mx.run_date = ai.RUN_DATE
  and rb.pol_num = pp.policy_number
  and rb.pol_num = rp.policy_number
  and rp.policy_number = rn.policy_number
  and rn.name_type = 'NI'
  and rb.pol_num = mt.policy_number (+)
  and rb.pol_num = ap.policy_number (+));



insert_count:=SQL%ROWCOUNT;

COMMIT;

  --APDEV.APDEV_UTIL.SEND_MAIL(v_procname, apdev.mail_pkg.array( 'Ora_LoadAlerts@NDGROUP.COM'),' INSERTED '||insert_count||' ROWS INTO AGENTPAK_INVOICE TABLE');


   EXCEPTION
     WHEN OTHERS THEN
     v_err_msg:=v_err_loc||' '||SQLERRM(SQLCODE);
     apdev.apdev_util.write_error(v_procname,v_err_msg);
       -- Consider logging the error and then re-raise
       RAISE;
END BILL_LOAD_PROC;
/
