# Azure Data Factory — the ingestion orchestrator.
# Managed identity RBAC is granted here (storage + Key Vault). The Azure SQL side
# needs a SQL-level user grant, which Terraform's azurerm provider does not manage —
# see sql/control/02_grant_adf_managed_identity.sql for that step, run manually or
# from the CI/CD pipeline's post-infra stage. Same "Terraform owns Azure-resource RBAC,
# SQL scripts own data-plane grants" boundary used throughout this project.

resource "azurerm_data_factory" "this" {
  name                = "adf-${var.project_name}-${random_string.suffix.result}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

# ADF managed identity -> Storage Blob Data Contributor on the whole storage account
# (covers both the data lake filesystem and, if ever needed, the synapse-fs one).
resource "azurerm_role_assignment" "adf_storage_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

# ADF managed identity -> Key Vault Secrets User (read-only secret access).
resource "azurerm_role_assignment" "adf_keyvault_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_data_factory.this.identity[0].principal_id
}

output "adf_managed_identity_principal_id" {
  value       = azurerm_data_factory.this.identity[0].principal_id
  description = "Paste this into sql/control/02_grant_adf_managed_identity.sql where indicated."
}

output "adf_managed_identity_display_name" {
  value       = azurerm_data_factory.this.name
  description = "ADF's managed identity is granted a SQL user matching this exact name — CREATE USER [<this-name>] FROM EXTERNAL PROVIDER."
}
