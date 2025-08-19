provider "volterra" {
  api_p12_file = var.xc_api_p12_file
  url          = var.xc_api_url
}

provider "azurerm" {
  features {}

  subscription_id = var.azure_subscription_id
  tenant_id       = var.azure_subscription_tenant_id
  client_id       = var.azure_service_principal_appid
  client_secret   = var.azure_service_principal_password
}

provider "azuread" {
  tenant_id = var.azure_subscription_tenant_id
}

module "azure_vnet_site" {
  source = "../.."

  site_name             = var.name
  azure_rg_location     = var.azure_rg_location
  azure_rg_name         = var.name
  site_type             = "ingress_egress_gw"
  master_nodes_az_names = ["1", "2", "3"]
  vnet_cidr             = "172.10.0.0/16"
  outside_subnets       = ["172.10.11.0/24", "172.10.12.0/24", "172.10.13.0/24"]
  inside_subnets        = ["172.10.31.0/24", "172.10.32.0/24", "172.10.33.0/24"]

  worker_nodes_per_az = 2

  az_cloud_credentials_name = module.azure_cloud_credentials.name
  block_all_services        = false

  global_network_connections_list = [{
    sli_to_global_dr = {
      global_vn = {
        name = "sli-to-global-dr"
      }
    }
  }]

  tags = {
    key1 = "value1"
    key2 = "value2"
  }

  depends_on = [
    module.azure_cloud_credentials
  ]
}

module "azure_cloud_credentials" {
  source  = "f5devcentral/azure-cloud-credentials/xc"
  version = "0.0.4"

  name                  = format("%s-creds", var.name)
  azure_subscription_id = var.azure_subscription_id
  azure_tenant_id       = var.azure_subscription_tenant_id
  azure_client_id       = var.azure_service_principal_appid
  azure_client_secret   = var.azure_service_principal_password
}
