DROP MATERIALIZED VIEW BILLING.MBSI_GLOBAL_ENTITY
/

CREATE MATERIALIZED VIEW BILLING.MBSI_GLOBAL_ENTITY 
    (POLICY_NUMBER,PROCESS_DATE,POLICY_EFFECTIVE_DATE,STATE_ALPHA_CODE,GROUP_LINE_CODE,
     AGENCY_NUMBER,AGENCY_MASTER_NUMBER,PAY_OPTION_CODE,ROUTING_NUMBER,BANK_ACCOUNT_NUMBER,
     WITHDRAW_DAY,BILL_TO_CODE,BANK_NAME,FULL_NAME,FIRST_NAME,
     LAST_NAME,STREET_CLEANSED,NAME_ADDRESS,STREET,CITY,
     ZIP,COUNTRY_CODE,SOURCE_SYSTEM_CODE,CANCEL_TYPE,ORIGINAL_EFFECTIVE_DATE,
     EFT_ACCT_TYPE,EMAIL,ITEM_SEQ,INVOICING_CURRENCY,ADDRESS_TYPE,
     PRIMARY_ADDRESS,BILL_TYPE_CODE,ENTITY_TYPE,COUNTY)
TABLESPACE STAGING_DATA001
PCTUSED    0
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
NOCACHE
NOLOGGING
NOCOMPRESS
BUILD IMMEDIATE
REFRESH FORCE ON DEMAND
WITH PRIMARY KEY
AS 
/* Formatted on 5/23/2019 2:50:22 PM (QP5 v5.326) */
SELECT DISTINCT
       RP.POLICY_NUMBER,
       BA.PROCESS_DATE,
       BA.POLICY_EFFECTIVE_DATE,
       BA.STATE_ALPHA_CODE,
       BA.GROUP_LINE_CODE,
       RP.AGENCY_NUMBER,
       AGY.AG_MASTER_NUM
           AGENCY_MASTER_NUMBER,
       RP.PAY_OPTION_CODE,
       RP.BANK_NUMBER
           ROUTING_NUMBER,
       RP.BANK_ACCOUNT_NUMBER,
       RP.WITHDRAW_DAY,
       DECODE (RP.BILL_TO_CODE, 'H', 'I', RP.BILL_TO_CODE)
           BILL_TO_CODE, -- Adjusted to set "H" (Account Holder) as "I" Insured
       UPPER (RP.BANK_NAME)
           BANK_NAME,
       DECODE (RP.BILL_TO_CODE,
               'P', NVL (AP.NAME, RN.NAME),
               'M', NVL (MT.NAME, RN.NAME),
               RN.NAME)
           FULL_NAME,
       DECODE (RP.BILL_TO_CODE,  'P', NULL,  'M', NULL,  RN.NAME_FIRST)
           FIRST_NAME, --DECODE to assign the correct NAME_FIRST based on bill_to (could be NI,AP or MT)
       DECODE (RP.BILL_TO_CODE,  'P', NULL,  'M', NULL,  RN.NAME_LAST)
           LAST_NAME, --DECODE to assign the correct NAME_LAST based on bill_to (could be NI or AP)
       CASE
           WHEN RP.BILL_TO_CODE = 'P'
           THEN
               NVL (AP.STREET, RN.STREET)
           WHEN RP.BILL_TO_CODE = 'M' AND MT.STREET IS NOT NULL
           THEN
               MT.STREET
           ELSE
               LTRIM (
                   DECODE (REGEXP_INSTR (RN.NAME_ADDR, '[[:digit:]]'),
                           0, RN.STREET,
                           RN.NAME_ADDR || ' ' || RN.STREET),
                   ' ')
       END
           STREET_CLEANSED,
       --original name_address
       /*     DECODE (RP.BILL_TO_CODE,
                    'P', NVL (AP.NAME_ADDR, RN.NAME_ADDR),
                    'M', NVL (MT.NAME_ADDR, RN.NAME_ADDR),
                    RN.NAME_ADDR) */
       -- new definition
       (CASE
            WHEN RP.BILL_TO_CODE IN ('I', 'H')
            THEN
                LTRIM (
                    DECODE (REGEXP_INSTR (RN.NAME_ADDR, '[[:digit:]]'),
                            0, RN.STREET,
                            NVL (RN.NAME_ADDR, RN.STREET)),
                    ' ')
            WHEN RP.BILL_TO_CODE = 'P'
            THEN
                LTRIM (
                    DECODE (REGEXP_INSTR (AP.NAME_ADDR, '[[:digit:]]'),
                            0, RN.STREET,
                            NVL (RN.NAME_ADDR, RN.STREET)),
                    ' ')
            WHEN RP.BILL_TO_CODE = 'M'
            THEN
                LTRIM (
                    DECODE (REGEXP_INSTR (MT.NAME_ADDR, '[[:digit:]]'),
                            0, RN.STREET,
                            NVL (RN.NAME_ADDR, RN.STREET)),
                    ' ')
            WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') --Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted 4/12/2018
                 AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
            THEN
                RN.STREET
            ELSE
                RN.NAME_ADDR
        END)
           NAME_ADDRESS, --DECODE to assign the correct NAME_ADDR based on bill_to (could be NI,AP or MT)
       (CASE
            WHEN RP.BILL_TO_CODE IN ('I',
                                     'H',
                                     'M',
                                     'P')
            THEN
                NULL
            WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') --Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted
                 AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
            THEN
                NULL
            ELSE
                RN.STREET
        END)
           STREET, --DECODE to assign the correct STREET based on bill_to (could be NI,AP or MT)
       DECODE (RP.BILL_TO_CODE,
               'P', NVL (AP.CITY, RN.CITY),
               'M', NVL (MT.CITY, RN.CITY),
               RN.CITY)
           CITY, --DECODE to assign the correct CITY based on bill_to (could be NI,AP or MT)
       SUBSTR (
           (DECODE (RP.BILL_TO_CODE,
                    'P', NVL (AP.ZIP1, RN.ZIP1),
                    'M', NVL (MT.ZIP1, RN.ZIP1),
                    RN.ZIP1)),
           0,
           5)
           ZIP, --DECODE to assign the correct ZIP1 based on bill_to (could be NI,AP or MT)
       CTY.COUNTRY_CODE
           COUNTRY_CODE,
       CASE
           WHEN RP.GROUP_LINE_CODE = '95'
           THEN
               'MAJ'
           WHEN RP.GROUP_LINE_CODE = '22'
           THEN
               'NPS'
           WHEN     RP.GROUP_LINE_CODE IN ('24', '46', '75')
                AND RP.STATE_ALPHA_CODE = 'NH'
           THEN
               'NPS'
           ELSE
               'APAK'
       END
           SOURCE_SYSTEM_CODE,
       DECODE (NVL (RP.CANCEL_TYPE, 'P'),
               'I', 'P',
               NVL (RP.CANCEL_TYPE, 'P'))
           CANCEL_TYPE, -- Changed to assign P for Pro Rata Cancellation Type "I'3/1/2018
       RP.ORIGINAL_EFFECTIVE_DATE,
       RP.EFT_ACCT_TYPE,
       RN.INS_EMAIL
           EMAIL,
       RN.ITEM_SEQ,
       'USD'
           INVOICING_CURRENCY,
       'MAILING'
           ADDRESS_TYPE,
       'Y'
           PRIMARY_ADDRESS,
       BA.BILL_TYPE_CODE,
       'ACCOUNT'
           ENTITY_TYPE,
       '01'
           COUNTY
  FROM BILLING.V_DAILY_BILLING_ACTIVITY  BA,
       RPTVIEWER.RPT_POLICY              RP,
       (SELECT RN.POLICY_NUMBER,
               NAME_SEQ,
               NVL (ITEM_SEQ, NAME_SEQ)     ITEM_SEQ,
               RN.NAME_TYPE,
               RN.NAME,
               RN.NAME_ADDR,
               RN.NAME_FIRST,
               RN.NAME_LAST,
               RN.STREET,
               RN.CITY,
               RN.ZIP1,
               RN.ST_ABBR,
               INS_EMAIL
          FROM RPTVIEWER.RPT_NAME RN
         WHERE REGEXP_LIKE (NAME_TYPE, '[A-Za-z]') -- Only the alpha numeric name types
                                                  ) RN, --Changed 12/19/2017 to include the item_seq on name records.
       RPTVIEWER.V_AGENCY                AGY,
       (  SELECT ALPHA_CODE, MAX (COUNTRY_CODE) COUNTRY_CODE -- Max Group By used to retrieve US for those state abbreviations that may be in other countries
            FROM (SELECT ALPHA_CODE, COUNTRY_CODE
                    FROM APDEV.STATE
                   WHERE COUNTRY_CODE IS NOT NULL)
        GROUP BY ALPHA_CODE) CTY,    -- Used to get the country of the address
       (SELECT DISTINCT
               RP.POLICY_NUMBER,
               RN.NAME,
               RN.NAME_ADDR,
               RN.STREET,
               RN.CITY,
               RN.ST_ABBR,
               CASE
                   WHEN RN.ZIP2 IS NOT NULL THEN RN.ZIP1 || '-' || RN.ZIP2
                   ELSE RN.ZIP1
               END
                   ZIP1,
               RN.LOAN_NUM
          FROM RPTVIEWER.RPT_POLICY RP, RPTVIEWER.RPT_NAME RN
         WHERE     RP.POLICY_NUMBER = RN.POLICY_NUMBER
               AND RN.NAME_TYPE = 'AP'
               AND RN.NAME IS NOT NULL --- Added on 5/22/2019  to handle more than 1 AP
               AND RP.BILL_TO_CODE = 'P') AP,   -- Alternamte Payor info (PFC)
       (SELECT DISTINCT
               RP.POLICY_NUMBER,                    -- MT Info added 3/21/2018
               RN.NAME,
               RN.NAME_ADDR,
               RN.STREET,
               RN.CITY,
               RN.ST_ABBR,
               CASE
                   WHEN RN.ZIP2 IS NOT NULL THEN RN.ZIP1 || ' - ' || RN.ZIP2
                   ELSE RN.ZIP1
               END
                   ZIP1,
               RN.LOAN_NUM
          FROM RPTVIEWER.RPT_POLICY RP, RPTVIEWER.RPT_NAME RN
         WHERE     RP.POLICY_NUMBER = RN.POLICY_NUMBER
               AND RN.NAME_TYPE = 'MT'
               AND RP.BILL_TO_CODE = 'M'
               AND RN.NAME_SEQ =
                   (SELECT MIN (RN1.NAME_SEQ)
                      FROM RPTVIEWER.RPT_NAME RN1
                     WHERE     RN1.POLICY_NUMBER = RN.POLICY_NUMBER
                           AND RN1.NAME_TYPE = 'MT')
               AND NVL (RN.ITEM_SEQ, 0) =
                   (SELECT MIN (NVL (RN1.ITEM_SEQ, 0))
                      FROM RPTVIEWER.RPT_NAME RN1
                     WHERE     RN1.POLICY_NUMBER = RN.POLICY_NUMBER
                           AND RN1.NAME_TYPE = 'MT')) MT -- Mortgagee Info (MT)
 WHERE     BA.POLICY_NUMBER = RP.POLICY_NUMBER
       AND RP.POLICY_NUMBER = RN.POLICY_NUMBER
       AND RN.NAME_TYPE = 'NI'
       AND RP.AGENCY_NUMBER = AGY.AG_NUMBER
       AND CTY.ALPHA_CODE = RN.ST_ABBR
       AND BA.POLICY_NUMBER = AP.POLICY_NUMBER(+)
       AND BA.POLICY_NUMBER = MT.POLICY_NUMBER(+)
/


COMMENT ON MATERIALIZED VIEW BILLING.MBSI_GLOBAL_ENTITY IS 'snapshot table for snapshot BILLING.MBSI_GLOBAL_ENTITY'
/

CREATE UNIQUE INDEX BILLING.MBSI_GBL_ENT_PK ON BILLING.MBSI_GLOBAL_ENTITY
(POLICY_NUMBER, PROCESS_DATE, POLICY_EFFECTIVE_DATE)
LOGGING
TABLESPACE STAGING_DATA001
PCTFREE    10
INITRANS   2
MAXTRANS   255
STORAGE    (
            INITIAL          64K
            NEXT             1M
            MINEXTENTS       1
            MAXEXTENTS       UNLIMITED
            PCTINCREASE      0
            BUFFER_POOL      DEFAULT
           )
/
