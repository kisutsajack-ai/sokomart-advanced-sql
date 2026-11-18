-- Section A — CTEs and subqueries
--Question 1 — Big spenders of 2025 (Medium)
/* Scenario. Marketing wants to invite 2025's above-average customers to a loyalty launch.
Task. In a CTE, compute each customer's 2025 revenue (completed orders placed in 2025).
List the customers whose 2025 revenue is above the average 2025 revenue of customers who
bought in 2025. Get the average with a subquery (or a second CTE) over the first CTE — not
a hard-coded number. Order by total_spent_2025 descending. Then, in a second query, give
the number of customers who bought in 2025, the average, and the number of rows your main
query returns.
Required concept. CTE + scalar subquery over the CTE.
Expected output. customer_id, full_name, county, total_spent_2025, avg_spent_2025, amount_above_avg */
 
with customer_revenue_2025 as (  
select customer_id, first_name||' '||last_name as full_name, county, sum(oi.line_total) as total_spent_2025
from customers c
join orders o using (customer_id)
join order_items oi using(order_id)
where order_status = 'completed' 
and order_date >= '2025-01-01' and order_date < '2026-01-01'
group by customer_id, full_name,county
)
select customer_id, full_name, county, total_spent_2025, round((select avg(total_spent_2025) from customer_revenue_2025),2) as avg_spent_2025, round(total_spent_2025 - (select avg(total_spent_2025) from customer_revenue_2025),2) as amount_above_avg
from customer_revenue_2025
where total_spent_2025 > (select avg(total_spent_2025) from customer_revenue_2025)
order by total_spent_2025 desc, customer_id;

-- part 2
with customer_revenue_2025 as (  
select customer_id, sum(oi.line_total) as total_spent_2025
from orders o
join order_items oi using(order_id)
where order_status = 'completed' 
and order_date >= '2025-01-01' and order_date < '2026-01-01'
group by customer_id
)
select count(*) as customers_who_bought_2025,
round(avg(total_spent_2025),2) as avg_spent_2025,
count(*) filter (
where total_spent_2025 > (select avg(total_spent_2025)
from customer_revenue_2025
)) as customer_above_average
from customer_revenue_2025;


-- Question 2 — Premium-priced products (Medium)
/* Scenario. The pricing team wants every active product that is priced above the average
price of its own category.
Task. Use a correlated subquery that computes the category average for each product's
category (average over all products in the category, any status). Show the gap. Order by
category, then price_gap descending. Add a second query counting the rows per category.
Required concept. Correlated subquery (in WHERE and in SELECT). No window functions.
Expected output. product_id, product_name, category, unit_price, category_avg_price, price_gap */

SELECT p.product_id,p.product_name,p.category,p.unit_price,
       ROUND((SELECT AVG(p2.unit_price) FROM sokomart.products p2 WHERE p2.category=p.category),2) AS category_avg_price,
       ROUND(p.unit_price-(SELECT AVG(p2.unit_price) FROM sokomart.products p2 WHERE p2.category=p.category),2) AS price_gap
FROM sokomart.products p
WHERE p.product_status='active' AND p.unit_price > (SELECT AVG(p2.unit_price) FROM sokomart.products p2 WHERE p2.category=p.category)
ORDER BY category,price_gap DESC,product_id;
SELECT p.category,COUNT(*) AS qualifying_products
FROM sokomart.products p
WHERE p.product_status='active' AND p.unit_price > (SELECT AVG(p2.unit_price) FROM sokomart.products p2 WHERE p2.category=p.category)
GROUP BY p.category ORDER BY p.category;


-- Question 3 — 2026 monthly profit and loss (Medium)
/* Scenario. Finance needs a monthly P&L for January–October 2026.
Task. Build it with at least three chained CTEs: (1) the completed order lines with
their month and line cost; (2) monthly revenue and cost; (3) gross profit. Final SELECT adds
the margin. One row per month, in month order.
Required concept. Multiple chained CTEs.
Expected output. month, revenue, cost, gross_profit, margin_pct (10 rows) */


with completed_lines as (
select date_trunc('month', o.order_date)::date as month, oi.line_total, oi.quantity * p.cost_price as line_cost
from order_items oi
join orders o using(order_id)
join products p using(product_id)
where o.order_status = 'completed' and order_date >= '2026-01-01' and order_date < '2026-11-01'
),
profit_summary as (
select month, sum(line_total) as revenue, sum(line_cost) as cost
from completed_lines
group by month 
),
monthly_totals as (
select month, revenue, cost, (revenue - cost) as gross_profit 
from profit_summary
)
select to_char(month, 'yyyy-mm') as month, revenue, cost, gross_profit, round(100.0 * gross_profit/nullif(revenue,0),2) as margin_pct
from monthly_totals
order by month;


-- Question 4 — Cross-category shoppers in Nakuru (Medium)
/* Scenario. The Nakuru regional manager wants customers who already shop across several
departments, for a bundle campaign.
Task. In a derived table (a subquery in FROM), compute for every customer the number of
distinct product categories in their completed orders and their total revenue. Join it to
customers and keep customers living in Nakuru with 3 or more categories. Order by
category_count descending, then total_spent descending. Second query: how many Nakuru
customers qualify, and how many of them bought from all five categories.
Required concept. Derived table, COUNT(DISTINCT …).
Expected output. customer_id, full_name, county, category_count, total_spent */


SELECT c.customer_id,c.first_name||' '||c.last_name AS full_name,c.county,d.category_count,d.total_spent
FROM (SELECT o.customer_id,COUNT(DISTINCT p.category) AS category_count,SUM(i.line_total) AS total_spent
FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
WHERE o.order_status='completed' 
GROUP BY o.customer_id) d 
JOIN sokomart.customers c USING(customer_id)
WHERE c.county='Nakuru' AND d.category_count>=3
ORDER BY category_count DESC,total_spent DESC,customer_id;
SELECT COUNT(*) AS qualifying_nakuru_customers,
       COUNT(*) FILTER(WHERE d.category_count=5) AS all_five_categories
FROM (SELECT o.customer_id,COUNT(DISTINCT p.category) AS category_count,SUM(i.line_total) AS total_spent
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
WHERE o.order_status='completed' GROUP BY o.customer_id) d JOIN sokomart.customers c USING(customer_id)
WHERE c.county='Nakuru' AND d.category_count>=3;


-- Question 5 — Products nobody has ordered (Easy)
/* Scenario. The warehouse is reviewing shelf space: which products have never appeared on
any order (any status)?
Task. Use NOT EXISTS (or LEFT JOIN … IS NULL). NOT IN is not allowed — it returns
nothing at all if the subquery ever yields a NULL. Order by category, then product name.
Required concept. Anti-join with NOT EXISTS.
Expected output. product_id, product_name, category, product_status, stock_quantity, created_at */

select p.product_id, p.product_name, p.category, p.product_status, p.stock_quantity, p.created_at
from products p 
left join order_items oi using(product_id)
where oi.product_id is null
order by p.category, p.product_name

-- or

select p.product_id, p.product_name, p.category, p.product_status, p.stock_quantity, p.created_at
from products p
where not exists (
    select 1
    from order_items oi
    where oi.product_id = p.product_id)
order by p.category, p.product_name;


