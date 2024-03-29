locals {
  master_nodes_in_az_count  = length(var.master_nodes_az_names)
  master_nodes_az_names     = var.master_nodes_az_names
  autogenerate_vnet         = (false == ((length(var.existing_inside_subnets) > 0 && length(var.existing_outside_subnets) > 0) || (length(var.existing_local_subnets) > 0)))
  vnet_resource_group       = coalesce(var.vnet_rg_name, var.azure_rg_name)
  vnet_name                 = coalesce(var.vnet_name, format("%s-vnet", var.site_name))
  default_outside_sg_name   = "security-group"
  location                  = coalesce(var.vnet_rg_location, var.azure_rg_location)

  existing_inside_rt_names  =  var.existing_inside_rt_names
  generated_inside_rt_names = [for i in range(0, length(var.master_nodes_az_names)) : format("rt-%d", i)]
}

#-----------------------------------------------------
# SSH Key
#-----------------------------------------------------

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

#-----------------------------------------------------
# XC Azure VNET Site
#-----------------------------------------------------

resource "volterra_azure_vnet_site" "this" {
  #-----------------------------------------------------
  # General Settings
  #-----------------------------------------------------

  name        = var.site_name
  description = var.site_description
  namespace   = var.site_namespace

  os {
    default_os_version       = (null == var.operating_system_version)
    operating_system_version = (null != var.operating_system_version) ? var.operating_system_version : null
  }

  sw {
    default_sw_version        = (null == var.software_version)
    volterra_software_version = (null != var.software_version) ? var.software_version : null
  }

  offline_survivability_mode {
    enable_offline_survivability_mode = (true == var.offline_survivability_mode)
    no_offline_survivability_mode     = (true != var.offline_survivability_mode)
  }

  #-----------------------------------------------------
  # Azure
  #-----------------------------------------------------

  resource_group = var.azure_rg_name
  azure_region   = var.azure_rg_location
  machine_type   = var.machine_type
  disk_size      = var.nodes_disk_size
  tags           = var.tags

  azure_cred {
    name      = var.az_cloud_credentials_name
    namespace = var.az_cloud_credentials_namespace
    tenant    = var.az_cloud_credentials_tenant
  }

  #-----------------------------------------------------
  # VNET
  #-----------------------------------------------------
  vnet {
    dynamic "existing_vnet" {
      for_each = local.autogenerate_vnet ? [] : [0]
      content {
        resource_group = local.vnet_resource_group
        vnet_name      = local.vnet_name
      }
    }

    dynamic "new_vnet" {
      for_each = local.autogenerate_vnet ? [0] : []
      content {
        primary_ipv4 = var.vnet_cidr
        name         = local.vnet_name
      }
    }
  }

  #-----------------------------------------------------
  # Logs Streaming
  #-----------------------------------------------------

  logs_streaming_disabled = (null == var.log_receiver)

  dynamic log_receiver {
    for_each = null != var.log_receiver ? [0] : []

    content {
      name      = var.log_receiver.name
      namespace = var.log_receiver.namespace
      tenant    = vat.log_receiver.tenant
    }
  }

  #-----------------------------------------------------
  # SSH
  #-----------------------------------------------------

  ssh_key = coalesce(var.ssh_key, tls_private_key.key.public_key_openssh)

  #-----------------------------------------------------
  # Worker Nodes
  #-----------------------------------------------------

  no_worker_nodes = (0 == var.worker_nodes_per_az)
  nodes_per_az    = (0 < var.worker_nodes_per_az) ? var.worker_nodes_per_az : null

  #-----------------------------------------------------
  # Blocked Services
  #-----------------------------------------------------

  default_blocked_services = (true != var.block_all_services && null == var.blocked_service)
  block_all_services       = var.block_all_services

  dynamic blocked_services {
    for_each = (null != var.blocked_service && true != var.block_all_services) ? [0] : []

    content {
      blocked_sevice {
        dns                = var.blocked_service.dns
        ssh                = var.blocked_service.ssh
        web_user_interface = var.blocked_service.web_user_interface
        network_type       = var.blocked_service.network_type
      }
    }
  }

  #-----------------------------------------------------
  # Site type: Ingress Gateway
  #-----------------------------------------------------

  dynamic ingress_gw {
    for_each = var.site_type == "ingress_gw" ? [0] : []

    content {
      azure_certified_hw = "azure-byol-voltmesh"

      dynamic az_nodes {
        for_each = { for idx, value in slice(local.master_nodes_az_names, 0, local.master_nodes_in_az_count) : tostring(idx) => value }

        content {
          azure_az = az_nodes.value

          local_subnet {
            dynamic "subnet" {
              for_each = (false == local.autogenerate_vnet) ? [0] : []
              content {
                subnet_name         = var.existing_local_subnets[tonumber(az_nodes.key)]
                subnet_resource_grp = local.vnet_resource_group
              }
            }

            dynamic "subnet_param" {
              for_each = (true == local.autogenerate_vnet) ? [0] : []
              content {
                ipv4 = var.local_subnets[tonumber(az_nodes.key)]
              }
            }
          }
        }
      }
      performance_enhancement_mode {
        perf_mode_l7_enhanced = (null == var.jumbo)

        dynamic perf_mode_l3_enhanced {
          for_each = (null != var.jumbo) ? [0] : []
          content {
            jumbo    = (true == var.jumbo) ? true : null
            no_jumbo = (false == var.jumbo) ? true : null
          }
        }
      }
    }
  }

  #-----------------------------------------------------
  # Ingress Egress Gateway
  #-----------------------------------------------------
  dynamic ingress_egress_gw  {
    for_each = var.site_type == "ingress_egress_gw" ? [0] : []

    content {
      azure_certified_hw = "azure-byol-multi-nic-voltmesh"

      dynamic az_nodes {
        for_each = { for idx, value in slice(local.master_nodes_az_names, 0, local.master_nodes_in_az_count) : tostring(idx) => value }

        content {
          azure_az = az_nodes.value

          inside_subnet {
            dynamic "subnet" {
              for_each = (false == local.autogenerate_vnet) ? [0] : []
              content {
                subnet_name         = var.existing_inside_subnets[tonumber(az_nodes.key)]
                subnet_resource_grp = local.vnet_resource_group
              }
            }

            dynamic "subnet_param" {
              for_each = (true == local.autogenerate_vnet) ? [0] : []
              content {
                ipv4 = var.inside_subnets[tonumber(az_nodes.key)]
              }
            }
          }

          outside_subnet {
            dynamic "subnet" {
              for_each = (false == local.autogenerate_vnet) ? [0] : []
              content {
                subnet_name         = var.existing_outside_subnets[tonumber(az_nodes.key)]
                subnet_resource_grp = local.vnet_resource_group
              }
            }

            dynamic "subnet_param" {
              for_each = (true == local.autogenerate_vnet) ? [0] : []
              content {
                ipv4 = var.outside_subnets[tonumber(az_nodes.key)]
              }
            }
          }
        }
      }

      #-----------------------------------------------------
      # Manage Firewall Policy
      #-----------------------------------------------------

      no_network_policy = (length(var.enhanced_firewall_policies_list) == 0 && length(var.active_network_policies_list) == 0)

      dynamic "active_enhanced_firewall_policies" {
        for_each = (length(var.enhanced_firewall_policies_list) > 0) ? [0] : []
        content {
          dynamic "enhanced_firewall_policies" {
            for_each = var.enhanced_firewall_policies_list
            content {
              name      = enhanced_firewall_policies.value.name
              namespace = enhanced_firewall_policies.value.namespace
              tenant    = enhanced_firewall_policies.value.tenant
            }
          }

        }
      }

      dynamic "active_network_policies" {
        for_each = (length(var.active_network_policies_list) > 0) ? [0] : []
        content {
          dynamic "network_policies" {
            for_each = var.active_network_policies_list
            content {
              name      = network_policies.value.name
              namespace = network_policies.value.namespace
              tenant    = network_policies.value.tenant
            }
          }

        }
      }

      #-----------------------------------------------------
      # Manage Forward Proxy
      #-----------------------------------------------------

      no_forward_proxy = (length(var.active_forward_proxy_policies_list) == 0)

      forward_proxy_allow_all = (true == var.forward_proxy_allow_all)

      dynamic "active_forward_proxy_policies" {
        for_each = (length(var.active_forward_proxy_policies_list) > 0) ? [0] : []
        content {
          dynamic "forward_proxy_policies" {
            for_each = var.active_forward_proxy_policies_list
            content {
              name      = enhanced_firewall_policies.value.name
              namespace = enhanced_firewall_policies.value.namespace
              tenant    = enhanced_firewall_policies.value.tenant
            }
          }

        }
      }

      #-----------------------------------------------------
      # Select Global Network to Connect
      #-----------------------------------------------------

      no_global_network = (length(var.global_network_connections_list) == 0)

      dynamic global_network_list {
        for_each = (length(var.global_network_connections_list) > 0) ? [0] : []

        content {
          dynamic "global_network_connections" {
            for_each = var.global_network_connections_list
            content {
              dynamic "sli_to_global_dr" {
                for_each = (null != global_network_connections.value.sli_to_global_dr) ? [0] : []

                content {
                  global_vn {
                    name      = global_network_connections.value.sli_to_global_dr.global_vn.name
                    namespace = global_network_connections.value.sli_to_global_dr.global_vn.namespace
                    tenant    = global_network_connections.value.sli_to_global_dr.global_vn.tenant
                  }
                }
              }

              dynamic "slo_to_global_dr" {
                for_each = (null != global_network_connections.value.slo_to_global_dr) ? [0] : []

                content {
                  global_vn {
                    name      = global_network_connections.value.slo_to_global_dr.global_vn.name
                    namespace = global_network_connections.value.slo_to_global_dr.global_vn.namespace
                    tenant    = global_network_connections.value.slo_to_global_dr.global_vn.tenant
                  }
                }
              }
            }
          }
        }
      }

      #-----------------------------------------------------
      # Select DC Cluster Group
      #-----------------------------------------------------

      no_dc_cluster_group = (null == var.dc_cluster_group_inside_vn && null == var.dc_cluster_group_outside_vn)

      dynamic dc_cluster_group_inside_vn {
        for_each = (null != var.dc_cluster_group_inside_vn) ? [0] : []

        content {
          name      = var.dc_cluster_group_inside_vn.name
          namespace = var.dc_cluster_group_inside_vn.namespace
          tenant    = var.dc_cluster_group_inside_vn.tenant
        }
      }

      dynamic dc_cluster_group_outside_vn {
        for_each = (null != var.dc_cluster_group_outside_vn) ? [0] : []

        content {
          name      = var.dc_cluster_group_outside_vn.name
          namespace = var.dc_cluster_group_outside_vn.namespace
          tenant    = var.dc_cluster_group_outside_vn.tenant
        }
      }

      #-----------------------------------------------------
      # Site Mesh Group Connection Type
      #-----------------------------------------------------

      sm_connection_public_ip  = (true == var.sm_connection_public_ip)
      sm_connection_pvt_ip     = (true != var.sm_connection_public_ip)

      #-----------------------------------------------------
      # Manage Static Routes for Inside Network
      #-----------------------------------------------------

      no_inside_static_routes  = (length(var.inside_static_route_list) == 0)

      dynamic "inside_static_routes" {
        for_each = (length(var.inside_static_route_list) > 0) ? [0] : []
        content {
          dynamic "static_route_list" {
            for_each = var.inside_static_route_list
            content {
              simple_static_route = static_route_list.value.simple_static_route
              dynamic "custom_static_route" {
                for_each = (null != static_route_list.value.custom_static_route) ? [0] : []
                content {
                  attrs  = static_route_list.value.custom_static_route.attrs
                  labels = static_route_list.value.custom_static_route.labels

                  dynamic "nexthop" {
                    for_each = (null != static_route_list.value.custom_static_route.nexthop) ? [0] : []
                    content {
                      type = static_route_list.value.custom_static_route.nexthop.type

                      dynamic "interface" {
                        for_each = (null != static_route_list.value.custom_static_route.nexthop.interface) ? [0] : []
                        content {
                          name      = static_route_list.value.custom_static_route.nexthop.interface.name
                          namespace = static_route_list.value.custom_static_route.nexthop.interface.namespace
                          tenant    = static_route_list.value.custom_static_route.nexthop.interface.tenant
                        }
                      }

                      dynamic "nexthop_address" {
                        for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address) ? [0] : []
                        content {
                          dynamic "ipv4" {
                            for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv4) ? [0] : []
                            content {
                              addr = static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv4.addr
                            }
                          }
                          dynamic "ipv6" {
                            for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv6) ? [0] : []
                            content {
                              addr = static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv6.addr
                            }
                          }
                        }
                      }
                    }
                  }

                  dynamic "subnets" {
                    for_each = (null != static_route_list.value.custom_static_route.subnets) ? [0] : []
                    content {
                      dynamic "ipv4" {
                        for_each = (null != static_route_list.value.custom_static_route.subnets.ipv4) ? [0] : []
                        content {
                          plen   = static_route_list.value.custom_static_route.subnets.ipv4.plen
                          prefix = static_route_list.value.custom_static_route.subnets.ipv4.prefix
                        }
                      }
                      dynamic "ipv6" {
                        for_each = (null != static_route_list.value.custom_static_route.subnets.ipv6) ? [0] : []
                        content {
                          plen   = static_route_list.value.custom_static_route.subnets.ipv6.plen
                          prefix = static_route_list.value.custom_static_route.subnets.ipv6.prefix
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      #-----------------------------------------------------
      # Manage Static Routes for Outside Network
      #-----------------------------------------------------

      no_outside_static_routes = (length(var.outside_static_route_list) == 0)

      dynamic "outside_static_routes" {
        for_each = (length(var.outside_static_route_list) > 0) ? [0] : []
        content {
          dynamic "static_route_list" {
            for_each = var.outside_static_route_list
            content {
              simple_static_route = static_route_list.value.simple_static_route
              dynamic "custom_static_route" {
                for_each = (null != static_route_list.value.custom_static_route) ? [0] : []
                content {
                  attrs  = static_route_list.value.custom_static_route.attrs
                  labels = static_route_list.value.custom_static_route.labels

                  dynamic "nexthop" {
                    for_each = (null != static_route_list.value.custom_static_route.nexthop) ? [0] : []
                    content {
                      type = static_route_list.value.custom_static_route.nexthop.type

                      dynamic "interface" {
                        for_each = (null != static_route_list.value.custom_static_route.nexthop.interface) ? [0] : []
                        content {
                          name      = static_route_list.value.custom_static_route.nexthop.interface.name
                          namespace = static_route_list.value.custom_static_route.nexthop.interface.namespace
                          tenant    = static_route_list.value.custom_static_route.nexthop.interface.tenant
                        }
                      }

                      dynamic "nexthop_address" {
                        for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address) ? [0] : []
                        content {
                          dynamic "ipv4" {
                            for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv4) ? [0] : []
                            content {
                              addr = static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv4.addr
                            }
                          }
                          dynamic "ipv6" {
                            for_each = (null != static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv6) ? [0] : []
                            content {
                              addr = static_route_list.value.custom_static_route.nexthop.nexthop_address.ipv6.addr
                            }
                          }
                        }
                      }
                    }
                  }
                  dynamic "subnets" {
                    for_each = (null != static_route_list.value.custom_static_route.subnets) ? [0] : []
                    content {
                      dynamic "ipv4" {
                        for_each = (null != static_route_list.value.custom_static_route.subnets.ipv4) ? [0] : []
                        content {
                          plen  = static_route_list.value.custom_static_route.subnets.ipv4.plen
                          prefix = static_route_list.value.custom_static_route.subnets.ipv4.prefix
                        }
                      }
                      dynamic "ipv6" {
                        for_each = (null != static_route_list.value.custom_static_route.subnets.ipv6) ? [0] : []
                        content {
                          plen   = static_route_list.value.custom_static_route.subnets.ipv6.plen
                          prefix = static_route_list.value.custom_static_route.subnets.ipv6.prefix
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      #-----------------------------------------------------
      # Select VNET type
      #-----------------------------------------------------

      # TODO: add hub support
      not_hub = true

      #-----------------------------------------------------
      # Performance Mode
      #-----------------------------------------------------

      performance_enhancement_mode {
        perf_mode_l7_enhanced = (null == var.jumbo)

        dynamic perf_mode_l3_enhanced {
          for_each = (null != var.jumbo) ? [0] : []
          content {
            jumbo    = (true == var.jumbo) ? true : null
            no_jumbo = (false == var.jumbo) ? true : null
          }
        }
      }
    }
  }

  lifecycle {
    ignore_changes = [labels]
  }
}

resource "volterra_cloud_site_labels" "labels" {
  name             = volterra_azure_vnet_site.this.name
  site_type        = "azure_vnet_site"
  labels           = var.tags
  ignore_on_delete = true

  depends_on = [
    volterra_azure_vnet_site.this,
  ]
}

resource "time_sleep" "wait_30_seconds" {
  # wait for 30 seconds until the site is created and validated
  depends_on = [volterra_azure_vnet_site.this]

  create_duration = "30s"
}

resource "volterra_tf_params_action" "action_apply" {
  site_name       = volterra_azure_vnet_site.this.name
  site_kind       = "azure_vnet_site"
  action          = "apply"
  wait_for_action = true

  depends_on = [
    volterra_azure_vnet_site.this,
    time_sleep.wait_30_seconds
  ]
}

locals {
  tf_output = resource.volterra_tf_params_action.action_apply.tf_output
  lines = split("\n", trimspace(local.tf_output))
  output_map = { 
    for line in local.lines :
      trimspace(element(split("=", line), 0)) => jsondecode(trimspace(element(split("=", line), 1)))
    if can(regex("=", line))
  }
}

data "azurerm_subnet" "existing_outside_subnets" {
  count = length(var.existing_outside_subnets)

  name                 = var.existing_outside_subnets[count.index]
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_resource_group
}

data "azurerm_subnet" "existing_local_subnets" {
  count = length(var.existing_local_subnets)

  name                 = var.existing_local_subnets[count.index]
  virtual_network_name = local.vnet_name
  resource_group_name  = local.vnet_resource_group
}

module "outside_nsg_rules" {
  count = var.apply_outside_sg_rules ? 1 : 0
  source  = "f5devcentral/azure-vnet-site-networking/xc//modules/azure-nsg-rules"
  version = "0.0.1"

  resource_group_name         = var.azure_rg_name
  network_security_group_name = local.default_outside_sg_name
  outside_subnets             = (true == local.autogenerate_vnet) ? tolist(flatten([var.outside_subnets, var.local_subnets])) : tolist(flatten([data.azurerm_subnet.existing_outside_subnets[*].address_prefixes, data.azurerm_subnet.existing_local_subnets[*].address_prefixes]))

  depends_on = [
    volterra_azure_vnet_site.this,
    volterra_tf_params_action.action_apply,
  ]
}

data "azurerm_network_interface" "sli" {
  count = var.site_type == "ingress_egress_gw" ? local.master_nodes_in_az_count : 0

  name                = format("master-%d-sli", count.index)
  resource_group_name = var.azure_rg_name

  depends_on = [
    volterra_azure_vnet_site.this,
    volterra_tf_params_action.action_apply,
  ]
}

data "azurerm_network_interface" "slo" {
  count = local.master_nodes_in_az_count

  name                = format("master-%d-slo", count.index)
  resource_group_name = var.azure_rg_name

  depends_on = [
    volterra_azure_vnet_site.this,
    volterra_tf_params_action.action_apply,
  ]
}

data "azurerm_lb" "this" {
  count = !local.autogenerate_vnet && var.worker_nodes_per_az > 0 ? 1 : 0

  name                = local.output_map.azure_object_name
  resource_group_name = var.azure_rg_name

  depends_on = [
    volterra_azure_vnet_site.this,
    volterra_tf_params_action.action_apply,
  ]
}

resource "azurerm_route" "private_gw" {
  count = (length(var.existing_inside_rt_names) == local.master_nodes_in_az_count) ? local.master_nodes_in_az_count : 0

  name                   = format("xc-master-%d", count.index)
  resource_group_name    = local.vnet_resource_group
  route_table_name       = var.existing_inside_rt_names[count.index]
  address_prefix         = "0.0.0.0/0"
  next_hop_in_ip_address = var.worker_nodes_per_az > 0 ? data.azurerm_lb.this[0].private_ip_address : data.azurerm_network_interface.sli[count.index].private_ip_address
  next_hop_type          = "VirtualAppliance"

  depends_on = [ 
    volterra_azure_vnet_site.this,
    volterra_tf_params_action.action_apply,
  ]
}
