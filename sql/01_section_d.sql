-- Section D — Questions 16–20
-- Run questions in order. Intentional errors are in labelled comment blocks.


-- Q16. Customer summary and monthly category views
-- Result (reference test): Top 10; totals: 1; December categories: 5. Confirm in DBeaver before submission.
-- Required concept: View, materialized view, unique index.
-- Screenshot: screenshots/section_d/q16_result.png (add _summary, _before, _after, _error as needed).

CREATE OR REPLACE VIEW sokomart.v_customer_purchase_summary AS
WITH order_revenue AS (
 SELECT o.customer_id,o.order_id,o.order_date,SUM(i.line_total) AS revenue
 FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id)
 WHERE o.order_status='completed' GROUP BY o.customer_id,o.order_id,o.order_date
), spending AS (
 SELECT customer_id,COUNT(*) AS completed_orders,SUM(revenue) AS lifetime_spent,
 ROUND(AVG(revenue),2) AS avg_order_value,MIN(order_date) AS first_order_date,MAX(order_date) AS last_order_date
 FROM order_revenue GROUP BY customer_id
)
SELECT c.customer_id,c.first_name||' '||c.last_name AS full_name,c.county,c.registration_date,
 COALESCE(s.completed_orders,0) AS completed_orders,COALESCE(s.lifetime_spent,0) AS lifetime_spent,
 COALESCE(s.avg_order_value,0) AS avg_order_value,s.first_order_date,s.last_order_date,
 DATE '2026-10-31'-s.last_order_date::date AS days_since_last_order
FROM sokomart.customers c LEFT JOIN spending s USING(customer_id);
SELECT * FROM sokomart.v_customer_purchase_summary WHERE county='Kiambu'
ORDER BY lifetime_spent DESC,customer_id LIMIT 10;
SELECT COUNT(*) AS view_rows,COUNT(*) FILTER(WHERE completed_orders=0) AS customers_without_completed_orders
FROM sokomart.v_customer_purchase_summary;
-- PostgreSQL has no CREATE OR REPLACE MATERIALIZED VIEW. Drop/recreate this derived object.
DROP MATERIALIZED VIEW IF EXISTS sokomart.mv_monthly_category_sales;
CREATE MATERIALIZED VIEW sokomart.mv_monthly_category_sales AS
SELECT DATE_TRUNC('month',o.order_date)::date AS sales_month,p.category,
 COUNT(DISTINCT o.order_id) AS orders,SUM(i.quantity) AS units_sold,SUM(i.line_total) AS revenue,
 SUM(i.line_total-i.quantity*p.cost_price) AS gross_profit
FROM sokomart.orders o JOIN sokomart.order_items i USING(order_id) JOIN sokomart.products p USING(product_id)
WHERE o.order_status='completed' GROUP BY DATE_TRUNC('month',o.order_date)::date,p.category;
CREATE UNIQUE INDEX idx_mv_monthly_category ON sokomart.mv_monthly_category_sales(sales_month,category);
SELECT TO_CHAR(sales_month,'YYYY-MM') AS sales_month,category,orders,units_sold,revenue,gross_profit
FROM sokomart.mv_monthly_category_sales WHERE sales_month=DATE '2025-12-01' ORDER BY revenue DESC;


-- Q17. Customer spend for a date range
-- Result (reference test): Calls: 1 row of 5 values; validation: 1; top customers: 5. Confirm in DBeaver before submission.
-- Required concept: PL/pgSQL function and validation.
-- Screenshot: screenshots/section_d/q17_result.png (add _summary, _before, _after, _error as needed).

CREATE OR REPLACE FUNCTION sokomart.fn_customer_spend(p_customer_id INTEGER,p_start_date DATE,p_end_date DATE)
RETURNS NUMERIC LANGUAGE plpgsql AS $$
DECLARE v_spend NUMERIC;
BEGIN
 IF p_start_date IS NULL OR p_end_date IS NULL OR p_end_date<p_start_date THEN
  RAISE EXCEPTION 'End date must be on or after start date; dates cannot be NULL';
 END IF;
 SELECT COALESCE(SUM(i.line_total),0) INTO v_spend FROM sokomart.orders o
 JOIN sokomart.order_items i USING(order_id)
 WHERE o.customer_id=p_customer_id AND o.order_status='completed'
 AND o.order_date>=p_start_date AND o.order_date<p_end_date+INTERVAL '1 day';
 RETURN v_spend;
END; $$;
SELECT sokomart.fn_customer_spend(4000,'2025-01-01','2025-12-31') AS spend_2025,
 sokomart.fn_customer_spend(4000,'2026-01-01','2026-10-31') AS spend_2026,
 sokomart.fn_customer_spend(4000,'2025-01-01','2026-10-31') AS all_time_spend,
 sokomart.fn_customer_spend(4000,'2025-12-01','2025-12-31') AS december_2025,
 sokomart.fn_customer_spend(-1,'2025-01-01','2026-10-31') AS nonexistent_customer;
SELECT customer_id,lifetime_spent,sokomart.fn_customer_spend(customer_id,'2025-01-01','2026-10-31') AS fn_value,
 lifetime_spent=sokomart.fn_customer_spend(customer_id,'2025-01-01','2026-10-31') AS matches
FROM sokomart.v_customer_purchase_summary WHERE customer_id=4000;

SELECT customer_id,first_name||' '||last_name AS full_name,
 sokomart.fn_customer_spend(customer_id,'2025-12-01','2025-12-31') AS december_2025_spend
FROM sokomart.customers WHERE county='Nairobi' ORDER BY december_2025_spend DESC,customer_id LIMIT 5;


/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q17: reversed dates.
SELECT sokomart.fn_customer_spend(4000,'2026-02-01','2026-01-01');
*/


-- Q18. Change a price and keep its history
-- Result (reference test): Before/after: 1 each; history: 1; audit: 1. Confirm in DBeaver before submission.
-- Required concept: Procedure, row lock, history and audit.
-- Screenshot: screenshots/section_d/q18_result.png (add _summary, _before, _after, _error as needed).

CREATE OR REPLACE PROCEDURE sokomart.sp_update_product_price(p_product_id INTEGER,p_new_price NUMERIC,p_reason VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_old NUMERIC; v_cost NUMERIC; v_new NUMERIC(12,2);
BEGIN
 SELECT unit_price,cost_price INTO v_old,v_cost FROM sokomart.products WHERE product_id=p_product_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Product % does not exist',p_product_id; END IF;
 v_new:=ROUND(p_new_price,2);
 IF v_new IS NULL OR v_new<=0 OR v_new<v_cost THEN RAISE EXCEPTION 'Price must be positive and at least cost (%)',v_cost; END IF;
 UPDATE sokomart.products SET unit_price=v_new WHERE product_id=p_product_id;
 INSERT INTO sokomart.product_price_history(product_id,old_price,new_price,change_reason) VALUES(p_product_id,v_old,v_new,p_reason);
 INSERT INTO sokomart.audit_logs(table_name,record_id,action,old_data,new_data)
 VALUES('products',p_product_id,'UPDATE',jsonb_build_object('unit_price',v_old),jsonb_build_object('unit_price',v_new));
END; $$;
SELECT product_id,product_name,unit_price,cost_price FROM sokomart.products WHERE product_id=71;
CALL sokomart.sp_update_product_price(71,1099.00,'Supplier price increase - Nov 2026');
SELECT product_id,product_name,unit_price,cost_price FROM sokomart.products WHERE product_id=71;
SELECT price_history_id,product_id,old_price,new_price,change_reason FROM sokomart.product_price_history WHERE product_id=71 ORDER BY price_history_id;
SELECT table_name,record_id,action,old_data,new_data FROM sokomart.audit_logs WHERE table_name='products' AND record_id=71 ORDER BY audit_id;


/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q18: record the count, attempt the change, then verify count and price unchanged.
SELECT COUNT(*) AS history_before FROM sokomart.product_price_history WHERE product_id=71;
CALL sokomart.sp_update_product_price(71,500.00,'Rejected below-cost test');
SELECT COUNT(*) AS history_after FROM sokomart.product_price_history WHERE product_id=71;
SELECT product_id,unit_price,cost_price FROM sokomart.products WHERE product_id=71;
*/


-- Q19. Audit order status changes
-- Result (reference test): Status checks: 1 each; final history: 2; audit: 2. Confirm in DBeaver before submission.
-- Required concept: Trigger and status-transition procedure.
-- Screenshot: screenshots/section_d/q19_result.png (add _summary, _before, _after, _error as needed).

CREATE OR REPLACE FUNCTION sokomart.fn_orders_status_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 IF TG_OP='INSERT' THEN
  INSERT INTO sokomart.order_status_history(order_id,old_status,new_status) VALUES(NEW.order_id,NULL,NEW.order_status);
  INSERT INTO sokomart.audit_logs(table_name,record_id,action,old_data,new_data)
  VALUES('orders',NEW.order_id,'INSERT',NULL,jsonb_build_object('order_status',NEW.order_status));
 ELSIF OLD.order_status IS DISTINCT FROM NEW.order_status THEN
  INSERT INTO sokomart.order_status_history(order_id,old_status,new_status) VALUES(NEW.order_id,OLD.order_status,NEW.order_status);
  INSERT INTO sokomart.audit_logs(table_name,record_id,action,old_data,new_data)
  VALUES('orders',NEW.order_id,'UPDATE',jsonb_build_object('order_status',OLD.order_status),jsonb_build_object('order_status',NEW.order_status));
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS trg_orders_status_audit ON sokomart.orders;
CREATE TRIGGER trg_orders_status_audit AFTER INSERT OR UPDATE OF order_status ON sokomart.orders
FOR EACH ROW EXECUTE FUNCTION sokomart.fn_orders_status_audit();
CREATE OR REPLACE PROCEDURE sokomart.sp_update_order_status(p_order_id INTEGER,p_new_status VARCHAR)
LANGUAGE plpgsql AS $$
DECLARE v_old VARCHAR;
BEGIN
 SELECT order_status INTO v_old FROM sokomart.orders WHERE order_id=p_order_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Order % does not exist',p_order_id; END IF;
 IF p_new_status IS NULL OR NOT ((v_old='pending' AND p_new_status IN ('completed','cancelled')) OR
 (v_old='completed' AND p_new_status='returned')) THEN
 RAISE EXCEPTION 'Invalid status transition: % -> %',v_old,p_new_status; END IF;
 UPDATE sokomart.orders SET order_status=p_new_status WHERE order_id=p_order_id;
 IF p_new_status='completed' THEN
 UPDATE sokomart.payments SET payment_status='successful' WHERE order_id=p_order_id;
 ELSIF p_new_status='cancelled' THEN
 UPDATE sokomart.payments SET payment_status='failed' WHERE order_id=p_order_id AND payment_status<>'successful';
 END IF;
END; $$;
SELECT o.order_id,o.order_status,p.payment_status FROM sokomart.orders o JOIN sokomart.payments p USING(order_id) WHERE o.order_id=48882;
CALL sokomart.sp_update_order_status(48882,'completed');
SELECT o.order_id,o.order_status,p.payment_status FROM sokomart.orders o JOIN sokomart.payments p USING(order_id) WHERE o.order_id=48882;
SELECT order_id,old_status,new_status FROM sokomart.order_status_history WHERE order_id=48882 ORDER BY status_history_id;
SELECT table_name,record_id,action,old_data,new_data FROM sokomart.audit_logs WHERE table_name='orders' AND record_id=48882 ORDER BY audit_id;
UPDATE sokomart.orders SET order_status='returned' WHERE order_id=48882;
SELECT order_id,old_status,new_status FROM sokomart.order_status_history WHERE order_id=48882 ORDER BY status_history_id;
SELECT table_name,record_id,action,old_data,new_data FROM sokomart.audit_logs WHERE table_name='orders' AND record_id=48882 ORDER BY audit_id;
UPDATE sokomart.orders SET shipping_county=shipping_county WHERE order_id=48882;
SELECT COUNT(*) AS history_rows_expected_2 FROM sokomart.order_status_history WHERE order_id=48882;


/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q19: forbidden cancelled -> completed transition.
CALL sokomart.sp_update_order_status(49961,'completed');
*/


-- Q20. Place an order atomically
-- Result (reference test): Order: 1; lines: 3; payment: 1; stock: 3; refreshed categories: 2. Confirm in DBeaver before submission.
-- Required concept: Atomic checkout procedure with arrays.
-- Screenshot: screenshots/section_d/q20_result.png (add _summary, _before, _after, _error as needed).

-- Q16 and Q19 must run first. Use the same connection for this entire file.
-- Align identity sequences with imported CSV IDs; no business rows are changed here.
SELECT setval(pg_get_serial_sequence('sokomart.orders','order_id'),COALESCE(MAX(order_id),1),COUNT(*)>0) FROM sokomart.orders;
SELECT setval(pg_get_serial_sequence('sokomart.order_items','order_item_id'),COALESCE(MAX(order_item_id),1),COUNT(*)>0) FROM sokomart.order_items;
SELECT setval(pg_get_serial_sequence('sokomart.payments','payment_id'),COALESCE(MAX(payment_id),1),COUNT(*)>0) FROM sokomart.payments;
CREATE OR REPLACE PROCEDURE sokomart.sp_place_order(
 p_customer_id INTEGER,p_product_ids INTEGER[],p_quantities INTEGER[],p_payment_method VARCHAR,
 INOUT p_order_id INTEGER DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE v_county VARCHAR; v_status VARCHAR; v_pid INTEGER; v_qty INTEGER;
 v_price NUMERIC; v_available INTEGER; v_items NUMERIC:=0; v_fee NUMERIC; v_ref VARCHAR;
BEGIN
 SELECT county,customer_status INTO v_county,v_status FROM sokomart.customers
 WHERE customer_id=p_customer_id FOR SHARE;
 IF NOT FOUND OR v_status<>'active' THEN RAISE EXCEPTION 'Customer must exist and be active'; END IF;
 IF p_product_ids IS NULL OR p_quantities IS NULL OR cardinality(p_product_ids)=0
 OR cardinality(p_product_ids)<>cardinality(p_quantities)
 OR array_ndims(p_product_ids)<>1 OR array_ndims(p_quantities)<>1 THEN
 RAISE EXCEPTION 'Supply nonempty one-dimensional arrays of equal length'; END IF;
 IF EXISTS(SELECT 1 FROM unnest(p_quantities) q WHERE q IS NULL OR q<=0)
 OR EXISTS(SELECT 1 FROM unnest(p_product_ids) id WHERE id IS NULL)
 OR (SELECT COUNT(DISTINCT id) FROM unnest(p_product_ids) id)<>cardinality(p_product_ids) THEN
 RAISE EXCEPTION 'Product IDs must be unique and non-NULL; quantities must be positive'; END IF;
 IF p_payment_method IS NULL OR p_payment_method NOT IN ('M-Pesa','card','bank transfer','cash on delivery') THEN
 RAISE EXCEPTION 'Invalid payment method'; END IF;
 INSERT INTO sokomart.orders(customer_id,order_date,order_status,shipping_county,delivery_fee,total_amount)
 VALUES(p_customer_id,CURRENT_TIMESTAMP,'pending',v_county,0,0) RETURNING order_id INTO p_order_id;
 -- Lock products in ID order to reduce deadlock risk between concurrent checkouts.
 FOR v_pid,v_qty IN SELECT id,qty FROM unnest(p_product_ids,p_quantities) AS x(id,qty) ORDER BY id LOOP
  UPDATE sokomart.products SET stock_quantity=stock_quantity-v_qty
  WHERE product_id=v_pid AND stock_quantity>=v_qty AND product_status='active'
  RETURNING unit_price INTO v_price;
  IF NOT FOUND THEN
   SELECT stock_quantity INTO v_available FROM sokomart.products WHERE product_id=v_pid;
   RAISE EXCEPTION 'Product %: requested %, available % (must also be active)',v_pid,v_qty,v_available;
  END IF;
  INSERT INTO sokomart.order_items(order_id,product_id,quantity,unit_price,discount_percentage,line_total)
  VALUES(p_order_id,v_pid,v_qty,v_price,0,ROUND(v_qty*v_price,2));
  v_items:=v_items+ROUND(v_qty*v_price,2);
 END LOOP;
 v_fee:=CASE WHEN v_items>=5000 THEN 0 WHEN v_county='Nairobi' THEN 200
 WHEN v_county IN ('Kiambu','Kajiado','Machakos') THEN 250 ELSE 350 END;
 UPDATE sokomart.orders SET delivery_fee=v_fee,total_amount=v_items+v_fee WHERE order_id=p_order_id;
 v_ref:=CASE WHEN p_payment_method='cash on delivery' THEN NULL ELSE 'SM-'||p_order_id::text END;
 INSERT INTO sokomart.payments(order_id,payment_date,payment_method,amount,payment_status,transaction_reference)
 VALUES(p_order_id,CURRENT_TIMESTAMP,p_payment_method,v_items+v_fee,'pending',v_ref);
END; $$;
SELECT product_id,unit_price,stock_quantity FROM sokomart.products WHERE product_id IN (6,73,82) ORDER BY product_id;
CALL sokomart.sp_place_order(177,ARRAY[6,73,82],ARRAY[1,2,3],'M-Pesa',NULL);
-- currval is connection-local; capture immediately after the successful CALL.
DROP TABLE IF EXISTS pg_temp.q20_new_order;
CREATE TEMP TABLE q20_new_order AS SELECT currval(pg_get_serial_sequence('sokomart.orders','order_id'))::integer AS order_id;
SELECT o.order_id,o.customer_id,o.order_status,o.shipping_county,o.delivery_fee,o.total_amount,SUM(i.line_total) AS items_total
FROM sokomart.orders o JOIN q20_new_order n USING(order_id) JOIN sokomart.order_items i USING(order_id)
GROUP BY o.order_id,o.customer_id,o.order_status,o.shipping_county,o.delivery_fee,o.total_amount;
SELECT i.order_id,i.product_id,i.quantity,i.unit_price,i.line_total FROM sokomart.order_items i JOIN q20_new_order n USING(order_id) ORDER BY product_id;
SELECT p.order_id,p.payment_method,p.amount,p.payment_status,p.transaction_reference IS NOT NULL AS has_reference
FROM sokomart.payments p JOIN q20_new_order n USING(order_id);
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (6,73,82) ORDER BY product_id;
SELECT h.order_id,h.old_status,h.new_status FROM sokomart.order_status_history h JOIN q20_new_order n USING(order_id) ORDER BY status_history_id;

/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q20: BEFORE Q23 restocks 59. Run these statements individually (autocommit on).
SELECT COUNT(*) AS orders_before FROM sokomart.orders;
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (6,59) ORDER BY product_id;
CALL sokomart.sp_place_order(408,ARRAY[6,59],ARRAY[1,2],'card',NULL);
SELECT COUNT(*) AS orders_after FROM sokomart.orders;
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (6,59) ORDER BY product_id;
*/

-- Dynamic CALL uses the captured ID, not a guessed next sequence number.
DO $$ DECLARE v_id integer; BEGIN SELECT order_id INTO v_id FROM q20_new_order;
 CALL sokomart.sp_update_order_status(v_id,'completed'); END; $$;
SELECT o.order_id,o.order_status,p.payment_status FROM sokomart.orders o JOIN q20_new_order n USING(order_id)
JOIN sokomart.payments p USING(order_id);
REFRESH MATERIALIZED VIEW CONCURRENTLY sokomart.mv_monthly_category_sales;
-- Matches the actual execution month; this is November 2026 when run during the assignment.
SELECT TO_CHAR(sales_month,'YYYY-MM') AS sales_month,category,orders,units_sold,revenue,gross_profit
FROM sokomart.mv_monthly_category_sales
WHERE sales_month=DATE_TRUNC('month',CURRENT_DATE)::date ORDER BY category;
