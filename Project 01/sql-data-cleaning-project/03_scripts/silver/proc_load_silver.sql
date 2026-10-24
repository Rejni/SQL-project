/*
===============================================================================
Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    Truncates the silver tables and fills them with cleaned data from bronze.
    Every cleaning rule is explained in README.md.
    Run after ddl_silver.sql and proc_load_bronze.sql.
===============================================================================
*/

SET @batch_start_time = NOW();

-- ---------------------------------------------------------------- CRM tables

-- silver.crm_cust_info
SET @start_time = NOW();
TRUNCATE TABLE silver.crm_cust_info;
INSERT INTO silver.crm_cust_info (
    cst_id, cst_key, cst_firstname, cst_lastname,
    cst_marital_status, cst_gndr, cst_create_date
)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname)  AS cst_lastname,
    CASE
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        ELSE 'n/a'
    END AS cst_gndr,
    CASE
        WHEN YEAR(cst_create_date) = 0 THEN NULL     -- 0000-00-00 = missing date
        ELSE cst_create_date
    END AS cst_create_date
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
      AND cst_id != 0                                -- 0 = missing ID
) AS dupl
WHERE flag_last = 1;
SET @cust_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- silver.crm_prd_info
SET @start_time = NOW();
TRUNCATE TABLE silver.crm_prd_info;
INSERT INTO silver.crm_prd_info (
    prd_id, cat_id, prd_key, prd_nm, prd_cost,
    prd_line, prd_start_dt, prd_end_dt
)
SELECT
    p.prd_id,
    REPLACE(SUBSTRING(p.prd_key, 1, 5), '-', '_')   AS cat_id,
    SUBSTRING(p.prd_key, 7, CHAR_LENGTH(p.prd_key)) AS prd_key,
    TRIM(p.prd_nm)                                  AS prd_nm,
    IFNULL(p.prd_cost, 0)                           AS prd_cost,
    CASE
        WHEN UPPER(TRIM(p.prd_line)) = 'M' THEN 'Mountain'
        WHEN UPPER(TRIM(p.prd_line)) = 'R' THEN 'Road'
        WHEN UPPER(TRIM(p.prd_line)) = 'S' THEN 'Other Sales'
        WHEN UPPER(TRIM(p.prd_line)) = 'T' THEN 'Touring'
        ELSE 'n/a'
    END AS prd_line,
    CAST(p.prd_start_dt AS DATE) AS prd_start_dt,
    CAST(
        LEAD(p.prd_start_dt) OVER (PARTITION BY p.prd_key ORDER BY p.prd_start_dt)
        - INTERVAL 1 DAY
        AS DATE
    ) AS prd_end_dt
FROM bronze.crm_prd_info AS p;
SET @prd_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- silver.crm_sales_details
SET @start_time = NOW();
TRUNCATE TABLE silver.crm_sales_details;
INSERT INTO silver.crm_sales_details (
    sls_ord_num, sls_prd_key, sls_cust_id,
    sls_order_dt, sls_ship_dt, sls_due_dt,
    sls_sales, sls_quantity, sls_price
)
SELECT
    sls_ord_num,
    sls_prd_key,
    sls_cust_id,
    CASE
        WHEN sls_order_dt <= 0 OR CHAR_LENGTH(sls_order_dt) != 8
          OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS CHAR) AS DATE)
    END AS sls_order_dt,
    CASE
        WHEN sls_ship_dt <= 0 OR CHAR_LENGTH(sls_ship_dt) != 8
          OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS CHAR) AS DATE)
    END AS sls_ship_dt,
    CASE
        WHEN sls_due_dt <= 0 OR CHAR_LENGTH(sls_due_dt) != 8
          OR sls_due_dt > 20500101 OR sls_due_dt < 19000101 THEN NULL
        ELSE CAST(CAST(sls_due_dt AS CHAR) AS DATE)
    END AS sls_due_dt,
    CASE
        WHEN sls_sales IS NULL OR sls_sales <= 0
          OR (sls_price != 0 AND sls_sales != ABS(sls_quantity) * ABS(sls_price))  -- price 0 = missing: keep sales
            THEN ABS(sls_quantity) * ABS(sls_price)
        ELSE sls_sales
    END AS sls_sales,
    sls_quantity,
    CASE
        WHEN sls_price IS NULL OR sls_price = 0 THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
        WHEN sls_price < 0                      THEN ABS(sls_price)
        ELSE sls_price
    END AS sls_price
FROM bronze.crm_sales_details;
SET @sls_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- ---------------------------------------------------------------- ERP tables

-- silver.erp_cust_az12
SET @start_time = NOW();
TRUNCATE TABLE silver.erp_cust_az12;
INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
SELECT
    CASE
        WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, CHAR_LENGTH(cid))
        ELSE cid
    END AS cid,
    CASE
        WHEN bdate > NOW() THEN NULL
        ELSE bdate
    END AS bdate,
    CASE
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
        ELSE 'n/a'
    END AS gen
FROM bronze.erp_cust_az12;
SET @az12_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- silver.erp_loc_a101
SET @start_time = NOW();
TRUNCATE TABLE silver.erp_loc_a101;
INSERT INTO silver.erp_loc_a101 (cid, cntry)
SELECT
    REPLACE(cid, '-', '') AS cid,
    CASE
        WHEN TRIM(cntry) = 'DE'                THEN 'Germany'
        WHEN TRIM(cntry) IN ('US', 'USA')      THEN 'United States'
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END AS cntry
FROM bronze.erp_loc_a101;
SET @loc_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- silver.erp_px_cat_g1v2
SET @start_time = NOW();
TRUNCATE TABLE silver.erp_px_cat_g1v2;
INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
SELECT id, cat, subcat, maintenance
FROM bronze.erp_px_cat_g1v2;
SET @cat_seconds = TIMESTAMPDIFF(SECOND, @start_time, NOW());

SET @batch_seconds = TIMESTAMPDIFF(SECOND, @batch_start_time, NOW());

-- ---------------------------------------------------------------- summary
SELECT 'silver.crm_cust_info' AS table_name,
       (SELECT COUNT(*) FROM silver.crm_cust_info) AS row_count,
       @cust_seconds AS load_seconds
UNION ALL
SELECT 'silver.crm_prd_info',      (SELECT COUNT(*) FROM silver.crm_prd_info),      @prd_seconds
UNION ALL
SELECT 'silver.crm_sales_details', (SELECT COUNT(*) FROM silver.crm_sales_details), @sls_seconds
UNION ALL
SELECT 'silver.erp_cust_az12',     (SELECT COUNT(*) FROM silver.erp_cust_az12),     @az12_seconds
UNION ALL
SELECT 'silver.erp_loc_a101',      (SELECT COUNT(*) FROM silver.erp_loc_a101),      @loc_seconds
UNION ALL
SELECT 'silver.erp_px_cat_g1v2',   (SELECT COUNT(*) FROM silver.erp_px_cat_g1v2),   @cat_seconds
UNION ALL
SELECT 'Total Load Duration',      NULL,                                            @batch_seconds;
