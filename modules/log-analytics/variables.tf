# -----------------------------------------------------------------------------
# Inputs for the log-analytics module
# -----------------------------------------------------------------------------

variable "name" {
  description = "Workspace name, for example module.naming.names.log_analytics_workspace."
  type        = string

  validation {
    # Azure rule: 4 to 63 characters, letters, digits and hyphens, starting
    # and ending with a letter or digit.
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{2,61}[A-Za-z0-9]$", var.name))
    error_message = "name must be 4 to 63 letters, digits or hyphens, and start and end with a letter or digit."
  }
}

variable "location" {
  description = "Azure region for the workspace, for example \"eastus\"."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the workspace. Use the core group: module.resource_groups.names[\"core\"]."
  type        = string
}

variable "tags" {
  description = "Tags for the workspace. Pass module.naming.tags."
  type        = map(string)
}

variable "retention_in_days" {
  description = "Days to keep data. 30 to 730. Up to 31 days is free; longer retention is billed per GB per month."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Hard cap on ingestion per day, in GB. Ingestion stops for the rest of the day when it is reached. -1 means no cap. The default 0.15 keeps a month under the free 5 GB."
  type        = number
  default     = 0.15

  validation {
    # Azure accepts -1 (no cap) or at least 0.023 GB.
    condition     = var.daily_quota_gb == -1 || var.daily_quota_gb >= 0.023
    error_message = "daily_quota_gb must be -1 (no cap) or at least 0.023."
  }
}

variable "activity_log_enabled" {
  description = "Send the subscription activity log to this workspace. It is a subscription-wide setting, so enable it in one environment only."
  type        = bool
  default     = false
}

variable "subscription_id" {
  description = "Subscription resource ID in the form /subscriptions/<guid>. Required when activity_log_enabled is true. Pass data.azurerm_subscription.current.id so no ID is written in code."
  type        = string
  default     = null

  validation {
    condition     = var.subscription_id == null || can(regex("^/subscriptions/[0-9a-fA-F-]{36}$", var.subscription_id))
    error_message = "subscription_id must look like /subscriptions/<guid>."
  }
}

variable "activity_log_categories" {
  description = "Activity log categories to send. The default is all of them; activity log ingestion is free."
  type        = list(string)
  default = [
    "Administrative",
    "Security",
    "ServiceHealth",
    "Alert",
    "Recommendation",
    "Policy",
    "Autoscale",
    "ResourceHealth",
  ]

  validation {
    condition = alltrue([
      for c in var.activity_log_categories :
      contains(["Administrative", "Security", "ServiceHealth", "Alert", "Recommendation", "Policy", "Autoscale", "ResourceHealth"], c)
    ])
    error_message = "Unknown activity log category. Allowed: Administrative, Security, ServiceHealth, Alert, Recommendation, Policy, Autoscale, ResourceHealth."
  }
}

variable "workspace_audit_enabled" {
  description = "Send the workspace's own audit log (who queried what) to itself."
  type        = bool
  default     = true
}
