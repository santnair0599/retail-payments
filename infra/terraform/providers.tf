terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Remote state — required so your local `terraform apply` runs and the CI pipeline's
  # ephemeral agents share the same state. Without this, each one starts from zero and
  # thinks nothing exists yet, colliding with resources the other one already created.
  # The 'tfstate' container itself is created manually (az storage container create) —
  # this project's own storage account can't be its own backend's bootstrap dependency.
  backend "azurerm" {
    resource_group_name  = "rg-retailplat"
    storage_account_name = "stretailplat07rjei"
    container_name        = "tfstate"
    key                    = "retail-analytics-platform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

data "azurerm_client_config" "current" {}
