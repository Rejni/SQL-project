-- Dialect: MySQL 8.0 or later

/*
===============================================================================
Change Over Time Analysis - MySQL 8.0+
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.
===============================================================================
*/

-- Analyse sales performance over time
-- MySQL date functions: YEAR(), MONTH()
SELECT
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    YEAR(order_date),
    MONTH(order_date)
ORDER BY
    order_year,
    order_month;


-- Month start as a DATE
SELECT
    CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE) AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)
ORDER BY CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE);


-- DATE_FORMAT() - Formatting dates
SELECT
    DATE_FORMAT(order_date, '%Y-%b') AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    DATE_FORMAT(order_date, '%Y-%b'),
    CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE)
ORDER BY CAST(DATE_FORMAT(order_date, '%Y-%m-01') AS DATE);
