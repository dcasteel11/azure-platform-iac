# -----------------------------------------------------------------------------
# Key Vault with RBAC authorization
#
# A Key Vault stores secrets, keys and certificates so they never live in code,
# pipelines or app settings. This module creates one vault per environment in
# the core resource group, locked down by default:
#
#   - RBAC authorization: who can read or write secrets is decided by Azure
#     role assignments (the same system as the rest of Azure), not by the
#     older vault "access policies". Access is auditable in one place and can
#     be granted per vault, per environment, to groups.
#   - Firewall on by default: the data plane (reading and writing secrets)
#     denies every network except trusted Azure services, the IP ranges in
#     allowed_ip_rules and the subnets in allowed_subnet_ids. The control plane
#     (creating the vault through Azure Resource Manager, which is what
#     Terraform does here) is not affected by this firewall.
#   - Soft delete: a deleted vault or secret can be recovered for
#     soft_delete_retention_days. Purge protection, when on, stops anyone
#     (including an admin) from permanently deleting it before that time.
#   - Audit log: every secret read and write goes to Log Analytics.
#   - Optional private endpoint: the vault gets a private IP in the hub VNet and
#     public network access is turned off entirely.
#
# Cost on a free account:
#   - The vault itself is free. Standard SKU operations cost about $0.03 per
#     10,000, so a lab costs well under a cent a month.
#   - A private endpoint costs about $7.30 a month plus a private DNS zone at
#     about $0.50 a month, so it is off by default (see README).
# -----------------------------------------------------------------------------

resource "azurerm_key_vault" "this" {
  #checkov:skip=CKV2_AZURE_32:A private endpoint costs about $7.30 a month, so it is optional (private_endpoint input) and off by default in this free-tier lab
  #checkov:skip=CKV_AZURE_189:Public network access stays on only when there is no private endpoint; the firewall below still denies every network not explicitly allowed
  #checkov:skip=CKV_AZURE_110:Purge protection is set per environment (on in prod.tfvars); dev leaves it off so the lab can be destroyed and rebuilt
  #checkov:skip=CKV_AZURE_42:Soft delete is always on in Azure; purge protection is set per environment (see CKV_AZURE_110)
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = var.sku_name
  tags                = var.tags

  # Azure RBAC instead of access policies. With this on, access_policy blocks
  # are ignored, so none are defined.
  rbac_authorization_enabled = true

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled

  # With a private endpoint, the public endpoint is switched off completely.
  # Without one, it stays on but the firewall below denies by default.
  public_network_access_enabled = var.private_endpoint == null

  network_acls {
    # "AzureServices" lets trusted Microsoft services (for example Azure
    # Backup or Resource Manager template deployments) through the firewall.
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = var.allowed_ip_rules
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }
}

# --------------------------------------------------------------- Role assignments

# Who may use the vault. Optional, because creating a role assignment needs
# Owner, User Access Administrator or Role Based Access Control Administrator,
# and the pipeline identity only has Contributor (see the README for how to
# grant yourself access with one az command instead).
resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role_definition_name
  principal_id         = each.value.principal_id
  principal_type       = each.value.principal_type
}

# ------------------------------------------------------------------ Diagnostics

# Key Vault audit log -> Log Analytics. "audit" covers AuditEvent: every
# secret, key and certificate operation, who did it and from which IP.
# Very low volume in a lab.
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics_enabled ? 1 : 0

  name                       = "diag-to-log"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
}

# ------------------------------------------------------------- Private endpoint

# Everything below is created only when var.private_endpoint is set.
#
# How it works: the private endpoint puts a network interface with a private
# IP (from the given subnet) in front of the vault. The private DNS zone makes
# <vault>.vault.azure.net resolve to that private IP for any VNet linked to the
# zone, so apps keep using the normal vault URL and their traffic never leaves
# the Microsoft network.
locals {
  private_endpoint_enabled = var.private_endpoint != null
}

resource "azurerm_private_dns_zone" "this" {
  count = local.private_endpoint_enabled ? 1 : 0

  # The zone name is fixed by Azure for Key Vault in the public cloud.
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link the zone to every VNet that needs to resolve the vault privately
# (hub and spokes). Registration stays off: VMs should not add records here.
resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = local.private_endpoint_enabled ? var.private_endpoint.virtual_network_ids : {}

  name                  = "link-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "this" {
  count = local.private_endpoint_enabled ? 1 : 0

  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint.subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  # Creates the A record <vault name> -> private IP in the zone above.
  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.this[0].id]
  }
}
