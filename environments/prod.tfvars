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

# The subscription activity log is sent to dev's workspace (see dev.tfvars).
# prod still gets its own workspace for its own resources.
activity_log_enabled = false

# Hub-and-spoke network (step 8). Same shape as dev, different ranges, so the
# two environments could be peered later without overlapping.
hub_network = {
  address_space = ["10.20.0.0/24"]
  subnets = {
    shared = { address_prefixes = ["10.20.0.0/26"] }
  }
}

spoke_networks = {
  app = {
    address_space = ["10.21.0.0/24"]
    subnets = {
      workload          = { address_prefixes = ["10.21.0.0/26"] }
      private-endpoints = { address_prefixes = ["10.21.0.64/26"] }
    }
  }
}
