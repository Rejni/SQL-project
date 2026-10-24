/*
===============================================================================
Quality Checks: Silver
===============================================================================
Script Purpose:
    Checks the result of 03_scripts/silver/proc_load_silver.sql, column by
    column.
===============================================================================
*/

-- ============================================================================
-- silver.crm_cust_info
-- ============================================================================

-- Expect: 18484 rows (one per customer)
SELECT COUNT(*) AS row_count FROM silver.crm_cust_info;

-- cst_id: no NULL, no 0, no duplicates
SELECT cst_id, COUNT(*) AS occurrences
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL OR cst_id = 0;

-- cst_key: no missing, no spaces, format AW + 8 digits
SELECT cst_id, cst_key
FROM silver.crm_cust_info
WHERE cst_key IS NULL OR cst_key = ''
	OR cst_key != TRIM(cst_key)
	OR cst_key NOT LIKE 'AW%'          -- does not start with AW
	OR CHAR_LENGTH(cst_key) != 10;      -- not 10 characters long

-- cst_firstname / cst_lastname: no spaces, no missing names
SELECT cst_id, cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname)
   OR cst_lastname  != TRIM(cst_lastname)
   OR cst_firstname IS NULL OR cst_firstname = ''
   OR cst_lastname  IS NULL OR cst_lastname  = '';

-- cst_marital_status: only Married, Single, n/a
SELECT cst_marital_status, COUNT(*) AS occurrences
FROM silver.crm_cust_info
GROUP BY cst_marital_status
HAVING cst_marital_status NOT IN ('Married', 'Single', 'n/a') OR cst_marital_status IS NULL;

-- cst_gndr: only Male, Female, n/a
SELECT cst_gndr, COUNT(*) AS occurrences
FROM silver.crm_cust_info
GROUP BY cst_gndr
HAVING cst_gndr NOT IN ('Male', 'Female', 'n/a') OR cst_gndr IS NULL;

-- cst_create_date: no 0000-00-00, no NULL, not in the future
SELECT cst_id, cst_create_date
FROM silver.crm_cust_info
WHERE cst_create_date IS NULL
   OR YEAR(cst_create_date) = 0
   OR cst_create_date > CURDATE();

-- ============================================================================
-- silver.crm_prd_info
-- ============================================================================

-- Expect: 397 rows
SELECT COUNT(*) AS row_count FROM silver.crm_prd_info;

-- prd_id: no NULL, no duplicates
SELECT prd_id, COUNT(*) AS occurrences
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- cat_id: format XX_XX
SELECT prd_id, cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT LIKE '__\___';

-- cat_id: exists in the ERP category table
-- Expect: CO_PE only (known: this category is missing in the ERP source)
SELECT DISTINCT cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2);

-- prd_key: no missing, no spaces
SELECT prd_id, prd_key
FROM silver.crm_prd_info
WHERE prd_key IS NULL OR prd_key = ''
   OR prd_key != TRIM(prd_key);

-- prd_nm: no missing, no spaces
SELECT prd_id, prd_nm
FROM silver.crm_prd_info
WHERE prd_nm IS NULL OR prd_nm = '' OR prd_nm != TRIM(prd_nm);

-- prd_cost: no NULL, not negative
SELECT prd_id, prd_cost
FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- prd_line: only Mountain, Road, Other Sales, Touring, n/a
SELECT prd_line, COUNT(*) AS occurrences
FROM silver.crm_prd_info
GROUP BY prd_line
HAVING prd_line NOT IN ('Mountain', 'Road', 'Other Sales', 'Touring', 'n/a') OR prd_line IS NULL;

-- prd_start_dt: no NULL
SELECT prd_id, prd_start_dt
FROM silver.crm_prd_info
WHERE prd_start_dt IS NULL;

-- prd_end_dt: never before the start date
SELECT prd_id, prd_key, prd_start_dt, prd_end_dt
FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- prd_end_dt: exactly one current version (end date NULL) per product
SELECT prd_key, COUNT(*) AS current_versions
FROM silver.crm_prd_info
GROUP BY prd_key
HAVING SUM(prd_end_dt IS NULL) != 1;

-- ============================================================================
-- silver.crm_sales_details
-- ============================================================================

-- Expect: 60398 rows
SELECT COUNT(*) AS row_count FROM silver.crm_sales_details;

-- sls_ord_num: no missing, no spaces
SELECT sls_ord_num
FROM silver.crm_sales_details
WHERE sls_ord_num IS NULL OR sls_ord_num = '' OR sls_ord_num != TRIM(sls_ord_num);

-- sls_prd_key: every sale points to a product
SELECT sls_ord_num, sls_prd_key
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

-- sls_cust_id: every sale points to a customer
SELECT sls_ord_num, sls_cust_id
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);

-- sls_order_dt / sls_ship_dt / sls_due_dt: how many dates are NULL
-- Expect: 19 order dates (they were 0 or invalid in bronze), 0 ship, 0 due
SELECT
    SUM(sls_order_dt IS NULL) AS null_order_dates,
    SUM(sls_ship_dt  IS NULL) AS null_ship_dates,
    SUM(sls_due_dt   IS NULL) AS null_due_dates
FROM silver.crm_sales_details;

-- dates in the right order
SELECT *
FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- sls_sales / sls_quantity / sls_price: no NULL, nothing <= 0, sales = quantity * price
SELECT sls_sales, sls_quantity, sls_price, COUNT(*) AS occurrences
FROM silver.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0    OR sls_quantity <= 0    OR sls_price <= 0
GROUP BY sls_sales, sls_quantity, sls_price;

-- ============================================================================
-- silver.erp_cust_az12
-- ============================================================================

-- Expect: 18484 rows
SELECT COUNT(*) AS row_count FROM silver.erp_cust_az12;

-- cid: no 'NAS' prefix, every cid exists in CRM
SELECT cid
FROM silver.erp_cust_az12
WHERE cid LIKE 'NAS%'
   OR cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- bdate: not in the future
SELECT cid, bdate
FROM silver.erp_cust_az12
WHERE bdate > CURDATE() OR YEAR(bdate) = 0;

-- bdate: very old (Expect: 15 rows, kept on purpose; check they look plausible)
SELECT cid, bdate
FROM silver.erp_cust_az12
WHERE bdate < '1924-01-01'
ORDER BY bdate;

-- gen: only Female, Male, n/a
SELECT gen, COUNT(*) AS occurrences
FROM silver.erp_cust_az12
GROUP BY gen
HAVING gen NOT IN ('Female', 'Male', 'n/a') OR gen IS NULL;

-- ============================================================================
-- silver.erp_loc_a101
-- ============================================================================

-- Expect: 18484 rows
SELECT COUNT(*) AS row_count FROM silver.erp_loc_a101;

-- cid: no '-', every cid exists in CRM
SELECT cid
FROM silver.erp_loc_a101
WHERE cid LIKE '%-%'
   OR cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- cntry: no codes, no blanks, no spaces
-- Expect: Australia, Canada, France, Germany, United Kingdom, United States, n/a
SELECT cntry, COUNT(*) AS occurrences
FROM silver.erp_loc_a101
GROUP BY cntry
ORDER BY cntry;

SELECT cid, cntry
FROM silver.erp_loc_a101
WHERE cntry IS NULL OR cntry = '' OR cntry != TRIM(cntry)
   OR cntry IN ('DE', 'US', 'USA');

-- ============================================================================
-- silver.erp_px_cat_g1v2
-- ============================================================================

-- Expect: 37 rows
SELECT COUNT(*) AS row_count FROM silver.erp_px_cat_g1v2;

-- id: no NULL, no duplicates
SELECT id, COUNT(*) AS occurrences
FROM silver.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL;

-- cat / subcat / maintenance: no spaces, no blanks
SELECT *
FROM silver.erp_px_cat_g1v2
WHERE cat = '' OR subcat = '' OR maintenance = ''
   OR cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

-- maintenance: only Yes, No
SELECT DISTINCT maintenance
FROM silver.erp_px_cat_g1v2
WHERE maintenance NOT IN ('Yes', 'No');
