# -----------------------------------------------------------------------------
# Remote state
#
# State is the file where Terraform records what it has created. Kept on a
# laptop it gets lost, goes stale, and two people (or a person and CI) can
# overwrite each other. Kept in Azure Blob Storage it is shared, versioned and
# locked: Terraform takes a lease on the blob during plan and apply, so only one
# run can change it at a time.
#
# This is a "partial" backend configuration. The storage account details are
# not in Git; they come from backend.hcl, which bootstrap/bootstrap.sh writes:
#
#   terraform init -backend-config=backend.hcl
#
# CI passes the same values with -backend-config flags (roadmap step 4).
# "terraform init -backend=false" (used by CI checks and the quick start)
# skips the backend entirely, so no Azure access is needed for those.
# -----------------------------------------------------------------------------
terraform {
  backend "azurerm" {
    # Log in to the storage account with Entra ID instead of an access key.
    # Shared keys are turned off on the account, so this is required.
    use_azuread_auth = true
  }
}
