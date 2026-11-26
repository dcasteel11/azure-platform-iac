# -----------------------------------------------------------------------------
# Inputs for the network module
#
# The shape of hub and spokes follows azure-hub-spoke-terraform, so the two
# modules stay easy to compare. The difference is that names and resource
# groups come from outside (the naming and resource-groups modules) instead of
# being built here.
# -----------------------------------------------------------------------------

variable "location" {
  description = "Azure region for every network resource, for example \"eastus\"."
  type        = string
}

variable "tags" {
  description = "Tags for every resource. Pass module.naming.tags."
  type        = map(string)
}

variable "hub" {
  description = "The hub virtual network: shared services such as private endpoints for Key Vault. name is the VNet name, resource_group_name is usually the core group."
  type = object({
    name                = string
    resource_group_name = string
    address_space       = list(string)
    subnets = map(object({
      address_prefixes                  = list(string)
      service_endpoints                 = optional(list(string), [])
      private_endpoint_network_policies = optional(string, "Enabled")
    }))
  })

  validation {
    condition     = alltrue([for cidr in var.hub.address_space : can(cidrhost(cidr, 0))])
    error_message = "hub.address_space must contain valid CIDR ranges, for example \"10.10.0.0/24\"."
  }

  validation {
    condition = alltrue(flatten([
      for s in values(var.hub.subnets) : [for cidr in s.address_prefixes : can(cidrhost(cidr, 0))]
    ]))
    error_message = "Every hub subnet address prefix must be a valid CIDR range."
  }
}

variable "spokes" {
  description = "Spoke virtual networks keyed by role, for example { app = {...} }. Each spoke is peered to the hub."
  type = map(object({
    name                = string
    resource_group_name = string
    address_space       = list(string)
    subnets = map(object({
      address_prefixes                  = list(string)
      service_endpoints                 = optional(list(string), [])
      private_endpoint_network_policies = optional(string, "Enabled")
    }))
  }))
  default = {}

  validation {
    # "hub" is used internally as the key of the hub network.
    condition     = !contains(keys(var.spokes), "hub")
    error_message = "A spoke cannot be called \"hub\"."
  }

  validation {
    condition = alltrue(flatten([
      for spoke in values(var.spokes) : [for cidr in spoke.address_space : can(cidrhost(cidr, 0))]
    ]))
    error_message = "Every spoke address_space entry must be a valid CIDR range."
  }

  validation {
    condition = alltrue(flatten([
      for spoke in values(var.spokes) : [
        for s in values(spoke.subnets) : [for cidr in s.address_prefixes : can(cidrhost(cidr, 0))]
      ]
    ]))
    error_message = "Every spoke subnet address prefix must be a valid CIDR range."
  }
}

variable "diagnostics_enabled" {
  description = "Send NSG event and rule counter logs to log_analytics_workspace_id. A plain bool, because count cannot depend on an ID that is only known after apply."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace for NSG logs. Required when diagnostics_enabled is true. Pass module.log_analytics.id."
  type        = string
  default     = null
}
