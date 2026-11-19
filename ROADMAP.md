# Roadmap

The platform is built one step at a time. Each step is a working, validated change.

- [x] **1. Repo scaffold** - README, ROADMAP, docs/ folder, .gitignore, version pins (azurerm ~> 5.0, see ADR 0002), CI (fmt, validate, TFLint, Checkov soft fail), Dependabot, first ADRs
- [ ] **2. Naming and tagging module** - locals-based naming convention and required tags
- [ ] **3. Bootstrap: OIDC identity and remote state** - one-time Cloud Shell script that creates the GitHub OIDC identity (federated credentials, no secrets) and a versioned state storage account; why remote state and locking matter
- [ ] **4. Deploy pipeline** - plan on pull request, apply on main behind a GitHub environment approval; skips cleanly when Azure secrets are not set
- [ ] **5. Budget and cost alert** - consumption budget with email action, in place before any billable resources
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
- Module tests with `terraform test`
