# Power BI — Connection and Measures

## Connect

Power BI Desktop → Get Data → Azure → **Azure Synapse Analytics SQL** → server = your
Dedicated Pool's connection string (from Synapse workspace overview) → database = the
Dedicated Pool database → **DirectQuery** (so the dashboard always reflects the latest
`fact_sales`/`dim_*` state, not an imported snapshot) or Import, your choice for this
practice project — DirectQuery is the more production-realistic choice.

## Model relationships

- `fact_sales[customer_id]` → `dim_customer[customer_id]`
- `fact_sales[date_key]` → `dim_date[date_key]`
- No `dim_product` relationship exists yet since `fact_sales` is at order grain, not
  order-item grain (deliberate simplification for this project) — note this explicitly
  if asked, rather than pretending a product-level breakdown exists when it doesn't.

## DAX measures

```dax
Total Revenue =
CALCULATE(SUM(fact_sales[amount]), fact_sales[order_status] <> "CANCELLED")

Order Count =
CALCULATE(COUNTROWS(fact_sales), fact_sales[order_status] <> "CANCELLED")

Cancelled Orders =
CALCULATE(COUNTROWS(fact_sales), fact_sales[order_status] = "CANCELLED")

Cancellation Rate =
DIVIDE([Cancelled Orders], [Order Count] + [Cancelled Orders])

Paid Revenue =
CALCULATE([Total Revenue], fact_sales[payment_status] = "PAID")
```

## Visuals to build (matches the original scenario's Phase 8 list)

1. **Sales by month** — line chart, `dim_date[month_name]`/`year` on axis, `[Total Revenue]`.
2. **Sales by customer segment** — bar chart, `dim_customer[segment]`, `[Total Revenue]`.
3. **Order status breakdown** — donut/bar, `fact_sales[order_status]`, `[Order Count]`.
4. **Revenue KPI card** — `[Total Revenue]` and `[Cancellation Rate]` as two KPI cards.
5. *(Sales by product is intentionally dropped from the original scenario's list — it needs
   order-item grain, which this project's simplified order-level fact table doesn't carry.
   If you want it later, it would need a second fact table at order-item grain, joined to
   `dim_product` — a real, known, documented extension rather than a silent gap.)*
