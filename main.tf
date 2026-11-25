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

  resource_group_purposes = var.resource_group_purposes
}

# Step 6: resource groups per environment.
# The same code runs for every environment; only the tfvars file changes:
#   terraform plan -var-file=environments/dev.tfvars
# Each environment also has its own state file (see environments/README.md).
module "resource_groups" {
  source = "./modules/resource-groups"

  names    = module.naming.resource_group_names
  location = var.location
  tags     = module.naming.tags
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

# Step 7: Log Analytics workspace and diagnostic settings.
# One workspace per environment, in the core resource group, capped at a daily
# ingestion quota that keeps the month inside the free 5 GB. Later modules send
# their diagnostics to module.log_analytics.id.
module "log_analytics" {
  source = "./modules/log-analytics"

  name                = module.naming.names.log_analytics_workspace
  location            = var.location
  resource_group_name = module.resource_groups.names["core"]
  tags                = module.naming.tags

  retention_in_days = var.log_analytics_retention_days
  daily_quota_gb    = var.log_analytics_daily_quota_gb

  # The activity log setting covers the whole subscription, so only the
  # environment with activity_log_enabled = true creates it (dev, see tfvars).
  activity_log_enabled = var.activity_log_enabled
  subscription_id      = data.azurerm_subscription.current.id
}
