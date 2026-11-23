# -----------------------------------------------------------------------------
# Subscription budget with email alerts
#
# A budget does not stop spending. It watches the cost of the subscription and
# sends email when spend (or Azure's forecast of spend) crosses a percentage of
# the amount. It is the cheapest safety net there is: budgets are free.
#
# It goes in before any billable resource, so the first surprise on the bill is
# an email, not an invoice.
# -----------------------------------------------------------------------------

locals {
  # Azure requires the start date to be the first day of a month. If none is
  # given, use the first day of the month the budget is created.
  start_date = coalesce(var.start_date, formatdate("YYYY-MM-01'T'00:00:00Z", timestamp()))
}

resource "azurerm_consumption_budget_subscription" "this" {
  name            = var.name
  subscription_id = var.subscription_id
  amount          = var.amount
  time_grain      = var.time_grain

  time_period {
    start_date = local.start_date
    # No end_date: the budget runs until it is deleted.
  }

  # One notification block per threshold, for example 50%, 80% and a 100%
  # forecast. Every alert goes to the same people.
  dynamic "notification" {
    for_each = var.notifications

    content {
      enabled        = true
      threshold      = notification.value.threshold
      threshold_type = notification.value.threshold_type
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.contact_emails
      contact_roles  = var.contact_roles
    }
  }

  lifecycle {
    # timestamp() changes on every run. Without this, every plan would try to
    # replace the budget with a new start date. The start date only matters
    # once, at creation.
    ignore_changes = [time_period]

    precondition {
      # nonsensitive: the count of addresses is not secret, only the addresses.
      condition     = nonsensitive(length(var.contact_emails)) + length(var.contact_roles) > 0
      error_message = "Set at least one of contact_emails or contact_roles, or nobody gets the alerts."
    }
  }
}
