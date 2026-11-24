output "names" {
  description = "Map of purpose to resource group name."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}

output "ids" {
  description = "Map of purpose to resource group ID. Used later as the scope for role assignments and policy."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.id }
}

output "location" {
  description = "Region the resource groups were created in."
  value       = var.location
}
