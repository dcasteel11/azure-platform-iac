# naming module

Builds consistent resource names and the required tag set for the platform. It contains only `locals`, `variables` and `outputs`: no providers and no resources, so it costs nothing and can be tested without an Azure account.

## Why

- **Consistency**: every resource follows one pattern, so you can tell what something is, which environment it belongs to and where it lives from its name alone.
- **Azure rules in one place**: storage accounts allow no hyphens, Key Vault names max out at 24 characters, and both must be globally unique. The module handles those rules once instead of in every module.
- **Tags for cost and policy**: required tags drive cost reporting and are enforced later by Azure Policy (roadmap step 10).

## Naming pattern

Based on the [Cloud Adoption Framework](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming) naming guidance.

| Kind | Pattern | Example (`plat`, `dev`, `eastus`) |
|------|---------|-----------------------------------|
| Standard | `<abbr>-<workload>-<env>-<region>-<instance>` | `rg-plat-dev-eus-001` |
| Storage account | `st<workload><env><region><instance><suffix>` | `stplatdeveus001` |
| Key Vault | `kv-<workload>-<env>-<region><suffix>` | `kv-plat-dev-eus` |

Resource groups split by purpose add the purpose after the workload: `rg-plat-core-dev-eus-001`. Pass the purposes in `resource_group_purposes` and read the names from `resource_group_names`.

Standard abbreviations: `rg`, `log`, `vnet`, `snet`, `nsg`, `id`, `stapp`, `func`, `asp`, `ag`, `budget`.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `workload` | string | required | 2 to 6 lowercase letters or digits, starting with a letter |
| `environment` | string | required | `dev`, `test` or `prod` |
| `location` | string | required | Azure region, for example `eastus` (see `location_short` in `main.tf` for the supported list) |
| `instance` | string | `"001"` | Three digit instance number |
| `unique_suffix` | string | `""` | 0 to 4 characters added to globally unique names if one is taken |
| `owner` | string | required | Owning team for the `owner` tag (a team name, not personal data) |
| `cost_center` | string | required | Value for the `cost-center` tag |
| `extra_tags` | map(string) | `{}` | Extra tags; required tags win on a key clash |
| `resource_group_purposes` | list(string) | `[]` | Optional purposes, each 2 to 10 lowercase letters or digits, for example `["core", "app"]` |

## Outputs

| Name | Description |
|------|-------------|
| `names` | Map of resource type to name, for example `names.resource_group` |
| `resource_group_names` | Map of purpose to resource group name, for example `resource_group_names.core = "rg-plat-core-dev-eus-001"` |
| `tags` | Required tags merged with `extra_tags` |
| `required_tag_keys` | Sorted list of required tag keys, for Azure Policy later |
| `location_short` | Short region code, for example `eus` |

## Usage

```hcl
module "naming" {
  source = "./modules/naming"

  workload    = "plat"
  environment = "dev"
  location    = "eastus"
  owner       = "platform-team"
  cost_center = "lab"
}

resource "azurerm_resource_group" "platform" {
  name     = module.naming.names.resource_group
  location = "eastus"
  tags     = module.naming.tags
}
```

## Tests

```bash
cd modules/naming
terraform init -backend=false
terraform test
```

The tests in `tests/naming.tftest.hcl` check the name pattern, prove the longest allowed inputs still fit Azure length limits, check that required tags cannot be overridden, check resource group names per purpose, and check that an invalid environment or purpose is rejected. CI runs them on every push and pull request.

## Design notes

- **Validation instead of truncation.** Input lengths are limited so every name fits by construction. Silently cutting names short (with `substr`) can create two resources with the same name; a clear error at plan time is safer.
- **No random suffix.** A `random_string` would need a provider and state, and names would change if state were lost. `unique_suffix` is set by hand only when Azure reports a name clash.
- **Instance left out of Key Vault names** so the longest case stays at 23 characters.
- **Required tags are merged last**, so `extra_tags` can add tags but never change `environment`, `owner` or the others.
- Add a region by extending both `local.location_short` in `main.tf` and the `location` validation in `variables.tf`.
