-- Real Azure SQL control tables — an upgrade from the JSON-file control table used in
-- your adf-practice sandbox (which used JSON specifically to avoid provisioning a paid
-- database for that sandbox). Here you already have Azure SQL as the source, so a real
-- control schema costs nothing extra and is the more production-realistic design.
-- Create a dedicated 'control' schema so these are visibly separate from business tables.

CREATE SCHEMA control;
GO

CREATE TABLE control.source_config (
    object_name       NVARCHAR(50)  PRIMARY KEY,
    source_table      NVARCHAR(100) NOT NULL,
    target_path        NVARCHAR(200) NOT NULL,
    load_type          NVARCHAR(20)  NOT NULL,   -- 'FULL' or 'INCREMENTAL'
    watermark_column    NVARCHAR(50)  NULL,
    enabled             BIT           NOT NULL DEFAULT 1
);

CREATE TABLE control.watermark_control (
    object_name       NVARCHAR(50)  PRIMARY KEY,
    last_watermark     DATETIME2     NOT NULL,
    last_run_status     NVARCHAR(20)  NULL,
    last_run_id         NVARCHAR(100) NULL
);

CREATE TABLE control.pipeline_audit (
    audit_id          INT IDENTITY(1,1) PRIMARY KEY,
    pipeline_run_id    NVARCHAR(100) NOT NULL,
    object_name        NVARCHAR(50)  NOT NULL,
    load_type          NVARCHAR(20)  NOT NULL,
    start_time         DATETIME2     NOT NULL,
    end_time           DATETIME2     NULL,
    rows_read          INT           NULL,
    rows_written        INT           NULL,
    status              NVARCHAR(20)  NOT NULL,   -- 'RUNNING' / 'SUCCESS' / 'FAILED'
    error_message       NVARCHAR(MAX) NULL,
    watermark_from      DATETIME2     NULL,
    watermark_to        DATETIME2     NULL
);
GO

-- Seed the five source objects. This is the exact same shape as adf-practice's
-- source_config.json — same design, now as real rows instead of a file.
INSERT INTO control.source_config (object_name, source_table, target_path, load_type, watermark_column, enabled) VALUES
('customers',   'dbo.customers',   'bronze/customers',   'INCREMENTAL', 'updated_at', 1),
('products',    'dbo.products',    'bronze/products',    'FULL',        NULL,         1),
('orders',      'dbo.orders',      'bronze/orders',      'INCREMENTAL', 'updated_at', 1),
('order_items', 'dbo.order_items', 'bronze/order_items', 'FULL',        NULL,         1),
('payments',    'dbo.payments',    'bronze/payments',    'INCREMENTAL', 'updated_at', 1);

-- Seed an initial watermark far in the past so the first INCREMENTAL run behaves like
-- a full history load. Every subsequent run only picks up what actually changed.
INSERT INTO control.watermark_control (object_name, last_watermark, last_run_status, last_run_id)
SELECT object_name, '1900-01-01', 'SEEDED', 'initial-seed'
FROM control.source_config
WHERE load_type = 'INCREMENTAL';

SELECT *
FROM control.source_config;

SELECT *
FROM control.watermark_control;