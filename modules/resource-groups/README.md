# resource-groups module

Creates one Azure resource group per purpose in a single environment, all in the same region and with the same tags. Resource groups are free.

## Why

- **Lifecycle and access boundaries.** Everything in a resource group can be granted access, reported on and deleted together. Splitting `core` (shared platform services) from `app` (the workload) means the workload can be torn down or handed to another team without touching logging or secrets.
- **Names and tags come from one place.** The module does not build names itself. It takes them from [modules/naming](../naming/), so every group follows `rg-<workload>-<purpose>-<env>-<region>-<instance>`.
- **Stable keys.** Groups are created with `for_each` over a map keyed by purpose. Adding `data` later does not shift or recreate `core` or `app`, which `count` over a list would do.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `names` | map(string) | required | Purpose to name, for example `{ core = "rg-plat-core-dev-eus-001" }`. Pass `module.naming.resource_group_names` |
| `location` | string | required | Azure region for every group |
| `tags` | map(string) | required | Must include `environment`, `owner` and `cost-center`. Pass `module.naming.tags` |

## Outputs

| Name | Description |
|------|-------------|
| `names` | Purpose to resource group name |
| `ids` | Purpose to resource group ID, for role assignments and policy scopes later |
| `location` | Region of the groups |

## Usage

```hcl
module "naming" {
  source = "./modules/naming"

  workload                = "plat"
  environment             = "dev"
  location                = "eastus"
  owner                   = "platform-team"
  cost_center             = "lab"
  resource_group_purposes = ["core", "app"]
}

module "resource_groups" {
  source = "./modules/resource-groups"

  names    = module.naming.resource_group_names
  location = "eastus"
  tags     = module.naming.tags
}

# Later steps place resources in a group by purpose:
#   resource_group_name = module.resource_groups.names["core"]
```

## Tests

```bash
cd modules/resource-groups
terraform init -backend=false
terraform test
```

`tests/resource_groups.tftest.hcl` uses a mock azurerm provider, so it needs no Azure account. It checks that one group is planned per purpose with the right name, region and tags, and that a missing required tag, a name ending in a period, or an empty map is rejected at plan time.

## Design notes

- **No delete locks yet.** A `CanNotDelete` lock on prod groups is good practice, but creating locks needs `Microsoft.Authorization/locks/write`, which the pipeline's Contributor role does not have. Granting the pipeline more than Contributor is a decision for later, alongside RBAC as code.
- **Tags are checked here too.** Azure Policy will enforce required tags in step 10. Checking in the module gives the same answer earlier, at plan time, with a clearer message.
- **Region is per group, not per resource.** The group's region only stores its metadata. Resources inside can be in other regions, but in this platform they use the same one.
