# 0004. Bootstrap OIDC and remote state with a one-time CLI script

- Status: Accepted
- Date: 2026-11-21

## Context

Before the deploy pipeline (step 4) can run, two things must exist:

- A place for Terraform state that is shared, versioned and locked, so CI and people never overwrite each other and a bad apply can be rolled back.
- An Azure identity that GitHub Actions can use to log in.

Terraform cannot create the storage account that holds its own state, and CI cannot create its own login. The usual answers are a separate Terraform config with local state, ClickOps in the portal, or a script.

For the CI login, the options are a service principal with a client secret stored in GitHub, or workload identity federation (OIDC), where GitHub's short-lived token is exchanged for an Azure token.

## Decision

- Use one idempotent Azure CLI script, `bootstrap/bootstrap.sh`, run once from Cloud Shell. It is short, readable, safe to re-run, and needs nothing installed.
- Store state in a dedicated storage account in its own resource group, with blob versioning, 30 day soft delete, TLS 1.2 and no public access.
- Turn off shared key access on the state account and use Entra ID auth (`use_azuread_auth = true` in `backend.tf`). No storage keys exist to leak.
- Use OIDC federated credentials for GitHub Actions, scoped to this repo's `main` branch, pull requests and the `production` environment. No client secret is created.
- Give the CI identity Contributor on the subscription and Storage Blob Data Contributor on the state account. Extra roles (for example to assign Azure Policy in step 10) are added in the step that needs them.
- Keep `backend.tf` a partial configuration. Account names come from `backend.hcl` (local, ignored by Git) or `-backend-config` flags in CI.

## Consequences

- No long-lived credentials in GitHub or in the repo. Nothing to rotate.
- State is protected against loss (versioning, soft delete) and concurrent writes (blob lease locking).
- The bootstrap resources are not managed by Terraform. They are few, rarely change, and are documented in `bootstrap/README.md`, including how to remove them.
- Contributor at subscription scope is broad for a lab. In a real organization the identity would be scoped to specific resource groups or management groups, and plan and apply would use separate identities (read-only for plan).
- Running the script needs Owner on the subscription, because it creates role assignments.
