output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.this.fully_qualified_domain_name
}

output "sql_database_name" {
  value = azurerm_mssql_database.source.name
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "data_factory_name" {
  value = azurerm_data_factory.this.name
}
