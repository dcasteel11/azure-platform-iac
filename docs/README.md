# Documentation

This folder holds the written side of the platform. Docs are added alongside the code they describe.

| Document | Purpose | Status |
|----------|---------|--------|
| [decisions/](decisions/) | Architecture Decision Records (ADRs): one short file per significant choice | Started |
| [architecture.md](architecture.md) | What is deployed, how the pieces connect, and the development to publish workflow, with Mermaid diagrams | Started |
| runbook.md | How to deploy, roll back and destroy | Planned (step 13) |
| getting-started.md | Azure free account, OIDC setup, GitHub secrets, first deploy | Planned (step 13) |

## Conventions

- Plain Markdown so docs render on GitHub and diff cleanly in pull requests.
- Diagrams use Mermaid, which GitHub renders natively.
- No subscription IDs, tenant IDs, secrets or personal data in any doc.
