-- Section B — Questions 6–10
-- Run questions in order. Intentional errors are in labelled comment blocks.


-- Q06. County leaderboards
-- Result (reference test): 42. Confirm in DBeaver before submission.
-- Required concept: DENSE_RANK by county.
-- Screenshot: screenshots/section_b/q06_result.png (add _summary, _before, _after, _error as needed).

WITH spending AS (
 SELECT c.customer_id,c.first_name||' '||c.last_name AS full_name,c.county,
        COALESCE(SUM(i.line_total),0) AS total_spent
 FROM sokomart.customers c
 LEFT JOIN sokomart.orders o ON o.customer_id=c.customer_id AND o.order_status='completed'
 LEFT JOIN sokomart.order_items i ON i.order_id=o.order_id
 GROUP BY c.customer_id,c.first_name,c.last_name,c.county
), ranked AS (
 SELECT *,DENSE_RANK() OVER(PARTITION BY county ORDER BY total_spent DESC) AS county_rank FROM spending
)
SELECT county,county_rank,customer_id,full_name,total_spent
FROM ranked WHERE county_rank<=3 ORDER BY county,county_rank,customer_id;


-- Q07. Best sellers per category in 2025
-- Result (reference test): 15. Confirm in DBeaver before submission.
-- Required concept: ROW_NUMBER by category.
-- Screenshot: screenshots/section_b/q07_result.png (add _summary, _before, _after, _error as needed).

WITH sales AS (
 SELECT p.category,p.product_id,p.product_name,SUM(i.line_total) AS revenue,SUM(i.quantity) AS units_sold
 FROM sokomart.products p JOIN sokomart.order_items i USING(product_id) JOIN sokomart.orders o USING(order_id)
 WHERE o.order_status='completed' AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
 GROUP BY p.category,p.product_id,p.product_name
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY category ORDER BY revenue DESC,product_id) AS rank_in_category FROM sales
)
SELECT category,rank_in_category,product_id,product_name,revenue,units_sold
FROM ranked WHERE rank_in_category<=3 ORDER BY category,rank_in_category;


-- Q08. Month-over-month growth
-- Result (reference test): 22. Confirm in DBeaver before submission.
-- Required concept: LAG and NULLIF.
-- Screenshot: screenshots/section_b/q08_result.png (add _summary, _before, _after, _error as needed).

WITH monthly AS (SELECT DATE_TRUNC('month',o.order_date) AS month,SUM(i.line_total) AS revenue
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id)
 WHERE o.order_status='completed' GROUP BY DATE_TRUNC('month',o.order_date)), previous AS (
 SELECT *,LAG(revenue) OVER(ORDER BY month) AS prev_month_revenue FROM monthly
)
SELECT TO_CHAR(month,'YYYY-MM') AS month,revenue,prev_month_revenue,
 ROUND(100.0*(revenue-prev_month_revenue)/NULLIF(prev_month_revenue,0),2) AS growth_pct
FROM previous ORDER BY previous.month;


-- Q09. Is each order bigger than the last
-- Result (reference test): 393; summary: 1. Confirm in DBeaver before submission.
-- Required concept: LAG by customer.
-- Screenshot: screenshots/section_b/q09_result.png (add _summary, _before, _after, _error as needed).

WITH previous AS (
 SELECT c.customer_id,o.order_id,o.order_date,o.total_amount,
 LAG(o.total_amount) OVER(PARTITION BY c.customer_id ORDER BY o.order_date,o.order_id) AS previous_order_amount
 FROM sokomart.customers c JOIN sokomart.orders o USING(customer_id)
 WHERE c.county='Nyeri' AND o.order_status='completed'
 AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
), directions AS (
 SELECT *,total_amount-previous_order_amount AS change_amount,
 CASE WHEN previous_order_amount IS NULL THEN 'first order'
 WHEN total_amount>previous_order_amount THEN 'up'
 WHEN total_amount<previous_order_amount THEN 'down' ELSE 'same' END AS direction FROM previous
)
SELECT customer_id,order_id,order_date,total_amount,previous_order_amount,change_amount,direction
FROM directions ORDER BY customer_id,order_date,order_id;
WITH previous AS (
 SELECT c.customer_id,o.order_id,o.order_date,o.total_amount,
 LAG(o.total_amount) OVER(PARTITION BY c.customer_id ORDER BY o.order_date,o.order_id) AS previous_order_amount
 FROM sokomart.customers c JOIN sokomart.orders o USING(customer_id)
 WHERE c.county='Nyeri' AND o.order_status='completed'
 AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
), directions AS (
 SELECT *,total_amount-previous_order_amount AS change_amount,
 CASE WHEN previous_order_amount IS NULL THEN 'first order'
 WHEN total_amount>previous_order_amount THEN 'up'
 WHEN total_amount<previous_order_amount THEN 'down' ELSE 'same' END AS direction FROM previous
)
SELECT COUNT(*) AS total_rows,COUNT(DISTINCT customer_id) AS distinct_customers,
 COUNT(*) FILTER(WHERE direction='first order') AS first_orders,
 COUNT(*) FILTER(WHERE direction='up') AS orders_bigger,
 COUNT(*) FILTER(WHERE direction='down') AS orders_smaller FROM directions;


-- Q10. Year-to-date revenue
-- Result (reference test): 22. Confirm in DBeaver before submission.
-- Required concept: SUM OVER with explicit ROWS frame.
-- Screenshot: screenshots/section_b/q10_result.png (add _summary, _before, _after, _error as needed).

WITH monthly AS (SELECT DATE_TRUNC('month',o.order_date) AS month,SUM(i.line_total) AS revenue
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id)
 WHERE o.order_status='completed' GROUP BY DATE_TRUNC('month',o.order_date))
SELECT EXTRACT(YEAR FROM month)::integer AS year,TO_CHAR(month,'YYYY-MM') AS month,revenue AS monthly_revenue,
 SUM(revenue) OVER(PARTITION BY EXTRACT(YEAR FROM month) ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue_ytd,
 SUM(revenue) OVER(ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS running_revenue_all_time
FROM monthly ORDER BY monthly.month;
