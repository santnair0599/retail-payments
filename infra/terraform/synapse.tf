# Synapse workspace + Dedicated SQL Pool.
#
# COST WARNING: azurerm_synapse_sql_pool creates the pool in an ONLINE (billing) state
# immediately. There is no native Terraform "create paused" or auto-pause-on-idle option
# for Dedicated Pool (auto-pause exists for Spark pools and is implicit for Serverless,
# but NOT for Dedicated Pool as of this provider version — don't rely on Terraform to
# protect you from cost here). Use scripts/pause_dedicated_pool.sh immediately after
# every session — see that script and the README.

resource "azurerm_synapse_workspace" "this" {
  name                                 = "synws-${var.project_name}-${random_string.suffix.result}"
  resource_group_name                  = azurerm_resource_group.this.name
  location                             = azurerm_resource_group.this.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse_primary.id
  sql_administrator_login              = var.synapse_sql_admin_login
  sql_administrator_login_password     = var.synapse_sql_admin_password
  tags                                 = var.tags

  identity {
    type = "SystemAssigned"
  }

  # Purely for this practice project's convenience — a real deployment would scope
  # this to specific IP ranges / private endpoints instead of allowing all.
  lifecycle {
    ignore_changes = [
      # avoids Terraform fighting with any manual Studio-side firewall tweaks you make
      sql_administrator_login_password,
    ]
  }
}

resource "azurerm_synapse_firewall_rule" "allow_azure_services" {
  # Synapse's firewall API specifically requires this exact name when the rule allows
  # all Azure IPs (0.0.0.0-0.0.0.0) — a genuine Azure API validation, not something
  # you can name arbitrarily like the equivalent Azure SQL Server rule in sql.tf.
  name                 = "AllowAllWindowsAzureIps"
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "0.0.0.0"
}

resource "azurerm_synapse_firewall_rule" "allow_my_ip" {
  count                = var.my_client_ip == "" ? 0 : 1
  name                 = "AllowMyClientIP"
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  start_ip_address     = var.my_client_ip
  end_ip_address       = var.my_client_ip
}

resource "azurerm_synapse_sql_pool" "dedicated" {
  name                 = "sqlpool1"
  synapse_workspace_id = azurerm_synapse_workspace.this.id
  sku_name             = var.dedicated_pool_sku
  create_mode          = "Default"
  tags                 = var.tags
}

# Synapse workspace managed identity -> Storage Blob Data Contributor on the data lake
# (needed for Synapse to read/write bronze/silver/gold, same principle as ADF's grant).
resource "azurerm_role_assignment" "synapse_storage_contributor" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_synapse_workspace.this.identity[0].principal_id
}

output "synapse_workspace_name" {
  value = azurerm_synapse_workspace.this.name
}

output "dedicated_pool_name" {
  value       = azurerm_synapse_sql_pool.dedicated.name
  description = "Pass this to scripts/pause_dedicated_pool.sh and resume_dedicated_pool.sh"
}
