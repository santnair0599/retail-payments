-- Ongoing refresh pattern, distinct from 01's initial CTAS build. Run this after you've
-- run sql/source/03_simulate_changes.sql, re-run the ADF incremental ingestion, and
-- re-run the Bronze->Silver CETAS — this picks up just the changed rows using COPY INTO
-- + a staging table + MERGE (the exact pattern from synapse-practice Modules 11 and 14),
-- rather than dropping and rebuilding the whole fact table every time.

-- Staging table: round-robin + heap, transient, same reasoning as synapse-practice Module 14.
CREATE TABLE stg_fact_sales_incremental
WITH (DISTRIBUTION = ROUND_ROBIN, HEAP)
AS
SELECT
    o.order_id,
    o.customer_id,
    CAST(FORMAT(o.order_date, 'yyyyMMdd') AS INT) AS date_key,
    p.amount,
    p.currency,
    o.status          AS order_status,
    p.payment_status
FROM ext_dp_silver_orders o
LEFT JOIN ext_dp_silver_payments p ON o.order_id = p.order_id
WHERE o.updated_at >= DATEADD(DAY, -1, SYSUTCDATETIME())   -- only recently-changed orders
   OR p.updated_at  >= DATEADD(DAY, -1, SYSUTCDATETIME());

MERGE INTO fact_sales AS target
USING stg_fact_sales_incremental AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN
    UPDATE SET target.amount = source.amount,
               target.order_status = source.order_status,
               target.payment_status = source.payment_status
WHEN NOT MATCHED THEN
    INSERT (order_id, customer_id, date_key, amount, currency, order_status, payment_status)
    VALUES (source.order_id, source.customer_id, source.date_key, source.amount,
            source.currency, source.order_status, source.payment_status);

-- Same correctness practice as synapse-practice Module 14: drop staging immediately.
DROP TABLE stg_fact_sales_incremental;

-- Also refresh dim_customer for the segment changes from 03_simulate_changes.sql —
-- SCD1-style overwrite (deliberately not SCD2, per this project's scope).
TRUNCATE TABLE dim_customer;
INSERT INTO dim_customer SELECT customer_id, full_name, email, country, segment FROM ext_dp_silver_customers;

-- Verify no duplicate order_ids landed in fact_sales after the merge — the same
-- "rerun it twice, prove no duplication" idempotency check from adf-practice's capstone.
SELECT order_id, COUNT(*) FROM fact_sales GROUP BY order_id HAVING COUNT(*) > 1;
-- Should return zero rows.
