-- Section E — Questions 21–25
-- Run questions in order. Intentional errors are in labelled comment blocks.


-- Q21. Read a query plan
-- Result (reference test): 91 result rows; plan varies. Confirm in DBeaver before submission.
-- Required concept: EXPLAIN ANALYZE BUFFERS.
-- Screenshot: screenshots/section_e/q21_result.png (add _summary, _before, _after, _error as needed).

EXPLAIN (ANALYZE,BUFFERS) SELECT c.customer_id,c.first_name,c.last_name,SUM(i.line_total) AS revenue
FROM sokomart.customers c JOIN sokomart.orders o ON o.customer_id=c.customer_id
JOIN sokomart.order_items i ON i.order_id=o.order_id
WHERE c.county='Kisumu' AND o.order_status='completed'
AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id,c.first_name,c.last_name ORDER BY revenue DESC;
SELECT c.customer_id,c.first_name,c.last_name,SUM(i.line_total) AS revenue
FROM sokomart.customers c JOIN sokomart.orders o ON o.customer_id=c.customer_id
JOIN sokomart.order_items i ON i.order_id=o.order_id
WHERE c.county='Kisumu' AND o.order_status='completed'
AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id,c.first_name,c.last_name ORDER BY revenue DESC;
SELECT COUNT(*) AS result_rows FROM (SELECT c.customer_id,c.first_name,c.last_name,SUM(i.line_total) AS revenue
FROM sokomart.customers c JOIN sokomart.orders o ON o.customer_id=c.customer_id
JOIN sokomart.order_items i ON i.order_id=o.order_id
WHERE c.county='Kisumu' AND o.order_status='completed'
AND o.order_date >= '2026-09-01' AND o.order_date < '2026-10-01'
GROUP BY c.customer_id,c.first_name,c.last_name ORDER BY revenue DESC) result;
/* Fill from YOUR DBeaver plan, not from someone else's machine:
 top_node | join_methods_used | scan_on_orders | scan_on_customers |
 estimated_vs_actual_rows_orders | planning_ms | execution_ms | result_rows
 PENDING LOCAL PLAN CAPTURE
*/


-- Q22. Prove the indexes help
-- Result (reference test): 7 plans; sizes: 1 row; timings pending. Confirm in DBeaver before submission.
-- Required concept: Index comparison and partial index.
-- Screenshot: screenshots/section_e/q22_result.png (add _summary, _before, _after, _error as needed).

-- The original 05_indexes.sql was not attached. This equivalent test saves/restores
-- existing non-constraint indexes on the three measured tables, using pg_indexes.
-- Run on the assignment database, in one connection; do not run during other work.
DROP TABLE IF EXISTS pg_temp.q22_saved_indexes;
CREATE TEMP TABLE q22_saved_indexes AS
SELECT i.schemaname,i.indexname,i.indexdef
FROM pg_indexes i JOIN pg_namespace ns ON ns.nspname=i.schemaname
JOIN pg_class ix ON ix.relnamespace=ns.oid AND ix.relname=i.indexname
WHERE i.schemaname='sokomart' AND i.tablename IN ('orders','payments','order_items')
AND i.indexname<>'idx_orders_pending_date'
AND NOT EXISTS(SELECT 1 FROM pg_constraint con WHERE con.conindid=ix.oid);
-- Removes only the exercise's custom partial index if this file is rerun.
DROP INDEX IF EXISTS sokomart.idx_orders_pending_date;
DO $$ DECLARE r record; BEGIN FOR r IN SELECT * FROM q22_saved_indexes LOOP
 EXECUTE format('DROP INDEX %I.%I',r.schemaname,r.indexname); END LOOP; END; $$;
ANALYZE sokomart.orders; ANALYZE sokomart.payments; ANALYZE sokomart.order_items;
-- BEFORE: capture all three plans.
EXPLAIN ANALYZE SELECT order_id,order_date,total_amount FROM sokomart.orders WHERE customer_id=408 ORDER BY order_date;
EXPLAIN ANALYZE SELECT * FROM sokomart.payments WHERE order_id=25000;
EXPLAIN ANALYZE SELECT order_id,quantity,line_total FROM sokomart.order_items WHERE product_id=71;
-- Restore the exact original definitions (equivalent to rerunning 05_indexes.sql).
DO $$ DECLARE r record; BEGIN FOR r IN SELECT * FROM q22_saved_indexes LOOP EXECUTE r.indexdef; END LOOP; END; $$;
ANALYZE sokomart.orders; ANALYZE sokomart.payments; ANALYZE sokomart.order_items;
-- AFTER: capture all three plans.
EXPLAIN ANALYZE SELECT order_id,order_date,total_amount FROM sokomart.orders WHERE customer_id=408 ORDER BY order_date;
EXPLAIN ANALYZE SELECT * FROM sokomart.payments WHERE order_id=25000;
EXPLAIN ANALYZE SELECT order_id,quantity,line_total FROM sokomart.order_items WHERE product_id=71;
CREATE INDEX idx_orders_pending_date ON sokomart.orders(order_date) WHERE order_status='pending';
ANALYZE sokomart.orders;
EXPLAIN ANALYZE SELECT order_id,order_date,total_amount FROM sokomart.orders
WHERE order_status='pending' AND order_date < '2026-10-25';
SELECT pg_size_pretty(pg_relation_size('sokomart.idx_orders_pending_date')) AS partial_index_size,
 pg_size_pretty(pg_relation_size('sokomart.idx_orders_order_date')) AS full_index_size;
/* Fill from your seven plans; do not claim improvement if timings do not show it.
 query | scan_before | execution_ms_before | scan_after | execution_ms_after | rows
 customer_408 | PENDING | PENDING | PENDING | PENDING | PENDING
 payment_25000 | PENDING | PENDING | PENDING | PENDING | PENDING
 product_71 | PENDING | PENDING | PENDING | PENDING | PENDING
 If interrupted after dropping indexes, rerun your original 05_indexes.sql.
 For final Q22(a/b) evidence, run the DROP block
 in your original 05_indexes.sql and rerun that file at the marked restore point.
*/


-- Q23. Transactions you can see
-- Result (reference test): Averages: 1 per check; stocks: 2 per check. Confirm in DBeaver before submission.
-- Required concept: Transactions and savepoints.
-- Screenshot: screenshots/section_e/q23_result.png (add _summary, _before, _after, _error as needed).

SELECT ROUND(AVG(unit_price),2) AS beauty_average_before FROM sokomart.products WHERE category='Beauty';
BEGIN;
UPDATE sokomart.products SET unit_price=ROUND(unit_price*0.90,2) WHERE category='Beauty';
SELECT ROUND(AVG(unit_price),2) AS beauty_average_inside FROM sokomart.products WHERE category='Beauty';
ROLLBACK;
SELECT ROUND(AVG(unit_price),2) AS beauty_average_after FROM sokomart.products WHERE category='Beauty';
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (59,166) ORDER BY product_id;
BEGIN;
WITH changed AS (
 UPDATE sokomart.products SET stock_quantity=stock_quantity+40 WHERE product_id=59
 RETURNING product_id,stock_quantity
)
INSERT INTO sokomart.audit_logs(table_name,record_id,action,old_data,new_data)
SELECT 'products',product_id,'UPDATE',jsonb_build_object('stock_quantity',stock_quantity-40),
 jsonb_build_object('stock_quantity',stock_quantity) FROM changed;
SAVEPOINT after_restock;
UPDATE sokomart.products SET stock_quantity=0 WHERE product_id=166;
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (59,166) ORDER BY product_id;
ROLLBACK TO SAVEPOINT after_restock;
COMMIT;
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id IN (59,166) ORDER BY product_id;


/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q23(c): execute COMMIT even after the intentional error, then inspect stock.
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id=166;
BEGIN;
UPDATE sokomart.products SET stock_quantity=stock_quantity+1 WHERE product_id=166;
UPDATE sokomart.products SET stock_quantity=-5 WHERE product_id=166;
COMMIT;
SELECT product_id,stock_quantity FROM sokomart.products WHERE product_id=166;
*/


-- Q24. Clean up duplicate payments
-- Result (reference test): Summary: 1; deletion preview: 10; reconciliation: 1. Confirm in DBeaver before submission.
-- Required concept: ROW_NUMBER deduplication and unique index.
-- Screenshot: screenshots/section_e/q24_result.png (add _summary, _before, _after, _error as needed).

WITH copies AS (
 SELECT payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference,COUNT(*) AS copies
 FROM sokomart.payment_staging GROUP BY payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference
)
SELECT COUNT(*) FILTER(WHERE copies>1) AS duplicated_payments,
 COALESCE(SUM(copies-1),0) AS extra_rows_to_delete,MAX(copies) AS max_copies FROM copies;
WITH numbered AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference
 ORDER BY loaded_at,staging_id) AS copy_no FROM sokomart.payment_staging
)
SELECT staging_id,payment_id,transaction_reference,amount,source_file,loaded_at,copy_no
FROM numbered WHERE copy_no>1 ORDER BY loaded_at,staging_id LIMIT 10;
SELECT COUNT(*) AS staging_rows_before,COUNT(DISTINCT payment_id) AS distinct_payments_before FROM sokomart.payment_staging;
BEGIN;
WITH numbered AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference
 ORDER BY loaded_at,staging_id) AS copy_no FROM sokomart.payment_staging
)
DELETE FROM sokomart.payment_staging s USING numbered n WHERE s.staging_id=n.staging_id AND n.copy_no>1;
SELECT COUNT(*) AS staging_rows_after,COUNT(DISTINCT payment_id) AS distinct_payments_after,
 SUM(amount) AS staged_amount_after,
 (SELECT SUM(p.amount) FROM sokomart.payments p WHERE EXISTS
 (SELECT 1 FROM sokomart.payment_staging s WHERE s.payment_id=p.payment_id)) AS same_payments_in_payments_table
FROM sokomart.payment_staging;
-- Stop the transaction rather than commit a failed reconciliation.
DO $$ BEGIN
 IF (SELECT COUNT(*)<>COUNT(DISTINCT payment_id) FROM sokomart.payment_staging)
 OR (SELECT SUM(amount) FROM sokomart.payment_staging) IS DISTINCT FROM
 (SELECT SUM(p.amount) FROM sokomart.payments p WHERE EXISTS
 (SELECT 1 FROM sokomart.payment_staging s WHERE s.payment_id=p.payment_id)) THEN
 RAISE EXCEPTION 'Staging reconciliation failed'; END IF;
END; $$;
COMMIT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_staging_payment_id ON sokomart.payment_staging(payment_id);


/* INTENTIONAL ERROR DEMONSTRATION — run separately, statement by statement.
Copy the SQL below out of this comment to execute it and capture the error.
-- Q24: after unique index creation; choose a fresh staging_id to test payment_id uniqueness.
SELECT setval(pg_get_serial_sequence('sokomart.payment_staging','staging_id'),MAX(staging_id),true) FROM sokomart.payment_staging;
INSERT INTO sokomart.payment_staging(payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference,source_file,loaded_at)
SELECT payment_id,order_id,payment_date,payment_method,amount,payment_status,transaction_reference,'intentional_duplicate_test.csv',CURRENT_TIMESTAMP
FROM sokomart.payment_staging ORDER BY staging_id LIMIT 1;
*/


-- Q25. Three months in a row
-- Result (reference test): Top 10; summary: 1 (1,459 qualifiers). Confirm in DBeaver before submission.
-- Required concept: Gaps and islands with window functions.
-- Screenshot: screenshots/section_e/q25_result.png (add _summary, _before, _after, _error as needed).

WITH customer_months AS (
 SELECT DISTINCT customer_id,DATE_TRUNC('month',order_date)::date AS month FROM sokomart.orders WHERE order_status='completed'
), islands AS (
 SELECT *,month-ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY month)*INTERVAL '1 month' AS island FROM customer_months
), runs AS (
 SELECT customer_id,MIN(month) AS streak_start_month,MAX(month) AS streak_end_month,COUNT(*) AS streak_length
 FROM islands GROUP BY customer_id,island HAVING COUNT(*)>=3
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY streak_length DESC,streak_start_month) AS rn FROM runs
)
SELECT c.customer_id,c.first_name||' '||c.last_name AS full_name,c.county,
 TO_CHAR(r.streak_start_month,'YYYY-MM') AS streak_start_month,
 TO_CHAR(r.streak_end_month,'YYYY-MM') AS streak_end_month,r.streak_length
FROM ranked r JOIN sokomart.customers c USING(customer_id) WHERE r.rn=1
ORDER BY streak_length DESC,c.customer_id LIMIT 10;
WITH customer_months AS (
 SELECT DISTINCT customer_id,DATE_TRUNC('month',order_date)::date AS month FROM sokomart.orders WHERE order_status='completed'
), islands AS (
 SELECT *,month-ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY month)*INTERVAL '1 month' AS island FROM customer_months
), runs AS (
 SELECT customer_id,MIN(month) AS streak_start_month,MAX(month) AS streak_end_month,COUNT(*) AS streak_length
 FROM islands GROUP BY customer_id,island HAVING COUNT(*)>=3
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY streak_length DESC,streak_start_month) AS rn FROM runs
)
SELECT COUNT(*) AS customers_with_3plus_streak,MAX(streak_length) AS longest_streak FROM ranked WHERE rn=1;
