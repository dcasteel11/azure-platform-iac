# -----------------------------------------------------------------------------
# Root module
#
# This is the entry point that composes the platform. Each roadmap step adds a
# module under modules/ and wires it in here. See ROADMAP.md for the order.
# -----------------------------------------------------------------------------

# Step 2: naming and tagging.
# Every resource added in later steps takes its name from module.naming.names
# and its tags from module.naming.tags, for example:
#
#   resource "azurerm_resource_group" "platform" {
#     name     = module.naming.names.resource_group
#     location = var.location
#     tags     = module.naming.tags
#   }
module "naming" {
  source = "./modules/naming"

  workload      = var.workload
  environment   = var.environment
  location      = var.location
  instance      = var.instance
  unique_suffix = var.unique_suffix
  owner         = var.owner
  cost_center   = var.cost_center
  extra_tags    = var.extra_tags
}

# Step 5: budget and cost alert.
# The subscription ID is read at plan time from the logged-in identity, so it
# never appears in code. Budgets are free; see modules/budget/README.md.
data "azurerm_subscription" "current" {}

module "budget" {
  source = "./modules/budget"
  count  = var.budget_enabled ? 1 : 0

  name            = module.naming.names.budget
  subscription_id = data.azurerm_subscription.current.id
  amount          = var.budget_amount
  contact_emails  = var.budget_contact_emails
}
