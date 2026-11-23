# Roadmap

The platform is built one step at a time. Each step is a working, validated change.

- [x] **1. Repo scaffold** - README, ROADMAP, docs/ folder, .gitignore, version pins (azurerm ~> 5.0, see ADR 0002), CI (fmt, validate, TFLint, Checkov soft fail), Dependabot, first ADRs
- [x] **2. Naming and tagging module** - locals-based naming convention, required tags, `terraform test` unit tests run in CI (see ADR 0003)
- [x] **3. Bootstrap: OIDC identity and remote state** - one-time Cloud Shell script that creates the GitHub OIDC identity (federated credentials, no secrets) and a versioned state storage account; why remote state and locking matter (see [bootstrap/](bootstrap/) and ADR 0004)
- [x] **4. Deploy pipeline** - plan on pull request, apply a saved plan on main behind a GitHub environment approval; skips cleanly when Azure secrets are not set (see [deploy.yml](.github/workflows/deploy.yml) and ADR 0005)
- [x] **5. Budget and cost alert** - subscription consumption budget with actual and forecast email alerts to Owners, in place before any billable resources; mock-provider unit tests (see [modules/budget](modules/budget/) and ADR 0006)
- [ ] **6. Resource groups per environment** - dev and prod with per-environment tfvars
- [ ] **7. Log Analytics workspace** - free tier limits explained, diagnostic settings
- [ ] **8. Networking** - reuse [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform) as a module source (widen its azurerm constraint to accept 5.x, see ADR 0002)
- [ ] **9. Key Vault** - RBAC authorization, private access notes
- [ ] **10. Azure Policy** - allowed locations, require tags, deny public IPs on NICs
- [ ] **11. Free-tier workload** - Static Web App (Free) or Function App (Consumption)
- [ ] **12. Drift detection** - scheduled `terraform plan -detailed-exitcode`, opens an issue on drift
- [ ] **13. Documentation** - architecture (Mermaid), runbook, ADRs, getting started

## Later

- Private endpoints
- Defender for Cloud (free tier)
- Entra groups and RBAC as code
- Module tests with `terraform test` for the remaining modules (naming and budget already have them)
- Budget action group that runs automation (for example, shut down dev resources) at 100%
