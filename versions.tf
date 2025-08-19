terraform {
  required_version = ">= 1.4.0"

  required_providers {
    volterra = {
      source  = "volterraedge/volterra"
      version = "0.11.44"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=4.39.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">=3.5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">=0.13.1"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">=4.1.0"
    }
  }
}
