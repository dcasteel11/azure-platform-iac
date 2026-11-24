# 0007. One root module per environment via tfvars files and separate state keys

- Status: Accepted
- Date: 2026-11-24

## Context

The platform needs at least a dev and a prod environment that look the same but never affect each other. Common ways to do this in Terraform:

1. A folder per environment with copied code (or a thin root per environment calling shared modules).
2. Terraform CLI workspaces: one code base, one backend, state picked by the active workspace.
3. One code base with a tfvars file per environment and a separate state key per environment, both given on the command line.

The lab runs in one Azure subscription, and a subscription budget (step 5) covers the whole subscription.

## Decision

- Use option 3. `environments/dev.tfvars` and `environments/prod.tfvars` hold the values; state keys are `platform.dev.tfstate` and `platform.prod.tfstate`.
- Split each environment into resource groups by purpose (`core`, `app`), named by the naming module and created by `modules/resource-groups` with `for_each`.
- The deploy pipeline deploys dev only, passing `-var-file=environments/dev.tfvars`. Prod is planned and applied locally until a prod stage is added to the pipeline.
- Only dev owns the subscription budget (`budget_enabled = false` in prod), because both environments share one subscription.

## Consequences

- Dev and prod cannot drift in shape: they run the same code. Differences are visible in two short files.
- Separate state keys mean a dev plan or apply never touches prod resources.
- Every command must name the tfvars file and state key. Forgetting `-var-file` falls back to the dev defaults in `variables.tf`, which is safe for dev but wrong for prod. The prod stage in the pipeline will remove this risk.
- Option 1 would allow different module versions per environment (promote a module change to dev first). If that becomes necessary, a thin root per environment can be introduced without changing the modules.
- In a real organisation dev and prod would be separate subscriptions; the budget would then move to each environment, or to a subscription-vending layer.
