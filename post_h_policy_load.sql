CREATE OR REPLACE PROCEDURE RPTVIEWER."POST_H_POLICY_LOAD"    IS 
/******************************************************************************
   NAME:       POST_H_POLICY_LOAD

   REVISIONS:
   Ver        Date        Author           Description
   ---------  ----------  ---------------  ------------------------------------
   1.0        12/9/2006      DJO         1. Created this procedure.
   2.0        9/16/2013       CV          2. commented few statements

   OVERVIEW
   Sets the expiration dates for changed policies

******************************************************************************/

-- main body
BEGIN

 RPTVIEWER.RPT_UTIL.WRITE_LOG('POST_H_POLICY_LOAD', 'POINT1'); 

UPDATE h_policy h1 SET (pol_ver_exp, pol_ver_curr_fl)=
(SELECT max(pol_ver_eff)-1, null
   FROM h_policy h2
  WHERE pol_ver_curr_fl='Y'
    AND h1.policy_number=h2.policy_number
 --GROUP BY policy_number-- commented by chandu on 9/16/2013
 --HAVING count(*) > 1-- commented by chandu on 9/16/2013
 )
WHERE POLICY_V_ID IN
(SELECT min(POLICY_V_ID)
   FROM h_policy H3
  WHERE pol_ver_curr_fl='Y'
    --AND h1.policy_NUMBER=h3.policy_number -- commented by chandu on 9/16/2013
    GROUP BY policy_number
    HAVING count(*) > 1
    );

COMMIT;
 
 RPTVIEWER.RPT_UTIL.WRITE_LOG('POST_H_POLICY_LOAD', 'POINT2');

    EXCEPTION
        WHEN OTHERS THEN 
            NULL;  -- enter any exception code here
END; 
/
