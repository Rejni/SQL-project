# Project 01: Sales analytics

## Structure

```text
Project 01/
├── PostgreSQL/  # PostgreSQL queries
├── MySQL/       # MySQL queries
└── README.md
```

Both dialect folders contain the same files:

| File | Analysis |
| --- | --- |
| `01.sql` | Magnitude: customers, products, costs, and revenue |
| `02_Ranking.sql` | Best and worst products and customers |
| `03_Time_Analysis.sql` | Monthly sales trends |
| `04_Cumulative_Analysis.sql` | Running sales totals and average prices |
| `05_Segmentation_Analysis.sql` | Customer spending and lifespan segments |
| `06_Customer_Report.sql` | Customer metrics and KPIs |
| `07_Product_Report.sql` | Product metrics and KPIs |

## Running the queries

1. Load your dataset into the selected database. These scripts query existing
   tables; this repository does not include table definitions or sample data.
2. Use the same table and column names as the original project:
   - `dim_customers`: `customer_key`, `customer_number`, `first_name`, `last_name`,
     `country`, `gender`, `birthdate`.
   - `dim_product`: `product_key`, `product_name`, `category`, `subcategory`, `cost`.
   - `fact_sales`: `order_number`, `product_key`, `customer_key`, `order_date`,
     `sales_amount`, `quantity`, `price`.
3. Use date-compatible types for `birthdate` and `order_date`, and numeric types
   for the measures. Use `NUMERIC`/`DECIMAL` for monetary values so averages,
   division, and rounding use decimal arithmetic.
4. Open the folder matching your database and run the desired SQL file in your
   query editor, connected to your database/schema. The files can run independently.

MySQL requires **8.0 or later** for CTEs and window functions. The queries use
explicit grouping compatible with `ONLY_FULL_GROUP_BY`; changing SQL mode is
unnecessary. Dates should be valid dates, without MySQL zero-date values.

The reports return query results. The optional `CREATE VIEW` line in the customer
report remains commented out.

## Dialect differences

| PostgreSQL | MySQL |
| --- | --- |
| `DATE_TRUNC('month', order_date)::date` | `CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)` |
| `TO_CHAR(order_date, 'YYYY-Mon')` | `DATE_FORMAT(order_date, '%Y-%b')` |
| Year/month parts of `AGE(last_date, first_date)` | `TIMESTAMPDIFF(MONTH, first_date, last_date)` |
| Age in years from `AGE(birthdate)` | `TIMESTAMPDIFF(YEAR, birthdate, CURRENT_DATE)` |
| `CONCAT(first_name, ' ', last_name)` | `CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))` |

The name expression preserves PostgreSQL's treatment of NULL name components.
Monthly labels depend on the database locale; use matching English locale settings
for identical abbreviated month names. Session time zones should also match when
comparing timestamp-based data or reports using the current date.

Customer lifespan uses completed months. Customer recency and product lifespan
retain the original calendar-month subtraction (year × 12 + month), which counts
month boundaries regardless of the day. These are deliberately different metrics.
The customer segmentation labels and report calculations are retained from the
original scripts, including the `Reglar` spelling in the segmentation examples.

In both dialects, the second segmentation example repeats its CTE because a CTE
is visible only to the statement immediately following it. Previously that example
referenced a CTE from an already completed statement.

MySQL references:
- [Date and time functions](https://dev.mysql.com/doc/refman/8.0/en/date-and-time-functions.html)
- [Common table expressions](https://dev.mysql.com/doc/refman/8.0/en/with.html)

## MySQL compatibility verification

The MySQL scripts use `YEAR()` and `MONTH()` for date parts. MySQL also supports
`EXTRACT()`, but a space between `EXTRACT` and `(` causes a syntax error unless
`IGNORE_SPACE` is enabled. The scripts do not require `IGNORE_SPACE`.

On 2026-10-19, all seven MySQL files (20 statements) were executed successfully
on an isolated MySQL 8.0.34 server with `ONLY_FULL_GROUP_BY`, strict date checks,
and division-by-zero checking enabled. Every file ran against populated sample
tables and empty tables. Result checks covered customer segmentation, NULL names
and dates, zero quantities, completed-month lifespan, calendar-month recency and
product lifespan, average order values, monthly sales, and running totals.

All 14 SQL files were also parsed using their respective SQL dialects.
PostgreSQL files were unchanged by this MySQL compatibility correction.
Testing used sample data, not the user's database or production schema.

Reference: [MySQL function name parsing](https://dev.mysql.com/doc/refman/8.0/en/function-resolution.html).
