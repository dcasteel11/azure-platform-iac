# azure-platform-iac

[![ci](https://github.com/dcasteel11/azure-platform-iac/actions/workflows/ci.yml/badge.svg)](https://github.com/dcasteel11/azure-platform-iac/actions/workflows/ci.yml)

A small Azure platform built step by step with Terraform and GitHub Actions: landing zone, networking, security, policy and CI/CD.

It is sized for an **Azure free account**. Every component uses free-tier or very low-cost services, and nothing in the repo holds credentials, subscription IDs or tenant IDs.

## Status

The platform grows one step at a time. See [ROADMAP.md](ROADMAP.md) for what is done and what comes next.

| Area | State |
|------|-------|
| Repo scaffold and CI | Done |
| Naming and tagging | Planned |
| OIDC bootstrap and remote state | Planned |
| Deploy pipeline and budget alert | Planned |
| Environments, logging, networking, Key Vault, policy | Planned |
| Workload and drift detection | Planned |

## Repository layout

```text
.
├── .github/
│   ├── workflows/ci.yml   # fmt, validate, TFLint, Checkov on every push and PR
│   └── dependabot.yml     # weekly updates for Actions and the azurerm provider
├── docs/                  # architecture, runbook, getting started, ADRs
│   └── decisions/         # Architecture Decision Records
├── main.tf                # root module that composes the platform
├── providers.tf           # azurerm provider (no IDs or secrets in code)
├── versions.tf            # Terraform >= 1.6, azurerm ~> 5.0
├── .tflint.hcl            # lint rules (terraform + azurerm rulesets)
└── ROADMAP.md
```

Modules will live under `modules/` and per-environment values under `environments/` as they are added.

## Quick start (no Azure account needed)

```bash
git clone https://github.com/dcasteel11/azure-platform-iac.git
cd azure-platform-iac
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Deploying to Azure is covered in `docs/getting-started.md` (roadmap step 13).

## CI checks

| Check | What it catches | Blocks merge |
|-------|-----------------|--------------|
| `terraform fmt -check` | Unformatted code | Yes |
| `terraform validate` | Syntax, type and reference errors | Yes |
| TFLint | Unused code, deprecated syntax, invalid Azure SKUs | Yes |
| Checkov | Security misconfigurations | No (soft fail while building out) |

## Design principles

- **Everything as code**: infrastructure, policy, pipelines and docs live in this repo.
- **No secrets in Git**: identity comes from environment variables locally and OIDC in CI.
- **Small and cheap**: free-tier services first; cost guardrails are part of the roadmap.
- **Decisions are written down**: see [docs/decisions](docs/decisions/).

## Related repos

- [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform) - hub-and-spoke network module, reused here in the networking step.
- [devsecops-pipeline-templates](https://github.com/dcasteel11/devsecops-pipeline-templates) - reusable security gates for GitHub Actions and Azure DevOps.

## License

[MIT](LICENSE)
