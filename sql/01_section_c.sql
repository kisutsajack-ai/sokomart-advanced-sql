-- Section C — Questions 11–15
-- Run questions in order. Intentional errors are in labelled comment blocks.


-- Q11. Customer tiers
-- Result (reference test): 4. Confirm in DBeaver before submission.
-- Required concept: Nested derived tables, CASE, scalar subquery.
-- Screenshot: screenshots/section_c/q11_result.png (add _summary, _before, _after, _error as needed).

SELECT tier,COUNT(*) AS customer_count,MIN(total_spent) AS min_spent,MAX(total_spent) AS max_spent,
 ROUND(AVG(total_spent),2) AS avg_spent,
 ROUND(100.0*SUM(total_spent)/(SELECT SUM(i.line_total) FROM sokomart.order_items i
 JOIN sokomart.orders o USING(order_id) WHERE o.order_status='completed'),2) AS revenue_share_pct
FROM (
 SELECT customer_id,total_spent,CASE WHEN total_spent>=1000000 THEN 'Platinum'
 WHEN total_spent>=500000 THEN 'Gold' WHEN total_spent>=100000 THEN 'Silver' ELSE 'Bronze' END AS tier
 FROM (
  SELECT o.customer_id,SUM(i.line_total) AS total_spent FROM sokomart.orders o
  JOIN sokomart.order_items i USING(order_id) WHERE o.order_status='completed' GROUP BY o.customer_id
 ) spending
) tiers
GROUP BY tier ORDER BY CASE tier WHEN 'Platinum' THEN 1 WHEN 'Gold' THEN 2 WHEN 'Silver' THEN 3 ELSE 4 END;


-- Q12. What did Mombasa buy in October
-- Result (reference test): 152; count: 1. Confirm in DBeaver before submission.
-- Required concept: STRING_AGG and EXISTS.
-- Screenshot: screenshots/section_c/q12_result.png (add _summary, _before, _after, _error as needed).

SELECT c.customer_id,c.first_name||' '||c.last_name AS full_name,
 COUNT(DISTINCT p.product_id) AS product_count,
 STRING_AGG(DISTINCT p.product_name,'; ' ORDER BY p.product_name) AS products_ordered
FROM sokomart.customers c JOIN sokomart.orders o USING(customer_id)
JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
WHERE c.county='Mombasa' AND EXISTS (
 SELECT 1 FROM sokomart.orders x WHERE x.customer_id=c.customer_id AND x.order_status<>'cancelled'
 AND x.order_date >= '2026-10-01' AND x.order_date < '2026-11-01')
 AND o.order_status<>'cancelled' AND o.order_date >= '2026-10-01' AND o.order_date < '2026-11-01'
GROUP BY c.customer_id,c.first_name,c.last_name ORDER BY product_count DESC,c.customer_id;
SELECT COUNT(*) AS qualifying_customers FROM sokomart.customers c WHERE c.county='Mombasa' AND EXISTS (
 SELECT 1 FROM sokomart.orders x WHERE x.customer_id=c.customer_id AND x.order_status<>'cancelled'
 AND x.order_date >= '2026-10-01' AND x.order_date < '2026-11-01');


-- Q13. Payment health by method in 2026
-- Result (reference test): 4. Confirm in DBeaver before submission.
-- Required concept: COUNT FILTER and CTE.
-- Screenshot: screenshots/section_c/q13_result.png (add _summary, _before, _after, _error as needed).

WITH payments_2026 AS (
 SELECT * FROM sokomart.payments WHERE payment_date >= '2026-01-01' AND payment_date < '2027-01-01'
)
SELECT payment_method,COUNT(*) AS total_payments,
 COUNT(*) FILTER(WHERE payment_status='successful') AS successful,
 COUNT(*) FILTER(WHERE payment_status='failed') AS failed,
 COUNT(*) FILTER(WHERE payment_status='pending') AS pending,
 ROUND(100.0*COUNT(*) FILTER(WHERE payment_status='successful')/COUNT(*),2) AS success_rate_pct,
 COALESCE(SUM(amount) FILTER(WHERE payment_status='failed'),0) AS failed_amount
FROM payments_2026 GROUP BY payment_method ORDER BY total_payments DESC,payment_method;


-- Q14. Which departments carry the profit
-- Result (reference test): 2. Confirm in DBeaver before submission.
-- Required concept: CTE and scalar subqueries.
-- Screenshot: screenshots/section_c/q14_result.png (add _summary, _before, _after, _error as needed).

WITH category_profit AS (
 SELECT p.category,SUM(i.line_total) AS revenue,SUM(i.line_total-i.quantity*p.cost_price) AS gross_profit
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
 WHERE o.order_status='completed' AND o.order_date >= '2025-01-01' AND o.order_date < '2026-01-01'
 GROUP BY p.category
)
SELECT category,revenue,gross_profit,ROUND(100.0*gross_profit/NULLIF(revenue,0),2) AS margin_pct,
 ROUND((SELECT AVG(gross_profit) FROM category_profit),2) AS avg_category_gross_profit,
 ROUND(100.0*(gross_profit-(SELECT AVG(gross_profit) FROM category_profit))/
 NULLIF((SELECT AVG(gross_profit) FROM category_profit),0),2) AS pct_above_avg
FROM category_profit WHERE gross_profit>(SELECT AVG(gross_profit) FROM category_profit)
ORDER BY gross_profit DESC;


-- Q15. One sales table with subtotals
-- Result (reference test): 36. Confirm in DBeaver before submission.
-- Required concept: GROUPING SETS and GROUPING.
-- Screenshot: screenshots/section_c/q15_result.png (add _summary, _before, _after, _error as needed).

WITH lines AS (
 SELECT o.order_id,o.shipping_county AS county,p.category,i.line_total
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
 WHERE o.order_status='completed' AND o.order_date >= '2026-01-01' AND o.order_date < '2027-01-01'
 AND o.shipping_county IN ('Nairobi','Mombasa','Kisumu','Nakuru','Uasin Gishu')
)
SELECT CASE WHEN GROUPING(county)=0 AND GROUPING(category)=0 THEN 'county x category'
 WHEN GROUPING(county)=0 THEN 'county total' WHEN GROUPING(category)=0 THEN 'category total'
 ELSE 'grand total' END AS grouping_level,
 CASE WHEN GROUPING(county)=1 THEN 'ALL COUNTIES' ELSE county END AS county,
 CASE WHEN GROUPING(category)=1 THEN 'ALL CATEGORIES' ELSE category END AS category,
 SUM(line_total) AS revenue,COUNT(DISTINCT order_id) AS order_count
FROM lines GROUP BY GROUPING SETS ((county,category),(county),(category),())
ORDER BY GROUPING(county),lines.county,GROUPING(category),lines.category;
