-- This is the step Terraform's azurerm provider CANNOT do for you — SQL-level
-- database permissions are data-plane, not Azure-resource-plane, so they need a real
-- SQL script. Run this connected as the Azure AD admin (the aad_admin_login you set
-- as the server's AAD administrator in infra/terraform/sql.tf), against retail_source_db.
--
-- Replace <adf-managed-identity-name> with the exact value from Terraform's
-- 'adf_managed_identity_display_name' output (it's the Data Factory resource's own
-- name — that's what SQL Server sees as the AAD identity's display name).

CREATE USER [adf-retailplat-07rjei] FROM EXTERNAL PROVIDER;

-- Read-only is enough for a source system ADF only ever extracts from.
ALTER ROLE db_datareader ADD MEMBER [adf-retailplat-07rjei];

-- Also grant read on the control schema, since pl_master_ingestion's Lookup activities
-- read source_config and watermark_control, and pl_child_ingestion writes pipeline_audit
-- and updates watermark_control after a successful load.
GRANT SELECT, INSERT, UPDATE ON SCHEMA::control TO [adf-retailplat-07rjei];

-- Verify:
SELECT dp.name AS user_name, dp.type_desc, r.name AS role_name
FROM sys.database_role_members drm
JOIN sys.database_principals dp ON drm.member_principal_id = dp.principal_id
JOIN sys.database_principals r  ON drm.role_principal_id = r.principal_id
WHERE dp.name = 'adf-retailplat-07rjei';
