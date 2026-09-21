# ADF Ingestion Framework — Design Notes

Same pattern as `adf-practice` Module 04 (metadata-driven ingestion), upgraded from JSON-file
config to real Azure SQL control tables (`control.source_config`, `control.watermark_control`,
`control.pipeline_audit`, created by `sql/control/01_create_control_tables.sql`).

ADF pipelines themselves are authored in ADF Studio's UI/JSON (not something to hand-write
here) — this doc gives you the exact shape to build, matching what you already know.

## Linked services needed

1. **Azure SQL Database** linked service, pointed at `retail_source_db` — authenticate via
   ADF's **System Assigned Managed Identity** (not a SQL login), since you already granted it
   `db_datareader` + control-schema access in `sql/control/02_grant_adf_managed_identity.sql`.
2. **ADLS Gen2** linked service, pointed at the `datalake` filesystem from Terraform, via
   managed identity (already granted `Storage Blob Data Contributor` by Terraform).
3. **Azure Key Vault** linked service, for anything that can't use managed identity directly.

## `pl_master_ingestion`

```
Lookup (reads control.source_config WHERE enabled = 1)
        ↓
ForEach (Items = @activity('Lookup Config').output.value, batch count 2-3, not unlimited)
        ↓
    Execute Pipeline -> pl_child_ingestion
        parameters:
          pObjectName    = @item().object_name
          pSourceTable   = @item().source_table
          pTargetPath    = @item().target_path
          pLoadType      = @item().load_type
          pWatermarkCol  = @item().watermark_column
```

## `pl_child_ingestion`

```
Set Variable  vRunStartTime = @utcNow()
        ↓
If Condition  @equals(toUpper(pipeline().parameters.pLoadType), 'INCREMENTAL')

  True branch (INCREMENTAL):
    Lookup  -> control.watermark_control WHERE object_name = @pipeline().parameters.pObjectName
        ↓
    Set Variable  vLastWatermark = @activity('Lookup Watermark').output.value[0].last_watermark
        ↓
    Set Variable  vUpperBound = @utcNow()
        ↓
    Copy Activity
        Source: dynamic SQL query against pSourceTable, filtered
                WHERE [pWatermarkCol] > '@{variables('vLastWatermark')}'
                  AND [pWatermarkCol] <= '@{variables('vUpperBound')}'
        Sink: ADLS parquet, folder = @{pipeline().parameters.pTargetPath}
        ↓
    Set Variable  vLastWatermark (commit) = @variables('vUpperBound')
        -- exactly the "commit the captured upper bound, not a fresh utcNow()" rule
        -- from adf-practice Module 05 — the same real bug you caught there applies here.
        ↓
    Script Activity / Stored Proc -> UPDATE control.watermark_control
        SET last_watermark = @{variables('vLastWatermark')}, last_run_status = 'SUCCESS'
        WHERE object_name = @{pipeline().parameters.pObjectName}

  False branch (FULL):
    Copy Activity
        Source: SELECT * FROM [pSourceTable] (no filter)
        Sink: ADLS parquet, folder = @{pipeline().parameters.pTargetPath}, overwrite mode
        -- deterministic overwrite, same reasoning as adf-practice Module 04's FULL branch

        ↓ (both branches converge here — same If Condition convergence trick from
           adf-practice capstone: hook the next step off the If Condition's own Success
           output, not off each branch separately)

Script Activity -> INSERT INTO control.pipeline_audit
    (pipeline_run_id, object_name, load_type, start_time, end_time,
     rows_read, rows_written, status, watermark_from, watermark_to)
    VALUES (@pipeline().RunId, @pipeline().parameters.pObjectName, ..., 'SUCCESS', ...)

On Failure path (from the Copy Activity):
    Script Activity -> INSERT INTO control.pipeline_audit (..., status = 'FAILED',
        error_message = @{activity('Copy').error.message})
        ↓
    Fail Activity -> deliberately fail the parent, same discipline as adf-practice Module 07
```

## Output format — use Parquet, not CSV, for Bronze

Unlike `adf-practice`'s sandbox (which used CSV for simplicity), land Bronze here as
**Parquet** — this sets up the Synapse Serverless layer (Phase 4) to demonstrate the real
cost/performance benefit from `synapse-practice` Module 13, rather than re-explaining CSV's
limitations on a project meant to look production-realistic.

## Sizing the ForEach batch count

With 5 objects, don't run all 5 fully parallel — cap `batchCount` at 2-3, the same
"protect the source system" discipline from `adf-practice` Module 04, now meaningful for
real reasons: this is a real Azure SQL Basic-tier database with limited DTUs, and running
5 concurrent Copy activities against it at once is a genuine way to throttle your own source.
