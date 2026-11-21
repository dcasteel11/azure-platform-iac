# Architecture Decision Records

An ADR captures one significant decision: the context, what was decided, and the consequences. They are short, numbered and never rewritten. If a decision changes, a new ADR supersedes the old one.

## Index

| # | Title | Status |
|---|-------|--------|
| [0001](0001-terraform-and-azurerm-4.md) | Use Terraform with the azurerm 4.x provider and static checks in CI | Accepted, amended by 0002 |
| [0002](0002-upgrade-to-azurerm-5.md) | Upgrade to the azurerm 5.x provider before deploying anything | Accepted |
| [0003](0003-naming-and-tagging.md) | One naming and tagging module for every resource | Accepted |
| [0004](0004-bootstrap-oidc-and-remote-state.md) | Bootstrap OIDC and remote state with a one-time CLI script | Accepted |

## Template

```markdown
# NNNN. Title

- Status: Proposed | Accepted | Superseded by NNNN
- Date: YYYY-MM-DD

## Context
What problem or force is driving this decision?

## Decision
What we are going to do.

## Consequences
What becomes easier, what becomes harder, and any follow-up work.
```
