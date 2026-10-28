-- Dialect: MySQL 8.0 or later
-- =============================================================================
-- Product Report
-- =============================================================================
-- Purpose:
--   - This report consolidates key product metrics and behaviors.

-- Highlights:
--   1. Gathers essential fields such as product name, category, subcategory, and cost.
--   2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
--   3. Aggregates product-level metrics:
--      - total orders
--      - total sales
--      - total quantity sold
--      - total customers (unique)
--      - lifespan (in months)
--   4. Calculates valuable KPIs:
--      - recency (months since last sale)
--      - average order revenue (AOR)
--      - average monthly revenue

With base_query as (
-- 1.
SELECT 
f.order_number,
f.order_date,
f.customer_key,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost
FROM dim_product p
LEFT JOIN fact_sales f ON p.product_key = f.product_key 
WHERE f.order_date IS NOT NULL
order by f.order_date desc
),
product_agregation as (
-- 3.
SELECT 
product_key,
product_name,
category,
subcategory,
SUM(sales_amount) as total_sales,
SUM(quantity) as total_quantity,
COUNT(DISTINCT (order_number)) as total_orders,
COUNT(DISTINCT (customer_key)) as total_customers,
(YEAR(MAX(order_date))*12 + MONTH(MAX(order_date))) - (YEAR(MIN(order_date))*12 + MONTH(MIN(order_date))) as lifespan,
-- ??? avg_selling_price
ROUND(AVG(sales_amount / NULLIF(quantity,0)),2) as avg_selling_price
FROM base_query
GROUP BY category, subcategory, product_name, product_key
order by category, subcategory, product_name
)

Select
product_key,
product_name,
category,
subcategory,
total_sales,
total_quantity,
total_orders,
total_customers,
case
	when total_sales>50000 then 'High-Performer'
	when total_sales>=10000 then 'Mid-Range'
	ELSE 'Low-Perfermer'
END as product_segment,
lifespan,
-- average order revenue (AOR)
CASE
	when total_orders = 0 then 0
	ELSE ROUND(total_sales / total_orders,2)
END as avg_order_revenue,
-- average monthly revenue
CASE
	when lifespan = 0 then 0
	ELSE ROUND(total_sales / lifespan,2)
END as avg_monthly_revenue
from product_agregation;
