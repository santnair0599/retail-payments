# Retail / Orders Analytics Platform

A small, production-shaped project combining everything from `adf-practice` and
`synapse-practice`, plus real Terraform and Azure DevOps CI/CD — the one piece neither
of those two curricula covered. Built against a **real Azure SQL OLTP source**, not flat
CSV files, and a **real Synapse Dedicated SQL Pool**, both genuine gaps versus your
InvestSphere Payments project (Databricks-only).

**Deliberately simplified, per instruction:** order-level fact grain (not order-item
level), SCD Type 1 / overwrite dimensions (not SCD2), no formal cross-layer
reconciliation scripts. These are real, known simplifications — say so plainly if asked,
rather than implying more sophistication than what's actually built.

```
Azure SQL (OLTP source)
   ↓  ADF incremental ingestion (managed identity, watermark pattern)
ADLS Bronze (Parquet)
   ↓  Synapse Serverless CETAS (cost-conscious — no Spark pool needed for this)
ADLS Silver (Parquet, cleaned + deduped)
   ↓  Synapse Serverless external tables (schema-on-read access)
   ↓  Dedicated SQL Pool CTAS / COPY INTO + MERGE (star schema)
Power BI (DirectQuery against the Dedicated Pool)
```

## Folder structure

```
retail-analytics-platform/
  README.md
  infra/terraform/          Resource group, storage, Azure SQL, ADF, Synapse + Dedicated Pool, Key Vault, RBAC
  sql/source/                Source table DDL, synthetic data generator, change-simulation script
  sql/control/                source_config / watermark_control / pipeline_audit (real Azure SQL tables) + the ADF managed-identity grant script
  sql/serverless/              External tables over Bronze + Bronze->Silver CETAS
  sql/dedicated_pool/           Star schema CTAS, incremental MERGE refresh, RLS/masking
  adf/README.md                pl_master_ingestion / pl_child_ingestion design (build in ADF Studio)
  cicd/                        Three Azure DevOps YAML pipelines: infra, ADF, Synapse
  scripts/                     pause/resume Dedicated Pool CLI scripts
  powerbi/measures.md           DAX measures + visual list
  docs/                         Monitoring & deliberate-failure-handling notes
```

## Build order

1. **Infra.** Copy `infra/terraform/terraform.tfvars.example` → `terraform.tfvars`, fill in real values (never commit it — see `.gitignore`). `terraform init && terraform plan && terraform apply`. Note the outputs — you'll need `adf_managed_identity_display_name` shortly.
2. **Source schema + data.** Connect to `retail_source_db` (SSMS / Azure Data Studio / `sqlcmd`), run `sql/source/01_create_tables.sql`, then `02_seed_data.sql`.
3. **Control tables.** Run `sql/control/01_create_control_tables.sql`, then `02_grant_adf_managed_identity.sql` (replace the placeholder name with Terraform's output first).
4. **Build the ADF pipelines** in ADF Studio, following `adf/README.md` exactly. Run `pl_master_ingestion` once — this is your FULL baseline load for `products`/`order_items` and the first INCREMENTAL pass for the rest.
5. **Simulate changes.** Run `sql/source/03_simulate_changes.sql`, then re-run `pl_master_ingestion` — confirm only the changed rows land, and `control.pipeline_audit` records both runs.
6. **Serverless layer.** In Synapse Studio, run `sql/serverless/01_external_tables.sql`, then `02_bronze_to_silver_cetas.sql`.
7. **Dedicated Pool.** `scripts/resume_dedicated_pool.sh`, then `sql/dedicated_pool/01_create_star_schema.sql`. After your next round of simulated changes + re-ingestion, use `02_incremental_refresh.sql` instead of rebuilding from scratch. Run `03_security.sql` once. **Always `scripts/pause_dedicated_pool.sh` when you stop.**
8. **Power BI.** Follow `powerbi/measures.md`.
9. **Break it on purpose.** Follow `docs/monitoring_and_failure_handling.md` — pick at least one deliberate failure and actually diagnose it.
10. **CI/CD.** Once the manual build works end to end, wire up the three pipelines in `cicd/` against a real Azure DevOps project — infra, ADF, Synapse, in that dependency order.

## Cost discipline, restated

Azure SQL Basic tier and ADLS storage are cheap enough to leave running. **The Dedicated
SQL Pool is not** — it bills continuously while online, and neither Terraform nor Azure
DevOps will pause it for you automatically (see the warning in `infra/terraform/synapse.tf`).
The two pause/resume scripts in `scripts/` are not optional extras — use them every session.

## Interview narrative

Once built, use the same structure that's worked for every other project in your prep:
business problem (a retail team needs one trusted revenue/order view instead of
inconsistent exports) → architecture (the flow diagram above, with the "responsibility
per service, not service count" framing) → key decisions (managed-identity-only auth,
Parquet over CSV, CETAS instead of a Spark pool for Bronze→Silver, hash-vs-replicate
distribution choices) → production controls (the audit table, deliberate failure
handling, CI/CD with approval gates) → results (a working star schema feeding a real
Power BI dashboard, end to end).
