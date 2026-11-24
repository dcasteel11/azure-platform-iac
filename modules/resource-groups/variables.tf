# -----------------------------------------------------------------------------
# Inputs
# -----------------------------------------------------------------------------

variable "names" {
  description = "Map of purpose to resource group name, for example { core = \"rg-plat-core-dev-eus-001\" }. Pass module.naming.resource_group_names."
  type        = map(string)

  validation {
    condition     = length(var.names) > 0
    error_message = "names must contain at least one resource group."
  }

  validation {
    # Azure rule: 1 to 90 characters; letters, digits, underscores, hyphens,
    # periods and parentheses; must not end with a period.
    condition     = alltrue([for n in values(var.names) : can(regex("^[-\\w.()]{0,89}[-\\w()]$", n))])
    error_message = "Each resource group name must be 1 to 90 characters of letters, digits, _ - . ( ) and must not end with a period."
  }
}

variable "location" {
  description = "Azure region for every resource group, for example \"eastus\". Resources inside a group can still live in other regions."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource group. Pass module.naming.tags."
  type        = map(string)

  validation {
    # Azure Policy (roadmap step 10) will deny resources without these keys,
    # so catch a missing one here, at plan time, instead.
    condition     = alltrue([for k in ["environment", "owner", "cost-center"] : contains(keys(var.tags), k)])
    error_message = "tags must include environment, owner and cost-center. Pass module.naming.tags."
  }
}
