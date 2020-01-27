CREATE OR REPLACE FUNCTION APDEV.GET_BILL_SCAN_LINE(policy_num_arg in NEW_APDEV.POLICY.POLICY_NUMBER%TYPE)
RETURN varchar2 is

v_pol_cd       number; -- POLICY CHECK DIGIT
v_amt_cd       number; -- AMOUNT DUE CHECK DIGIT
v_gr_amt_cd    number; -- GROSS AMOUNT DUE CHECK DIGIT
v_mx_due_dt_cd number; -- MAX DUE DATE CHECK DIGIT (DROP DEAD DATE)

v_pol_num       varchar2(10);
v_pol_num_pd    varchar2(10);
v_pol_fst_pos   varchar2(1);
v_pol_scnd_pos  varchar2(1);
v_pol_thrd_pos  varchar2(1);
v_pol_frth_pos  varchar2(1);
v_pol_lst_pos   varchar2(1);
v_amt_due       varchar2(10);
v_amt_due_pd    varchar2(10);
v_gr_amt_due    varchar2(10);
v_gr_amt_due_pd varchar2(10);
v_exp_dt        date;
v_due_dt        date;
v_due_chr       varchar2(10);
v_due_dt_pd     varchar2(10);
v_state_cd      varchar2(2);
v_sdip_pts      varchar2(2);
v_num_lapsed    number;
v_num_rems      varchar2(4);
v_grp_line      varchar2(2);
v_agency_num    varchar2(8);
v_pay_opt_cd    varchar2(1);
v_co_cd         varchar2(2);

v_bill_scan_ln  varchar2(50);
v_err_loc       varchar2(100);
v_pol_cnv_9th_pos number;

BEGIN



SELECT WR.POL_NUM, DECODE(WR.TOT_TO_BILL, WR.TIMES_BILLED, WR.AMOUNT_DUE, ABS((WR.ARREARS_SVC_CHG + WR.ARREARS_AMT))) AMOUNT_DUE, WR.AMOUNT_DUE GROSS_AMOUNT_DUE, WR.DUE_DATE,  WR.STATE_CD, RP.POLICY_EXPIRATION_DATE, -- ADDED REMOVAL OF SIGN BY ABS FUNCTION ON AMOUNT_DUE
       NVL(RP.MMV_BILL_STEP, '00'), RP.NUM_LAPSED, RP.NUM_REMINDERS, RP.GROUP_LINE_CODE, RP.AGENCY_NUMBER, RP.PAY_OPTION_CODE, RP.ISSUE_COMPANY_CODE
  INTO v_pol_num, v_amt_due, v_gr_amt_due, v_due_dt, v_state_cd, v_exp_dt, v_sdip_pts, v_num_lapsed, v_num_rems, v_grp_line, v_agency_num, v_pay_opt_cd, v_co_cd
  FROM APDEV.WANG_RECAP WR, RPTVIEWER.RPT_POLICY RP,
(SELECT MAX(PROCESS_DATE) PROCESS_DATE, POL_NUM
   FROM APDEV.WANG_RECAP
  WHERE POL_NUM = policy_num_arg
    AND (BILL_FORM1 = 'A10' OR
         BILL_FORM2 = 'A10')
    AND BILL_FORM1 IS NOT NULL
  GROUP BY POL_NUM) MX
  WHERE MX.PROCESS_DATE = WR.PROCESS_DATE
   AND MX.POL_NUM = WR.POL_NUM
   AND (WR.BILL_FORM1 = 'A10' OR
         WR.BILL_FORM2 = 'A10')               -- Added 11/7/2019 to prevent subquery multiple rows error on bill generalation.
   --AND WR.TRANS_SOURCE_SW <> 'M'
   AND (case when WR.TRANS_SOURCE_SW = 'M' and wr.mbs_flg = 'Y' then 1  -- Added 4/30/2019 to support Merge of MBS Bills on Manual Transactions
            when WR.TRANS_SOURCE_SW <> 'M' then 1
         else 0 end) = 1
   AND WR.POL_NUM = RP.POLICY_NUMBER;

/*************************************************************************
***********  POLICY  NUMBER  CHECK  DIGIT  ASSIGNMENT  *******************
**************************************************************************/

 -- Check first position of policy number for alpha and translate
 select ltn.nbr
   into v_pol_fst_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, 1, 1)) = ltn.letter;

 -- Check second position of policy number for alpha and translate
 select ltn.nbr
   into v_pol_scnd_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, 2, 1)) = ltn.letter;

 -- Check third position of policy number for alpha and translate
 select ltn.nbr
   into v_pol_thrd_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, 3, 1)) = ltn.letter;

  -- Check fourth position of policy number for alpha and translate
 select ltn.nbr
   into v_pol_frth_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, 4, 1)) = ltn.letter;

 -- Check last position of policy number for alpha and translate
  select ltn.nbr
   into v_pol_lst_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, length(trim(v_pol_num)), 1)) = ltn.letter;

/**** Added 8/2/2019 to support alpha numeric 9th position ****/
  -- Converted 9th position alpha numeric to numeric
  select ltn.nbr
   into v_pol_cnv_9th_pos
   from APDEV.BILL_SCAN_LTR_TO_NBR ltn
  where to_char(substr(v_pol_num, length(trim(v_pol_num)), 9)) = ltn.letter;
/**** Added 8/2/2019 to support alpha numeric 9th position ****/

  -- Concatenate first 4 positions, poistion 5 thru the second to last position and the last position;  all positions of the policy number should be converted to numeric
 v_pol_num_pd := lpad(v_pol_fst_pos||v_pol_scnd_pos||v_pol_thrd_pos||v_pol_frth_pos||substr(v_pol_num, 5, length(v_pol_num)-5)||v_pol_lst_pos,  10, 0);  -- PAD THE POLICY NUMBER WITH 0'S OUT 10 POISTIONS


/* SUM THE VALUE OF THE ODD VALUE IPOSITIONS OF THE PADDED POLICY NUMBER + THE SUM OF THE VALUE OF EVEN POSITIONS MULTIPLIED BY 2
   IF THE LAST POSITION IS AN ALPHA NUMBERIC USE THE BILL_SCAN_LTR_TO_NBR TO MAP LETTERS TO NUMBERS ASSIGN THE AGGREGATE TO v_pol_cd */

 select substr(v_pol_num_pd, 1, 1) + substr(v_pol_num_pd, 3, 1) + substr(v_pol_num_pd, 5, 1) + substr(v_pol_num_pd, 7, 1) +  decode(is_number(substr(v_pol_num_pd, 9, 1)), 1, substr(v_pol_num_pd, 9, 1), v_pol_cnv_9th_pos)  +  --Added 9/13/2019 to support alpha numeric 9th position 
       (substr(v_pol_num_pd, 2, 1)*2) + (substr(v_pol_num_pd, 4, 1)*2) + (substr(v_pol_num_pd, 6, 1)*2) + (substr(v_pol_num_pd, 8, 1)*2) + (substr(v_pol_num_pd, 10, 1)*2)
   into v_pol_cd
   from dual;

-- IF THE LAST POSITION OF THE CHECK DIGIT IS NOT 0 THEN SUBTRACT THE CHECK DIGIT FROM 10

  IF substr(v_pol_cd, length(v_pol_cd), 1) <> 0
     THEN v_pol_cd := (10 - substr(v_pol_cd, length(v_pol_cd), 1));
   ELSE
      v_pol_cd := substr(v_pol_cd, length(v_pol_cd), 1);
   END IF;

/*************************************************************************
***************  AMOUNT DUE  CHECK  DIGIT  ASSIGNMENT  *******************
**************************************************************************/

   select DECODE(INSTR(v_amt_due,'.'), 0, LPAD((LPAD(v_amt_due,7,'0') || '000'), 10, 0), LPAD(trunc(v_amt_due),7,'0') || RPAD(SUBSTR(v_amt_due,INSTR(v_amt_due,'.')+1,2),2,'0') ||'0')
     into v_amt_due_pd
     from dual;

/* SUM THE VALUE OF THE ODD VALUE IPOSITIONS OF THE PADDED POLICY NUMBER + THE SUM OF THE VALUE OF EVEN POSITIONS MULTIPLIED BY 2
   IF THE LAST POSITION IS AN ALPHA NUMBERIC USE THE BILL_SCAN_LTR_TO_NBR TO MAP LETTERS TO NUMBERS ASSIGN THE AGGREGATE TO v_amt_cd */

 select substr(v_amt_due_pd, 1, 1) + substr(v_amt_due_pd, 3, 1) + substr(v_amt_due_pd, 5, 1) + substr(v_amt_due_pd, 7, 1) + substr(v_amt_due_pd, 9, 1)+ 
       (substr(v_amt_due_pd, 2, 1)*2) + (substr(v_amt_due_pd, 4, 1)*2) + (substr(v_amt_due_pd, 6, 1)*2) + (substr(v_amt_due_pd, 8, 1)*2)
   into v_amt_cd
   from dual;


-- IF THE LAST POSITION OF THE CHECK DIGIT IS NOT 0 THEN SUBTRACT THE CHECK DIGIT FROM 10
  IF substr(v_amt_cd, length(v_amt_cd), 1) <> 0
    THEN v_amt_cd := (10 - substr(v_amt_cd, length(v_amt_cd), 1));
   ELSE
      v_amt_cd := substr(v_amt_cd, length(v_amt_cd), 1);
  END IF;

  v_amt_due_pd := substr(v_amt_due_pd, 1, 9);

/*************************************************************************
************  GROSS AMOUNT DUE  CHECK  DIGIT  ASSIGNMENT  ****************
**************************************************************************/

   select DECODE(INSTR(v_gr_amt_due,'.'), 0, LPAD((LPAD(v_gr_amt_due,7,'0') || '000'), 10, 0), LPAD(trunc(v_gr_amt_due),7,'0') || RPAD(SUBSTR(v_gr_amt_due,INSTR(v_gr_amt_due,'.')+1,2),2,'0') ||'0')
     into v_gr_amt_due_pd
     from dual;

/* SUM THE VALUE OF THE ODD VALUE IPOSITIONS OF THE PADDED POLICY NUMBER + THE SUM OF THE VALUE OF EVEN POSITIONS MULTIPLIED BY 2
   IF THE LAST POSITION IS AN ALPHA NUMBERIC USE THE BILL_SCAN_LTR_TO_NBR TO MAP LETTERS TO NUMBERS ASSIGN THE AGGREGATE TO v_gr_amt_due_pd*/

 select substr(v_gr_amt_due_pd, 1, 1) + substr(v_gr_amt_due_pd, 3, 1) + substr(v_gr_amt_due_pd, 5, 1) + substr(v_gr_amt_due_pd, 7, 1) + substr(v_gr_amt_due_pd, 9, 1)+  
       (substr(v_gr_amt_due_pd, 2, 1)*2) + (substr(v_gr_amt_due_pd, 4, 1)*2) + (substr(v_gr_amt_due_pd, 6, 1)*2) + (substr(v_gr_amt_due_pd, 8, 1)*2)
   into v_gr_amt_cd
   from dual;

-- IF THE LAST POSITION OF THE CHECK DIGIT IS NOT 0 THEN SUBTRACT THE CHECK DIGIT FROM 10
  IF substr(v_gr_amt_cd, length(v_gr_amt_cd), 1) <> 0
    THEN v_gr_amt_cd := (10 - substr(v_gr_amt_cd, length(v_gr_amt_cd), 1));
   ELSE
      v_gr_amt_cd := substr(v_gr_amt_cd, length(v_gr_amt_cd), 1);
  END IF;

  v_gr_amt_due_pd :=  substr(v_gr_amt_due_pd, 1, 9);

/*************************************************************************
*************** MAX DUE DATE  CHECK  DIGIT  ASSIGNMENT  ******************
**************************************************************************/

  -- v_due_dt, v_state_cd, v_sdip_pts, v_num_lapsed, v_num_rems, v_grp_line, v_agency_num, v_pay_opt_cd,

    -- ASSIGN ADDITIONAL DAYS ON TO THE DUE DATE TO GET THE MAX DUE DATE CONDITIONS FOR WHICH WE ADD ADDITIONAL DAYS FOR THE MAX DUE DATE (DROP DEAD DATE )

 -- All states except RI
    IF v_state_cd <> 'RI'  and v_num_rems = 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'), 'MMDD')
      THEN v_due_chr := to_char(v_due_dt+33, 'YYYYMMDD');
     ELSE IF v_state_cd <> 'RI' and v_num_rems > 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'),'MMDD')
      THEN v_due_chr := to_char(v_due_dt+23, 'YYYYMMDD');
     END IF;
    END IF;

    IF v_state_cd <> 'RI' and v_num_rems = 0 and (to_char(v_due_dt,'MMDD') > to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') <= to_char(to_date('1231','MMDD'), 'MMDD') or
                                                  to_char(v_due_dt,'MMDD') >= to_char(to_date('0101','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') < to_char(to_date('0106','MMDD'), 'MMDD'))
      THEN v_due_chr := to_char(v_due_dt+35, 'YYYYMMDD');
     ELSE IF v_state_cd <> 'RI' and v_num_rems > 0 and (to_char(v_due_dt,'MMDD') > to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') <= to_char(to_date('1231','MMDD'), 'MMDD') or
                                                 to_char(v_due_dt,'MMDD') >= to_char(to_date('0101','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') < to_char(to_date('0106','MMDD'), 'MMDD'))
      THEN v_due_chr := to_char(v_due_dt+25, 'YYYYMMDD');
     END IF;
    END IF;

     -- RI
    IF v_state_cd = 'RI' and v_grp_line in ('01','05') and v_pay_opt_cd = 'T' and v_num_rems = 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'),'MMDD')
      THEN v_due_chr := to_char(v_due_dt+23, 'YYYYMMDD');
     ELSE IF v_state_cd = 'RI' and v_grp_line in ('01','05') and v_pay_opt_cd = 'T' and v_num_rems > 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'),'MMDD')
      THEN v_due_chr := to_char(v_due_dt+13, 'YYYYMMDD');
     END IF;
    END IF;

    IF v_state_cd = 'RI' and v_grp_line in ('01','03','05') and v_pay_opt_cd <> 'T' and v_num_rems = 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'),'MMDD')
      THEN v_due_chr := to_char(v_due_dt+25, 'YYYYMMDD');
     ELSE IF v_state_cd = 'RI' and v_grp_line in ('01','03','05') and v_pay_opt_cd <> 'T' and v_num_rems > 0 and to_char(v_due_dt,'MMDD') <= to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') >= to_char(to_date('0106','MMDD'),'MMDD')
      THEN v_due_chr := to_char(v_due_dt+15, 'YYYYMMDD');
     END IF;
    END IF;

    IF v_state_cd = 'RI' and v_grp_line in ('01','05') and v_pay_opt_cd = 'T' and v_num_rems = 0 and (to_char(v_due_dt,'MMDD') > to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') <= to_char(to_date('1231','MMDD'), 'MMDD') or
                                                                                                      to_char(v_due_dt,'MMDD') >= to_char(to_date('0101','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') < to_char(to_date('0106','MMDD'), 'MMDD'))
      THEN v_due_chr := to_char(v_due_dt+25, 'YYYYMMDD');
     ELSE IF v_state_cd = 'RI' and v_grp_line in ('01','05') and v_pay_opt_cd = 'T' and v_num_rems > 0 and (to_char(v_due_dt,'MMDD') > to_char(to_date('1214','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') <= to_char(to_date('1231','MMDD'), 'MMDD') or
                                                                                                            to_char(v_due_dt,'MMDD') >= to_char(to_date('0101','MMDD'),'MMDD') and to_char(v_due_dt,'MMDD') < to_char(to_date('0106','MMDD'), 'MMDD'))
      THEN v_due_chr := to_char(v_due_dt+15, 'YYYYMMDD');
     END IF;
    END IF;


  -- Add 5 days

   IF v_agency_num in ('20985','20986','20987') or v_sdip_pts not in ('00','98', '99') or v_num_lapsed > 0
         THEN v_due_dt := to_date(v_due_chr, 'YYYYMMDD');
    ELSE v_due_dt := to_date(v_due_chr, 'YYYYMMDD')+5;
   END IF;

  -- If the drop dead due date is greater than the expiration date of the policy then make the drop dead date the expiration date.

   IF v_due_dt > v_exp_dt
      THEN v_due_dt := v_exp_dt;
    ELSE v_due_dt := v_due_dt;
   END IF;

   v_due_chr := to_char(v_due_dt, 'YYYYMMDD');

/* SUM THE VALUE OF THE ODD VALUE IPOSITIONS OF THE PADDED POLICY NUMBER + THE SUM OF THE VALUE OF EVEN POSITIONS MULTIPLIED BY 2
   IF THE LAST POSITION IS AN ALPHA NUMBERIC USE THE BILL_SCAN_LTR_TO_NBR TO MAP LETTERS TO NUMBERS ASSIGN THE AGGREGATE TO MX DUE DATE (10 POSITIONS)*/

    select substr(v_co_cd||v_due_chr, 1, 1) + substr(v_co_cd||v_due_chr, 3, 1) + substr(v_co_cd||v_due_chr, 5, 1) + substr(v_co_cd||v_due_chr, 7, 1) + substr(v_co_cd||v_due_chr, 9, 1) +
       (substr(v_co_cd||v_due_chr, 2, 1)*2) + (substr(v_co_cd||v_due_chr, 4, 1)*2) + (substr(v_co_cd||v_due_chr, 6, 1)*2) + (substr(v_co_cd||v_due_chr, 8, 1)*2) + (substr(v_co_cd||v_due_chr, 10, 1)*2)
     into v_mx_due_dt_cd
     from dual;

  -- TAKE THE LAST DIGIT OF THE ABOVE AGGREGATE FOR THE MAX DUE DATE CHECK DIGIT
     v_mx_due_dt_cd := substr(v_mx_due_dt_cd, length(v_mx_due_dt_cd), 1);


  -- IF THE LAST POSITION OF THE CHECK DIGIT IS NOT 0 THEN SUBTRACT THE CHECK DIGIT FROM 10
     IF v_mx_due_dt_cd <> 0
        THEN v_mx_due_dt_cd := (10 - v_mx_due_dt_cd);
      ELSE
       v_mx_due_dt_cd := v_mx_due_dt_cd;
     END IF;


  v_bill_scan_ln := v_pol_num||' '||v_pol_cd||' '||v_amt_due_pd||v_amt_cd||' '||v_gr_amt_due_pd||v_gr_amt_cd||' '||v_co_cd||' '||v_due_chr||' '||v_mx_due_dt_cd;


RETURN  v_bill_scan_ln;

--***************************************************
EXCEPTION
   WHEN others THEN
      RAISE_APPLICATION_ERROR(-20000,'GET_BILL_SCAN_LINE: Policy Number '||v_pol_num||' '||v_due_chr||' '||v_err_loc ||SQLERRM);


END GET_BILL_SCAN_LINE;
/
