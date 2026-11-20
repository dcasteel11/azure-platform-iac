# -----------------------------------------------------------------------------
# Root inputs
#
# Defaults describe a dev lab so "terraform plan" works with no tfvars file.
# Per-environment values (dev, prod) move into environments/*.tfvars in
# roadmap step 6. Detailed validation lives in modules/naming/variables.tf.
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
