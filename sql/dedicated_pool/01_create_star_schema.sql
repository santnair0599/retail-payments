-- Run against the Dedicated Pool (sqlpool1), connected — NOT Built-in/Serverless.
-- Resume the pool first: scripts/resume_dedicated_pool.sh
--
-- Dedicated Pool has its OWN external table mechanism (PolyBase-based), separate from
-- Serverless's — even though both point at the same Silver Parquet files, you need a
-- second set of EXTERNAL FILE FORMAT / DATA SOURCE / TABLE objects defined here.

-- Dedicated Pool needs its own master key + managed-identity credential — separate
-- from anything created on the Serverless/Built-in pool, since each pool is its own
-- database as far as scoped credentials are concerned.
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'ANOTHER-STRONG-MASTER-KEY-PASSWORD';

CREATE DATABASE SCOPED CREDENTIAL SynapseIdentity
WITH IDENTITY = 'Managed Identity';

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (FORMAT_TYPE = PARQUET);

CREATE EXTERNAL DATA SOURCE silver_source
WITH (
    LOCATION   = 'abfss://datalake@stretailplat07rjei.dfs.core.windows.net/silver/',
    CREDENTIAL = SynapseIdentity
);

CREATE EXTERNAL TABLE ext_dp_silver_customers (
    customer_id INT, full_name VARCHAR(100), email VARCHAR(150), country VARCHAR(50),
    segment VARCHAR(20), updated_at DATETIME2
) WITH (LOCATION = 'customers/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_dp_silver_products (
    product_id INT, product_name VARCHAR(150), category VARCHAR(50), unit_price DECIMAL(10,2)
) WITH (LOCATION = 'products/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_dp_silver_orders (
    order_id INT, customer_id INT, order_date DATETIME2, status VARCHAR(20), updated_at DATETIME2
) WITH (LOCATION = 'orders/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_dp_silver_payments (
    payment_id INT, order_id INT, amount DECIMAL(10,2), currency VARCHAR(5),
    payment_status VARCHAR(20), payment_date DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'payments/', DATA_SOURCE = silver_source, FILE_FORMAT = parquet_format);

------------------------------------------------------------
-- Dimension tables — REPLICATE (small, frequently joined)
------------------------------------------------------------
CREATE TABLE dim_customer
WITH (DISTRIBUTION = REPLICATE, CLUSTERED COLUMNSTORE INDEX)
AS
SELECT customer_id, full_name, email, country, segment FROM ext_dp_silver_customers;

CREATE TABLE dim_product
WITH (DISTRIBUTION = REPLICATE, CLUSTERED COLUMNSTORE INDEX)
AS
SELECT product_id, product_name, category, unit_price FROM ext_dp_silver_products;

-- dim_date — no source table for this; generated directly, the standard DW pattern.
-- Covers a 2-year window, plenty for this project's order date range.
;WITH tally AS (
    SELECT TOP (730) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
),
dates AS (
    SELECT DATEADD(DAY, n, '2025-01-01') AS full_date FROM tally
)
SELECT
    CAST(FORMAT(full_date, 'yyyyMMdd') AS INT) AS date_key,
    full_date,
    YEAR(full_date)                            AS year,
    MONTH(full_date)                           AS month,
    DATENAME(MONTH, full_date)                 AS month_name,
    DAY(full_date)                             AS day,
    DATENAME(WEEKDAY, full_date)               AS day_of_week,
    DATEPART(QUARTER, full_date)                AS quarter
INTO dim_date_staging
FROM dates;

CREATE TABLE dim_date
WITH (DISTRIBUTION = REPLICATE, CLUSTERED COLUMNSTORE INDEX)
AS SELECT * FROM dim_date_staging;

DROP TABLE dim_date_staging;

------------------------------------------------------------
-- Fact table — one row per order (payments.amount already reflects the order total,
-- so no separate order_items aggregation is needed to build this).
-- HASH on customer_id: analysis is expected to be mostly by customer/segment, matching
-- the Power BI visuals planned in Phase 8.
------------------------------------------------------------
CREATE TABLE fact_sales
WITH (DISTRIBUTION = HASH(customer_id), CLUSTERED COLUMNSTORE INDEX)
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
LEFT JOIN ext_dp_silver_payments p ON o.order_id = p.order_id;

------------------------------------------------------------
-- Prove the star schema works end to end
------------------------------------------------------------
SELECT c.segment, COUNT(*) AS orders, SUM(f.amount) AS revenue
FROM fact_sales f
JOIN dim_customer c ON f.customer_id = c.customer_id
WHERE f.order_status <> 'CANCELLED'
GROUP BY c.segment
ORDER BY revenue DESC;

-- Don't forget: scripts/pause_dedicated_pool.sh when you're done.
