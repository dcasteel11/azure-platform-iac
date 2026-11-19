# -----------------------------------------------------------------------------
# Terraform and provider version constraints
#
# Pinning versions keeps every run (your laptop, CI, a teammate) on the same
# behaviour. "~> 5.0" means "any 5.x release, but never 6.0", so we get bug
# fixes and new resources without surprise breaking changes.
# See docs/decisions/0002-upgrade-to-azurerm-5.md for why we use 5.x.
# -----------------------------------------------------------------------------
terraform {
  # 1.6+ is needed for the native "terraform test" framework used later.
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}
