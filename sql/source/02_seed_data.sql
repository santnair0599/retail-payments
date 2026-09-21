-- Synthetic data generator — run once after 01_create_tables.sql.
-- Uses sys.all_columns as a cheap tally-number source (reliably has thousands of
-- rows in any Azure SQL database's system catalog) instead of hand-writing rows.

SET NOCOUNT ON;

------------------------------------------------------------
-- Customers (~200)
------------------------------------------------------------
;WITH tally AS (
    SELECT TOP (200) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns
)
INSERT INTO dbo.customers (full_name, email, country, segment, created_at, updated_at)
SELECT
    CONCAT('Customer ', n),
    CONCAT('customer', n, '@example.com'),
    CASE ABS(CHECKSUM(NEWID())) % 6
        WHEN 0 THEN 'AE' WHEN 1 THEN 'IN' WHEN 2 THEN 'GB'
        WHEN 3 THEN 'US' WHEN 4 THEN 'EG' ELSE 'SG' END,
    CASE WHEN ABS(CHECKSUM(NEWID())) % 2 = 0 THEN 'Business' ELSE 'Leisure' END,
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, SYSUTCDATETIME()),
    DATEADD(DAY, -ABS(CHECKSUM(NEWID())) % 365, SYSUTCDATETIME())
FROM tally;

------------------------------------------------------------
-- Products (~50)
------------------------------------------------------------
;WITH tally AS (
    SELECT TOP (50) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns
)
INSERT INTO dbo.products (product_name, category, unit_price, created_at, updated_at)
SELECT
    CONCAT('Product ', n),
    CASE ABS(CHECKSUM(NEWID())) % 4
        WHEN 0 THEN 'Electronics' WHEN 1 THEN 'Home' WHEN 2 THEN 'Apparel' ELSE 'Grocery' END,
    CAST(10 + (ABS(CHECKSUM(NEWID())) % 490) AS DECIMAL(10,2)),
    SYSUTCDATETIME(),
    SYSUTCDATETIME()
FROM tally;

------------------------------------------------------------
-- Orders (~3000), spread over the last 90 days
------------------------------------------------------------
;WITH tally AS (
    SELECT TOP (3000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_columns a CROSS JOIN sys.all_columns b
),
customer_count AS (SELECT COUNT(*) AS c FROM dbo.customers)
INSERT INTO dbo.orders (customer_id, order_date, status, created_at, updated_at)
SELECT
    1 + (ABS(CHECKSUM(NEWID())) % (SELECT c FROM customer_count)),
    DATEADD(MINUTE, -ABS(CHECKSUM(NEWID())) % (90 * 24 * 60), SYSUTCDATETIME()),
    CASE ABS(CHECKSUM(NEWID())) % 10
        WHEN 0 THEN 'CANCELLED'
        WHEN 1 THEN 'PLACED'
        WHEN 2 THEN 'CONFIRMED'
        ELSE 'COMPLETED' END,
    SYSUTCDATETIME(),
    SYSUTCDATETIME()
FROM tally;

-- Align created_at/updated_at with the synthetic order_date rather than "now" for realism.
UPDATE dbo.orders
SET created_at = order_date, updated_at = order_date;

------------------------------------------------------------
-- Order items (1-3 per order)
------------------------------------------------------------
;WITH item_counts AS (
    SELECT order_id, order_date, 1 + ABS(CHECKSUM(NEWID())) % 3 AS n_items
    FROM dbo.orders
),
expanded AS (
    SELECT ic.order_id, ic.order_date, x.item_no
    FROM item_counts ic
    CROSS APPLY (SELECT TOP (ic.n_items) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS item_no
                 FROM sys.all_columns) x
),
product_count AS (SELECT COUNT(*) AS c FROM dbo.products)
INSERT INTO dbo.order_items (order_id, product_id, quantity, unit_price, created_at, updated_at)
SELECT
    e.order_id,
    1 + (ABS(CHECKSUM(NEWID())) % (SELECT c FROM product_count)),
    1 + ABS(CHECKSUM(NEWID())) % 5,
    p.unit_price,
    e.order_date,
    e.order_date
FROM expanded e
CROSS APPLY (SELECT TOP 1 unit_price FROM dbo.products ORDER BY NEWID()) p;

------------------------------------------------------------
-- Payments (one per non-cancelled order; skip cancelled ones deliberately —
-- gives Phase 1's "payment status changes" simulation something real to update later)
------------------------------------------------------------
INSERT INTO dbo.payments (order_id, amount, currency, payment_status, payment_date, created_at, updated_at)
SELECT
    o.order_id,
    ISNULL((SELECT SUM(oi.quantity * oi.unit_price) FROM dbo.order_items oi WHERE oi.order_id = o.order_id), 0),
    'AED',
    CASE ABS(CHECKSUM(NEWID())) % 10
        WHEN 0 THEN 'PENDING'
        WHEN 1 THEN 'FAILED'
        ELSE 'PAID' END,
    o.order_date,
    o.order_date,
    o.order_date
FROM dbo.orders o
WHERE o.status <> 'CANCELLED';

-- Sanity check
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM dbo.customers
UNION ALL SELECT 'products', COUNT(*) FROM dbo.products
UNION ALL SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM dbo.payments;
