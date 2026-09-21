-- Bronze -> Silver transformation, done via CETAS on Serverless SQL Pool rather than
-- spinning up a Spark pool for this — a deliberate, cost-conscious design choice
-- (same CETAS pattern as synapse-practice Module 13). Light cleaning + dedup, since
-- incremental Bronze loads can contain more than one version of a changed row across
-- different runs; keep only the latest version per business key.

CREATE EXTERNAL DATA SOURCE silver_source
WITH (
    LOCATION   = 'abfss://datalake@stretailplat07rjei.dfs.core.windows.net/silver/',
    CREDENTIAL = SynapseIdentity
);

CREATE EXTERNAL TABLE ext_silver_customers
WITH (LOCATION = 'customers/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format)
AS
SELECT customer_id, TRIM(full_name) AS full_name, LOWER(TRIM(email)) AS email,
       UPPER(country) AS country, segment, updated_at
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) AS rn
    FROM ext_bronze_customers
) x
WHERE rn = 1;

CREATE EXTERNAL TABLE ext_silver_products
WITH (LOCATION = 'products/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format)
AS
SELECT product_id, TRIM(product_name) AS product_name, category, unit_price
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY updated_at DESC) AS rn
    FROM ext_bronze_products
) x
WHERE rn = 1;

CREATE EXTERNAL TABLE ext_silver_orders
WITH (LOCATION = 'orders/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format)
AS
SELECT order_id, customer_id, order_date, UPPER(status) AS status, updated_at
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
    FROM ext_bronze_orders
) x
WHERE rn = 1;

CREATE EXTERNAL TABLE ext_silver_payments
WITH (LOCATION = 'payments/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format)
AS
SELECT payment_id, order_id, amount, currency, UPPER(payment_status) AS payment_status,
       payment_date, updated_at
FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY updated_at DESC) AS rn
    FROM ext_bronze_payments
) x
WHERE rn = 1;

-- order_items is a FULL load (no watermark), so no dedup-by-recency needed — but still
-- guard against a rerun of the FULL load duplicating rows if it landed a second file.
CREATE EXTERNAL TABLE ext_silver_order_items
WITH (LOCATION = 'order_items/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format)
AS
SELECT DISTINCT order_item_id, order_id, product_id, quantity, unit_price
FROM ext_bronze_order_items;

-- Check the data-processed cost of these CETAS statements in Monitor -> SQL requests,
-- same habit as synapse-practice Module 13.
