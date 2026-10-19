
/*
===============================================================================
Change Over Time Analysis - PostgreSQL
===============================================================================
Purpose:
    - To track trends, growth, and changes in key metrics over time.
    - For time-series analysis and identifying seasonality.
    - To measure growth or decline over specific periods.
===============================================================================
*/

-- Analyse sales performance over time
-- Quick Date Functions: EXTRACT()
SELECT
    EXTRACT(YEAR FROM order_date) AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    EXTRACT(YEAR FROM order_date),
    EXTRACT(MONTH FROM order_date)
ORDER BY
    order_year,
    order_month;


-- DATE_TRUNC()
SELECT
    DATE_TRUNC('month', order_date)::date AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);


-- TO_CHAR() - Formatting dates
SELECT
    TO_CHAR(order_date, 'YYYY-Mon') AS order_date,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY
    TO_CHAR(order_date, 'YYYY-Mon'),
    DATE_TRUNC('month', order_date)
ORDER BY DATE_TRUNC('month', order_date);
