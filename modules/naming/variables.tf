# -----------------------------------------------------------------------------
# Inputs
#
# Each variable has a validation block so a bad value fails at plan time with a
# clear message, instead of failing later inside Azure with a vague API error.
# -----------------------------------------------------------------------------

variable "workload" {
  description = "Short workload or platform name used in every resource name, for example \"plat\". 2 to 6 lowercase letters or digits, starting with a letter."
  type        = string

  validation {
    # Kept short on purpose: Key Vault names max out at 24 characters.
    condition     = can(regex("^[a-z][a-z0-9]{1,5}$", var.workload))
    error_message = "workload must be 2 to 6 characters: lowercase letters and digits, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment. One of dev, test or prod."
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  description = "Azure region name, for example \"eastus\". Must be one of the regions in local.location_short (add more there as needed)."
  type        = string

  validation {
    # Keep this list in sync with local.location_short in main.tf.
    condition = contains([
      "eastus", "eastus2", "centralus", "westus2", "westus3",
      "northeurope", "westeurope", "uksouth",
    ], var.location)
    error_message = "location must be a supported region: eastus, eastus2, centralus, westus2, westus3, northeurope, westeurope, uksouth."
  }
}

variable "instance" {
  description = "Three digit instance number, so two copies of the same thing can live side by side. Defaults to \"001\"."
  type        = string
  default     = "001"

  validation {
    condition     = can(regex("^[0-9]{3}$", var.instance))
    error_message = "instance must be exactly three digits, for example \"001\"."
  }
}

variable "unique_suffix" {
  description = "Optional 0 to 4 lowercase letters or digits appended to globally unique names (storage accounts, Key Vaults). Use it if a name is already taken in Azure."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,4}$", var.unique_suffix))
    error_message = "unique_suffix must be 0 to 4 lowercase letters or digits."
  }
}

variable "owner" {
  description = "Team or role that owns the resources, written to the owner tag. Use a team name, not a personal email."
  type        = string

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner must not be empty."
  }
}

variable "cost_center" {
  description = "Cost center or budget code, written to the cost-center tag."
  type        = string

  validation {
    condition     = length(trimspace(var.cost_center)) > 0
    error_message = "cost_center must not be empty."
  }
}

variable "extra_tags" {
  description = "Optional extra tags merged onto the required tags. Required tags always win if a key is repeated."
  type        = map(string)
  default     = {}
}

variable "resource_group_purposes" {
  description = "Optional short purposes, one per resource group, for example [\"core\", \"app\"]. Each becomes a name in the resource_group_names output. 2 to 10 lowercase letters or digits, starting with a letter."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for p in var.resource_group_purposes : can(regex("^[a-z][a-z0-9]{1,9}$", p))])
    error_message = "Each resource group purpose must be 2 to 10 lowercase letters or digits, starting with a letter."
  }

  validation {
    condition     = length(distinct(var.resource_group_purposes)) == length(var.resource_group_purposes)
    error_message = "Resource group purposes must not repeat."
  }
}
