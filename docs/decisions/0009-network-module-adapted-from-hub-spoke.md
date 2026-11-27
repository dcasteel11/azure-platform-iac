# 0009. A local network module adapted from azure-hub-spoke-terraform

- Status: Accepted
- Date: 2026-11-26

## Context

The roadmap planned to reuse [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform) as a remote module source for the networking step. Reading that module against this platform showed two blockers:

1. **Provider version.** It pins `hashicorp/azurerm ~> 4.0`. This platform uses `~> 5.0` (ADR 0002). Terraform needs one provider version that satisfies every module, and no version satisfies both, so `terraform init` would fail.
2. **It creates its own resource groups and names.** It builds `rg-<prefix>-hub` and `rg-<prefix>-<spoke>` itself. This platform already has `core` and `app` groups per environment (ADR 0007) and one naming module for everything (ADR 0003). Using it as is would add extra, differently named groups.

Options considered:

1. Change azure-hub-spoke-terraform (widen to `>= 4.0, < 6.0`, accept existing resource groups and names), tag a release, and reference it with `?ref=<tag>`.
2. Copy its design into a local module here, adapted to take names and resource groups as inputs.
3. Use the Azure Verified Module for virtual networks.

## Decision

Option 2 for now. `modules/network` keeps the same input shape (`hub`, `spokes`, subnets with `address_prefixes`, `service_endpoints`, `private_endpoint_network_policies`), the same NSG per subnet rule and the same two-way peering, but takes VNet and resource group names from the caller, adds NSG diagnostics to Log Analytics, turns off default outbound access, and leaves out firewall routing until there is a firewall.

Changing the shared repo is a larger change to a separate public project with its own users and example, and it should be reviewed on its own rather than as a side effect of this step.

## Consequences

- The platform works today on azurerm 5.x, with unit tests in CI.
- There are two copies of similar code. To converge later: update azure-hub-spoke-terraform (provider range, optional existing resource groups, name inputs), tag a release, then change `source` in `main.tf` to `git::https://github.com/dcasteel11/azure-hub-spoke-terraform.git?ref=<tag>` and use `moved` blocks so no resource is recreated.
- Pinning a remote module to a tag (not `main`) will matter then: a module change should reach this platform only through a reviewed pull request here.
- The minimum Terraform version rises from 1.6 to 1.9, because the module checks "diagnostics on needs a workspace ID" as an input validation that refers to another variable. A precondition on a resource fired too late (after the provider's own "missing argument" error). CI already uses 1.9.8.
