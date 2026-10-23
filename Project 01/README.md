# Project 01: SQL Data Analytics — Sales Analysis

A collection of SQL scripts for data exploration, analytics, and reporting, focused on sales performance, customer behavior, and product trends.

This project contains **seven analytical modules implemented in PostgreSQL and MySQL**. Each module focuses on a specific analytical topic, from exploring key business metrics to analyzing time-based trends, customer segmentation, and product performance.

The goal is to practice SQL techniques commonly used in data analytics and business intelligence, while exploring the differences between two relational database systems.

## Project Structure

```text
Project 01/
├── Database/
│   ├── dim_customers.csv
│   ├── dim_products.csv
│   └── fact_sales.csv
├── PostgreSQL/
│   ├── 01.sql
│   ├── 02_Ranking.sql
│   ├── 03_Time_Analysis.sql
│   ├── 04_Cumulative_Analysis.sql
│   ├── 05_Segmentation_Analysis.sql
│   ├── 06_Customer_Report.sql
│   └── 07_Product_Report.sql
├── MySQL/
│   └── [Same seven SQL files]
└── README.md
```

## SQL Analyses

The project covers the following analytical areas:

| Analysis | Description |
|---|---|
| **01. Magnitude Analysis** | Explore key metrics such as total customers, products, costs, and revenue. |
| **02. Ranking Analysis** | Identify top-performing and underperforming products and customers. |
| **03. Time-Based Analysis** | Analyze monthly sales trends and performance over time. |
| **04. Cumulative Analysis** | Calculate running sales totals and cumulative metrics. |
| **05. Segmentation Analysis** | Group customers based on spending behavior and lifespan. |
| **06. Customer Report** | Generate customer-level metrics and KPIs. |
| **07. Product Report** | Generate product-level metrics and KPIs. |

## Technologies and SQL Concepts

**Databases**
- PostgreSQL
- MySQL 8.0+

**SQL concepts**
- Aggregation and grouping
- Joins and subqueries
- Common Table Expressions (CTEs)
- Window functions
- Date and time functions
- Ranking and segmentation
- Analytical reporting

## Dataset

The project uses a relational sales dataset consisting of three main tables:

| Table | Description | Columns |
|---|---|---|
| `dim_customers` | Customer information and demographic attributes used for customer analysis and segmentation. | `customer_key`, `customer_number`, `first_name`, `last_name`, `country`, `gender`, `birthdate` |
| `dim_product` | Product information, including product classifications and costs, used for product performance analysis. | `product_key`, `product_name`, `category`, `subcategory`, `cost` |
| `fact_sales` | Sales transactions containing order details, quantities, prices, and revenue. | `order_number`, `product_key`, `customer_key`, `order_date`, `sales_amount`, `quantity`, `price` |

## PostgreSQL vs. MySQL

The project implements the same analytical queries in PostgreSQL and MySQL, demonstrating differences in SQL syntax and built-in functions.

| Functionality | PostgreSQL | MySQL |
|---|---|---|
| Monthly date grouping | `DATE_TRUNC('month', order_date)::date` | `CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)` |
| Date formatting | `TO_CHAR(order_date, 'YYYY-Mon')` | `DATE_FORMAT(order_date, '%Y-%b')` |
| Date differences in months | Year and month components of `AGE(last_date, first_date)` | `TIMESTAMPDIFF(MONTH, first_date, last_date)` |
| Customer age calculation | `EXTRACT(YEAR FROM AGE(birthdate))` | `TIMESTAMPDIFF(YEAR, birthdate, CURRENT_DATE)` |
| NULL-safe name concatenation | `CONCAT(first_name, ' ', last_name)` | `CONCAT(COALESCE(first_name, ''), ' ', COALESCE(last_name, ''))` |

These adaptations help maintain consistent analytical logic across both database systems while accounting for differences in date handling, formatting, and NULL behavior.

**Note:** Date-difference calculations may produce slightly different results in edge cases because PostgreSQL and MySQL handle calendar intervals differently.

The SQL scripts expect these tables and their corresponding columns to exist in the database.


## Getting Started

1. Set up a PostgreSQL or MySQL database.
2. Load a compatible sales dataset containing the required tables.
3. Open the `PostgreSQL` or `MySQL` directory.
4. Execute the selected SQL script in your SQL editor.

The SQL files can be executed independently, provided the necessary tables and columns are available.

## PostgreSQL vs. MySQL

The project includes equivalent analyses for both database systems, demonstrating differences in SQL syntax and built-in functions.

| Functionality | PostgreSQL | MySQL |
|---|---|---|
| Monthly date grouping | `DATE_TRUNC()` | `DATE_FORMAT()` |
| Date formatting | `TO_CHAR()` | `DATE_FORMAT()` |
| Date differences | `AGE()` | `TIMESTAMPDIFF()` |


Some differences in date calculations, NULL handling, and formatting may affect results. These are accounted for in the corresponding implementations.


## Learning Resources

This project is based on the [SQL Data Analyst Portfolio Project](https://www.youtube.com/watch?v=2jGhQpbzHes) tutorial by **Data with Baraa**.

The SQL implementations are organized for PostgreSQL and MySQL to practice analytical querying across both database systems.

