variable "project_name" {
  description = "Short project prefix used in resource names."
  type        = string
  default     = "retailplat"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "uaenorth"
}

variable "sql_admin_login" {
  description = "SQL Server admin login for the Azure SQL source database."
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "SQL Server admin password. Pass via TF_VAR_sql_admin_password env var or a tfvars file that is NOT committed to Git."
  type        = string
  sensitive   = true
}

variable "synapse_sql_admin_login" {
  description = "SQL admin login for the Synapse workspace's built-in pool."
  type        = string
  default     = "synapseadmin"
}

variable "synapse_sql_admin_password" {
  description = "SQL admin password for Synapse. Pass via TF_VAR_synapse_sql_admin_password env var."
  type        = string
  sensitive   = true
}

variable "aad_admin_login" {
  description = "Your Azure AD user principal name (UPN) — set as SQL Server's Azure AD admin, so you can later run 'CREATE USER FROM EXTERNAL PROVIDER' for ADF's managed identity. Find it with: az ad signed-in-user show --query userPrincipalName -o tsv"
  type        = string
}

variable "aad_admin_object_id" {
  description = "Your Azure AD object ID, paired with aad_admin_login above. Find it with: az ad signed-in-user show --query id -o tsv"
  type        = string
}

variable "dedicated_pool_sku" {
  description = "Dedicated SQL Pool performance tier. DW100c is the smallest/cheapest — do not increase for this project."
  type        = string
  default     = "DW100c"
}

variable "tags" {
  description = "Common tags applied to every resource."
  type        = map(string)
  default = {
    project = "retail-analytics-platform"
    purpose = "portfolio-practice"
  }
}
