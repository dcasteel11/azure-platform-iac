# -----------------------------------------------------------------------------
# Version constraints for the key-vault module.
#
# 1.9+ because some input validations refer to another variable (for example
# log_analytics_workspace_id checks diagnostics_enabled), which older versions
# do not allow. CI uses 1.9.8.
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}
