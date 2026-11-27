# -----------------------------------------------------------------------------
# Inputs for the key-vault module
# -----------------------------------------------------------------------------

variable "name" {
  description = "Key Vault name, 3 to 24 letters, digits and hyphens, unique across all of Azure. Pass module.naming.names.key_vault."
  type        = string

  validation {
    # Azure rules: start with a letter, end with a letter or digit, no "--".
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name)) && !strcontains(var.name, "--")
    error_message = "name must be 3 to 24 characters, start with a letter, end with a letter or digit, and use only letters, digits and single hyphens."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault (and its private endpoint and DNS zone, when enabled). Usually the core group."
  type        = string
}

variable "tenant_id" {
  description = "Entra ID tenant that authenticates requests to the vault. Pass data.azurerm_client_config.current.tenant_id so it never appears in code."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.tenant_id))
    error_message = "tenant_id must be a GUID."
  }
}

variable "tags" {
  description = "Tags for every resource. Pass module.naming.tags."
  type        = map(string)
}

variable "sku_name" {
  description = "standard (software-protected keys) or premium (adds HSM-protected keys, costs more per operation)."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be standard or premium."
  }
}

variable "soft_delete_retention_days" {
  description = "Days a deleted vault or secret can be recovered (7 to 90). Cannot be changed after the vault is created."
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90 && floor(var.soft_delete_retention_days) == var.soft_delete_retention_days
    error_message = "soft_delete_retention_days must be a whole number from 7 to 90."
  }
}

variable "purge_protection_enabled" {
  description = "Block permanent deletion until the soft delete period ends. Once on, it can never be turned off for this vault."
  type        = bool
  default     = false
}

variable "allowed_ip_rules" {
  description = "Public IPs or CIDR ranges allowed through the vault firewall, for example your home IP to manage secrets from a laptop. Pass at run time (TF_VAR_...), not in a committed file."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.allowed_ip_rules : can(cidrhost(strcontains(ip, "/") ? ip : "${ip}/32", 0))])
    error_message = "Every allowed_ip_rules entry must be an IPv4 address or CIDR range."
  }
}

variable "allowed_subnet_ids" {
  description = "Subnet IDs allowed through the vault firewall. Each subnet needs the Microsoft.KeyVault service endpoint."
  type        = list(string)
  default     = []
}

variable "private_endpoint" {
  description = "Optional private endpoint. subnet_id is where the endpoint's private IP comes from; virtual_network_ids (keyed by a short name such as hub or app) are linked to the private DNS zone. null means no private endpoint."
  type = object({
    subnet_id           = string
    virtual_network_ids = map(string)
  })
  default = null
}

variable "role_assignments" {
  description = "Optional Key Vault role assignments on this vault, keyed by a short label. Needs a deploy identity that can assign roles (Contributor cannot)."
  type = map(object({
    principal_id         = string
    role_definition_name = string
    principal_type       = optional(string)
  }))
  default = {}

  validation {
    # Only the data plane roles built for Key Vault, so a typo or an
    # over-broad role (Owner, Contributor) is caught at plan time.
    condition = alltrue([
      for ra in values(var.role_assignments) : contains([
        "Key Vault Administrator",
        "Key Vault Reader",
        "Key Vault Secrets Officer",
        "Key Vault Secrets User",
        "Key Vault Crypto Officer",
        "Key Vault Crypto User",
        "Key Vault Crypto Service Encryption User",
        "Key Vault Certificates Officer",
        "Key Vault Certificate User",
      ], ra.role_definition_name)
    ])
    error_message = "role_definition_name must be one of the built-in Key Vault roles, for example \"Key Vault Secrets User\"."
  }

  validation {
    condition = alltrue([
      for ra in values(var.role_assignments) : contains(["User", "Group", "ServicePrincipal"], coalesce(ra.principal_type, "User"))
    ])
    error_message = "principal_type must be User, Group or ServicePrincipal (or left out)."
  }
}

variable "diagnostics_enabled" {
  description = "Send the vault audit log to log_analytics_workspace_id. A plain bool, because count cannot depend on an ID that is only known after apply."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace for the audit log. Required when diagnostics_enabled is true. Pass module.log_analytics.id."
  type        = string
  default     = null

  validation {
    condition     = !var.diagnostics_enabled || var.log_analytics_workspace_id != null
    error_message = "diagnostics_enabled is true, so log_analytics_workspace_id must be set. Pass module.log_analytics.id."
  }
}
