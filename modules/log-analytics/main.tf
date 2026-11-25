# -----------------------------------------------------------------------------
# Log Analytics workspace and diagnostic settings
#
# The workspace is the central place where logs land and can be searched with
# KQL (Kusto Query Language). Later steps (Key Vault, networking, policy, the
# workload) send their diagnostics here, so it is created early.
#
# Cost on a free account:
#   - PerGB2018 (pay as you go) is the only SKU new workspaces can use. The
#     old "Free" SKU is retired for new subscriptions.
#   - The first 5 GB of ingestion per billing account per month is free.
#   - Retention up to 31 days is free, so 30 days costs nothing.
#   - Azure Activity log data is free to ingest.
#   - daily_quota_gb is a hard cap: when it is hit, ingestion stops until the
#     next day. 0.15 GB a day is about 4.5 GB a month, inside the free 5 GB.
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags

  lifecycle {
    # Checked here, on a resource that is always planned, so the plan stops
    # with a clear message before the activity log setting is even built.
    precondition {
      condition     = !var.activity_log_enabled || var.subscription_id != null
      error_message = "activity_log_enabled is true, so subscription_id must be set. Pass data.azurerm_subscription.current.id."
    }
  }
}

# Subscription activity log -> workspace.
#
# The activity log records every control plane action in the subscription:
# who created, changed or deleted what, policy decisions, service health
# events. Azure keeps it for 90 days on its own, but only in the portal.
# Sending it to the workspace makes it queryable with KQL, joinable with other
# logs and usable for alerts.
#
# This is a subscription-wide setting, so only one environment should own it
# (see activity_log_enabled in the root variables and environments/*.tfvars).
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  count = var.activity_log_enabled ? 1 : 0

  name                       = "diag-${var.name}"
  target_resource_id         = var.subscription_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = toset(var.activity_log_categories)

    content {
      category = enabled_log.value
    }
  }
}

# Workspace audit log -> the same workspace.
#
# Records who ran which queries against the workspace. Useful evidence for
# security reviews ("who looked at this data?") and very low volume.
resource "azurerm_monitor_diagnostic_setting" "workspace_audit" {
  count = var.workspace_audit_enabled ? 1 : 0

  name                       = "diag-audit"
  target_resource_id         = azurerm_log_analytics_workspace.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log {
    category_group = "audit"
  }
}
