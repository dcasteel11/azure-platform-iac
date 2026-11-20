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
}
