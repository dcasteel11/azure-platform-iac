# -----------------------------------------------------------------------------
# Unit tests for the network module, run with: terraform test
#
# mock_provider replaces azurerm with a fake, so nothing is created in Azure
# and no account is needed. "command = plan" checks names, address ranges,
# NSG coverage, peering and every validation rule.
# -----------------------------------------------------------------------------

mock_provider "azurerm" {}

variables {
  location = "eastus"
  tags = {
    environment = "dev"
  }

  hub = {
    name                = "vnet-plat-hub-dev-eus-001"
    resource_group_name = "rg-plat-core-dev-eus-001"
    address_space       = ["10.10.0.0/24"]
    subnets = {
      shared = { address_prefixes = ["10.10.0.0/26"] }
    }
  }

  spokes = {
    app = {
      name                = "vnet-plat-app-dev-eus-001"
      resource_group_name = "rg-plat-app-dev-eus-001"
      address_space       = ["10.11.0.0/24"]
      subnets = {
        workload          = { address_prefixes = ["10.11.0.0/26"] }
        private-endpoints = { address_prefixes = ["10.11.0.64/26"] }
      }
    }
  }
}

run "hub_and_spoke_are_built_and_peered" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.hub.name == "vnet-plat-hub-dev-eus-001"
    error_message = "The hub VNet should take the name it is given."
  }

  assert {
    condition     = azurerm_virtual_network.spoke["app"].resource_group_name == "rg-plat-app-dev-eus-001"
    error_message = "The app spoke should live in the app resource group."
  }

  assert {
    condition     = length(azurerm_subnet.this) == 3
    error_message = "Expected three subnets: hub/shared, app/workload and app/private-endpoints."
  }

  assert {
    condition     = azurerm_subnet.this["app/workload"].name == "snet-workload"
    error_message = "Subnets should be named snet-<key>."
  }

  assert {
    condition     = length(azurerm_virtual_network_peering.hub_to_spoke) == 1 && length(azurerm_virtual_network_peering.spoke_to_hub) == 1
    error_message = "Each spoke needs a peering in both directions."
  }
}

run "every_subnet_has_an_nsg_and_no_default_outbound" {
  command = plan

  assert {
    condition     = length(azurerm_subnet_network_security_group_association.this) == length(azurerm_subnet.this)
    error_message = "Every non-reserved subnet should have an NSG."
  }

  assert {
    condition     = azurerm_network_security_group.this["app/workload"].name == "nsg-plat-app-dev-eus-001-workload"
    error_message = "NSGs should be named nsg-<vnet suffix>-<subnet>."
  }

  assert {
    condition     = alltrue([for s in azurerm_subnet.this : s.default_outbound_access_enabled == false])
    error_message = "Default outbound internet access should be off on every subnet."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.nsg) == 0
    error_message = "NSG diagnostics should be off unless asked for."
  }
}

run "reserved_subnets_keep_their_name_and_get_no_nsg" {
  command = plan

  variables {
    hub = {
      name                = "vnet-plat-hub-dev-eus-001"
      resource_group_name = "rg-plat-core-dev-eus-001"
      address_space       = ["10.10.0.0/24"]
      subnets = {
        shared        = { address_prefixes = ["10.10.0.0/26"] }
        GatewaySubnet = { address_prefixes = ["10.10.0.192/27"] }
      }
    }
  }

  assert {
    condition     = azurerm_subnet.this["hub/GatewaySubnet"].name == "GatewaySubnet"
    error_message = "Reserved subnet names must not get the snet- prefix."
  }

  assert {
    condition     = !contains(keys(azurerm_network_security_group.this), "hub/GatewaySubnet")
    error_message = "GatewaySubnet cannot take an NSG."
  }
}

run "nsg_logs_go_to_the_workspace" {
  command = plan

  variables {
    diagnostics_enabled        = true
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-plat-core-dev-eus-001/providers/Microsoft.OperationalInsights/workspaces/log-plat-dev-eus-001"
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.nsg) == 3
    error_message = "Each NSG should get a diagnostic setting."
  }
}

run "diagnostics_need_a_workspace" {
  command = plan

  variables {
    diagnostics_enabled = true
  }

  expect_failures = [azurerm_virtual_network.hub]
}

run "bad_cidr_is_rejected" {
  command = plan

  variables {
    hub = {
      name                = "vnet-plat-hub-dev-eus-001"
      resource_group_name = "rg-plat-core-dev-eus-001"
      address_space       = ["10.10.0.0/33"]
      subnets             = {}
    }
  }

  expect_failures = [var.hub]
}

run "spoke_named_hub_is_rejected" {
  command = plan

  variables {
    spokes = {
      hub = {
        name                = "vnet-plat-hub2-dev-eus-001"
        resource_group_name = "rg-plat-app-dev-eus-001"
        address_space       = ["10.11.0.0/24"]
        subnets             = {}
      }
    }
  }

  expect_failures = [var.spokes]
}
