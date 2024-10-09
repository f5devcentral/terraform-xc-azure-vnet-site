terraform {
  required_version = ">= 1.4.0"

  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = "0.11.37"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=2.44.0"
    }
  }
}