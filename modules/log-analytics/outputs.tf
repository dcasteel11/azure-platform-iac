output "id" {
  description = "Resource ID of the workspace. Later modules pass it to their diagnostic settings."
  value       = azurerm_log_analytics_workspace.this.id
}

output "name" {
  description = "Name of the workspace."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_id" {
  description = "Workspace (customer) GUID, used by agents and some APIs. Not a secret, but not the same as the resource ID."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "activity_log_enabled" {
  description = "True when the subscription activity log is sent to this workspace."
  value       = length(azurerm_monitor_diagnostic_setting.activity_log) == 1
}
