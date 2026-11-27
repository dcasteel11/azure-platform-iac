# 0010. Key Vault per environment with RBAC, a deny-by-default firewall and an optional private endpoint

- Status: Accepted
- Date: 2026-11-27

## Context

The free-tier workload (step 11) and later pipelines need somewhere to keep secrets that is not Git, a pipeline variable or an app setting. The platform must stay inside a free account, and the pipeline identity only has Contributor on the subscription.

Choices to make:

1. **Authorization model.** Vault access policies (a permission list inside each vault) or Azure RBAC (role assignments, like the rest of Azure).
2. **Network exposure.** Public endpoint open, public endpoint behind the vault firewall, or a private endpoint with public access off.
3. **Who grants access.** Terraform role assignments in the pipeline, or a one-time manual grant.
4. **Name uniqueness.** Vault names are global across Azure, so `kv-plat-dev-eus` may already be taken.

## Decision

- **Azure RBAC** (`rbac_authorization_enabled = true`). Access is reviewed and audited with the same tools as every other role, can be granted to groups, and access policies are the model Microsoft recommends moving away from.
- **Firewall deny by default, private endpoint optional.** `network_acls.default_action = "Deny"` with only trusted Azure services allowed. A private endpoint (about $8 a month with its DNS zone) is supported by the module and off in both environments, so the lab stays free. The pipeline only uses the control plane, which the firewall does not block.
- **No role assignments from the pipeline.** Contributor cannot create role assignments, and giving the pipeline a role that can would let it grant itself anything. The module accepts `role_assignments` for a future identity that may assign roles; until then the owner grants access once with the Azure CLI (see the module README).
- **Unique suffix from the subscription ID.** When `unique_suffix` is empty, the root module uses the first 4 characters of a SHA-256 hash of the subscription ID, the same rule the bootstrap script uses for the state account. It is stable for one subscription, different for others, and does not reveal the ID.
- **Soft delete per environment.** dev: 7 days, no purge protection, so it can be destroyed and rebuilt. prod: 30 days and purge protection on. The provider is set to leave vaults soft-deleted on destroy and to recover them on re-create.

## Consequences

- Nobody can read a secret until an owner grants a role and a network path, which is the intended starting point but adds one manual step for the first secret.
- The vault keeps a public endpoint (behind the firewall) until private endpoints are turned on; Checkov flags this and the finding is skipped in code with the reason.
- Once a private endpoint is enabled, anything that writes secrets must run inside the network (for example a self-hosted runner). The module itself writes no secrets, so secret values never enter Terraform state.
- prod purge protection cannot be reversed. A destroyed prod vault keeps its name reserved for 30 days.
- Setting `unique_suffix` later renames, and therefore replaces, the vault.
