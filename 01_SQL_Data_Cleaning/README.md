# SQL Data Cleaning (MySQL)

Data cleaning for a data warehouse with the **Medallion architecture** (bronze → silver → gold), written in **MySQL 8**.

The focus is on **checking raw data for quality problems and cleaning it from bronze into silver**.

- **Bronze**: raw data, imported from the CSV files as-is
- **Silver**: cleaned and standardized data
- **Gold**: the CRM and ERP data combined into a star schema: `dim_customers`, `dim_products`, `fact_sales` (see [Gold layer](#gold-layer))

## Folders

```
├── 01_datasets/
│   ├── source_crm/               cust_info.csv, prd_info.csv, sales_details.csv
│   └── source_erp/               CUST_AZ12.csv, LOC_A101.csv, PX_CAT_G1V2.csv
├── 02_docs/
│   └── data_model.png            picture of the gold model (source tables -> gold views)
├── 03_scripts/
│   ├── bronze/
│   │   ├── ddl_bronze.sql        create database bronze + its tables
│   │   ├── proc_load_bronze.sql  import the CSV files
│   │   └── profiling_bronze.sql  find the problems in every column of the raw data
│   ├── silver/
│   │   ├── ddl_silver.sql        create database silver + its tables
│   │   └── proc_load_silver.sql  the cleaning: fix the problems, bronze -> silver
│   └── gold/
│       └── ddl_gold.sql          create database gold + views dim_customers, dim_products, fact_sales
└── 04_tests/
    ├── quality_checks_silver.sql check the result: every column after cleaning
    └── quality_checks_gold.sql   check the joins and the star schema
```

- **03_scripts** does the work: find the problems (profiling) and fix them (cleaning).
- **04_tests** only checks the result. If a check returns rows, fix the rule in `03_scripts` and run it again.

## How to run

Requirements: MySQL 8.0 or newer, MySQL Workbench.

1. `03_scripts/bronze/ddl_bronze.sql`. Creates the bronze database and tables.
2. `03_scripts/bronze/proc_load_bronze.sql`. First change the file paths in it, and allow local file import (see the comment at the top of the file).
3. `03_scripts/bronze/profiling_bronze.sql`. Finds the problems in every column; the `Found:` comments show the results.
4. `03_scripts/silver/ddl_silver.sql`. Creates the silver database and tables.
5. `03_scripts/silver/proc_load_silver.sql`. Fixes the problems and shows rows and load time per table.
6. `04_tests/quality_checks_silver.sql`. Checks the cleaned data: queries return no rows, unless the comment says otherwise.
7. `03_scripts/gold/ddl_gold.sql`. Creates the gold database and the three views.
8. `04_tests/quality_checks_gold.sql`. Checks the joins and the star schema.

Both `proc_load_` files are plain scripts, not stored procedures. MySQL does not allow `LOAD DATA` inside a procedure, and the silver file uses the same simple style.

---

# Data cleaning

Every column follows the same steps:

1. **Import**: how `proc_load_bronze.sql` stores the value in bronze.
2. **Check**: the query from `profiling_bronze.sql` that looks for problems.
3. **Found**: the result with the CSV files in `01_datasets`.
4. **Modification**: the code from `proc_load_silver.sql` that fixes the problem.
5. **Test**: what `quality_checks_silver.sql` checks after the cleaning.

## Useful SQL basics

- `COUNT(*)` counts every row, including rows containing NULL. `COUNT(cst_id)` counts only rows where `cst_id` is not NULL.
- `TRIM()` removes leading and trailing spaces; it does not remove spaces inside a name. NULL input remains NULL.
- `UPPER(TRIM(column))` lets a `CASE` expression recognize variants such as `m`, `M` and `' M '`.
- A comparison with NULL (`x != NULL`, `x > NULL`) is **unknown**, not true, so the row does not match the `WHEN` / `WHERE`. Use `IS NULL`.
- A window function (`ROW_NUMBER`, `LEAD`) cannot be used in the `WHERE` of the same `SELECT`. Calculate it in a subquery and filter outside.

## How the import stores empty fields

The bronze import has no `NULLIF`, so MySQL stores an empty CSV field like this (each one gives an import warning):

| Column type | Empty field becomes | How to find it |
|---|---|---|
| Number (INT) | `0` | `= 0` |
| Date | `0000-00-00` | `YEAR(column) = 0` |
| Text (VARCHAR) | `''` (empty text) | `= ''` |

Only the last line of `cust_info.csv` and `CUST_AZ12.csv` is different. It has no line ending, so its last empty field becomes NULL (warning 1261).

---

## Table: crm_cust_info

Source: `cust_info.csv`. Bronze: 18,494 rows, 8 import warnings. Silver: 18,484 rows (one per customer).

### `cst_id`

- **Import:** INT. An empty ID becomes `0`.
- **Check:** missing (NULL or `0`) or repeated IDs.

```sql
SELECT cst_id, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL OR cst_id = 0;
```

- `COUNT(*) > 1` finds duplicates.
- `cst_id = 0` finds missing IDs, even if there is only one (its count is 1, not > 1).
- `cst_id IS NULL` finds nothing with this import; it is a safety check.
- **Found:** `0` (4 rows), and 5 duplicates: 29433, 29449, 29466, 29473, 29483. In each duplicate the newest row is the complete one; older rows have empty names.
- **Modification:** remove rows without an ID, then keep only the newest row per ID.

```sql
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL AND cst_id != 0               -- 0 = missing ID
) AS dupl
WHERE flag_last = 1;
```

`PARTITION BY` restarts the numbering for each customer ID. `ORDER BY ... DESC` puts the newest creation date first, so `flag_last = 1` is the newest row. `flag_last > 1` would show the rows that are dropped.

### `cst_key`

- **Import:** VARCHAR, as in the file.
- **Check:** missing, spaces, wrong format (expected `AW` + 8 digits, e.g. `AW00011000`).

```sql
SELECT cst_id, cst_key
FROM bronze.crm_cust_info
WHERE cst_key IS NULL OR cst_key = ''
	OR cst_key != TRIM(cst_key)
	OR cst_key NOT LIKE 'AW%'          -- does not start with AW
	OR CHAR_LENGTH(cst_key) != 10      -- not 10 characters long
```

- **Found:** `SF566`, `PO25`, `13451235`, `A01Ass`. These are the same 4 rows that have no `cst_id`.
- **Modification:** none needed. Copied unchanged; the 4 bad keys are already removed by the `cst_id` rule.


### `cst_firstname` and `cst_lastname`

- **Import:** VARCHAR, as in the file (spaces kept).
- **Check:** leading/trailing spaces, and missing names.

```sql
SELECT cst_id, cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);    -- same for cst_lastname

SELECT cst_id, cst_firstname, cst_lastname
FROM bronze.crm_cust_info
WHERE cst_firstname IS NULL OR cst_firstname = ''
   OR cst_lastname  IS NULL OR cst_lastname  = '';
```

- **Found:** 17 first names and 22 last names with spaces (`' Jon'`, `'Yang '`). 8 empty first names and 7 empty last names, all in rows that are removed (old duplicates and rows without ID).
- **Modification:** `TRIM`. It removes spaces at the beginning and end, not inside a name. NULL stays NULL.

```sql
TRIM(cst_firstname) AS cst_firstname,
TRIM(cst_lastname)  AS cst_lastname,
```

`' Jon'` → `'Jon'`, `'Yang '` → `'Yang'`.

- **Test:** no spaces, no empty names.

### `cst_marital_status`

- **Import:** VARCHAR, as in the file.
- **Check:** all values and how often they appear, to decide the mapping.

```sql
SELECT cst_marital_status, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_marital_status;
```

- **Found:** `M`, `S`, and `''` (7 empty).
- **Modification:** `CASE` with `UPPER(TRIM())`: `M` → `Married`, `S` → `Single`, anything else → `n/a`.

```sql
CASE
    WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
    WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
    ELSE 'n/a'
END AS cst_marital_status
```

Step 1: `TRIM(cst_marital_status)` removes spaces at the beginning and end. `' M '` → `'M'`
Step 2: `UPPER(...)` converts the text to uppercase. `'m'` → `'M'`
Step 3: `CASE` replaces the code with a word. Empty, NULL or unknown values go to `ELSE 'n/a'`.

- **Test:** only `Married`, `Single`, `n/a`.

### `cst_gndr`

- **Import:** VARCHAR, as in the file.
- **Check:** all values and how often they appear.

```sql
SELECT cst_gndr, COUNT(*) AS occurrences
FROM bronze.crm_cust_info
GROUP BY cst_gndr;
```

- **Found:** `M`, `F`, and `''` (4,578 empty).
- **Modification:** `CASE` with `UPPER(TRIM())`: `M` → `Male`, `F` → `Female`, anything else → `n/a`. Same steps as `cst_marital_status`.

```sql
CASE
    WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
    WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
    ELSE 'n/a'
END AS cst_gndr
```

The 4,578 `n/a` values are filled from the ERP table later (see "Joining CRM and ERP").

- **Test:** only `Male`, `Female`, `n/a`.

### `cst_create_date`

- **Import:** DATE. An empty date becomes `0000-00-00`; on the last line of the file it becomes NULL.
- **Check:** missing (NULL or `0000-00-00`) or in the future. `YEAR('0000-00-00')` is `0`.

```sql
SELECT cst_id, cst_key, cst_create_date
FROM bronze.crm_cust_info
WHERE cst_create_date IS NULL
   OR YEAR(cst_create_date) = 0
   OR cst_create_date > CURDATE();
```

- **Found:** 3 × `0000-00-00` and 1 × NULL, all in the 4 rows without `cst_id`. Dates go from 2025-10-06 to 2026-01-27.
- **Modification:** `0000-00-00` → NULL (safety rule; these rows are already removed by the `cst_id` rule). The column is also used to choose the newest duplicate (`ORDER BY cst_create_date DESC`).

```sql
CASE
    WHEN YEAR(cst_create_date) = 0 THEN NULL     -- 0000-00-00 = missing date
    ELSE cst_create_date
END AS cst_create_date
```

`YEAR(...) = 0` is used instead of `= '0000-00-00'`, because MySQL 8 may treat the text `'0000-00-00'` as an invalid date and stop with an error.

- **Test:** no NULL, no `0000-00-00`, nothing in the future.

### Summary: crm_cust_info

| Column               | Before                     | After                      | Modification                                                   |
| -------------------- | -------------------------- | -------------------------- | -------------------------------------------------------------- |
| `cst_id`             | `0` (missing), duplicates  | one row per ID             | Drop ID NULL or `0`; keep the newest row per ID (`ROW_NUMBER`) |
| `cst_key`            | `AW00011000`               | `AW00011000`               | Unchanged                                                      |
| `cst_firstname`      | `' Jon'`                   | `'Jon'`                    | `TRIM`                                                         |
| `cst_lastname`       | `'Yang '`                  | `'Yang'`                   | `TRIM`                                                         |
| `cst_marital_status` | `M`, `S`, `''`             | `Married`, `Single`, `n/a` | `CASE` with `UPPER(TRIM())`                                    |
| `cst_gndr`           | `M`, `F`, `''`             | `Male`, `Female`, `n/a`    | `CASE` with `UPPER(TRIM())`                                    |
| `cst_create_date`    | `2025-10-06`, `0000-00-00` | `2025-10-06`, NULL         | `0000-00-00` → NULL                                            |

```SQL
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
```


---

## Table: crm_prd_info

### `prd_id`

- **Import:** INT.
- **Check:** missing or repeated.

```sql
SELECT prd_id, COUNT(*) AS occurrences
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL OR prd_id = 0;
```

- **Found:** no problems.
- **Modification:** none, copied unchanged.
- **Test:** no NULL, no duplicates.

### `prd_key` → `cat_id` (new) and `prd_key`

- **Import:** VARCHAR, e.g. `AC-HE-HL-U509-R`. One key holds two things:

```text
AC-HE-HL-U509-R
└───┘ └───────┘
category  product key
```

```sql
REPLACE(SUBSTRING(p.prd_key, 1, 5), '-', '_')   AS cat_id,
SUBSTRING(p.prd_key, 7, CHAR_LENGTH(p.prd_key)) AS prd_key,
```

1. `SUBSTRING(..., 1, 5)` starts at character 1 and takes 5 characters: `AC-HE`.
2. `REPLACE(..., '-', '_')` changes the separator: `AC_HE`. Now it matches `erp_px_cat_g1v2.id`.
3. `SUBSTRING(..., 7, CHAR_LENGTH(prd_key))` starts at character 7 and takes `CHAR_LENGTH(prd_key)` characters, which is always enough to reach the end: `HL-U509-R`. Now it matches `crm_sales_details.sls_prd_key`. `CHAR_LENGTH()` counts characters.


**Check:** spaces; does the category part exist in the ERP category table?
It finds category IDs that exist in the product table (CRM) but are **missing** from the category table (ERP). If a category is missing, a product can’t get its category name when you join the two tables later.

```sql
SELECT DISTINCT REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id
FROM bronze.crm_prd_info
WHERE REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') NOT IN (SELECT id FROM bronze.erp_px_cat_g1v2);
```

- **Found:** no spaces. `CO_PE` has no category in ERP (known gap in the source).
- **Modification:** split the key into two columns.


- **Test:** `cat_id` has the format `XX_XX` and exists in ERP (expect only `CO_PE` to be missing); `prd_key` has no spaces.

### `prd_nm`

- **Import:** VARCHAR.
- **Check:** missing or spaces.

```sql
SELECT prd_id, prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm IS NULL OR prd_nm = '' OR prd_nm != TRIM(prd_nm);
```

- **Found:** no problems.
- **Modification:** `TRIM(p.prd_nm)`, as a safety rule.
- **Test:** no missing names, no spaces.

### `prd_cost`

- **Import:** INT. An empty cost becomes `0`.
- **Check:** missing (NULL or `0`) or negative.

```sql
SELECT prd_id, prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost <= 0;
```

- **Found:** 2 × `0` (empty in the CSV), no negative costs.
- **Modification:** a missing cost should be `0`, and it already is. `IFNULL` is a safety rule for NULL.

```sql
IFNULL(p.prd_cost, 0) AS prd_cost
```

| Original cost | Cleaned cost |
|---|---|
| `0` (empty) | 0 |
| NULL | 0 |
| 12 | 12 |

- **Test:** no NULL, no negative cost.

### `prd_line`

- **Import:** VARCHAR, as in the file.
- **Check:** all values and how often they appear.

```sql
SELECT prd_line, COUNT(*) AS occurrences
FROM bronze.crm_prd_info
GROUP BY prd_line;
```

- **Found:** `M `, `R `, `S `, `T ` (with a trailing space) and `''` (17 empty), so `TRIM` is needed before comparing.
- **Modification:** `CASE` with `UPPER(TRIM())`.

```sql
CASE
    WHEN UPPER(TRIM(p.prd_line)) = 'M' THEN 'Mountain'
    WHEN UPPER(TRIM(p.prd_line)) = 'R' THEN 'Road'
    WHEN UPPER(TRIM(p.prd_line)) = 'S' THEN 'Other Sales'
    WHEN UPPER(TRIM(p.prd_line)) = 'T' THEN 'Touring'
    ELSE 'n/a'
END AS prd_line
```

- **Test:** only `Mountain`, `Road`, `Other Sales`, `Touring`, `n/a`.

### `prd_start_dt`

- **Import:** DATETIME, e.g. `2011-07-01 00:00:00`.
- **Check:** missing.

```sql
SELECT prd_id, prd_start_dt
FROM bronze.crm_prd_info
WHERE prd_start_dt IS NULL OR YEAR(prd_start_dt) = 0;
```

- **Found:** no problems.
- **Modification:** remove the time part.

```sql
CAST(p.prd_start_dt AS DATE) AS prd_start_dt
```

`2011-07-01 00:00:00` → `2011-07-01`.

- **Test:** no NULL.

### `prd_end_dt`

- **Import:** DATETIME. An empty end date becomes `0000-00-00`.
- **Check:** end date before start date (empty dates counted separately).

```sql
SELECT prd_id, prd_key, prd_start_dt, prd_end_dt
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt
  AND YEAR(prd_end_dt) != 0;   -- 0000-00-00 = empty end date

SELECT COUNT(*) AS empty_end_dates
FROM bronze.crm_prd_info
WHERE YEAR(prd_end_dt) = 0;
```

- **Found:** 200 rows end before they start, and 197 rows have an empty end date (`0000-00-00`).
- **Modification:** the bronze end date is not used. It is rebuilt: a version ends one day before the next version of the same product starts.

```sql
CAST(
    LEAD(p.prd_start_dt) OVER (PARTITION BY p.prd_key ORDER BY p.prd_start_dt)
    - INTERVAL 1 DAY
    AS DATE
) AS prd_end_dt
```

1. `PARTITION BY` groups records by the original product key. `p.` makes sure the original key is used, not the shortened `prd_key` column of the result.
2. `ORDER BY` sorts each product's versions from oldest to newest.
3. `LEAD()` reads the next version's start date.
4. `- INTERVAL 1 DAY` makes the current version end the day before the next starts.
5. `CAST(... AS DATE)` returns the date without a time component.

Real example for `AC-HE-HL-U509-R`:

| prd_id | Start date | Original end date    | Calculated end date |
| ------ | ---------- | -------------------- | ------------------- |
| 212    | 2011-07-01 | 2007-12-28           | 2012-06-30          |
| 213    | 2012-07-01 | 2008-12-27           | 2013-06-30          |
| 214    | 2013-07-01 | `0000-00-00` (empty) | NULL                |

For the last version, `LEAD()` returns NULL because no next version exists. NULL means "current version".

### Summary: crm_prd_info

| Column         | Before                       | After                                               | Modification                               |
| -------------- | ---------------------------- | --------------------------------------------------- | ------------------------------------------ |
| `prd_id`       | `212`                        | `212`                                               | Unchanged                                  |
| `cat_id` (new) | —                            | `AC_HE`                                             | First 5 characters of `prd_key`, `-` → `_` |
| `prd_key`      | `AC-HE-HL-U509-R`            | `HL-U509-R`                                         | From character 7 to the end                |
| `prd_nm`       | `Sport-100 Helmet- Red`      | same                                                | `TRIM`                                     |
| `prd_cost`     | `0` (empty), NULL            | `0`                                                 | `IFNULL(prd_cost, 0)`                      |
| `prd_line`     | `M `, `R `, `S `, `T `, `''` | `Mountain`, `Road`, `Other Sales`, `Touring`, `n/a` | `CASE` with `UPPER(TRIM())`                |
| `prd_start_dt` | `2011-07-01 00:00:00`        | `2011-07-01`                                        | `CAST(... AS DATE)`                        |
| `prd_end_dt`   | `2007-12-28`, `0000-00-00`   | `2012-06-30`, NULL                                  | Next version's start date − 1 day (`LEAD`) |

```SQL
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
```


---

## Table: crm_sales_details

Source: `sales_details.csv`. Bronze: 60,398 rows, 15 import warnings. Silver: 60,398 rows.

### `sls_ord_num`

- **Import:** VARCHAR.
- **Check:** missing or spaces.

```sql
SELECT sls_ord_num
FROM bronze.crm_sales_details
WHERE sls_ord_num IS NULL OR sls_ord_num = '' OR sls_ord_num != TRIM(sls_ord_num);
```

- **Found:** no problems.
- **Modification:** none, copied unchanged.
- **Test:** no missing values, no spaces.

### `sls_prd_key`

- **Import:** VARCHAR, e.g. `BK-R93R-62`.
- **Check:** spaces; every sale must point to a product (the product part of `prd_key`, from character 7).

```sql
SELECT sls_ord_num, sls_prd_key
FROM bronze.crm_sales_details
WHERE sls_prd_key != TRIM(sls_prd_key)
   OR sls_prd_key NOT IN (SELECT SUBSTRING(prd_key, 7, CHAR_LENGTH(prd_key)) FROM bronze.crm_prd_info);
```

- **Found:** no problems.
- **Modification:** none, copied unchanged.
- **Test:** every `sls_prd_key` exists in `silver.crm_prd_info`.

### `sls_cust_id`

- **Import:** INT. An empty ID would become `0`.
- **Check:** missing; every sale must point to a customer.

```sql
SELECT sls_ord_num, sls_cust_id
FROM bronze.crm_sales_details
WHERE sls_cust_id IS NULL OR sls_cust_id = 0
   OR sls_cust_id NOT IN (SELECT cst_id FROM bronze.crm_cust_info);
```

- **Found:** no problems.
- **Modification:** none, copied unchanged.
- **Test:** every `sls_cust_id` exists in `silver.crm_cust_info`.

### `sls_order_dt`, `sls_ship_dt`, `sls_due_dt`

- **Import:** INT, a date written as a number `YYYYMMDD`, e.g. `20101229`.
- **Check:** a valid date has 8 digits and a sensible range.

```sql
SELECT sls_order_dt, COUNT(*) AS occurrences
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
   OR CHAR_LENGTH(sls_order_dt) != 8     -- a valid date has 8 digits (20101211)
   OR sls_order_dt > 20500101            -- too big
   OR sls_order_dt < 19000101            -- too small
GROUP BY sls_order_dt;                   -- same for sls_ship_dt and sls_due_dt

-- dates in the wrong order (only valid order dates)
SELECT *
FROM bronze.crm_sales_details
WHERE CHAR_LENGTH(sls_order_dt) = 8
  AND (sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt);
```

- **Found:** `sls_order_dt`: `0`, `5489`, `32154` (19 rows). `sls_ship_dt` and `sls_due_dt`: no problems. No dates in the wrong order.
- **Modification:** invalid → NULL, valid → DATE. The same rule for all three columns.

```sql
CASE
    WHEN sls_order_dt <= 0 OR CHAR_LENGTH(sls_order_dt) != 8
      OR sls_order_dt > 20500101 OR sls_order_dt < 19000101 THEN NULL
    ELSE CAST(CAST(sls_order_dt AS CHAR) AS DATE)
END AS sls_order_dt
```

1. `CAST(sls_order_dt AS CHAR)`: number → text, `20101229` → `'20101229'`.
2. `CAST(... AS DATE)`: text → date, `'20101229'` → `2010-12-29`.
3. The result for invalid dates must be the real `NULL`, not the text `'NULL'`.

- **Test:** 19 NULL order dates, 0 NULL ship and due dates; order date never after ship or due date.

### `sls_sales`, `sls_quantity`, `sls_price`

- **Import:** INT. An empty sales or price becomes `0`.
- **Check:** business rule `sales = quantity × price`, and none of them NULL, zero or negative.

```sql
SELECT sls_sales, sls_quantity, sls_price, COUNT(*) AS occurrences
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price
   OR sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0    OR sls_quantity <= 0    OR sls_price <= 0
GROUP BY sls_sales, sls_quantity, sls_price
ORDER BY 1, 2, 3;
```

- **Found:** 8 empty sales (`0`), 7 empty prices (`0`), negative sales and prices, sales ≠ quantity × price. `sls_quantity` has no problems.
- **Modification:** rules:
  - **If sales is missing, zero, negative or not equal to quantity × price, calculate it from quantity and price.**
  - **If price is missing (`0`), calculate it from sales and quantity.**
  - **If price is negative, convert it to a positive value.**
  - `sls_quantity` is copied unchanged.

```sql
CASE
    WHEN sls_sales IS NULL OR sls_sales <= 0
      OR (sls_price != 0 AND sls_sales != ABS(sls_quantity) * ABS(sls_price))
        THEN ABS(sls_quantity) * ABS(sls_price)
    ELSE sls_sales
END AS sls_sales,
sls_quantity,
CASE
    WHEN sls_price IS NULL OR sls_price = 0 THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
    WHEN sls_price < 0                      THEN ABS(sls_price)
    ELSE sls_price
END AS sls_price
```

| sls_sales | sls_quantity | sls_price | → sales | → price | Why |
|---|---|---|---|---|---|
| `0` (empty) | 1 | 35 | 35 | 35 | sales missing |
| -54 | 1 | 54 | 54 | 54 | sales negative |
| -18 | 1 | 9 | 9 | 9 | sales negative and wrong |
| 2 | 1 | 50 | 50 | 50 | sales ≠ quantity × price |
| 9 | 1 | `0` (empty) | 9 | 9 | price missing → from sales |
| 10 | 2 | `0` (empty) | 10 | 5 | price missing → from sales |
| 10 | 1 | -10 | 10 | 10 | price negative → positive |

- `ABS()` makes a negative number positive.
- `NULLIF(sls_quantity, 0)` prevents division by zero.
- `sls_price != 0 AND ...`: when the price is missing (`0`), the sales value is kept, not compared with `quantity × 0`. Without this, a correct sales value like `10` would become `0`. The kept sales value is then used to calculate the price.

- **Test:** no NULL, nothing ≤ 0, and `sales = quantity × price` in every row.

### Summary: crm_sales_details

| Column | Before | After | Modification |
|---|---|---|---|
| `sls_ord_num` | `SO43697` | `SO43697` | Unchanged |
| `sls_prd_key` | `BK-R93R-62` | `BK-R93R-62` | Unchanged |
| `sls_cust_id` | `21768` | `21768` | Unchanged |
| `sls_order_dt` | `20101229`, `0`, `5489` | `2010-12-29`, NULL, NULL | Number → DATE; invalid → NULL |
| `sls_ship_dt` | `20110105` | `2011-01-05` | Number → DATE; invalid → NULL |
| `sls_due_dt` | `20110110` | `2011-01-10` | Number → DATE; invalid → NULL |
| `sls_sales` | `0` (empty), `-54`, `2` (wrong) | quantity × price | Recalculate when missing, ≤ 0 or wrong |
| `sls_quantity` | `1` | `1` | Unchanged |
| `sls_price` | `0` (empty), `-10` | from sales, or positive | Calculate from sales, or `ABS` |
```SQL
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
```
---

## Table: erp_cust_az12

Source: `CUST_AZ12.csv`. Bronze: 18,484 rows, 1 import warning (last line). Silver: 18,484 rows.

### `cid`

- **Import:** VARCHAR, e.g. `NASAW00011000`.
- **Check:** missing or spaces; the `NAS` prefix; after removing it, does every ID exist in CRM?

```sql
SELECT cid
FROM bronze.erp_cust_az12
WHERE cid IS NULL OR cid = '' OR cid != TRIM(cid);

SELECT COUNT(*) AS nas_prefix
FROM bronze.erp_cust_az12
WHERE cid LIKE 'NAS%';
```

- **Found:** no missing values or spaces. 11,042 IDs start with `NAS` (`NASAW00011000`), but the CRM key is `AW00011000`. After removing `NAS`, every ID exists in CRM.
- **Modification:** remove `NAS` if `cid` starts with `NAS`.

```sql
CASE
    WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, CHAR_LENGTH(cid))
    ELSE cid
END AS cid
```

`LIKE 'NAS%'`: starts with `NAS` (`%` = any characters). `SUBSTRING(cid, 4, ...)` starts after `NAS`: `NASAW00011000` → `AW00011000`.

- **Test:** no `NAS` prefix left; every `cid` exists in `silver.crm_cust_info`.

### `bdate`

- **Import:** DATE.
- **Check:** missing, in the future, very old.

```sql
SELECT bdate
FROM bronze.erp_cust_az12
WHERE bdate IS NULL OR YEAR(bdate) = 0
   OR bdate > CURDATE()
   OR bdate < '1924-01-01'
ORDER BY bdate DESC;
```

- **Found:** 16 birthdates in the future (up to `9999-11-20`). 15 before 1924; they are possible, so they are kept.
- **Modification:** a future birthdate is impossible → NULL.

```sql
CASE
    WHEN bdate > NOW() THEN NULL
    ELSE bdate
END AS bdate
```

- **Test:** no birthdate in the future; the 15 old ones are listed for review.

### `gen`

- **Import:** VARCHAR, as in the file. On the last line the empty value becomes NULL.
- **Check:** all values and how often they appear.

```sql
SELECT gen, COUNT(*) AS occurrences
FROM bronze.erp_cust_az12
GROUP BY gen;
```

- **Found:** `F`, `F `, `Female`, `M`, `M `, `Male`, `''` and NULL.
- **Modification:** `CASE` with `UPPER(TRIM())` and `IN`.

```sql
CASE
    WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
    WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
    ELSE 'n/a'
END AS gen
```

Step 1: `TRIM(gen)` removes spaces at the beginning and end. `'F '` → `'F'`
Step 2: `UPPER(...)` converts the text to uppercase. `'female'` → `'FEMALE'`
Step 3: `IN ('F', 'FEMALE')` checks whether the value matches either `F` or `FEMALE`.

The result uses the same words as `crm_cust_info.cst_gndr` (`Female` / `Male`), so the two sources can be compared and combined.

- **Test:** only `Female`, `Male`, `n/a`.

### Summary: erp_cust_az12

| Column | Before | After | Modification |
|---|---|---|---|
| `cid` | `NASAW00011000` | `AW00011000` | Remove the `NAS` prefix |
| `bdate` | `9999-11-20` | NULL | Future date → NULL |
| `gen` | `F`, `F `, `Female`, `M`, `M `, `Male`, `''`, NULL | `Female`, `Male`, `n/a` | `CASE` with `UPPER(TRIM())` and `IN` |
```SQL
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
```
---

## Table: erp_loc_a101

Source: `LOC_A101.csv`. Bronze: 18,484 rows, no import warnings. Silver: 18,484 rows.

### `cid`

- **Import:** VARCHAR, e.g. `AW-00011000`.
- **Check:** missing or spaces; after removing `-`, does every ID exist in CRM?

```sql
SELECT cid
FROM bronze.erp_loc_a101
WHERE cid IS NULL OR cid = '' OR cid != TRIM(cid)
   OR REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM bronze.crm_cust_info);
```

- **Found:** ERP writes `AW-00011000`, CRM writes `AW00011000`. After removing `-`, every ID exists in CRM.
- **Modification:**

```sql
REPLACE(cid, '-', '') AS cid
```

- **Test:** no `-` left; every `cid` exists in `silver.crm_cust_info`.

### `cntry`

- **Import:** VARCHAR, as in the file.
- **Check:** all values and how often they appear (data standardization and consistency).

```sql
SELECT cntry, COUNT(*) AS occurrences
FROM bronze.erp_loc_a101
GROUP BY cntry
ORDER BY cntry;
```

- **Found:** `''` (332 empty), 5 values that are only spaces, the codes `DE`, `US`, `USA`, and full names: Australia, Canada, France, Germany, United Kingdom, United States.
- **Modification:** codes → full names, empty → `n/a`, `TRIM` for the rest.

```sql
CASE
    WHEN TRIM(cntry) = 'DE'                THEN 'Germany'
    WHEN TRIM(cntry) IN ('US', 'USA')      THEN 'United States'
    WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
    ELSE TRIM(cntry)
END AS cntry
```

A value that is only spaces becomes `''` after `TRIM`, so it also goes to `n/a`.

- **Test:** only full country names and `n/a`; no codes, no blanks, no spaces.

### Summary: erp_loc_a101

| Column | Before | After | Modification |
|---|---|---|---|
| `cid` | `AW-00011000` | `AW00011000` | Remove `-` |
| `cntry` | `DE` | `Germany` | Code → full name |
| `cntry` | `US`, `USA` | `United States` | Code → full name |
| `cntry` | `''`, `'  '`, NULL | `n/a` | Missing → `n/a` |
| `cntry` | `Australia` | `Australia` | `TRIM` |
```SQL
SELECT
    REPLACE(cid, '-', '') AS cid,
    CASE
        WHEN TRIM(cntry) = 'DE'                THEN 'Germany'
        WHEN TRIM(cntry) IN ('US', 'USA')      THEN 'United States'
        WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
        ELSE TRIM(cntry)
    END AS cntry
FROM bronze.erp_loc_a101;
```
---

## Table: erp_px_cat_g1v2

Source: `PX_CAT_G1V2.csv`. Bronze: 37 rows, no import warnings. Silver: 37 rows.

### `id`, `cat`, `subcat`, `maintenance`

- **Import:** VARCHAR, as in the file.
- **Check:** `id` missing, spaces or repeated; spaces in the other columns; all values.

```sql
SELECT id, COUNT(*) AS occurrences
FROM bronze.erp_px_cat_g1v2
GROUP BY id
HAVING COUNT(*) > 1 OR id IS NULL OR id = '' OR id != TRIM(id);

SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

SELECT DISTINCT cat FROM bronze.erp_px_cat_g1v2;   -- same for subcat, maintenance
```

- **Found:** no problems. `cat`: Accessories, Bikes, Clothing, Components. `maintenance`: Yes, No.
- **Modification:** none, all columns copied unchanged.
- **Test:** no duplicate `id`, no blanks or spaces, `maintenance` only `Yes` / `No`.

### Summary: erp_px_cat_g1v2

| Column | Before | After | Modification |
|---|---|---|---|
| `id` | `AC_BR` | `AC_BR` | Unchanged |
| `cat` | `Accessories` | `Accessories` | Unchanged |
| `subcat` | `Bike Racks` | `Bike Racks` | Unchanged |
| `maintenance` | `Yes` | `Yes` | Unchanged |

---

# Gold layer

The gold layer combines the 6 cleaned silver tables into 3 that are easy to use for reports: 2 **dimensions** and 1 **fact**. 

1. **Step 1:** `gold.dim_customers`: join 3 customer tables (CRM + 2 × ERP).
2. **Step 2:** `gold.dim_products`: join 2 product tables (CRM + ERP).
3. **Step 3:** `gold.fact_sales`: sales + the keys of both dimensions.

## Step 1: gold.dim_customers

**Tables joined:**

| Table | Gives | Join key |
|---|---|---|
| `silver.crm_cust_info` (main table) | ID, number, names, marital status, gender, create date | `cst_key` |
| `silver.erp_cust_az12` | birthdate, gender (second source) | `cid` = `cst_key` |
| `silver.erp_loc_a101` | country | `cid` = `cst_key` |

The join only works because silver made the keys equal: `NASAW00011000` → `AW00011000` and `AW-00011000` → `AW00011000`.

### 1.1 Check: no duplicates after the join

A `LEFT JOIN` creates extra rows if a key appears more than once in an ERP table.

```sql
SELECT cst_id, COUNT(*)
FROM (
    SELECT
        ci.cst_id, ci.cst_key, ci.cst_firstname, ci.cst_lastname,
        ci.cst_marital_status, ci.cst_gndr, ci.cst_create_date,
        ca.bdate, ca.gen, la.cntry
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
    LEFT JOIN silver.erp_loc_a101  la ON ci.cst_key = la.cid
) AS t
GROUP BY cst_id
HAVING COUNT(*) > 1;
```

Result: no rows. Every `cid` is unique in both ERP tables, and every CRM customer is found in both.

### 1.2 Problem: two gender columns

After the join there are two gender columns: `cst_gndr` (CRM) and `gen` (ERP). They do not always agree:

```sql
SELECT DISTINCT ci.cst_gndr, ca.gen
FROM silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca ON ci.cst_key = ca.cid
ORDER BY 1, 2;
```

| | cst_gndr | gen |
|---|---|---|
| 1 | Female | Female |
| 2 | Female | Male |
| 3 | Female | n/a |
| 4 | Male | Female |
| 5 | Male | Male |
| 6 | Male | n/a |
| 7 | n/a | NULL |
| 8 | n/a | Female |
| 9 | n/a | Male |
| 10 | n/a | n/a |

Rule: **CRM is the master source. ERP is used only when CRM has `n/a`.**

```sql
CASE
    WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
    ELSE IFNULL(ca.gen, 'n/a')
END AS gender
```

| cst_gndr (CRM) | gen (ERP) | gender (gold) |
|---|---|---|
| Female | Male | Female (CRM wins) |
| Male | n/a | Male |
| n/a | Female | Female (ERP fills the gap) |
| n/a | NULL (no ERP row) | n/a |

### 1.3 Create the view

```sql
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
```

- `crm_cust_info` is the main table. `LEFT JOIN` keeps every CRM customer, even if an ERP table has no row for it (then `country` / `birthdate` are NULL).
- `ROW_NUMBER() OVER (ORDER BY ci.cst_id)` makes the surrogate key `customer_key` (the PK).
- Columns get friendly names: `cst_firstname` → `first_name`, `cntry` → `country`.

| Column | From | Key |
|---|---|---|
| `customer_key` | `ROW_NUMBER()` | **PK** (surrogate) |
| `customer_id` | `crm_cust_info.cst_id` | business key |
| `customer_number` | `crm_cust_info.cst_key` | business key |
| `first_name`, `last_name`, `marital_status`, `create_date` | `crm_cust_info` | |
| `gender` | `crm_cust_info.cst_gndr`, else `erp_cust_az12.gen` | |
| `birthdate` | `erp_cust_az12.bdate` | |
| `country` | `erp_loc_a101.cntry` | |


---

## Step 2: gold.dim_products

**Tables joined:**

| Table | Gives | Join key |
|---|---|---|
| `silver.crm_prd_info` (main table) | ID, number, name, cost, line, start date | `cat_id` |
| `silver.erp_px_cat_g1v2` | category, subcategory, maintenance | `id` = `cat_id` |

The join only works because silver split `prd_key`: `AC-HE-HL-U509-R` → `cat_id` = `AC_HE`, which matches `erp_px_cat_g1v2.id`.

### 2.1 Check: categories that do not exist in ERP

```sql
SELECT DISTINCT cat_id
FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2);
```

Result: `CO_PE`. It is missing in the ERP source. 

### 2.2 Check: no duplicates after the join

Each product must appear only once in `dim_products`. Check it after the join:

```sql
SELECT prd_key, COUNT(*)
FROM (
    SELECT
        pn.prd_id, pn.cat_id, pn.prd_key, pn.prd_nm, pn.prd_cost,
        pn.prd_line, pn.prd_start_dt, pn.prd_end_dt,
        pc.cat, pc.subcat, pc.maintenance
    FROM silver.crm_prd_info pn
    LEFT JOIN silver.erp_px_cat_g1v2 pc ON pn.cat_id = pc.id
    WHERE pn.prd_end_dt IS NULL
) AS t
GROUP BY prd_key
HAVING COUNT(*) > 1;
```

Result: no rows.

### 2.3 Why `WHERE prd_end_dt IS NULL`

`silver.crm_prd_info` keeps every **version** of a product: a new row each time something changes, e.g. the cost. `prd_end_dt` (rebuilt with `LEAD` in silver) shows which version is current:

| prd_id | prd_key | prd_cost | prd_start_dt | prd_end_dt | |
|---|---|---|---|---|---|
| 212 | HL-U509-R | 12 | 2011-07-01 | 2012-06-30 | old version |
| 213 | HL-U509-R | 14 | 2012-07-01 | 2013-06-30 | old version |
| 214 | HL-U509-R | 13 | 2013-07-01 | **NULL** | **current version** |

- `prd_end_dt IS NULL` means "this version has not ended": it is the **current** version.
- `WHERE pn.prd_end_dt IS NULL` keeps only that row (214) and drops the history (212, 213).

### 2.4 Create the view

```sql
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
```

| Column                                               | From                   | Key                        |
| ---------------------------------------------------- | ---------------------- | -------------------------- |
| `product_key`                                        | `ROW_NUMBER()`         | **PK** (surrogate)         |
| `product_id`                                         | `crm_prd_info.prd_id`  | business key               |
| `product_number`                                     | `crm_prd_info.prd_key` | business key               |
| `category_id`                                        | `crm_prd_info.cat_id`  | business key (join to ERP) |
| `product_name`, `cost`, `product_line`, `start_date` | `crm_prd_info`         |                            |
| `category`, `subcategory`, `maintenance`             | `erp_px_cat_g1v2`      |                            |


---

## Step 3: gold.fact_sales

**Tables joined:**

| Table | Gives | Join key |
|---|---|---|
| `silver.crm_sales_details` (main table) | order number, dates, sales, quantity, price | `sls_prd_key`, `sls_cust_id` |
| `gold.dim_products` (step 2) | `product_key` | `product_number` = `sls_prd_key` |
| `gold.dim_customers` (step 1) | `customer_key` | `customer_id` = `sls_cust_id` |

The business keys from silver are used once, to look up the surrogate keys. The fact keeps only the surrogate keys (FK).

### 3.1 Check: every sale finds its product and customer (in silver)

```sql
SELECT sls_ord_num, sls_prd_key
FROM silver.crm_sales_details
WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info);

SELECT sls_ord_num, sls_cust_id
FROM silver.crm_sales_details
WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info);
```

Result: no rows (also in `quality_checks_silver.sql`).

### 3.2 How the fact gets the surrogate keys: LEFT JOIN

The surrogate keys are made only once, in the dimensions (steps 1 and 2). `fact_sales` does **not** make its own numbers. It **looks them up** with a `LEFT JOIN` on the business keys, and then keeps the surrogate keys instead of `sls_cust_id` and `sls_prd_key`:

```sql
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_products AS pr
       ON sd.sls_prd_key = pr.product_number    -- find the product
LEFT JOIN gold.dim_customers AS cu
       ON sd.sls_cust_id = cu.customer_id       -- find the customer
```

### 3.3 Create the view

```sql
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
```

- `LEFT JOIN` keeps every sale; if a key is not found, the FK is NULL and the quality check shows it.

| Column | From | Key |
|---|---|---|
| `order_number` | `crm_sales_details.sls_ord_num` | |
| `product_key` | `dim_products.product_key` | **FK** → `dim_products` |
| `customer_key` | `dim_customers.customer_key` | **FK** → `dim_customers` |
| `order_date`, `shipping_date`, `due_date` | `crm_sales_details` | |
| `sales_amount`, `quantity`, `price` | `crm_sales_details` | |

---

**Example question:** sales per country and category.

```sql
SELECT c.country, p.category, SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales AS f
JOIN gold.dim_customers AS c ON f.customer_key = c.customer_key
JOIN gold.dim_products  AS p ON f.product_key  = p.product_key
GROUP BY c.country, p.category
ORDER BY total_sales DESC;
```

