DROP MATERIALIZED VIEW BILLING.MBSI_LOCAL_ENTITY
/

CREATE MATERIALIZED VIEW BILLING.MBSI_LOCAL_ENTITY 
    (POLICY_NUMBER,PROCESS_DATE,POLICY_EFFECTIVE_DATE,NAME_SEQ,NAME_TYPE,
     ADDRESS_1,ADDRESS_2,CITY,COUNTRY_CODE,FULL_NAME,
     FIRST_NAME,LAST_NAME,STATE_ALPHA_CODE,ZIP,BILL_TO_CODE,
     LOAN_NUM,ITEM_SEQ)
TABLESPACE BILLING_DATA
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
  SELECT BA.POLICY_NUMBER,
         BA.PROCESS_DATE,
         BA.POLICY_EFFECTIVE_DATE,
         RN.NAME_SEQ,
         RN.NAME_TYPE,
         /*  (CASE      -- LOGIC A/O 10/17/2018
               WHEN RN.NAME_TYPE = 'NI'
               THEN
                  LTRIM (
                     DECODE (REGEXP_INSTR (RN.NAME_ADDR, '[[:digit:]]'),
                             0, RN.STREET,
                             RN.NAME_ADDR || ' ' || RN.STREET),
                     ' ')
               WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when the Street needs to be shifted
                    AND RN.NAME_ADDR IS NULL
               THEN
                  RN.STREET
               WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted 4/12/2018
                    AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
               THEN
                  RN.STREET
               ELSE
                  RN.NAME_ADDR
            END)*/
         (CASE
              WHEN RN.NAME_TYPE = 'NI'
              THEN
                  LTRIM (
                      DECODE (REGEXP_INSTR (RN.NAME_ADDR, '[[:digit:]]'),
                              0, RN.STREET,
                              NVL (RN.NAME_ADDR, RN.STREET)), --RN.NAME_ADDR || ' ' || RN.STREET),
                      ' ')
              WHEN RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when the Street needs to be shifted
                                                      AND RN.NAME_ADDR IS NULL
              THEN
                  RN.STREET
              WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted 4/12/2018
                   AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
              THEN
                  RN.STREET
              ELSE
                  RN.NAME_ADDR
          END)
             ADDRESS_1,                            -- Cleansed address routine
         /* (CASE   -- LOGIC A/O 10/17/2018
              WHEN RN.NAME_TYPE = 'NI'
              THEN
                 NULL
              WHEN RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when the Street needs to be shifted
                                                     AND RN.STREET IS NULL
              THEN
                 NULL
              WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted
                   AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
              THEN
                 NULL
              ELSE
                 RN.STREET
           END) */
         (CASE
              WHEN RN.NAME_TYPE = 'NI'
              THEN
                  LTRIM (
                      DECODE (
                          REGEXP_INSTR (NVL (RN.NAME_ADDR, 'A'), '[[:digit:]]'),
                          0, NULL,
                          DECODE (RN.STREET, RN.NAME_ADDR, NULL, RN.STREET)),
                      ' ') -- Additional condition to null out Address_2 if sourc NAME_ADDR & STREET have the same values 11/1/2018
              WHEN RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when the Street needs to be shifted
                                                      AND RN.NAME_ADDR IS NULL
              THEN
                  NULL
              WHEN     RN.NAME_TYPE IN ('AP', 'MT', 'AI') -- Adjusment for MT's and AP's when Name_Addr has ISAOA notation and Address1 needs to be shifted
                   AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
              THEN
                  NULL
              ELSE
                  NULL
          END)
             ADDRESS_2,
         RN.CITY,
         CTY.COUNTRY_CODE,
         /* (CASE  -- LOGIC A/O 10/17/2018
              WHEN INSTR (RN.NAME_ADDR, 'ISAOA') > 0
              THEN
                 RN.NAME || ', ' || RN.NAME_ADDR
              ELSE
                 RN.NAME
           END)*/
         -- LOGIC A/O 10/17/2018
         (CASE
              WHEN RN.NAME_TYPE = 'NI' AND RN.NAME_ADDR IS NOT NULL
              THEN
                  LTRIM (
                      DECODE (REGEXP_INSTR (RN.NAME_ADDR, '[[:digit:]]'),
                              0, RN.NAME || ' ' || RN.NAME_ADDR,
                              RN.NAME),
                      ' ')
              WHEN RN.NAME_TYPE = 'MT' AND INSTR (RN.NAME_ADDR, 'ISAOA') > 0
              THEN
                  RN.NAME || ', ' || RN.NAME_ADDR
              ELSE
                  RN.NAME
          END)
             NAME,
         RN.NAME_FIRST,
         RN.NAME_LAST,
         RN.ST_ABBR,
         RN.ZIP1,
         BA.BILL_TO_CODE,
         RN.LOAN_NUM,
         RN.ITEM_SEQ
    FROM BILLING.MBSI_GLOBAL_ENTITY BA,
         (SELECT RN.POLICY_NUMBER,
                 RN.NAME_SEQ,
                 NS.ITEM_SEQ,
                 RN.NAME_TYPE,
                 RN.NAME_ADDR,
                 RN.STREET,
                 RN.CITY,
                 RN.NAME,
                 RN.NAME_FIRST,
                 RN.NAME_LAST,
                 RN.ST_ABBR,
                 RN.ZIP1,
                 RN.LOAN_NUM
            FROM RPTVIEWER.RPT_NAME RN,
                 (  SELECT RN.POLICY_NUMBER,
                           MIN (NAME_SEQ)              NAME_SEQ,
                           MIN (NVL (ITEM_SEQ, 0))     ITEM_SEQ,
                           NAME_TYPE
                      FROM RPTVIEWER.RPT_NAME            RN,
                           BILLING.V_DAILY_BILLING_ACTIVITY BA
                     WHERE     RN.POLICY_NUMBER = BA.POLICY_NUMBER
                           AND RN.NAME_TYPE IN ('AP', 'MT', 'NI')
                  GROUP BY RN.POLICY_NUMBER, NAME_TYPE) NS
           WHERE     RN.POLICY_NUMBER = NS.POLICY_NUMBER
                 AND RN.NAME_TYPE = NS.NAME_TYPE
                 AND RN.NAME_SEQ = NS.NAME_SEQ
                 AND NVL (RN.ITEM_SEQ, 0) = NS.ITEM_SEQ) RN, -- RPT_NAME subquery insuring that the min sequence is retrieved by name_type
         (SELECT ALPHA_CODE, COUNTRY_CODE
            FROM APDEV.STATE
           WHERE COUNTRY_CODE IS NOT NULL /* UNION
                                           SELECT ALPHA_CODE, COUNTRY_CODE
                                             FROM NEW_APDEV.STATE
                                            WHERE COUNTRY_CODE IS NOT NULL*/
                                         ) CTY -- Used to get the country of the address
   WHERE     BA.POLICY_NUMBER = RN.POLICY_NUMBER
         AND (CASE
                  WHEN BA.BILL_TO_CODE = 'M' AND RN.NAME_TYPE = 'MT' THEN '1'
                  WHEN RN.NAME_TYPE IN ('NI', 'AP') THEN '1'
                  ELSE '0'
              END) =
             '1'
         AND RN.ST_ABBR = CTY.ALPHA_CODE
GROUP BY BA.POLICY_NUMBER,
         BA.PROCESS_DATE,
         BA.POLICY_EFFECTIVE_DATE,
         RN.NAME_SEQ,
         RN.NAME_TYPE,
         RN.NAME_ADDR,
         RN.STREET,
         RN.CITY,
         CTY.COUNTRY_CODE,
         RN.NAME,
         RN.NAME_FIRST,
         RN.NAME_LAST,
         RN.ST_ABBR,
         RN.ZIP1,
         BA.BILL_TO_CODE,
         RN.LOAN_NUM,
         RN.ITEM_SEQ
/


COMMENT ON MATERIALIZED VIEW BILLING.MBSI_LOCAL_ENTITY IS 'snapshot table for snapshot BILLING.MBSI_LOCAL_ENTITY'
/

CREATE UNIQUE INDEX BILLING.MBSI_LOCAL_ENTITY_PK ON BILLING.MBSI_LOCAL_ENTITY
(POLICY_NUMBER, PROCESS_DATE, POLICY_EFFECTIVE_DATE, NAME_SEQ, NAME_TYPE)
LOGGING
TABLESPACE BILLING_INDX001
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
