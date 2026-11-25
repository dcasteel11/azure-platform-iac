# azure-platform-iac

[![ci](https://github.com/dcasteel11/azure-platform-iac/actions/workflows/ci.yml/badge.svg)](https://github.com/dcasteel11/azure-platform-iac/actions/workflows/ci.yml)

A small Azure platform built step by step with Terraform and GitHub Actions: landing zone, networking, security, policy and CI/CD.

It is sized for an **Azure free account**. Every component uses free-tier or very low-cost services, and nothing in the repo holds credentials, subscription IDs or tenant IDs.

## Status

The platform grows one step at a time. See [ROADMAP.md](ROADMAP.md) for what is done and what comes next.

| Area | State |
|------|-------|
| Repo scaffold and CI | Done |
| Naming and tagging | Done |
| OIDC bootstrap and remote state | Done |
| Deploy pipeline | Done |
| Budget alert | Done |
| Environments (dev, prod) and resource groups | Done |
| Logging (Log Analytics, activity log) | Done |
| Networking, Key Vault, policy | Planned |
| Workload and drift detection | Planned |

## Repository layout

```text
.
├── .github/
│   ├── workflows/ci.yml   # fmt, validate, test, TFLint, Checkov on every push and PR
│   ├── workflows/deploy.yml # plan on PR, approved apply on main (OIDC, no secrets)
│   └── dependabot.yml     # weekly updates for Actions and the azurerm provider
├── bootstrap/             # one-time script: state storage and GitHub OIDC identity
├── environments/          # dev.tfvars and prod.tfvars, one state key each
├── docs/                  # architecture, runbook, getting started, ADRs
│   └── decisions/         # Architecture Decision Records
├── modules/
│   ├── naming/            # naming convention, required tags, unit tests
│   ├── resource-groups/   # resource groups per purpose, unit tests
│   ├── log-analytics/     # workspace, activity log and audit diagnostics, unit tests
│   └── budget/            # subscription budget with email alerts, unit tests
├── backend.tf             # remote state in Azure Blob Storage (partial config)
├── main.tf                # root module that composes the platform
├── variables.tf           # root inputs (dev defaults)
├── outputs.tf             # generated names and tags
├── providers.tf           # azurerm provider (no IDs or secrets in code)
├── versions.tf            # Terraform >= 1.6, azurerm ~> 5.0
├── .tflint.hcl            # lint rules (terraform + azurerm rulesets)
└── ROADMAP.md
```

Each module under `modules/` has its own README.

## Quick start (no Azure account needed)

```bash
git clone https://github.com/dcasteel11/azure-platform-iac.git
cd azure-platform-iac
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# unit tests for the naming module
terraform -chdir=modules/naming init -backend=false
terraform -chdir=modules/naming test

# unit tests for the budget module (mock provider, no Azure needed)
terraform -chdir=modules/budget init -backend=false
terraform -chdir=modules/budget test

# unit tests for the resource-groups module (mock provider)
terraform -chdir=modules/resource-groups init -backend=false
terraform -chdir=modules/resource-groups test

# unit tests for the log-analytics module (mock provider)
terraform -chdir=modules/log-analytics init -backend=false
terraform -chdir=modules/log-analytics test
```

To deploy to Azure, first run the one-time [bootstrap](bootstrap/README.md) to create remote state storage and the GitHub OIDC identity. A full walkthrough follows in `docs/getting-started.md` (roadmap step 13).

## CI checks

| Check | What it catches | Blocks merge |
|-------|-----------------|--------------|
| `terraform fmt -check` | Unformatted code | Yes |
| `terraform validate` | Syntax, type and reference errors | Yes |
| `terraform test` | Module behaviour (names, tags, budget alerts, validation rules) | Yes |
| TFLint | Unused code, deprecated syntax, invalid Azure SKUs | Yes |
| Checkov | Security misconfigurations | No (soft fail while building out) |

## Deploy pipeline

`deploy.yml` runs `terraform plan` on every pull request and shows it on the run page. On `main` it plans again, saves the plan, and waits for approval in the `production` environment before applying that exact plan. Login uses OIDC, so no client secret exists. Until the bootstrap values are added as secrets and variables, plan and apply skip with a notice. See [ADR 0005](docs/decisions/0005-deploy-pipeline.md).

## Cost guardrail

Before anything billable is deployed, [modules/budget](modules/budget/) puts a monthly budget on the subscription (default $10) that emails subscription Owners at 50% and 80% of actual spend and when Azure forecasts 100%. Budgets are free. Add extra recipients with the optional `BUDGET_ALERT_EMAILS` secret. See [ADR 0006](docs/decisions/0006-budget-before-resources.md).

## Environments

Dev and prod run the same Terraform code. Only the values in [environments/](environments/) and the state key differ, so a dev change can never touch prod state. Each environment gets a `core` resource group for shared platform services and an `app` resource group for the workload, for example `rg-plat-core-dev-eus-001`. The pipeline deploys dev; prod is planned locally for now. See [ADR 0007](docs/decisions/0007-environments-with-tfvars.md).

## Logging

Each environment has a Log Analytics workspace in its `core` resource group, for example `log-plat-dev-eus-001`, built by [modules/log-analytics](modules/log-analytics/). It keeps 30 days of data and has a 0.15 GB daily ingestion cap, which keeps a month inside the free 5 GB. The subscription activity log (every create, change and delete) is sent to the dev workspace, and the workspace logs who queried it. Later steps send their diagnostics to the same place. See [ADR 0008](docs/decisions/0008-log-analytics-free-tier.md).

## Naming and tags

Every resource gets its name and tags from [modules/naming](modules/naming/), for example `rg-plat-dev-eus-001`, and carries the tags `environment`, `workload`, `owner`, `cost-center` and `managed-by`. See [ADR 0003](docs/decisions/0003-naming-and-tagging.md).

## Design principles

- **Everything as code**: infrastructure, policy, pipelines and docs live in this repo.
- **No secrets in Git**: identity comes from environment variables locally and OIDC in CI; state storage uses Entra ID auth with shared keys turned off.
- **Small and cheap**: free-tier services first; cost guardrails are part of the roadmap.
- **Decisions are written down**: see [docs/decisions](docs/decisions/).

## Related repos

- [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform) - hub-and-spoke network module, reused here in the networking step.
- [devsecops-pipeline-templates](https://github.com/dcasteel11/devsecops-pipeline-templates) - reusable security gates for GitHub Actions and Azure DevOps.

## License

[MIT](LICENSE)
