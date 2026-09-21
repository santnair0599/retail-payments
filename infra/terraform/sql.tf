# Azure SQL — the OLTP source: customers, products, orders, order_items, payments,
# plus the control tables (source_config, watermark_control, pipeline_audit).
# Table DDL itself lives in ../../sql/source and ../../sql/control — Terraform only
# provisions the server + database + AAD admin + firewall, not the schema.

resource "azurerm_mssql_server" "this" {
  name                         = "sql-${var.project_name}-${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = var.sql_admin_password
  minimum_tls_version          = "1.2"
  tags                         = var.tags

  # Required so you can later run 'CREATE USER [adf-name] FROM EXTERNAL PROVIDER'
  # for ADF's managed identity (see sql/control/02_grant_adf_managed_identity.sql).
  azuread_administrator {
    login_username = var.aad_admin_login
    object_id      = var.aad_admin_object_id
  }
}

resource "azurerm_mssql_database" "source" {
  name        = "retail_source_db"
  server_id   = azurerm_mssql_server.this.id
  sku_name    = "Basic" # cheapest tier — fine for a few thousand synthetic rows
  max_size_gb = 2
  tags        = var.tags
}

# Allows Azure services (including ADF's managed identity, once granted DB permissions)
# to reach this server. For a real production design you'd scope this much tighter —
# named IPs or a private endpoint — this is a practice-project simplification, said explicitly.
resource "azurerm_mssql_firewall_rule" "allow_azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Optional: allow your own current IP to connect directly with SSMS/Azure Data Studio.
# Fill in your own IP after 'terraform apply' if you want this (or add it manually
# in the Portal instead — it's the same effect, just outside Terraform's state).
variable "my_client_ip" {
  description = "Your current public IP, for direct SSMS/ADS access. Leave blank to skip."
  type        = string
  default     = ""
}

resource "azurerm_mssql_firewall_rule" "allow_my_ip" {
  count            = var.my_client_ip == "" ? 0 : 1
  name             = "AllowMyClientIP"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = var.my_client_ip
  end_ip_address   = var.my_client_ip
}
