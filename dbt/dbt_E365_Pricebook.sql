WITH DIM_PRICEBOOK AS (
    SELECT *
    FROM {{ ref('presentation_main_dim_pricebook') }}
),
 
FCT_PRICEBOOK AS (
    SELECT *
    FROM {{ ref('presentation_main_fct_pricebook') }}
),
 
DIM_CURRENCY AS (
    SELECT *
    FROM {{ ref('presentation_main_dim_currency') }}
),
 
DIM_MATERIAL AS (
    SELECT *
    FROM {{ ref('presentation_main_dim_material') }}
),
 
DIM_PRODUCT AS (
    SELECT *
    FROM {{ ref('presentation_main_dim_product') }}
),
 
PRODUCT_MATERIAL_MAPPING AS (
    SELECT
        FK_PRODUCT_KEY,
        FK_MATERIAL_KEY,
        IS_FEATURE_BASED_PRODUCT
    FROM {{ ref('presentation_edw_product_material_mapping') }}
)
 
SELECT
    FCT_PRICEBOOK.PRICEBOOK_DESCRIPTION AS "Pricebook",
    DIM_CURRENCY.CURRENCY_ISO_CODE AS "Currency",
    DIM_PRODUCT.PRODUCT_ID || ' ' || DIM_MATERIAL.FEATURE_STRING AS "Product Feature Combo",
    DIM_PRICEBOOK.PRICEBOOK_ITERATION_NUMBER AS "Iteration",
    DIM_PRODUCT.PRODUCT_ID AS "Product ID",
    CASE WHEN DIM_PRODUCT.PRODUCT_NAME = 'MicroStation For SELECT Users'
            THEN 'MicroStation'
        ELSE DIM_PRODUCT.PRODUCT_NAME
    END AS "Product Name",
    DIM_MATERIAL.FEATURE_STRING AS "Feature String",
    DIM_PRODUCT.BRAND AS "Brand",
    'Placeholder' AS "Application Type",                                  --Since this field is not used, added Placeholder. Will check with Paul B about the source of this field.
    DIM_MATERIAL.USAGE_INTERVAL AS "Usage Fee Interval",
    'Placeholder' AS "Counting Element",                                  --Since this field is not used, added Placeholder. Will check with Paul B about the source of this field.
    DIM_MATERIAL.MATERIAL_E365_CATEGORY AS "Pricebook Section",
    FCT_PRICEBOOK.PRICEBOOK_DESCRIPTION AS "Pricebook Code",
    FCT_PRICEBOOK.PRICEBOOK_PRICE_LC AS "E365 Gross Price",
    CASE WHEN DIM_PRICEBOOK.IS_E365_PRICEBOOK THEN 'YES' ELSE 'NO' END AS "E365 Pricebook Eligible",
    CASE WHEN PRODUCT_MATERIAL_MAPPING.IS_FEATURE_BASED_PRODUCT THEN 'YES' ELSE 'NO' END AS "Feature Based Product",
    CASE WHEN DIM_PRICEBOOK.IS_CURRENT_PRICEBOOK THEN 'YES' ELSE 'NO' END AS "Is Current",
    'Placeholder' AS "Update Type",                                       --Since this field is not used, added Placeholder. Will check with Paul B about the source of this field.
    --1.UpdatedToQuarterlyServer
    --2.ProductAdded
    --3.NameChange
    --4.Escalation
    --5.PriceUpdate
    DIM_PRICEBOOK.PRICEBOOK_EFFECTIVE_DATE AS "Start Date",
    DIM_PRICEBOOK.PRICEBOOK_EXPIRATION_DATE AS "End Date",
    DIM_PRICEBOOK.LOADED_AT::TIMESTAMP_NTZ(6) AS "Last Updated",          --This field is not used and we can even remove this. For now, assigned LOAD_TIMESTAMP
    DIM_PRICEBOOK.LOADED_AT::TIMESTAMP_NTZ(6) AS "Load Timestamp"
FROM DIM_PRICEBOOK
INNER JOIN FCT_PRICEBOOK
    ON DIM_PRICEBOOK.SK_PRICEBOOK_KEY = FCT_PRICEBOOK.FK_PRICEBOOK_KEY
LEFT OUTER JOIN DIM_CURRENCY
    ON FCT_PRICEBOOK.FK_PRICEBOOK_CURRENCY_KEY = DIM_CURRENCY.SK_CURRENCY_KEY
LEFT OUTER JOIN DIM_MATERIAL
    ON FCT_PRICEBOOK.FK_PRICEBOOK_MATERIAL_KEY = DIM_MATERIAL.SK_MATERIAL_KEY
LEFT OUTER JOIN DIM_PRODUCT
    ON FCT_PRICEBOOK.FK_PRICEBOOK_PRODUCT_KEY = DIM_PRODUCT.SK_PRODUCT_KEY
LEFT OUTER JOIN PRODUCT_MATERIAL_MAPPING
    ON FCT_PRICEBOOK.FK_PRICEBOOK_MATERIAL_KEY = PRODUCT_MATERIAL_MAPPING.FK_MATERIAL_KEY AND
    FCT_PRICEBOOK.FK_PRICEBOOK_PRODUCT_KEY = PRODUCT_MATERIAL_MAPPING.FK_PRODUCT_KEY
