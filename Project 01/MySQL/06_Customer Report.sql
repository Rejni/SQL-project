-- Dialect: MySQL 8.0 or later
-- Customer Report
-- =============================================================================
-- Purpose:
--   - This report consolidates key customer metrics and behaviors

-- Highlights:
--   1. Gathers essential fields such as names, ages, and transaction details.
--   2. Segments customers into categories (VIP, Regular, New) and age groups.
--   3. Aggregates customer-level metrics:
--      - total orders
--      - total sales
--      - total quantity purchased
--      - total products
--      - lifespan (in months)
--   4. Calculates valuable KPIs:
--      - recency (months since last order)
--      - average order value
--      - average monthly spend


-- Create view report_customers  as 
With base_query as (
-- 1.
SELECT 
 f.order_number, 
 f.product_key,
 f.order_date,
 f.sales_amount,
 f.quantity,
 c.customer_key,
 c.customer_number,
 c.birthdate,
 CONCAT(COALESCE(c.first_name, ''), ' ', COALESCE(c.last_name, '')) as customer_name,
TIMESTAMPDIFF(YEAR, c.birthdate, CURRENT_DATE) as age 
FROM fact_sales f
LEFT JOIN dim_customers c on f.customer_key = c.customer_key
where c.birthdate IS NOT NULL and f.order_date IS NOT NULL
order by f.order_date desc
),
-- 3.
customer_agregation as (
SELECT
customer_key,
customer_number,
customer_name,
age,
count(DISTINCT(order_number)) as total_orders,
SUM(sales_amount) as total_sales,
SUM(quantity) as  total_quantity,
count(DISTINCT(product_key)) as total_product,
MAX(order_date) as last_order_date,
TIMESTAMPDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
group by 
customer_key,
customer_number,
customer_name,
age
order by lifespan
)
-- 2. and 4.
SELECT
customer_key,
customer_number,
customer_name,
age,
CASE 
	WHEN age <= 20 then 'Under or equal  20'
	WHEN age <= 30 then 'Under or equal 30'
	WHEN age <= 40 then 'Under or equal 40'
	WHEN age <= 50 then 'Under or equal 50'
	WHEN age <= 60 then 'Under or equal 60'
	WHEN age <= 70 then 'Under or equal 70'
	Else 'Above 80'
END as age_group,
total_orders,
total_sales,
total_quantity,
total_product,
last_order_date,
lifespan,
 (Extract( Year from CURRENT_DATE) * 12 + EXTRACT (Month from CURRENT_DATE)) - (Extract( Year from last_order_date)*12 + Extract( MONTH from last_order_date)) as recency,
CASE 
	WHEN lifespan >= 12 and total_sales>5000 then 'VIP'
	WHEN lifespan >= 12 and total_sales<=5000 then 'Regular'
	Else 'New'
END as customer_segment,
CASE 
	WHEN total_orders = 0 then 0
	ELSE ROUND(total_sales / total_orders,2) 
END as avg_order_value,
CASE
	WHEN lifespan = 0 then total_sales
	ELSE total_sales / lifespan
END as avg_monthly_spend

FROM customer_agregation
order by recency desc;
