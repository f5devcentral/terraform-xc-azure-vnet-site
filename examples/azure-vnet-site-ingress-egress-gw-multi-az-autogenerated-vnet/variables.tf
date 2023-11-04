variable "name" {
  description = "Name of the Azure VNET Site"
  type        = string
  default     = "az-site-example"
}

variable "azure_rg_location" {
  type    = string
  default = "westus2"
}

variable "azure_subscription_id" {
  type    = string
  default = ""
}

variable "azure_subscription_tenant_id" {
  type    = string
  default = ""
}

variable "azure_service_principal_appid" {
  type    = string
  default = ""
}

variable "azure_service_principal_password" {
  type    = string
  default = ""
}

variable "xc_api_url" {
  description = "F5 XC Cloud API URL"
  type        = string
  default     = "https://your_xc-cloud_api_url.console.ves.volterra.io/api"
}

variable "xc_api_p12_file" {
  description = "Path to F5 XC Cloud API certificate"
  type        = string
  default     = "./api-certificate.p12"
}