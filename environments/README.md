# environments

One `.tfvars` file per environment. The Terraform code in the repo root is the same for every environment; only these values change.

| File | Environment | State key | Deployed by |
|------|-------------|-----------|-------------|
| `dev.tfvars` | dev | `platform.dev.tfstate` | `deploy.yml` (plan on PR, approved apply on main) |
| `prod.tfvars` | prod | `platform.prod.tfstate` | Locally for now; a pipeline stage comes later (see ROADMAP.md) |

## What each environment gets today

| Resource | dev | prod |
|----------|-----|------|
| Resource group `core` (shared platform services) | `rg-plat-core-dev-eus-001` | `rg-plat-core-prod-eus-001` |
| Resource group `app` (the workload) | `rg-plat-app-dev-eus-001` | `rg-plat-app-prod-eus-001` |
| Subscription budget | Yes | No, dev owns it (one subscription) |

Resource groups are free.

## Usage

Each environment needs its own state file, so pass a different `key` at init and use `-reconfigure` when switching:

```bash
# dev
terraform init -reconfigure -backend-config=backend.hcl -backend-config="key=platform.dev.tfstate"
terraform plan -var-file=environments/dev.tfvars

# prod
terraform init -reconfigure -backend-config=backend.hcl -backend-config="key=platform.prod.tfstate"
terraform plan -var-file=environments/prod.tfvars
```

`backend.hcl` is written by [bootstrap/bootstrap.sh](../bootstrap/README.md) and is not in Git. With no backend at all (`terraform init -backend=false`) you can still run `terraform validate`, but not `plan`.

## Inputs set here

| Variable | Purpose |
|----------|---------|
| `environment` | `dev`, `test` or `prod`; goes into every name and the `environment` tag |
| `location` | Azure region |
| `instance` | Three digit instance number |
| `owner`, `cost_center` | Required tags |
| `extra_tags` | Optional extra tags, for example `criticality` in prod |
| `resource_group_purposes` | Resource groups to create, one per purpose |
| `budget_enabled`, `budget_amount` | Subscription budget (only one environment should own it) |

## Design notes

- **Same code, different values.** Separate folders per environment (copying the code) drift apart over time. One root module with a tfvars file per environment keeps dev and prod identical in shape, which is the point of having a dev.
- **Separate state per environment.** A mistake while working on dev cannot touch prod resources, because prod is not in dev's state at all.
- **Why not workspaces?** Terraform CLI workspaces also give separate state, but the active workspace is hidden state on your machine and easy to get wrong. An explicit state key and tfvars file on the command line is visible in every command and every log. See [ADR 0007](../docs/decisions/0007-environments-with-tfvars.md).
- **No secrets here.** These files are public. Anything sensitive (budget email addresses) is passed as a `TF_VAR_` environment variable or a GitHub secret.
