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

# The subscription activity log goes to dev's workspace for the same reason:
# one subscription, one diagnostic setting. See modules/log-analytics.
activity_log_enabled = true

# Hub-and-spoke network (step 8). Ranges must not overlap prod, so dev uses
# 10.10.x.x (hub) and 10.11.x.x (spokes) and prod uses 10.20.x.x and 10.21.x.x.
# Each spoke key must also be in resource_group_purposes.
hub_network = {
  address_space = ["10.10.0.0/24"]
  subnets = {
    shared = { address_prefixes = ["10.10.0.0/26"] } # private endpoints for shared services
  }
}

spoke_networks = {
  app = {
    address_space = ["10.11.0.0/24"]
    subnets = {
      workload          = { address_prefixes = ["10.11.0.0/26"] }
      private-endpoints = { address_prefixes = ["10.11.0.64/26"] }
    }
  }
}
