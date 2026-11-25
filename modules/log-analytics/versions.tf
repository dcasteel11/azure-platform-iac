# -----------------------------------------------------------------------------
# Version constraints for the log-analytics module.
#
# The module itself works on Terraform 1.6+. Its tests use mock_provider,
# which needs Terraform 1.7+ (CI uses a newer version).
# -----------------------------------------------------------------------------
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}
