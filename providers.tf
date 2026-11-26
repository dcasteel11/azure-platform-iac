# -----------------------------------------------------------------------------
# Provider configuration
#
# No credentials or IDs live in this file. azurerm 5.x needs a subscription ID,
# and it reads it from the environment instead of from code:
#
#   Local:  az login, then export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
#   CI:     OIDC federated credentials set ARM_CLIENT_ID, ARM_TENANT_ID and
#           ARM_SUBSCRIPTION_ID (added in roadmap steps 3 and 4)
#
# Keeping IDs out of the repo means this code is safe to share publicly and the
# same code can target any subscription.
# -----------------------------------------------------------------------------
provider "azurerm" {
  # The features block is required, even when empty.
  features {}

  # Resource providers: every Azure service (Log Analytics, Key Vault,
  # networking...) is a "resource provider" that a subscription must be
  # registered for before it can create that kind of resource. New free
  # subscriptions only have a few registered, and an unregistered one fails at
  # apply time with "MissingSubscriptionRegistration" (the plan still passes).
  #
  # "core" registers a small base set. The list below adds the ones this
  # platform uses, so Terraform registers them on its first run. Registration
  # is free and only needs to happen once per subscription. Add a namespace
  # here in the same pull request as the first resource that needs it.
  resource_provider_registrations = "core"
  resource_providers_to_register = [
    "Microsoft.Consumption",         # budget (step 5)
    "Microsoft.Insights",            # diagnostic settings (step 7)
    "Microsoft.Network",             # VNets, subnets, NSGs, peering (step 8)
    "Microsoft.OperationalInsights", # Log Analytics workspace (step 7)
  ]
}
