# 0001. Use Terraform with the azurerm 4.x provider and static checks in CI

- Status: Accepted
- Date: 2026-11-19

## Context

The platform needs an infrastructure-as-code tool that is widely used in job postings, works well with GitHub Actions, and can manage Azure resources, Azure Policy and budgets from one codebase. Options considered: Terraform, Bicep, Pulumi.

Bicep is Azure-native and has no state file, but it only targets Azure. Pulumi uses general-purpose languages but has a smaller Azure footprint in industry. Terraform is cloud-agnostic, has the largest module ecosystem, and has mature linting and security scanning (TFLint, Checkov).

## Decision

- Use Terraform `>= 1.6` (needed for the native `terraform test` framework).
- Use the `hashicorp/azurerm` provider pinned to `~> 4.0`.
- Keep subscription and tenant IDs out of code; the provider reads them from environment variables.
- Run `terraform fmt -check`, `terraform validate` and TFLint as blocking CI checks, and Checkov as a non-blocking (soft fail) check until the baseline is clean.

## Consequences

- Terraform state must be stored and protected; remote state with versioning is roadmap step 3.
- azurerm 4.x requires a subscription ID at plan and apply time, so local runs need `ARM_SUBSCRIPTION_ID` and CI needs OIDC (roadmap step 11).
- Dependabot will propose provider updates inside the 4.x range; major upgrades need a new ADR.
- Checkov must be switched to a hard fail once findings are triaged.
