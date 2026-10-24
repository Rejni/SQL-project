/*
===============================================================================
Create silver database and tables
===============================================================================
Purpose:
    Creates the database 'silver' (if it does not exist yet) and its tables
    (cleaned data). Existing silver tables are dropped and recreated.
    Differences from bronze:
      - crm_prd_info: new column cat_id; dates are DATE instead of DATETIME
      - crm_sales_details: order/ship/due dates are DATE instead of INT
      - every table gets dwh_create_date (when the row was loaded)
===============================================================================
*/

CREATE DATABASE IF NOT EXISTS silver CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------- CRM
DROP TABLE IF EXISTS silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info (
    cst_id              INT,
    cst_key             VARCHAR(50),
    cst_firstname       VARCHAR(50),
    cst_lastname        VARCHAR(50),
    cst_marital_status  VARCHAR(50),
    cst_gndr            VARCHAR(50),
    cst_create_date     DATE,
    dwh_create_date     DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id           INT,
    cat_id           VARCHAR(50),
    prd_key          VARCHAR(50),
    prd_nm           VARCHAR(50),
    prd_cost         INT,
    prd_line         VARCHAR(50),
    prd_start_dt     DATE,
    prd_end_dt       DATE,
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num      VARCHAR(50),
    sls_prd_key      VARCHAR(50),
    sls_cust_id      INT,
    sls_order_dt     DATE,
    sls_ship_dt      DATE,
    sls_due_dt       DATE,
    sls_sales        INT,
    sls_quantity     INT,
    sls_price        INT,
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------- ERP
DROP TABLE IF EXISTS silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 (
    cid              VARCHAR(50),
    cntry            VARCHAR(50),
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid              VARCHAR(50),
    bdate            DATE,
    gen              VARCHAR(50),
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);

DROP TABLE IF EXISTS silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 (
    id               VARCHAR(50),
    cat              VARCHAR(50),
    subcat           VARCHAR(50),
    maintenance      VARCHAR(50),
    dwh_create_date  DATETIME DEFAULT CURRENT_TIMESTAMP
);
