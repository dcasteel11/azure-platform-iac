# Roadmap

The platform is built one step at a time. Each step is a working, validated change.

- [x] **1. Repo scaffold** - README, ROADMAP, docs/ folder, .gitignore, version pins (azurerm ~> 4.0), CI (fmt, validate, TFLint, Checkov soft fail), Dependabot, first ADR
- [ ] **2. Naming and tagging module** - locals-based naming convention and required tags
- [ ] **3. Remote state bootstrap** - storage account with versioning; why remote state and locking matter
- [ ] **4. Resource groups per environment** - dev and prod with per-environment tfvars
- [ ] **5. Log Analytics workspace** - free tier limits explained, diagnostic settings
- [ ] **6. Networking** - reuse [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform) as a module source
- [ ] **7. Key Vault** - RBAC authorization, private access notes
- [ ] **8. Azure Policy** - allowed locations, require tags, deny public IPs on NICs
- [ ] **9. Free-tier workload** - Static Web App (Free) or Function App (Consumption)
- [ ] **10. Budget and cost alert** - consumption budget with email action
- [ ] **11. Deploy pipeline with OIDC** - plan on PR, apply on main behind environment approval; skips cleanly when Azure secrets are not set
- [ ] **12. Drift detection** - scheduled `terraform plan -detailed-exitcode`, opens an issue on drift
- [ ] **13. Documentation** - architecture (Mermaid), runbook, ADRs, getting started

## Later

- Private endpoints
- Defender for Cloud (free tier)
- Entra groups and RBAC as code
- Module tests with `terraform test`
