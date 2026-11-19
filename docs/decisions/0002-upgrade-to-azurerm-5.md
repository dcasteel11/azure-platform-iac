# 0002. Upgrade to the azurerm 5.x provider before deploying anything

- Status: Accepted
- Date: 2026-11-19
- Amends: [0001](0001-terraform-and-azurerm-4.md) (provider version only)

## Context

ADR 0001 pinned the azurerm provider to `~> 4.0`. Dependabot then opened PR #1 proposing `~> 5.14`. azurerm 5.0 became generally available in July 2026 and is the current major version.

Major provider versions contain breaking changes. Upgrading an estate that already has resources means reading the upgrade guide, fixing renamed or removed arguments, and checking every plan for unintended replacements. At this point the repo has no resources and nothing is deployed, so the upgrade costs almost nothing now and more with every step that follows.

Notable 5.0 changes that affect later roadmap steps:

- Resource providers are no longer registered automatically. Any provider a resource needs (for example `Microsoft.Consumption` or `Microsoft.Web`) must be registered, in Terraform or once by hand.
- Some arguments were renamed or moved, for example on storage accounts, Log Analytics workspaces and Key Vault. New modules are written against 5.x from the start.
- Legacy App Service resources (`azurerm_app_service`, `azurerm_function_app`) are removed. The workload step uses the current resources.

## Decision

- Pin `hashicorp/azurerm` to `~> 5.0`.
- Close Dependabot PR #1; this change replaces it.
- When the networking step reuses `azure-hub-spoke-terraform`, widen that module's constraint (for example `>= 4.0, < 6.0`) so both repos can share one provider version.

## Consequences

- The platform starts on the current, supported major version.
- Every module is written and reviewed against the 5.x upgrade guide.
- One small change to `azure-hub-spoke-terraform` is needed at the networking step.
- Future major upgrades (6.x) follow the same pattern: an ADR, a branch, and a reviewed plan.
