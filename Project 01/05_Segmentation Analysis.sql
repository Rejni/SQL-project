
/*
===============================================================================
Data Segmentation Analysis - PostgreSQL
===============================================================================
Purpose:
    - To group data into meaningful categories.
    - To analyze customer spending and product costs.
===============================================================================
*/

With customers_lifespan as (
SELECT
c.customer_key,
SUM(f.sales_amount) as total_spending,
MIN(f.order_date) as fist_date,
MAX(f.order_date) as last_date,
EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12
+ EXTRACT(MONTH FROM AGE(MAX(order_date), MIN(order_date))) AS lifespan
FROM fact_sales f
LEFT JOIN dim_customers c
ON c.customer_key = f.customer_key
Group by c.customer_key
HAVING EXTRACT(YEAR FROM AGE(MAX(order_date), MIN(order_date))) * 12
+ EXTRACT(MONTH FROM AGE(MAX(order_date), MIN(order_date))) IS NOT NULL
order by lifespan DESC
)

select 
/*customer_key, total_spending, lifespan,*/
count(customer_key) as total_customers,
CASE when lifespan>=12 and total_spending>5000 then 'VIP'
	when lifespan>=12 and total_spending<=5000 then 'Reglar'
	Else 'New'
	End customer_segment
from customers_lifespan
Group by 
CASE when lifespan>=12 and total_spending>5000 then 'VIP'
	when lifespan>=12 and total_spending<=5000 then 'Reglar'
	Else 'New'
	End;
/* the same */
SELECT 
customer_segment,
count(customer_key)
FROM (
select 
/*customer_key, total_spending, lifespan,*/
customer_key,
CASE when lifespan>=12 and total_spending>5000 then 'VIP'
	when lifespan>=12 and total_spending<=5000 then 'Reglar'
	Else 'New'
	End customer_segment
from customers_lifespan ) as t
Group by customer_segment
order by 2 desc;
---- 