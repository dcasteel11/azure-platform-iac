# -----------------------------------------------------------------------------
# Unit tests for the key-vault module, run with: terraform test
#
# mock_provider replaces azurerm with a fake, so nothing is created in Azure
# and no account is needed. "command = plan" checks the security defaults, the
# optional private endpoint and role assignments, and every validation rule.
# -----------------------------------------------------------------------------

mock_provider "azurerm" {}

variables {
  name                = "kv-plat-dev-eus1a2b"
  location            = "eastus"
  resource_group_name = "rg-plat-core-dev-eus-001"
  tenant_id           = "00000000-0000-0000-0000-000000000000"
  tags = {
    environment = "dev"
  }
}

run "defaults_are_locked_down" {
  command = plan

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled == true
    error_message = "The vault should use Azure RBAC, not access policies."
  }

  assert {
    condition     = azurerm_key_vault.this.sku_name == "standard"
    error_message = "The default SKU should be standard."
  }

  assert {
    condition     = azurerm_key_vault.this.network_acls[0].default_action == "Deny"
    error_message = "The vault firewall should deny by default."
  }

  assert {
    condition     = azurerm_key_vault.this.network_acls[0].bypass == "AzureServices"
    error_message = "Trusted Azure services should be allowed through the firewall."
  }

  assert {
    condition     = azurerm_key_vault.this.soft_delete_retention_days == 7
    error_message = "Default soft delete retention should be 7 days."
  }

  assert {
    condition     = azurerm_key_vault.this.purge_protection_enabled == false
    error_message = "Purge protection should be off unless asked for (it can never be turned off again)."
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == true
    error_message = "Without a private endpoint the public endpoint stays on (behind the firewall)."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0 && length(azurerm_private_dns_zone.this) == 0
    error_message = "No private endpoint or DNS zone should be created by default."
  }

  assert {
    condition     = length(azurerm_role_assignment.this) == 0
    error_message = "No role assignments should be created by default."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 0
    error_message = "Diagnostics should be off unless diagnostics_enabled is true."
  }
}

run "audit_log_goes_to_the_workspace" {
  command = plan

  variables {
    diagnostics_enabled        = true
    log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.OperationalInsights/workspaces/log"
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this) == 1
    error_message = "diagnostics_enabled should create one diagnostic setting."
  }

  assert {
    condition     = one([for l in azurerm_monitor_diagnostic_setting.this[0].enabled_log : l.category_group]) == "audit"
    error_message = "The diagnostic setting should send the audit category group."
  }
}

run "firewall_allows_listed_networks" {
  command = plan

  variables {
    allowed_ip_rules   = ["203.0.113.10", "198.51.100.0/24"]
    allowed_subnet_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/snet"]
  }

  assert {
    condition     = length(azurerm_key_vault.this.network_acls[0].ip_rules) == 2
    error_message = "Both allowed IP rules should be on the firewall."
  }

  assert {
    condition     = length(azurerm_key_vault.this.network_acls[0].virtual_network_subnet_ids) == 1
    error_message = "The allowed subnet should be on the firewall."
  }
}

run "private_endpoint_turns_off_public_access" {
  command = plan

  variables {
    private_endpoint = {
      subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/hub/subnets/snet-shared"
      virtual_network_ids = {
        hub = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/hub"
        app = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/app"
      }
    }
  }

  assert {
    condition     = azurerm_key_vault.this.public_network_access_enabled == false
    error_message = "With a private endpoint the public endpoint should be off."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1
    error_message = "One private endpoint should be created."
  }

  assert {
    condition     = azurerm_private_endpoint.this[0].private_service_connection[0].subresource_names[0] == "vault"
    error_message = "The private endpoint should connect to the vault subresource."
  }

  assert {
    condition     = azurerm_private_dns_zone.this[0].name == "privatelink.vaultcore.azure.net"
    error_message = "The DNS zone should be the Key Vault private link zone."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.this) == 2
    error_message = "The DNS zone should be linked to the hub and the spoke."
  }
}

run "role_assignments_are_scoped_to_the_vault" {
  command = plan

  variables {
    role_assignments = {
      app = {
        principal_id         = "11111111-1111-1111-1111-111111111111"
        role_definition_name = "Key Vault Secrets User"
        principal_type       = "ServicePrincipal"
      }
    }
  }

  assert {
    condition     = azurerm_role_assignment.this["app"].role_definition_name == "Key Vault Secrets User"
    error_message = "The role assignment should use the requested role."
  }
}

run "rejects_short_retention" {
  command = plan

  variables {
    soft_delete_retention_days = 3
  }

  expect_failures = [var.soft_delete_retention_days]
}

run "rejects_unknown_sku" {
  command = plan

  variables {
    sku_name = "free"
  }

  expect_failures = [var.sku_name]
}

run "rejects_bad_name" {
  command = plan

  variables {
    name = "kv--bad-name-"
  }

  expect_failures = [var.name]
}

run "rejects_broad_role" {
  command = plan

  variables {
    role_assignments = {
      too_much = {
        principal_id         = "11111111-1111-1111-1111-111111111111"
        role_definition_name = "Owner"
      }
    }
  }

  expect_failures = [var.role_assignments]
}

run "rejects_bad_ip" {
  command = plan

  variables {
    allowed_ip_rules = ["not-an-ip"]
  }

  expect_failures = [var.allowed_ip_rules]
}

run "diagnostics_need_a_workspace" {
  command = plan

  variables {
    diagnostics_enabled = true
  }

  expect_failures = [var.log_analytics_workspace_id]
}
