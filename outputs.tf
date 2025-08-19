output "name" {
  description = "Name of the configured Azure VNET Site."
  value       = volterra_azure_vnet_site.this.name
}

output "id" {
  description = "ID of the configured Azure VNET Site."
  value       = volterra_azure_vnet_site.this.id
}

output "ssh_private_key_pem" {
  description = "Azure VNET Site generated private key."
  value       = (null == var.ssh_key) ? tls_private_key.key.private_key_pem : null
  sensitive   = true
}

output "ssh_private_key_openssh" {
  description = "Azure VNET Site generated OpenSSH private key."
  value       = (null == var.ssh_key) ? tls_private_key.key.private_key_openssh : null
  sensitive   = true
}

output "ssh_public_key" {
  description = "Azure VNET Site public key."
  value       = coalesce(var.ssh_key, tls_private_key.key.public_key_openssh)
}

output "apply_tf_output" {
  description = "Azure VNET Site apply terraform output parameter."
  value       = try(resource.volterra_tf_params_action.action_apply.tf_output, null)
}

output "apply_tf_output_map" {
  description = "Azure VNET Site apply terraform output parameter."
  value       = try(local.output_map, null)
}

output "master_nodes_az_names" {
  description = "Azure VNET Site master nodes availability zone names."
  value       = local.master_nodes_az_names
}

output "vnet_resource_group" {
  description = "Azure VNET resource group name."
  value       = local.vnet_resource_group
}

output "vnet_name" {
  description = "Azure VNET name."
  value       = local.vnet_name
}


output "inside_rt_names" {
  description = "Azure VNET inside route table name."
  value       = local.autogenerate_vnet ? local.generated_inside_rt_names : local.existing_inside_rt_names
}

output "location" {
  description = "Azure Resources Location."
  value       = local.location
}

output "site_resource_group" {
  description = "Azure VNET Site resource group name."
  value       = var.azure_rg_name
}

output "sli_nic_ids" {
  description = "Azure VNET Site SLI NIC IDs."
  value       = try(data.azurerm_network_interface.sli[*].id, [])
}

output "sli_nic_names" {
  description = "Azure VNET Site SLI NIC names."
  value       = try(data.azurerm_network_interface.sli[*].name, [])
}

output "sli_nic_private_ips" {
  description = "Azure VNET Site SLI NIC private IPs."
  value       = try(data.azurerm_network_interface.sli[*].private_ip_address, [])
}

output "slo_nic_ids" {
  description = "Azure VNET Site SLO NIC IDs."
  value       = try(data.azurerm_network_interface.slo[*].id, [])
}

output "slo_nic_names" {
  description = "Azure VNET Site SLO NIC names."
  value       = try(data.azurerm_network_interface.slo[*].name, [])
}

output "slo_nic_private_ips" {
  description = "Azure VNET Site SLO NIC private IPs."
  value       = try(data.azurerm_network_interface.slo[*].private_ip_address, [])
}

output "slo_nic_public_ips" {
  description = "Azure VNET Site SLO NIC public IPs."
  value       = try(data.azurerm_network_interface.slo[*].public_ip_address, [])
}