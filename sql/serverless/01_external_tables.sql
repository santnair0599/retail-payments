-- Run against Synapse Serverless SQL ("Built-in" pool). Bronze is Parquet, written by
-- the ADF pipeline described in adf/README.md.

CREATE DATABASE retail_lake_db;
GO
-- Switch your script's connected database to retail_lake_db before continuing.

CREATE EXTERNAL FILE FORMAT parquet_format
WITH (FORMAT_TYPE = PARQUET);

CREATE EXTERNAL DATA SOURCE bronze_source
WITH (LOCATION = 'https://stretailplat07rjei.dfs.core.windows.net/datalake/bronze/');

CREATE EXTERNAL TABLE ext_bronze_customers (
    customer_id INT, full_name VARCHAR(100), email VARCHAR(150),
    country VARCHAR(50), segment VARCHAR(20), created_at DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'customers/', DATA_SOURCE = bronze_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_bronze_products (
    product_id INT, product_name VARCHAR(150), category VARCHAR(50),
    unit_price DECIMAL(10,2), created_at DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'products/', DATA_SOURCE = bronze_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_bronze_orders (
    order_id INT, customer_id INT, order_date DATETIME2, status VARCHAR(20),
    created_at DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'orders/', DATA_SOURCE = bronze_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_bronze_order_items (
    order_item_id INT, order_id INT, product_id INT, quantity INT, unit_price DECIMAL(10,2),
    created_at DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'order_items/', DATA_SOURCE = bronze_source, FILE_FORMAT = parquet_format);

CREATE EXTERNAL TABLE ext_bronze_payments (
    payment_id INT, order_id INT, amount DECIMAL(10,2), currency VARCHAR(5),
    payment_status VARCHAR(20), payment_date DATETIME2, created_at DATETIME2, updated_at DATETIME2
) WITH (LOCATION = 'payments/', DATA_SOURCE = bronze_source, FILE_FORMAT = parquet_format);

-- Quick check
SELECT COUNT(*) FROM ext_bronze_orders;
