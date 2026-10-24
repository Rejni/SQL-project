/*
===============================================================================
Purpose:
    - To calculate running totals or moving averages.
    - To track performance over time cumulatively.
===============================================================================
*/

-- Calculate total sales per year
-- and the running total of sales over time

SELECT
    order_date,
    total_sales,
    ROUND(SUM(total_sales) OVER (ORDER BY order_date), 2) AS running_total_sales,
    ROUND(AVG(avg_price) OVER (ORDER BY order_date), 2) AS moving_average_price
FROM
(
    SELECT
        -- MAKEDATE(YEAR(order_date), 1) AS order_date,
		YEAR(order_date) AS order_date,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY YEAR(order_date)
) AS t
ORDER BY order_date;

