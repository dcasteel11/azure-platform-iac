# -----------------------------------------------------------------------------
# Outputs for the network module
# -----------------------------------------------------------------------------

output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub virtual network."
  value       = azurerm_virtual_network.hub.name
}

output "spoke_vnet_ids" {
  description = "Spoke virtual network IDs keyed by role, for example spoke_vnet_ids.app."
  value       = { for role, v in azurerm_virtual_network.spoke : role => v.id }
}

output "subnet_ids" {
  description = "Subnet IDs keyed by \"role/subnet\", for example subnet_ids[\"hub/shared\"]."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "nsg_ids" {
  description = "NSG IDs keyed by \"role/subnet\", for adding rules outside the module."
  value       = { for k, n in azurerm_network_security_group.this : k => n.id }
}
