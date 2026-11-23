# -----------------------------------------------------------------------------
# Unit tests for the budget module, run with: terraform test
#
# mock_provider replaces the real azurerm provider with a fake one, so these
# tests need no Azure account and create nothing. "command = plan" checks what
# Terraform would send to Azure, plus every validation and precondition.
# -----------------------------------------------------------------------------

mock_provider "azurerm" {}

variables {
  name            = "budget-plat-dev-eus-001"
  subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  amount          = 10
  start_date      = "2026-12-01T00:00:00Z"
}

run "defaults_create_three_alerts_for_owners" {
  command = plan

  assert {
    condition     = azurerm_consumption_budget_subscription.this.amount == 10
    error_message = "Budget amount should be 10."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.this.time_grain == "Monthly"
    error_message = "Default time grain should be Monthly."
  }

  assert {
    condition     = length(azurerm_consumption_budget_subscription.this.notification) == 3
    error_message = "Default should create 3 notifications (50%, 80%, 100% forecast)."
  }

  assert {
    condition     = alltrue([for n in azurerm_consumption_budget_subscription.this.notification : n.contact_roles == tolist(["Owner"])])
    error_message = "Every alert should go to subscription Owners by default."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.this.time_period[0].start_date == "2026-12-01T00:00:00Z"
    error_message = "An explicit start_date should be used as given."
  }
}

run "zero_amount_is_rejected" {
  command = plan

  variables {
    amount = 0
  }

  expect_failures = [var.amount]
}

run "start_date_must_be_first_of_month" {
  command = plan

  variables {
    start_date = "2026-12-15T00:00:00Z"
  }

  expect_failures = [var.start_date]
}

run "too_many_notifications_are_rejected" {
  command = plan

  variables {
    notifications = [
      { threshold = 10 },
      { threshold = 20 },
      { threshold = 30 },
      { threshold = 40 },
      { threshold = 50 },
      { threshold = 60 },
    ]
  }

  expect_failures = [var.notifications]
}

run "someone_must_receive_alerts" {
  command = plan

  variables {
    contact_roles  = []
    contact_emails = []
  }

  expect_failures = [azurerm_consumption_budget_subscription.this]
}
