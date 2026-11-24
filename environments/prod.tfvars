# -----------------------------------------------------------------------------
# prod environment
#
# Used locally with:
#   terraform plan -var-file=environments/prod.tfvars
# State key: platform.prod.tfstate (a separate state from dev)
#
# Never put secrets, emails, subscription or tenant IDs in this file. It is
# committed to a public repo.
# -----------------------------------------------------------------------------

environment = "prod"
location    = "eastus"
instance    = "001"
owner       = "platform-team"
cost_center = "lab"

resource_group_purposes = ["core", "app"]

extra_tags = {
  criticality = "high"
}

# The subscription budget is owned by dev (see dev.tfvars). Creating it here
# too would add a second budget on the same subscription and double the emails.
budget_enabled = false
