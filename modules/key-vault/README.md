# key-vault module

Creates an [Azure Key Vault](https://learn.microsoft.com/azure/key-vault/general/overview) for one environment, locked down by default: Azure RBAC instead of access policies, a firewall that denies every network not listed, soft delete, an audit log in Log Analytics, and an optional private endpoint.

## Why

- **Secrets out of code and pipelines.** Connection strings, API keys and certificates live in the vault. Apps and pipelines read them at run time with their own identity, so nothing secret is ever committed or pasted into a setting.
- **RBAC, not access policies.** `rbac_authorization_enabled = true` means access is an ordinary Azure role assignment, for example `Key Vault Secrets User` on this vault for the app's managed identity. It shows up in the same IAM views and audits as everything else, can be given to groups, and can be scoped to one vault. Access policies are a separate, vault-only permission list that Microsoft now recommends against.
- **Deny by default on the network.** The firewall (`network_acls`) blocks the data plane (reading and writing secrets) from every network except trusted Azure services and the IPs and subnets you list. Creating and configuring the vault goes through Azure Resource Manager, which the firewall does not affect, so the pipeline can still deploy it.
- **Recoverable.** Soft delete is always on: a deleted vault or secret can be restored for `soft_delete_retention_days`. With purge protection on, nobody, not even an Owner, can permanently delete it before then. That is what protects you from ransomware or a bad script.
- **Audited.** Every secret read and write (who, when, from which IP) goes to the environment's Log Analytics workspace.

## What it creates (dev example)

| Resource | Name | Notes |
|----------|------|-------|
| Key Vault | `kv-plat-dev-eus<suffix>` | Standard SKU, RBAC, firewall deny, 7 day soft delete |
| Diagnostic setting | `diag-to-log` | `audit` category group to the workspace |
| Role assignments | none by default | See "Getting access" below |
| Private endpoint, DNS zone, VNet links | only when `private_endpoint` is set | `pe-<vault>`, `privatelink.vaultcore.azure.net`, `link-hub`, `link-app` |

The `<suffix>` is 4 characters from a hash of the subscription ID, because vault names are global across Azure (see the root `main.tf`).

## Cost

| Item | Price | In this lab |
|------|-------|-------------|
| Vault (Standard) | Free to create; about $0.03 per 10,000 secret operations | A fraction of a cent a month |
| Audit log | Counts toward the free 5 GB of Log Analytics | A few KB a day |
| Private endpoint | About $7.30 a month plus about $0.01 per GB | Off by default |
| Private DNS zone | About $0.50 a month | Off by default |
| Premium SKU (HSM keys) | Higher per-operation price | Not used |

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | required | 3 to 24 characters, globally unique. Pass `module.naming.names.key_vault` |
| `location` | string | required | Azure region |
| `resource_group_name` | string | required | Usually the `core` group |
| `tenant_id` | string | required | Pass `data.azurerm_client_config.current.tenant_id` so it never appears in code |
| `tags` | map(string) | required | Pass `module.naming.tags` |
| `sku_name` | string | `"standard"` | `standard` or `premium` |
| `soft_delete_retention_days` | number | `7` | 7 to 90. Fixed after creation |
| `purge_protection_enabled` | bool | `false` | Once on, can never be turned off |
| `allowed_ip_rules` | list(string) | `[]` | IPs or CIDRs allowed through the firewall. Pass at run time, not in Git |
| `allowed_subnet_ids` | list(string) | `[]` | Subnets allowed through the firewall (need the `Microsoft.KeyVault` service endpoint) |
| `private_endpoint` | object | `null` | `{ subnet_id, virtual_network_ids = map(string) }`. Turns public access off |
| `role_assignments` | map(object) | `{}` | `{ principal_id, role_definition_name, principal_type? }`. Only built-in Key Vault roles are accepted |
| `diagnostics_enabled` | bool | `false` | Send the audit log to `log_analytics_workspace_id` |
| `log_analytics_workspace_id` | string | `null` | Required when `diagnostics_enabled` is true |

## Outputs

| Name | Description |
|------|-------------|
| `id` | Vault resource ID, the scope for role assignments |
| `name` | Vault name |
| `vault_uri` | `https://<name>.vault.azure.net/` |
| `public_network_access_enabled` | False when only the private endpoint can reach it |
| `private_endpoint_id` | Private endpoint ID, or null |

## Usage

```hcl
data "azurerm_client_config" "current" {}

module "key_vault" {
  source = "./modules/key-vault"

  name                = module.naming.names.key_vault
  location            = var.location
  resource_group_name = module.resource_groups.names["core"]
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = module.naming.tags

  diagnostics_enabled        = true
  log_analytics_workspace_id = module.log_analytics.id

  # Optional, about $8 a month:
  # private_endpoint = {
  #   subnet_id           = module.network.subnet_ids["hub/shared"]
  #   virtual_network_ids = merge({ hub = module.network.hub_vnet_id }, module.network.spoke_vnet_ids)
  # }
}
```

## Getting access to secrets

The vault starts with **no one** able to read or write secrets, by design. Two things are needed: a role and a network path.

1. **Role.** The pipeline identity only has Contributor, which cannot create role assignments, so `role_assignments` is empty in the pipeline. Grant yourself access once from Cloud Shell (you are Owner):

   ```bash
   KV_ID=$(az keyvault show --name <vault name> --query id -o tsv)
   az role assignment create --role "Key Vault Secrets Officer" \
     --assignee "$(az ad signed-in-user show --query id -o tsv)" --scope "$KV_ID"
   ```

2. **Network.** Add your public IP to the firewall for a session and remove it after:

   ```bash
   az keyvault network-rule add --name <vault name> --ip-address "$(curl -s https://api.ipify.org)"
   az keyvault secret set --vault-name <vault name> --name demo --value hello
   az keyvault network-rule remove --name <vault name> --ip-address "$(curl -s https://api.ipify.org)"
   ```

   A rule added by hand shows up as drift in the next plan, and Terraform removes it on the next apply, which is the point: temporary access does not linger. For permanent access pass `TF_VAR_key_vault_allowed_ip_rules='["x.x.x.x"]'` when you run Terraform locally.

## Private access notes

- **Service endpoint vs private endpoint.** A service endpoint (`allowed_subnet_ids`) lets a subnet reach the vault's public endpoint over the Azure backbone; it is free but the vault keeps a public IP. A private endpoint gives the vault a private IP inside your VNet and lets you turn the public endpoint off; it costs about $8 a month. Production platforms normally use private endpoints.
- **DNS is the part that breaks.** With a private endpoint, `<vault>.vault.azure.net` must resolve to the private IP. The module creates `privatelink.vaultcore.azure.net` and links it to the hub and every spoke. A VNet that is not linked (or an on-premises network without a DNS forwarder) still resolves the public IP and is then blocked.
- **Where the endpoint lives.** It goes in the hub's `snet-shared` subnet, because the vault is a shared service. Spokes reach it over peering.
- **Terraform needs a path too.** Once public access is off, anything that writes secrets (Terraform `azurerm_key_vault_secret`, the Azure CLI) must run from inside the network, for example a self-hosted runner in a spoke. This module does not write secrets, so the GitHub-hosted runners keep working.

## Design notes

- **No secrets in this module.** It builds the vault only. Secrets are created by whoever owns them (an app, a person, a later pipeline step), so their values never land in Terraform state.
- **`purge_soft_delete_on_destroy = false`** in the root provider: `terraform destroy` leaves the vault soft-deleted, so a mistaken destroy can be undone. `recover_soft_deleted_key_vaults = true` brings it back if Terraform recreates a vault with the same name.
- **Role names are validated.** Only the built-in Key Vault roles are accepted, so an over-broad role such as Owner fails at plan time.
- **Diagnostics use a plain bool,** like the network module, because `count` cannot depend on a workspace ID that is only known after apply.

## Tests

```bash
cd modules/key-vault
terraform init -backend=false
terraform test
```

The tests use `mock_provider "azurerm"`, so they need no Azure account. They check the locked-down defaults (RBAC, firewall deny, no public exposure beyond the firewall, no roles), the audit log setting, firewall rules, that a private endpoint creates the DNS zone and links and turns public access off, role assignments, and that bad input is rejected: retention under 7 days, an unknown SKU, a bad name, a non Key Vault role, a bad IP, and diagnostics without a workspace.
