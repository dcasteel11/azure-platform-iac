# -----------------------------------------------------------------------------
# Outputs for the key-vault module
# -----------------------------------------------------------------------------

output "id" {
  description = "Resource ID of the Key Vault. Use it as the scope of role assignments."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "URI apps and the Azure CLI use to reach the vault, for example https://kv-plat-dev-eus1a2b.vault.azure.net/."
  value       = azurerm_key_vault.this.vault_uri
}

output "public_network_access_enabled" {
  description = "False when the vault is reachable only through its private endpoint."
  value       = azurerm_key_vault.this.public_network_access_enabled
}

output "private_endpoint_id" {
  description = "Resource ID of the private endpoint, or null when there is none."
  value       = one(azurerm_private_endpoint.this[*].id)
}
