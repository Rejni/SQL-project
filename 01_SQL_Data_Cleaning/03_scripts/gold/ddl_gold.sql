/*
===============================================================================
Create Gold Layer (Silver -> Gold): star schema views
===============================================================================
Script Purpose:
    Creates the database 'gold' (if it does not exist yet) and three views:
      gold.dim_customers  = crm_cust_info + erp_cust_az12 + erp_loc_a101
      gold.dim_products   = crm_prd_info  + erp_px_cat_g1v2 (current versions)
      gold.fact_sales     = crm_sales_details + keys of both dimensions
    Views store no data: they always show the current silver data.
    Run after 03_scripts/silver/proc_load_silver.sql.
===============================================================================
*/

CREATE DATABASE IF NOT EXISTS gold CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- ============================================================================
-- gold.dim_customers
--   Business key: cst_key (CRM) = cid (both ERP tables)
--   Surrogate key: customer_key (new number, 1, 2, 3, ...)
-- ============================================================================
CREATE OR REPLACE VIEW gold.dim_customers AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_key,
    ci.cst_id                AS customer_id,
    ci.cst_key               AS customer_number,
    ci.cst_firstname         AS first_name,
    ci.cst_lastname          AS last_name,
    la.cntry                 AS country,
    ci.cst_marital_status    AS marital_status,
    CASE
        WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr   -- CRM is the master for gender
        ELSE IFNULL(ca.gen, 'n/a')                   -- ERP fills the gap
    END                      AS gender,
    ca.bdate                 AS birthdate,
    ci.cst_create_date       AS create_date
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
       ON ci.cst_key = ca.cid
LEFT JOIN silver.erp_loc_a101 AS la
       ON ci.cst_key = la.cid;

-- ============================================================================
-- gold.dim_products
--   Business key: cat_id (CRM) = id (ERP)
--   Surrogate key: product_key
--   Only current versions (prd_end_dt IS NULL): one row per product
-- ============================================================================
CREATE OR REPLACE VIEW gold.dim_products AS
SELECT
    ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt, pn.prd_key) AS product_key,
    pn.prd_id                AS product_id,
    pn.prd_key               AS product_number,
    pn.prd_nm                AS product_name,
    pn.cat_id                AS category_id,
    pc.cat                   AS category,
    pc.subcat                AS subcategory,
    pc.maintenance           AS maintenance,
    pn.prd_cost              AS cost,
    pn.prd_line              AS product_line,
    pn.prd_start_dt          AS start_date
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
       ON pn.cat_id = pc.id
WHERE pn.prd_end_dt IS NULL;

-- ============================================================================
-- gold.fact_sales
--   Foreign keys: product_key  -> gold.dim_products.product_key
--                 customer_key -> gold.dim_customers.customer_key
--   Found by the business keys: sls_prd_key = product_number,
--                               sls_cust_id = customer_id
-- ============================================================================
CREATE OR REPLACE VIEW gold.fact_sales AS
SELECT
    sd.sls_ord_num           AS order_number,
    pr.product_key           AS product_key,
    cu.customer_key          AS customer_key,
    sd.sls_order_dt          AS order_date,
    sd.sls_ship_dt           AS shipping_date,
    sd.sls_due_dt            AS due_date,
    sd.sls_sales             AS sales_amount,
    sd.sls_quantity          AS quantity,
    sd.sls_price             AS price
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_products AS pr
       ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers AS cu
       ON sd.sls_cust_id = cu.customer_id;
