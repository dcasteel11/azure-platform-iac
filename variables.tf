# -----------------------------------------------------------------------------
# Root inputs
#
# Defaults describe a dev lab so "terraform plan" works with no tfvars file.
# Per-environment values live in environments/dev.tfvars and
# environments/prod.tfvars and are passed with -var-file. Detailed validation
# lives in modules/naming/variables.tf.
# -----------------------------------------------------------------------------

variable "workload" {
  description = "Short platform name used in every resource name (2 to 6 lowercase letters or digits)."
  type        = string
  default     = "plat"
}

variable "environment" {
  description = "Deployment environment: dev, test or prod."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for platform resources."
  type        = string
  default     = "eastus"
}

variable "instance" {
  description = "Three digit instance number."
  type        = string
  default     = "001"
}

variable "unique_suffix" {
  description = "Optional 0 to 4 characters added to globally unique names if a name is already taken."
  type        = string
  default     = ""
}

variable "owner" {
  description = "Owning team, written to the owner tag. Use a team name, not personal data."
  type        = string
  default     = "platform-team"
}

variable "cost_center" {
  description = "Cost center or budget code, written to the cost-center tag."
  type        = string
  default     = "lab"
}

variable "extra_tags" {
  description = "Optional extra tags added to every resource."
  type        = map(string)
  default     = {}
}

variable "resource_group_purposes" {
  description = "Resource groups to create in this environment, one per purpose, for example [\"core\", \"app\"]."
  type        = list(string)
  default     = ["core", "app"]
}

variable "budget_enabled" {
  description = "Create the subscription budget. Set to false if your subscription offer does not support budgets."
  type        = bool
  default     = true
}

variable "budget_amount" {
  description = "Monthly spend limit for the subscription, in the billing currency. Alerts fire at 50% and 80% actual spend and at 100% forecast."
  type        = number
  default     = 10
}

variable "budget_contact_emails" {
  description = "Optional extra emails for budget alerts. Subscription Owners are always emailed. Set via TF_VAR_budget_contact_emails or the BUDGET_ALERT_EMAILS GitHub secret, never in a committed file."
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "log_analytics_retention_days" {
  description = "Days the Log Analytics workspace keeps data. Up to 31 days is free."
  type        = number
  default     = 30
}

variable "log_analytics_daily_quota_gb" {
  description = "Daily ingestion cap for the workspace, in GB. 0.15 keeps a month inside the free 5 GB. -1 removes the cap."
  type        = number
  default     = 0.15
}

variable "activity_log_enabled" {
  description = "Send the subscription activity log to this environment's workspace. Subscription-wide, so enable it in one environment only."
  type        = bool
  default     = false
}
