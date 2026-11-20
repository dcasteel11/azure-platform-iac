# 0003. One naming and tagging module for every resource

- Status: Accepted
- Date: 2026-11-20

## Context

Every later roadmap step creates Azure resources. Without a shared convention each module would invent its own names and tags, which makes resources hard to find, breaks cost reporting by tag, and makes tag enforcement with Azure Policy (step 10) impossible to roll out cleanly. Azure also has awkward per-type rules: storage accounts allow no hyphens, Key Vault names are limited to 24 characters, and both must be globally unique.

## Decision

- A provider-free module, `modules/naming`, builds all names and tags from a few inputs (workload, environment, region, instance).
- Names follow the Cloud Adoption Framework pattern `<abbr>-<workload>-<env>-<region>-<instance>`, with special patterns for storage accounts and Key Vaults.
- Input validation keeps every name within Azure limits. Names are never truncated.
- Five tags are required on every resource: `environment`, `workload`, `owner`, `cost-center`, `managed-by`. They cannot be overridden by extra tags.
- The module ships with `terraform test` unit tests that run in CI.

## Consequences

- Every new module takes `name` and `tags` as inputs from `module.naming`, so naming changes happen in one place.
- Changing the convention after deployment renames resources, which for most Azure types means destroy and recreate. The convention should be treated as fixed once step 6 deploys the first resources.
- Supporting a new region needs a two-line change in the module.
- Step 10 can read `required_tag_keys` to build the require-tags policy.
