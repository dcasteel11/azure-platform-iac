output "id" {
  description = "Resource ID of the budget."
  value       = azurerm_consumption_budget_subscription.this.id
}

output "name" {
  description = "Name of the budget."
  value       = azurerm_consumption_budget_subscription.this.name
}

output "amount" {
  description = "Spend limit per time grain, in the billing currency."
  value       = azurerm_consumption_budget_subscription.this.amount
}
