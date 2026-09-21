# Monitoring & Deliberate Failure Handling

`control.pipeline_audit` (created in `sql/control/01_create_control_tables.sql`) already
captures the full audit record shape: `pipeline_run_id`, `object_name`, `load_type`,
`start_time`, `end_time`, `rows_read`, `rows_written`, `status`, `error_message`,
`watermark_from`, `watermark_to` — wired into `pl_child_ingestion` per `adf/README.md`.

## Deliberate failure scenarios — pick one (or all three) and actually break it

**1. Rename a source column.**
```sql
EXEC sp_rename 'dbo.orders.status', 'order_status', 'COLUMN';
```
Re-run `pl_master_ingestion`. The Copy Activity's source query (`SELECT ... status ...`) will
fail. Diagnose it in **ADF Monitor** — the exact error should name the missing column.
Rename it back when done:
```sql
EXEC sp_rename 'dbo.orders.order_status', 'status', 'COLUMN';
```

**2. Remove an expected input at the Silver layer.**
Delete the `products/` folder contents from ADLS before running `02_bronze_to_silver_cetas.sql`
again. The CETAS statement for `ext_silver_products` should fail with a path-not-found style
error — diagnose it in **Synapse Monitor → SQL requests**, same DMV/monitoring discipline as
`synapse-practice` Module 09.

**3. Break a SQL permission.**
```sql
REVOKE SELECT ON SCHEMA::control FROM [<adf-managed-identity-name>];
```
Re-run the pipeline — the Lookup activity reading `control.source_config` should fail with
an authorization error. Diagnose it in ADF Monitor, then restore the grant:
```sql
GRANT SELECT, INSERT, UPDATE ON SCHEMA::control TO [<adf-managed-identity-name>];
```

## Where to actually look

| Layer | Tool |
|---|---|
| ADF pipeline/activity failures | ADF Monitor (pipeline runs, activity runs) |
| Synapse SQL query failures/cost | Synapse Studio → Monitor → SQL requests |
| Dedicated Pool query-level diagnosis | `sys.dm_pdw_exec_requests` / `sys.dm_pdw_request_steps` (synapse-practice Module 12) |
| Cross-cutting, longer retention | Log Analytics via diagnostic settings, KQL |
| Business-level audit trail | `control.pipeline_audit` — the one table that answers "did the right data actually arrive," not just "did the pipeline succeed" |

The `pipeline_audit` table is the important one to point to in an interview: a green ADF
Monitor run doesn't prove correct data arrived — `rows_read`/`rows_written`/`watermark_to`
in this table are what actually let you confirm that.
