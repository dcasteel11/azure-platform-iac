# -----------------------------------------------------------------------------
# dev environment
#
# Used by the deploy pipeline and locally with:
#   terraform plan -var-file=environments/dev.tfvars
# State key: platform.dev.tfstate
#
# Never put secrets, emails, subscription or tenant IDs in this file. It is
# committed to a public repo.
# -----------------------------------------------------------------------------

environment = "dev"
location    = "eastus"
instance    = "001"
owner       = "platform-team"
cost_center = "lab"

resource_group_purposes = ["core", "app"]

# One subscription hosts both environments in this lab, and a budget covers the
# whole subscription, so only one environment owns it. dev owns it because dev
# is deployed first.
budget_enabled = true
budget_amount  = 10
