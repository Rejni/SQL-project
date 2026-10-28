/*
===============================================================================
Load bronze Layer (Source -> bronze)
===============================================================================
Script Purpose:
    Loads data into the 'bronze' database from external CSV files.
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses LOAD DATA to load data from the CSV files into the bronze tables.
    - Shows a summary: rows, load duration and warnings per table.

Before running:
    1. Workbench: Connection > Advanced > Others: add  OPT_LOCAL_INFILE=1 ,
       save, reconnect.
    2. If  SHOW GLOBAL VARIABLES LIKE 'local_infile';  shows OFF, run:
           SET GLOBAL local_infile = ON;
    3. Change the paths below to the folder where you saved the datasets
       (use forward slashes /).
===============================================================================
*/

SET @batch_start_time = NOW();

-- ---------------------------------------------------------------- CRM tables

-- bronze.crm_cust_info
SET @start_time = NOW();
TRUNCATE TABLE bronze.crm_cust_info;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_crm/cust_info.csv'
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date);
SET @cust_warnings = @@warning_count;
SET @cust_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- bronze.crm_prd_info
SET @start_time = NOW();
TRUNCATE TABLE bronze.crm_prd_info;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_crm/prd_info.csv'
INTO TABLE bronze.crm_prd_info
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(prd_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt);
SET @prd_warnings = @@warning_count;
SET @prd_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- bronze.crm_sales_details
SET @start_time = NOW();
TRUNCATE TABLE bronze.crm_sales_details;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_crm/sales_details.csv'
INTO TABLE bronze.crm_sales_details
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt,
 sls_sales, sls_quantity, sls_price);
SET @sls_warnings = @@warning_count;
SET @sls_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- ---------------------------------------------------------------- ERP tables

-- bronze.erp_loc_a101
SET @start_time = NOW();
TRUNCATE TABLE bronze.erp_loc_a101;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_erp/LOC_A101.csv'
INTO TABLE bronze.erp_loc_a101
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(cid, cntry);
SET @loc_warnings = @@warning_count;
SET @loc_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- bronze.erp_cust_az12
SET @start_time = NOW();
TRUNCATE TABLE bronze.erp_cust_az12;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_erp/CUST_AZ12.csv'
INTO TABLE bronze.erp_cust_az12
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(cid, bdate, gen);
SET @az12_warnings = @@warning_count;
SET @az12_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

-- bronze.erp_px_cat_g1v2
SET @start_time = NOW();
TRUNCATE TABLE bronze.erp_px_cat_g1v2;
LOAD DATA LOCAL INFILE 'C:/path/to/sql-data-cleaning-project/01_datasets/source_erp/PX_CAT_G1V2.csv'
INTO TABLE bronze.erp_px_cat_g1v2
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(id, cat, subcat, maintenance);
SET @cat_warnings = @@warning_count;
SET @cat_seconds  = TIMESTAMPDIFF(SECOND, @start_time, NOW());

SET @batch_seconds = TIMESTAMPDIFF(SECOND, @batch_start_time, NOW());

-- ---------------------------------------------------------------- summary
SELECT 'bronze.crm_cust_info' AS table_name,
       (SELECT COUNT(*) FROM bronze.crm_cust_info) AS row_count,
       @cust_seconds  AS load_seconds,
       @cust_warnings AS warnings
UNION ALL
SELECT 'bronze.crm_prd_info',      (SELECT COUNT(*) FROM bronze.crm_prd_info),      @prd_seconds,  @prd_warnings
UNION ALL
SELECT 'bronze.crm_sales_details', (SELECT COUNT(*) FROM bronze.crm_sales_details), @sls_seconds,  @sls_warnings
UNION ALL
SELECT 'bronze.erp_loc_a101',      (SELECT COUNT(*) FROM bronze.erp_loc_a101),      @loc_seconds,  @loc_warnings
UNION ALL
SELECT 'bronze.erp_cust_az12',     (SELECT COUNT(*) FROM bronze.erp_cust_az12),     @az12_seconds, @az12_warnings
UNION ALL
SELECT 'bronze.erp_px_cat_g1v2',   (SELECT COUNT(*) FROM bronze.erp_px_cat_g1v2),   @cat_seconds,  @cat_warnings
UNION ALL
SELECT 'Total Load Duration',      NULL,                                            @batch_seconds, NULL;
