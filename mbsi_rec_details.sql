DROP MATERIALIZED VIEW BILLING.MBSI_REC_DETAILS
/

CREATE MATERIALIZED VIEW BILLING.MBSI_REC_DETAILS 
    (POLICY_NUMBER,PROCESS_DATE,POLICY_EFFECTIVE_DATE,RECEIVABLE_CODE,COMMISSION_PERCENT,
     COMMISSION_AMOUNT,RECEIVABLE_AMOUNT)
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
/* Formatted on 5/23/2019 2:50:24 PM (QP5 v5.326) */
SELECT policy_number,
       process_date,
       policy_effective_date,
       receivable_code,
       commission_prct,
       commission_amt,
       receivable_amt
  FROM (SELECT policy_number,
               process_date,
               policy_effective_date,
               receivable_code,
               commission_prct,
               commission_amt,
               receivable_amt
          FROM BILLING.V_MBSI_PREM_RECEIVABLE
        --WHERE COMMISSION_AMT <> 0 AND RECEIVABLE_AMT <> 0
        UNION
        SELECT policy_number,
               process_date,
               policy_effective_date,
               receivable_code,
               0     commission_prct,
               0     commission_amount,
               receivable_amt
          FROM BILLING.V_MBSI_STATE_TAX_RECEIVABLE)
/


COMMENT ON MATERIALIZED VIEW BILLING.MBSI_REC_DETAILS IS 'snapshot table for snapshot BILLING.MBSI_REC_DETAILS'
/

CREATE UNIQUE INDEX BILLING.MBSI_REC_DETAILS_PK ON BILLING.MBSI_REC_DETAILS
(POLICY_NUMBER, PROCESS_DATE, POLICY_EFFECTIVE_DATE, RECEIVABLE_CODE, COMMISSION_PERCENT, 
COMMISSION_AMOUNT, RECEIVABLE_AMOUNT)
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
