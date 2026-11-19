# -----------------------------------------------------------------------------
# Terraform and provider version constraints
#
# Pinning versions keeps every run (your laptop, CI, a teammate) on the same
# behaviour. "~> 4.0" means "any 4.x release, but never 5.0", so we get bug
# fixes and new resources without surprise breaking changes.
# -----------------------------------------------------------------------------
terraform {
  # 1.6+ is needed for the native "terraform test" framework used later.
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
