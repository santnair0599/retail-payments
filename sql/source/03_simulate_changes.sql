-- Run this AFTER your first FULL ingestion has already captured a baseline snapshot.
-- Everything here bumps updated_at, which is exactly what your INCREMENTAL watermark
-- pipeline needs to pick up on its next run. Run this, then trigger pl_master_ingestion
-- again with INCREMENTAL load_type rows and confirm only these changes land in Bronze.

SET NOCOUNT ON;

------------------------------------------------------------
-- 1. New orders (plus their items and a payment) — simulates real new business
------------------------------------------------------------
DECLARE @new_order_id INT;

INSERT INTO dbo.orders (customer_id, order_date, status, created_at, updated_at)
SELECT TOP (25) customer_id, SYSUTCDATETIME(), 'PLACED', SYSUTCDATETIME(), SYSUTCDATETIME()
FROM dbo.customers ORDER BY NEWID();

INSERT INTO dbo.order_items (order_id, product_id, quantity, unit_price, created_at, updated_at)
SELECT o.order_id,
       (SELECT TOP 1 product_id FROM dbo.products ORDER BY NEWID()),
       1 + ABS(CHECKSUM(NEWID())) % 3,
       (SELECT TOP 1 unit_price FROM dbo.products ORDER BY NEWID()),
       o.created_at, o.created_at
FROM dbo.orders o
WHERE o.created_at >= DATEADD(MINUTE, -2, SYSUTCDATETIME());

INSERT INTO dbo.payments (order_id, amount, currency, payment_status, payment_date, created_at, updated_at)
SELECT o.order_id,
       ISNULL((SELECT SUM(oi.quantity * oi.unit_price) FROM dbo.order_items oi WHERE oi.order_id = o.order_id), 0),
       'AED', 'PENDING', NULL, o.created_at, o.created_at
FROM dbo.orders o
WHERE o.created_at >= DATEADD(MINUTE, -2, SYSUTCDATETIME());

------------------------------------------------------------
-- 2. Updated customers — a real update, real updated_at bump
------------------------------------------------------------
UPDATE TOP (10) dbo.customers
SET segment = CASE WHEN segment = 'Business' THEN 'Leisure' ELSE 'Business' END,
    updated_at = SYSUTCDATETIME();

------------------------------------------------------------
-- 3. Payment status changes — PENDING -> PAID, a couple to FAILED
------------------------------------------------------------
UPDATE TOP (15) dbo.payments
SET payment_status = 'PAID',
    payment_date   = SYSUTCDATETIME(),
    updated_at     = SYSUTCDATETIME()
WHERE payment_status = 'PENDING';

UPDATE TOP (3) dbo.payments
SET payment_status = 'FAILED',
    updated_at     = SYSUTCDATETIME()
WHERE payment_status = 'PENDING';

------------------------------------------------------------
-- 4. Cancelled order — status change on an existing order, not a delete
------------------------------------------------------------
UPDATE TOP (5) dbo.orders
SET status = 'CANCELLED', updated_at = SYSUTCDATETIME()
WHERE status IN ('PLACED', 'CONFIRMED');

-- What changed, for your own sanity check before running the incremental pipeline:
SELECT 'orders changed in last 5 min'   AS what, COUNT(*) FROM dbo.orders   WHERE updated_at >= DATEADD(MINUTE, -5, SYSUTCDATETIME())
UNION ALL
SELECT 'payments changed in last 5 min', COUNT(*) FROM dbo.payments WHERE updated_at >= DATEADD(MINUTE, -5, SYSUTCDATETIME())
UNION ALL
SELECT 'customers changed in last 5 min', COUNT(*) FROM dbo.customers WHERE updated_at >= DATEADD(MINUTE, -5, SYSUTCDATETIME());
