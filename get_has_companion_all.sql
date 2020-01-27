CREATE OR REPLACE FUNCTION APDEV.GET_HAS_COMPANION_ALL(
  policy_arg IN apdev.policy.policy_number%TYPE)
  RETURN VARCHAR2
IS

/******************************************************************************
   NAME:       GET_HAS_COMPANION_ALL                                                      
   PURPOSE:    Function will return Y/N indicating the presence of a companion 
                  policy for the provided group lines for the policy passed in. 

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        2/7/2008    DJO             1. Created this function.
   1.1        4/23/2008   DJO          2. Changed schema to NEW_APDEV and 
                                          incorporated pending statuses.
   1.3        12/18/2008  CHANDU        3. MOVED NEW FUNCTION TO PROD AND CHANGED EXCEPTIONAL HANDLING 
                                           TO CONTROL THE FUNCTION RETURNING NULL VALUES.   
   2.0        12/16/2009  SHAYNES        4. Added check for valid account for Homeowners                                                                         
   3.0         7/20/2010    DJO          5. Added logic to include DF check.  This function should
                                            be modified to accommodate account logic for all lob's.
   4.0        7/26/10       DJO          6. Rewrite of the function to a table-based approoach to address
                                            all lob account credits.  Includes state-cd logic. 
   NOTES:
    Need to verify only for active policies or non-canceled? 

*******************************************************************************/
--
v_err_loc       varchar2(100);   
v_acct_count    NUMBER;
V_GROUP_LINE    VARCHAR2(2);
V_state    VARCHAR2(2);
--
--
BEGIN

v_err_loc := 'Checking for policy: ' || policy_arg || '; ';

select distinct p.group_line_code,state_alpha_code 
into v_group_line,v_state
from ( select group_line_code,state_alpha_code from new_apdev.policy p
       where p.policy_number = policy_arg
       union
       select group_line_code,state_alpha_code from apdev.policy p
       where p.policy_number=policy_arg
       union 
       select group_line_code,state_alpha_code from rptviewer.rpt_policy p
       where p.policy_number=policy_arg) p;


SELECT count(p.policy_number)
INTO v_acct_count
FROM new_apdev.policy_accounts pa,
     new_apdev.policy p,
     new_apdev.policy_accounts_lob pal 
WHERE pa.policy_number=p.policy_number
AND p.POLICY_STATUS_CODE in ('A','E','F') 
AND pa.ACCOUNT_TYPE='M'
and P.GROUP_LINE_CODE=PAL.ELIGIBLE_GROUP_LINE_CODE
AND PAL.GROUP_LINE_CODE=v_group_line
and (PAL.STATE_CD = v_state or pal.state_cd='XX')
AND pa.account_number=
(SELECT account_number FROM new_apdev.policy_accounts pa2 WHERE pa2.policy_number=policy_arg);

-- if no eligible companions found above, check apdev for candidates from the latest mappa policy data 
IF v_acct_count < 1 THEN
    SELECT count(p.policy_number)
    INTO v_acct_count
    FROM new_apdev.policy_accounts pa,
         apdev.policy p,
         new_apdev.policy_accounts_lob pal 
    WHERE pa.policy_number=p.policy_number
    AND p.POLICY_STATUS_CODE in ('A','E','F') 
    AND pa.ACCOUNT_TYPE='M'
    and P.GROUP_LINE_CODE=PAL.ELIGIBLE_GROUP_LINE_CODE
    AND PAL.GROUP_LINE_CODE=v_group_line
    and (PAL.STATE_CD = v_state or pal.state_cd='XX')
    AND pa.account_number=
    (SELECT account_number FROM new_apdev.policy_accounts pa2 WHERE pa2.policy_number=policy_arg);
END IF; 



IF v_acct_count = 0 THEN
    RETURN 'N';
ELSE
    RETURN 'Y';
END IF;

--
EXCEPTION
   WHEN NO_DATA_FOUND THEN
    RETURN 'N';
   WHEN others THEN
   -- RETURN 'N';
     RAISE_APPLICATION_ERROR(-20000,'GET_HAS_COMPANION_ALL: '||v_err_loc ||SQLERRM);

END GET_HAS_COMPANION_ALL; 
/
