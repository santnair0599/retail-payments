# Core resources: resource group, storage (data lake + Synapse primary filesystem), Key Vault.

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}"
  location = var.location
  tags     = var.tags
}

# --- Storage account: hierarchical namespace ON = ADLS Gen2 ---
resource "azurerm_storage_account" "this" {
  name                     = "st${var.project_name}${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true
  tags                     = var.tags
}

# Data lake filesystem: bronze/silver/gold live as folders inside this one filesystem,
# created by the ingestion pipeline / manually — Terraform just owns the filesystem itself.
resource "azurerm_storage_data_lake_gen2_filesystem" "datalake" {
  name               = "datalake"
  storage_account_id = azurerm_storage_account.this.id
}

# Synapse requires its own dedicated primary filesystem, separate from your data filesystem.
resource "azurerm_storage_data_lake_gen2_filesystem" "synapse_primary" {
  name               = "synapse-fs"
  storage_account_id = azurerm_storage_account.this.id
}

# --- Key Vault ---
resource "azurerm_key_vault" "this" {
  name                       = "kv-${var.project_name}-${random_string.suffix.result}"
  location                   = azurerm_resource_group.this.location
  resource_group_name        = azurerm_resource_group.this.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags
}

# You (the deploying user) get Secrets Officer so you can create the SQL admin password
# secret etc. by hand after apply, if you want it stored rather than only in tfvars.
resource "azurerm_role_assignment" "deployer_kv_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
