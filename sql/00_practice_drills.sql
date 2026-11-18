-- D1 List the products whose `unit_price` is above the average `unit_price` of **all** products. Show the 10 most expensive, then on a second query the count.
-- list all product | unit price
select product_id, product_name, category, unit_price, round((select avg(unit_price) from products),2) as overall_avg_price
from products
where unit_price > (select avg(unit_price) from products)
order by unit_price desc
limit 10;

-- Part 2
select count(*) as products_above_average
from products
where unit_price > (select avg(unit_price) from products);

-- D2 List customers living in **Mombasa** who placed at least one order (any status) in **December 2025**.

select customer_id, first_name||' '||last_name as customer_name, email
from customers 
where customer_id in (select customer_id from orders where order_date >= '2025-12-01' and order_date < '2026-01-01') and county = 'Mombasa'
order by customer_id;


-- D3 How many customers living in **Kisumu** have at least one payment with `payment_status = 'failed'`? 

select count(distinct o.customer_id)
from orders o
join customers c using(customer_id)
where c.county = 'Kisumu'
      and order_id in (select order_id from payments where payment_status = 'failed')

select COUNT(*) AS kisumu_customers_with_failed_payment
from sokomart.customers c
where c.county = 'Kisumu'
  and exists (
      select 1
      from orders o
      join payments p on p.order_id = o.order_id
      where o.customer_id = c.customer_id
        and p.payment_status = 'failed'
  );

-- D4 For each `order_status`, show the number of orders, the average number of lines per order and the average number of units per order.      
      
  select o.order_status, 
  count(*) as orders, 
  round(avg(d.number_of_lines),2) as avg_lines_per_order, 
  round(avg(d.number_of_units),2) as avg_units_per_order
  from (
  select order_id, count(*) as number_of_lines, sum(quantity) as number_of_units
  from order_items
  group by order_id
  order by order_id asc
  ) d
  join orders o on o.order_id = d.order_id
  group by o.order_status
  order by o.order_status;
  
-- D5 Top 5 shipping counties by number of completed orders in 2026. Put the filtered orders in a CTE.
  
  with completed_orders_2026 as (
  select shipping_county, count(*) as total_shipping_orders
  from orders 
  where order_status = 'completed' and order_date >= '2026-01-01' and order_date < '2027-01-01'
  group by shipping_county
  )
  select shipping_county, total_shipping_orders as completed_orders
  from completed_orders_2026   
  order by total_shipping_orders desc
  limit 5;
  
  -- D6 For 2025: completed orders per month, the 2025 monthly average, and whether each month is above average or at/below average. Use two CTEs (monthly counts, then the stats).
  
  with monthly_orders as (
  select date_trunc('Month', order_date)::date as month, 
  count(*) as completed_orders
  from orders
  where order_status = 'completed'
  and order_date >= '2025-01-01' and order_date < '2026-01-01'
  group by month
  ),
  stats as(
  select round(avg(completed_orders),2) as avg_per_month 
  from monthly_orders
  )
  select m.month, m.completed_orders,
  round(s.avg_per_month,2) as avg_per_month,
  case
  	when m.completed_orders > s.avg_per_month
          then 'above average'
          else 'at/below average'
       end as vs_average
  from monthly_orders m
  cross join stats s as
  order by m.month;
  
 
      
-- D7 Write sokomart.fn_order_count(p_customer_id INTEGER) RETURNS INTEGER — the number of orders (any status) a customer has. Call it for customer 177 and for a customer that does not exist (-1). 
CREATE OR REPLACE FUNCTION sokomart.fn_order_count(p_customer_id INTEGER) RETURNS INTEGER
LANGUAGE sql 
AS $$ 
SELECT COUNT(*)::integer 
FROM sokomart.orders 
WHERE customer_id=p_customer_id; 
$$;
SELECT sokomart.fn_order_count(177) AS customer_177_orders,sokomart.fn_order_count(-1) AS nonexistent_customer_orders;

-- D8 Write sokomart.sp_set_customer_status(p_customer_id INTEGER, p_status VARCHAR). It raises an exception for a status other than active / inactive / suspended, and for a customer that does not exist. Inside BEGIN … ROLLBACK, set customer 177 to suspended, show it, roll back, show it is active again. Then show the exception for status 'vip'.

CREATE OR REPLACE PROCEDURE sokomart.sp_set_customer_status(p_customer_id INTEGER,p_status VARCHAR)
LANGUAGE plpgsql 
AS $$ 
BEGIN
 IF p_status IS NULL OR p_status NOT IN ('active','inactive','suspended') THEN RAISE EXCEPTION 'Invalid customer status: %',p_status; END IF;
 UPDATE sokomart.customers SET customer_status=p_status WHERE customer_id=p_customer_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Customer % does not exist',p_customer_id; END IF;
END; 
$$;
SELECT customer_id,customer_status FROM sokomart.customers WHERE customer_id=177;
BEGIN;
CALL sokomart.sp_set_customer_status(177,'suspended');
SELECT customer_id,customer_status FROM sokomart.customers WHERE customer_id=177;
ROLLBACK;
SELECT customer_id,customer_status FROM sokomart.customers WHERE customer_id=177;

-- D9 Beauty products whose stock_quantity is below the average Beauty stock. Put the Beauty products in a CTE and compare with a scalar subquery on that CTE.
  
  with beauty_products as (
  select product_id, product_name, stock_quantity
  from products  
  where category = 'Beauty'
  )
  select product_id, product_name, stock_quantity, (select round(avg(stock_quantity),2) from beauty_products) as avg_beauty_stock
  from beauty_products 
  where stock_quantity < (select avg(stock_quantity) from beauty_products)
  order by stock_quantity;
  
-- D10 Write sokomart.sp_county_summary(IN p_county VARCHAR, OUT p_customers INTEGER, OUT p_revenue NUMERIC) returning the number of customers living in the county and their completed revenue. CALL sokomart.sp_county_summary('Nakuru', NULL, NULL);
  
CREATE OR REPLACE PROCEDURE sokomart.sp_county_summary(IN p_county VARCHAR,OUT p_customers INTEGER,OUT p_revenue NUMERIC)
LANGUAGE plpgsql 
AS $$ 
BEGIN
 SELECT COUNT(*)::integer INTO p_customers FROM sokomart.customers WHERE county=p_county;
 SELECT COALESCE(SUM(i.line_total),0) INTO p_revenue FROM sokomart.customers c
 JOIN sokomart.orders o USING(customer_id) JOIN sokomart.order_items i USING(order_id)
 WHERE c.county=p_county AND o.order_status='completed';
END; 
$$;
CALL sokomart.sp_county_summary('Nakuru',NULL,NULL);