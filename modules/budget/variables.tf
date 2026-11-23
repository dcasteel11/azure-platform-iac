# -----------------------------------------------------------------------------
# Inputs for the budget module
# -----------------------------------------------------------------------------

variable "name" {
  description = "Budget name, for example module.naming.names.budget."
  type        = string
}

variable "subscription_id" {
  description = "Full resource ID of the subscription to watch, in the form /subscriptions/<guid>. Pass data.azurerm_subscription.current.id so no ID is written in code."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must look like /subscriptions/<guid>."
  }
}

variable "amount" {
  description = "Spend limit per time grain, in the billing currency of the subscription (USD for most free accounts)."
  type        = number

  validation {
    condition     = var.amount > 0
    error_message = "amount must be greater than 0."
  }
}

variable "time_grain" {
  description = "How often the budget resets: Monthly, Quarterly or Annually."
  type        = string
  default     = "Monthly"

  validation {
    condition     = contains(["Monthly", "Quarterly", "Annually"], var.time_grain)
    error_message = "time_grain must be Monthly, Quarterly or Annually."
  }
}

variable "start_date" {
  description = "First day the budget applies, as YYYY-MM-01T00:00:00Z. Azure requires the first day of a month. Leave null to use the first day of the current month."
  type        = string
  default     = null

  validation {
    condition     = var.start_date == null || can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.start_date))
    error_message = "start_date must be the first day of a month, for example 2026-12-01T00:00:00Z."
  }
}

variable "notifications" {
  description = <<-EOT
    Alerts as a percentage of amount. threshold_type is "Actual" (money already
    spent) or "Forecasted" (Azure predicts you will reach it by the end of the
    period). Azure allows 1 to 5 notifications per budget.
  EOT
  type = list(object({
    threshold      = number
    threshold_type = optional(string, "Actual")
  }))
  default = [
    { threshold = 50 },
    { threshold = 80 },
    { threshold = 100, threshold_type = "Forecasted" },
  ]

  validation {
    condition     = length(var.notifications) >= 1 && length(var.notifications) <= 5
    error_message = "Azure allows between 1 and 5 notifications per budget."
  }

  validation {
    condition     = alltrue([for n in var.notifications : contains(["Actual", "Forecasted"], n.threshold_type)])
    error_message = "threshold_type must be Actual or Forecasted."
  }

  validation {
    condition     = alltrue([for n in var.notifications : n.threshold > 0 && n.threshold <= 1000])
    error_message = "threshold must be a percentage between 1 and 1000."
  }
}

variable "contact_emails" {
  description = "Email addresses that receive the alerts. Marked sensitive so they never show in plan output or CI logs. Pass them in at run time, not in committed files."
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "contact_roles" {
  description = "Azure RBAC roles on the subscription whose members are emailed. The default \"Owner\" reaches the account owner with no email address in code."
  type        = list(string)
  default     = ["Owner"]
}
