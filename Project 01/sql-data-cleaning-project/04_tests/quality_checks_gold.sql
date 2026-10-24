/*
===============================================================================
Quality Checks: Gold
===============================================================================
Script Purpose:
    Checks the joins and the star schema views created by
    03_scripts/gold/ddl_gold.sql, in the same 3 steps:
      Step 1: gold.dim_customers
      Step 2: gold.dim_products
      Step 3: gold.fact_sales
    Every query should return NO ROWS, unless the comment says otherwise.
===============================================================================
*/

-- ============================================================================
-- Step 1: gold.dim_customers  (crm_cust_info + erp_cust_az12 + erp_loc_a101)
-- ============================================================================

-- Join: no duplicates after joining the 3 customer tables
SELECT cst_id, COUNT(*) AS occurrences
FROM (
    SELECT
        ci.cst_id,
        ci.cst_key,
        ci.cst_firstname,
        ci.cst_lastname,
        ci.cst_marital_status,
        ci.cst_gndr,
        ci.cst_create_date,
        ca.bdate,
        ca.gen,
        la.cntry
    FROM silver.crm_cust_info AS ci
    LEFT JOIN silver.erp_cust_az12 AS ca ON ci.cst_key = ca.cid
    LEFT JOIN silver.erp_loc_a101  AS la ON ci.cst_key = la.cid
) AS t
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Join: two gender sources (Expect: rows, this is for review).
-- Rule: CRM is the master; ERP only fills CRM 'n/a'.
SELECT DISTINCT
    ci.cst_gndr,
    ca.gen,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
        ELSE IFNULL(ca.gen, 'n/a')
    END AS gen_correct
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca ON ci.cst_key = ca.cid
ORDER BY 1, 2;

-- View: Expect 18484 rows
SELECT COUNT(*) AS row_count FROM gold.dim_customers;

-- View: customer_key (PK, surrogate) unique and not NULL
SELECT customer_key, COUNT(*) AS occurrences
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1 OR customer_key IS NULL;

-- View: customer_id / customer_number (business keys) unique
SELECT customer_id, COUNT(*) AS occurrences
FROM gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT customer_number, COUNT(*) AS occurrences
FROM gold.dim_customers
GROUP BY customer_number
HAVING COUNT(*) > 1;

-- View: every customer found in erp_loc_a101
SELECT customer_id, customer_number, country
FROM gold.dim_customers
WHERE country IS NULL;

-- View: gender only Male, Female, n/a
SELECT gender, COUNT(*) AS occurrences
FROM gold.dim_customers
GROUP BY gender
HAVING gender NOT IN ('Male', 'Female', 'n/a') OR gender IS NULL;

-- ============================================================================
-- Step 2: gold.dim_products  (crm_prd_info + erp_px_cat_g1v2)
-- ============================================================================

-- Join: categories that do not exist in ERP
-- Expect: CO_PE only (missing in the ERP source)
SELECT DISTINCT cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2);

-- Join: no duplicates after joining the 2 product tables (current versions only)
-- Without "WHERE prd_end_dt IS NULL" this returns 77 products (the history).
SELECT prd_key, COUNT(*) AS occurrences
FROM (
    SELECT
        pn.prd_id,
        pn.cat_id,
        pn.prd_key,
        pn.prd_nm,
        pn.prd_cost,
        pn.prd_line,
        pn.prd_start_dt,
        pn.prd_end_dt,
        pc.cat,
        pc.subcat,
        pc.maintenance
    FROM silver.crm_prd_info AS pn
    LEFT JOIN silver.erp_px_cat_g1v2 AS pc ON pn.cat_id = pc.id
    WHERE pn.prd_end_dt IS NULL
) AS t
GROUP BY prd_key
HAVING COUNT(*) > 1;

-- View: Expect 295 rows (one current version per product)
SELECT COUNT(*) AS row_count FROM gold.dim_products;

-- View: product_key (PK, surrogate) unique and not NULL
SELECT product_key, COUNT(*) AS occurrences
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1 OR product_key IS NULL;

-- View: product_number (business key) unique
SELECT product_number, COUNT(*) AS occurrences
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- View: products without a category
-- Expect: 7 rows, all category_id CO_PE (never sold)
SELECT product_key, product_number, category_id
FROM gold.dim_products
WHERE category IS NULL;

-- ============================================================================
-- Step 3: gold.fact_sales  (crm_sales_details + both dimensions)
-- ============================================================================

-- View: Expect 60398 rows (the same as silver.crm_sales_details)
SELECT COUNT(*) AS row_count FROM gold.fact_sales;

-- View: every FK found in its dimension
SELECT f.*
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c ON c.customer_key = f.customer_key
LEFT JOIN gold.dim_products  AS p ON p.product_key  = f.product_key
WHERE c.customer_key IS NULL OR p.product_key IS NULL;
