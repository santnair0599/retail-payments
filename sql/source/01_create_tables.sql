-- Run against retail_source_db (the OLTP source database).
-- Deliberately simple: no history tracking, no soft-delete columns — every table
-- has created_at/updated_at, which is all the incremental ingestion pattern needs.

CREATE TABLE dbo.customers (
    customer_id     INT IDENTITY(1,1) PRIMARY KEY,
    full_name       NVARCHAR(100)   NOT NULL,
    email           NVARCHAR(150)   NOT NULL,
    country         NVARCHAR(50)    NOT NULL,
    segment         NVARCHAR(20)    NOT NULL,   -- 'Business' or 'Leisure'
    created_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.products (
    product_id      INT IDENTITY(1,1) PRIMARY KEY,
    product_name    NVARCHAR(150)   NOT NULL,
    category        NVARCHAR(50)    NOT NULL,
    unit_price      DECIMAL(10,2)   NOT NULL,
    created_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.orders (
    order_id        INT IDENTITY(1,1) PRIMARY KEY,
    customer_id     INT             NOT NULL REFERENCES dbo.customers(customer_id),
    order_date      DATETIME2       NOT NULL,
    status          NVARCHAR(20)    NOT NULL,   -- 'PLACED' / 'CONFIRMED' / 'CANCELLED' / 'COMPLETED'
    created_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.order_items (
    order_item_id   INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT             NOT NULL REFERENCES dbo.orders(order_id),
    product_id      INT             NOT NULL REFERENCES dbo.products(product_id),
    quantity        INT             NOT NULL,
    unit_price      DECIMAL(10,2)   NOT NULL,
    created_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.payments (
    payment_id      INT IDENTITY(1,1) PRIMARY KEY,
    order_id        INT             NOT NULL REFERENCES dbo.orders(order_id),
    amount          DECIMAL(10,2)   NOT NULL,
    currency        NVARCHAR(5)     NOT NULL DEFAULT 'AED',
    payment_status  NVARCHAR(20)    NOT NULL,   -- 'PENDING' / 'PAID' / 'FAILED' / 'REFUNDED'
    payment_date    DATETIME2       NULL,
    created_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at      DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
);

-- Helpful for the incremental watermark queries downstream.
CREATE INDEX ix_orders_updated_at   ON dbo.orders(updated_at);
CREATE INDEX ix_payments_updated_at ON dbo.payments(updated_at);
CREATE INDEX ix_customers_updated_at ON dbo.customers(updated_at);
