/*
===============================================================================
Profiling Bronze: find the problems in the raw data
===============================================================================
Script Purpose:
    Checks every column of every bronze table. The results decide the
    cleaning rules in 03_scripts/silver/proc_load_silver.sql.
===============================================================================
*/

-- ============================================================================
-- bronze.crm_cust_info
-- ============================================================================

-- cst_id: missing (NULL or 0) or repeated
SELECT cst_id, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL OR cst_id = 0;
-- Found: 0 (4 rows) and 29433, 29449, 29466, 29473, 29483 (duplicates)

-- cst_id: all rows of the duplicates, newest first (flag_last > 1 = dropped in silver)
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL AND cst_id != 0
) AS dupl
WHERE cst_id IN (SELECT cst_id FROM bronze.crm_cust_info GROUP BY cst_id HAVING COUNT(*) > 1);
-- Found: the newest row is the complete one; older rows have empty names

-- cst_key: missing, spaces, wrong format (expected AW + 8 digits)
SELECT cst_id, cst_key
FROM bronze.crm_cust_info
WHERE cst_key IS NULL OR cst_key = ''
   OR cst_key != TRIM(cst_key)
   OR cst_key NOT LIKE 'AW%'          -- does not start with AW
   OR CHAR_LENGTH(cst_key) != 10;     -- not 10 characters long
-- Found: SF566, PO25, 13451235, A01Ass (the 4 rows without cst_id)

-- cst_firstname / cst_lastname: leading or trailing spaces
SELECT cst_id, cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

SELECT cst_id, cst_lastname
FROM bronze.crm_cust_info
WHERE cst_lastname != TRIM(cst_lastname);
-- Found: 17 first names, 22 last names (' Jon', 'Yang ')

-- cst_firstname / cst_lastname: missing
SELECT cst_id, cst_firstname, cst_lastname
FROM bronze.crm_cust_info
WHERE cst_firstname IS NULL OR cst_firstname = ''
   OR cst_lastname  IS NULL OR cst_lastname  = '';
-- Found: 8 empty first names, 7 empty last names (old duplicates and rows without ID)

-- cst_marital_status: all values (decide the CASE mapping)
SELECT cst_marital_status, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_marital_status;
-- Found: 'M', 'S', '' -> Married, Single, n/a

-- cst_gndr: all values (decide the CASE mapping)
SELECT cst_gndr, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_gndr;
-- Found: 'M', 'F', '' (4578 empty) -> Male, Female, n/a

-- cst_create_date: missing (NULL or 0000-00-00), in the future
SELECT cst_id, cst_key, cst_create_date
FROM bronze.crm_cust_info
WHERE cst_create_date IS NULL
   OR YEAR(cst_create_date) = 0
   OR cst_create_date > CURDATE();
-- Found: 3 x 0000-00-00 and 1 x NULL (last line of the file), all in rows without cst_id

-- ============================================================================
-- bronze.crm_prd_info
-- ============================================================================

-- prd_id: missing or repeated
SELECT prd_id, COUNT(*) AS occurrences
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL OR prd_id = 0;
-- Found: none

-- prd_key: spaces; category part (first 5 chars) not in the ERP category table
SELECT prd_key
FROM bronze.crm_prd_info
WHERE prd_key != TRIM(prd_key);

SELECT DISTINCT REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') NOT IN (SELECT id FROM bronze.erp_px_cat_g1v2);
-- Found: no spaces; CO_PE has no category

-- prd_key: product part (from char 7) never sold
SELECT DISTINCT SUBSTRING(prd_key, 7, CHAR_LENGTH(prd_key)) AS prd_key
FROM bronze.crm_prd_info
WHERE SUBSTRING(prd_key, 7, CHAR_LENGTH(prd_key)) NOT IN (SELECT sls_prd_key FROM bronze.crm_sales_details);
-- Info only: products without sales are allowed

-- prd_nm: missing or spaces
SELECT prd_id, prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm IS NULL OR prd_nm = '' OR prd_nm != TRIM(prd_nm);
-- Found: none

-- prd_cost: missing (NULL or 0) or negative
SELECT prd_id, prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost <= 0;
-- Found: 2 x 0 (empty in the CSV)

-- prd_line: all values (decide the CASE mapping)
SELECT prd_line, COUNT(*) AS occurrences
FROM bronze.crm_prd_info
GROUP BY prd_line;
-- Found: 'M ', 'R ', 'S ', 'T ' (trailing space), '' (17) -> TRIM needed

-- prd_start_dt: missing
SELECT prd_id, prd_start_dt
FROM bronze.crm_prd_info
WHERE prd_start_dt IS NULL OR YEAR(prd_start_dt) = 0;
-- Found: none

-- prd_end_dt: before the start date (0000-00-00 = empty, counted separately)
SELECT prd_id, prd_key, prd_start_dt, prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt
  AND YEAR(prd_end_dt) != 0;
-- Found: 200 rows -> end dates are rebuilt with LEAD

SELECT COUNT(*) AS empty_end_dates
FROM bronze.crm_prd_info
WHERE YEAR(prd_end_dt) = 0;
-- Found: 197

-- ============================================================================
-- bronze.crm_sales_details
-- ============================================================================

-- sls_ord_num: missing or spaces
SELECT sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num IS NULL OR sls_ord_num = '' OR sls_ord_num != TRIM(sls_ord_num);
-- Found: none

-- sls_prd_key: spaces; not in the product table
SELECT sls_ord_num, sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key != TRIM(sls_prd_key)
   OR sls_prd_key NOT IN (SELECT SUBSTRING(prd_key, 7, CHAR_LENGTH(prd_key)) FROM bronze.crm_prd_info);
-- Found: none

-- sls_cust_id: missing or not in the customer table
SELECT sls_ord_num, sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id IS NULL OR sls_cust_id = 0
   OR sls_cust_id NOT IN (SELECT cst_id FROM bronze.crm_cust_info);
-- Found: none

-- sls_order_dt / sls_ship_dt / sls_due_dt: invalid YYYYMMDD numbers
SELECT sls_order_dt, COUNT(*) AS occurrences
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR CHAR_LENGTH(sls_order_dt) != 8
   OR sls_order_dt > 20500101 OR sls_order_dt < 19000101
GROUP BY sls_order_dt;
-- Found: 0, 5489, 32154 (19 rows)

SELECT sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_ship_dt <= 0 OR CHAR_LENGTH(sls_ship_dt) != 8
   OR sls_ship_dt > 20500101 OR sls_ship_dt < 19000101;
-- Found: none

SELECT sls_due_dt
FROM bronze.crm_sales_details
WHERE sls_due_dt <= 0 OR CHAR_LENGTH(sls_due_dt) != 8
   OR sls_due_dt > 20500101 OR sls_due_dt < 19000101;
-- Found: none

-- Dates in the wrong order (only valid 8-digit order dates)
SELECT *
FROM bronze.crm_sales_details
WHERE CHAR_LENGTH(sls_order_dt) = 8
  AND (sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt);
-- Found: none

-- sls_sales / sls_quantity / sls_price: missing, zero, negative, sales != quantity * price
SELECT sls_sales, sls_quantity, sls_price, COUNT(*) AS occurrences
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0    OR sls_quantity <= 0    OR sls_price <= 0
GROUP BY sls_sales, sls_quantity, sls_price
ORDER BY 1, 2, 3;
-- Found: empty sales (0) and price (0), negative values, wrong sales; quantity is always OK

-- ============================================================================
-- bronze.erp_cust_az12
-- ============================================================================

-- cid: missing, spaces, 'NAS' prefix, not in CRM after removing the prefix
SELECT cid
FROM bronze.erp_cust_az12
WHERE cid IS NULL OR cid = '' OR cid != TRIM(cid);
-- Found: none

SELECT COUNT(*) AS nas_prefix
FROM bronze.erp_cust_az12
WHERE cid LIKE 'NAS%';
-- Found: 11042 -> remove 'NAS'

SELECT cid
FROM bronze.erp_cust_az12
WHERE CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, CHAR_LENGTH(cid)) ELSE cid END
      NOT IN (SELECT cst_key FROM bronze.crm_cust_info);
-- Found: none

-- bdate: missing, in the future, very old
SELECT bdate
FROM bronze.erp_cust_az12
WHERE bdate IS NULL OR YEAR(bdate) = 0
   OR bdate > CURDATE()
   OR bdate < '1924-01-01'
ORDER BY bdate DESC;
-- Found: 16 in the future (up to 9999-11-20) -> NULL; 15 before 1924 (kept)

-- gen: all values (decide the CASE mapping)
SELECT gen, COUNT(*) AS occurrences
FROM bronze.erp_cust_az12
GROUP BY gen;
-- Found: 'F', 'F ', 'Female', 'M', 'M ', 'Male', '' and NULL (last line)

-- ============================================================================
-- bronze.erp_loc_a101
-- ============================================================================

-- cid: missing, spaces, not in CRM after removing '-'
SELECT cid
FROM bronze.erp_loc_a101
WHERE cid IS NULL OR cid = '' OR cid != TRIM(cid)
   OR REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM bronze.crm_cust_info);
-- Found: none (after REPLACE)

-- cntry: all values (decide the CASE mapping)
SELECT cntry, COUNT(*) AS occurrences
FROM bronze.erp_loc_a101
GROUP BY cntry
ORDER BY cntry;
-- Found: '' (332), 5 values that are only spaces, 'DE', 'US', 'USA', full names

-- ============================================================================
-- bronze.erp_px_cat_g1v2
-- ============================================================================

-- id: missing, spaces, repeated
SELECT id, COUNT(*) AS occurrences
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL OR id = '' OR id != TRIM(id);
-- Found: none

-- cat / subcat / maintenance: spaces
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);
-- Found: none

-- cat / subcat / maintenance: all values
SELECT DISTINCT cat         FROM bronze.erp_px_cat_g1v2;   -- Accessories, Bikes, Clothing, Components
SELECT DISTINCT subcat      FROM bronze.erp_px_cat_g1v2;
SELECT DISTINCT maintenance FROM bronze.erp_px_cat_g1v2;   -- Yes, No
