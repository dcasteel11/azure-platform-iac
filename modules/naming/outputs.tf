output "names" {
  description = "Map of resource type to name, for example names.resource_group = \"rg-plat-dev-eus-001\"."
  value       = local.names
}

output "resource_group_names" {
  description = "Map of purpose to resource group name, one entry per resource_group_purposes item, for example resource_group_names.core = \"rg-plat-core-dev-eus-001\"."
  value       = local.resource_group_names
}

output "tags" {
  description = "Tags to apply to every resource: the required tags plus any extra_tags."
  value       = local.tags
}

output "required_tag_keys" {
  description = "Keys of the required tags. Used later by Azure Policy to enforce tagging."
  value       = sort(keys(local.required_tags))
}

output "location_short" {
  description = "Short code for the chosen region, for example \"eus\"."
  value       = local.region
}
