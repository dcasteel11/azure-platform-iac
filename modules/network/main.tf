# -----------------------------------------------------------------------------
# Hub-and-spoke network for one environment
#
# Adapted from github.com/dcasteel11/azure-hub-spoke-terraform (see ADR 0009
# for why it is not used as a remote module source yet).
#
#   hub   (core resource group)  shared services, for example the Key Vault
#                                private endpoint in step 9
#   spoke (app resource group)   the workload, one spoke per application
#
# Each spoke is peered to the hub in both directions. Spokes are not peered
# to each other, so app A cannot reach app B unless traffic is routed through
# the hub on purpose.
#
# Every subnet gets its own network security group (NSG). Azure's built-in
# NSG rules already allow traffic inside the VNet and from peered VNets and
# deny all other inbound traffic, including from the internet. Specific allow
# rules are added later, next to the resource that needs them.
#
# Cost on a free account:
#   - Virtual networks, subnets and NSGs are free.
#   - VNet peering is billed per GB that crosses the peering (about $0.01 per
#     GB each way in the same region). With no traffic it costs nothing.
#   - No Azure Firewall, VPN gateway or Bastion: each costs from about $100
#     to $900 a month and is out of scope for this lab.
# -----------------------------------------------------------------------------

locals {
  # Subnet names Azure reserves for specific services. They keep their exact
  # name and cannot take an NSG (Bastion can, but needs a special rule set).
  reserved_subnets = ["AzureFirewallSubnet", "AzureFirewallManagementSubnet", "GatewaySubnet", "AzureBastionSubnet", "RouteServerSubnet"]

  # Hub and spokes in one map, keyed by role ("hub", "app"), so subnets and
  # NSGs can be created with a single for_each each.
  networks = merge({ hub = var.hub }, var.spokes)

  # VNet name and resource group per role, used by subnets and NSGs below.
  vnet_names = merge(
    { hub = azurerm_virtual_network.hub.name },
    { for role, v in azurerm_virtual_network.spoke : role => v.name },
  )

  # Flatten networks -> subnets so each subnet has a stable key "role/subnet",
  # for example "app/workload". Adding a subnet never recreates another one.
  #   name:        "workload" becomes "snet-workload"; reserved names stay as is
  #   vnet_suffix: middle part of the VNet name, for example "plat-app-dev-eus-001"
  subnets = merge([
    for role, net in local.networks : {
      for key, subnet in net.subnets :
      "${role}/${key}" => merge(subnet, {
        role                = role
        key                 = key
        resource_group_name = net.resource_group_name
        name                = contains(local.reserved_subnets, key) ? key : "snet-${key}"
        vnet_suffix         = trimprefix(net.name, "vnet-")
      })
    }
  ]...)

  nsg_subnets = {
    for k, s in local.subnets : k => s
    if !contains(local.reserved_subnets, s.key)
  }
}

# ------------------------------------------------------------- Virtual networks

resource "azurerm_virtual_network" "hub" {
  name                = var.hub.name
  location            = var.location
  resource_group_name = var.hub.resource_group_name
  address_space       = var.hub.address_space
  tags                = var.tags

  lifecycle {
    # Checked on a resource that is always planned, so a missing workspace
    # stops the plan with a clear message instead of a provider error.
    precondition {
      condition     = !var.diagnostics_enabled || var.log_analytics_workspace_id != null
      error_message = "diagnostics_enabled is true, so log_analytics_workspace_id must be set. Pass module.log_analytics.id."
    }
  }
}

resource "azurerm_virtual_network" "spoke" {
  for_each = var.spokes

  name                = each.value.name
  location            = var.location
  resource_group_name = each.value.resource_group_name
  address_space       = each.value.address_space
  tags                = var.tags
}

# ---------------------------------------------------------------------- Subnets

resource "azurerm_subnet" "this" {
  #checkov:skip=CKV2_AZURE_31:Reserved subnets (firewall, gateway, Bastion) cannot take an NSG; every other subnet is associated below
  for_each = local.subnets

  name                              = each.value.name
  resource_group_name               = each.value.resource_group_name
  virtual_network_name              = local.vnet_names[each.value.role]
  address_prefixes                  = each.value.address_prefixes
  private_endpoint_network_policies = each.value.private_endpoint_network_policies

  # No implicit outbound internet access. Azure is retiring "default outbound
  # access" for new subnets; anything that needs the internet later gets an
  # explicit path (NAT gateway, firewall), which is easier to audit.
  default_outbound_access_enabled = false

  # azurerm 5.x replaced the service_endpoints list with one service_endpoint
  # block per service. The input stays a simple list, for example
  # ["Microsoft.KeyVault"], and is turned into blocks here.
  dynamic "service_endpoint" {
    for_each = toset(each.value.service_endpoints)

    content {
      service = service_endpoint.value
    }
  }
}

# ---------------------------------------------------- Network security groups

# One NSG per subnet, so rules can be scoped to one tier without affecting
# the others. NSGs are free.
resource "azurerm_network_security_group" "this" {
  for_each = local.nsg_subnets

  name                = "nsg-${each.value.vnet_suffix}-${lower(each.value.key)}"
  location            = var.location
  resource_group_name = each.value.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.nsg_subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# NSG logs -> Log Analytics. "allLogs" covers NetworkSecurityGroupEvent (which
# rule matched) and NetworkSecurityGroupRuleCounter (how often). Low volume.
resource "azurerm_monitor_diagnostic_setting" "nsg" {
  for_each = var.diagnostics_enabled ? local.nsg_subnets : {}

  name                       = "diag-to-log"
  target_resource_id         = azurerm_network_security_group.this[each.key].id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}

# ---------------------------------------------------------------------- Peering

# Peering is not transitive and needs a link in each direction.
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spokes

  name                      = "peer-hub-to-${each.key}"
  resource_group_name       = var.hub.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke[each.key].id
  allow_forwarded_traffic   = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spokes

  name                      = "peer-${each.key}-to-hub"
  resource_group_name       = each.value.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke[each.key].name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true

  # Create the hub side first so the two links come up together cleanly.
  depends_on = [azurerm_virtual_network_peering.hub_to_spoke]
}
