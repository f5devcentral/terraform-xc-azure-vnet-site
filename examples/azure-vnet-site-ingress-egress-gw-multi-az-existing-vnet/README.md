# Multi-AZ Ingress/Egress Gateway with Existing VNET

This example demonstrates how to deploy an F5 Distributed Cloud (XC) Azure VNET Site with ingress/egress gateway functionality across multiple availability zones using an existing VNET infrastructure.

## Configuration

This example creates:
- A new Azure Resource Group for networking (via F5 networking module)
- A new VNET with CIDR `172.10.0.0/16` (via F5 networking module)
- Outside subnets across 3 AZs: `172.10.11.0/24`, `172.10.12.0/24`, `172.10.13.0/24`
- Inside subnets across 3 AZs: `172.10.31.0/24`, `172.10.32.0/24`, `172.10.33.0/24`
- F5 XC Azure VNET Site configured to use the existing multi-AZ VNET infrastructure

## Prerequisites

1. **F5 Distributed Cloud Account**: You need an active F5 XC account
2. **Azure Subscription**: Valid Azure subscription with appropriate permissions
3. **Service Principal**: Azure Service Principal with contributor access
4. **F5 XC API Credentials**: API certificate (.p12 file) from F5 XC console
5. **Multi-AZ Support**: Ensure your target Azure region supports the availability zones you plan to use

## Variables

| Name                             | Description                                   | Type     | Default             |
| -------------------------------- | --------------------------------------------- | -------- | ------------------- |
| name                             | Name of the Azure VNET Site                   | `string` | `"az-site-example"` |
| azure_rg_location                | Azure region where resources will be deployed | `string` | `"westus2"`         |
| azure_subscription_id            | Azure subscription ID                         | `string` | `""`                |
| azure_subscription_tenant_id     | Azure tenant ID                               | `string` | `""`                |
| azure_service_principal_appid    | Azure service principal application ID        | `string` | `""`                |
| azure_service_principal_password | Azure service principal password              | `string` | `""`                |
| xc_api_url                       | F5 XC API URL                                 | `string` | `""`                |
| xc_api_p12_file                  | Path to F5 XC API certificate (.p12 file)     | `string` | `""`                |

## Usage

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd terraform-xc-azure-vnet-site/examples/azure-vnet-site-ingress-egress-gw-multi-az-existing-vnet
   ```

2. **Set up your variables**:
   Create a `terraform.tfvars` file:
   ```hcl
   name = "my-xc-site-ha"
   azure_rg_location = "eastus"  # Ensure this region supports 3 AZs
   azure_subscription_id = "your-subscription-id"
   azure_subscription_tenant_id = "your-tenant-id"
   azure_service_principal_appid = "your-sp-app-id"
   azure_service_principal_password = "your-sp-password"
   xc_api_url = "https://your-tenant.console.ves.volterra.io/api"
   xc_api_p12_file = "/path/to/your/api-cert.p12"
   ```

3. **Initialize and apply**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Outputs

| Name                | Description                                    |
| ------------------- | ---------------------------------------------- |
| site_name           | Name of the created F5 XC site                 |
| site_id             | ID of the created F5 XC site                   |
| vnet_id             | ID of the existing Azure VNET                  |
| vnet_name           | Name of the existing Azure VNET                |
| resource_group_name | Name of the networking resource group          |
| availability_zones  | List of availability zones used for deployment |

## Clean Up

To destroy the resources:
```bash
terraform destroy
```
