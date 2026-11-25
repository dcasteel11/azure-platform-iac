# -----------------------------------------------------------------------------
# Unit tests for the log-analytics module, run with: terraform test
#
# mock_provider replaces azurerm with a fake, so nothing is created in Azure
# and no account is needed. "command = plan" checks the planned values, every
# validation rule and the precondition.
# -----------------------------------------------------------------------------

mock_provider "azurerm" {}

variables {
  name                = "log-plat-dev-eus-001"
  location            = "eastus"
  resource_group_name = "rg-plat-core-dev-eus-001"
  tags = {
    environment = "dev"
  }
}

run "defaults_stay_inside_the_free_tier" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "The workspace should use the PerGB2018 SKU."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30
    error_message = "Default retention should be 30 days (free up to 31)."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.daily_quota_gb * 31 < 5
    error_message = "The default daily cap should keep a 31 day month under the free 5 GB."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.activity_log) == 0
    error_message = "The activity log setting is subscription-wide and should be off unless asked for."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.workspace_audit) == 1
    error_message = "Workspace audit logging should be on by default."
  }
}

run "activity_log_sends_every_category" {
  command = plan

  variables {
    activity_log_enabled = true
    subscription_id      = "/subscriptions/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.activity_log) == 1
    error_message = "activity_log_enabled should create one diagnostic setting."
  }

  assert {
    condition     = azurerm_monitor_diagnostic_setting.activity_log[0].target_resource_id == "/subscriptions/00000000-0000-0000-0000-000000000000"
    error_message = "The activity log setting should target the subscription."
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.activity_log[0].enabled_log) == 8
    error_message = "All eight activity log categories should be sent by default."
  }
}

run "activity_log_needs_a_subscription" {
  command = plan

  variables {
    activity_log_enabled = true
  }

  expect_failures = [azurerm_log_analytics_workspace.this]
}

run "short_retention_is_rejected" {
  command = plan

  variables {
    retention_in_days = 7
  }

  expect_failures = [var.retention_in_days]
}

run "tiny_daily_cap_is_rejected" {
  command = plan

  variables {
    daily_quota_gb = 0.01
  }

  expect_failures = [var.daily_quota_gb]
}

run "unknown_category_is_rejected" {
  command = plan

  variables {
    activity_log_categories = ["Administrative", "Everything"]
  }

  expect_failures = [var.activity_log_categories]
}
