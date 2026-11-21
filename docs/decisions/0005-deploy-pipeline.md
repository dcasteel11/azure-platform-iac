# 0005. Plan on pull request, apply a saved plan on main behind an approval

- Status: Accepted
- Date: 2026-11-21

## Context

With remote state and an OIDC identity in place (ADR 0004), GitHub Actions can run Terraform against Azure. The pipeline has to answer three questions: when does a plan run, who approves an apply, and how do we know the apply does exactly what was reviewed.

The repo is public and may be forked. A fork has no Azure secrets, and a red build on every fork would hide real failures.

## Decision

- A separate `deploy.yml` workflow. `ci.yml` stays credential-free and safe for forks.
- Pull requests run `terraform plan` and write it to the run summary for review. Nothing is applied from a PR.
- A push to `main` runs a plan, saves it as an artifact, and an `apply` job applies that saved file. Applying a saved plan fails if state changed after the plan, so nothing unreviewed is applied.
- The apply job uses the `production` GitHub environment with required reviewers, so it waits for a human approval. The job's OIDC subject (`environment:production`) matches the federated credential created by the bootstrap.
- Apply is skipped when the plan shows no changes.
- A first `check` job tests whether the Azure secrets and state variables are set. If not, plan and apply skip with a notice and the run stays green.
- `concurrency` with `cancel-in-progress: false` stops two deploys from touching state at once without killing an apply mid-run. Terraform's blob lease lock is the second line of defense.

## Consequences

- Every change to Azure is reviewed twice: the code in the PR and the plan before apply.
- Forks and new clones stay green with no setup.
- The plan identity has Contributor, the same as apply. A stricter setup would give plan a read-only identity; this is listed as a later improvement.
- Only one state file (`platform.dev.tfstate`) for now. Per-environment state and tfvars arrive in roadmap step 6.
