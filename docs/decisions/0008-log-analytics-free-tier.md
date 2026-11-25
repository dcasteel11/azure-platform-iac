# 0008. A Log Analytics workspace per environment, capped inside the free tier

- Status: Accepted
- Date: 2026-11-25

## Context

Later steps (Key Vault, networking, policy, the workload) need somewhere to send their logs, and the subscription activity log should be searchable for audits and incident reviews. The lab runs on an Azure free account in a single subscription, so logging must not quietly turn into the biggest line on the bill.

Facts that shaped the decision:

- New workspaces can only use the `PerGB2018` SKU. The first 5 GB of ingestion per billing account per month and the first 31 days of retention are free.
- Azure Activity log data is free to ingest.
- A diagnostic setting on the subscription is subscription-wide. Two of them sending the same categories to two workspaces would duplicate the data.

Options considered:

1. One shared workspace for all environments.
2. One workspace per environment, with the activity log sent to one of them.
3. No workspace until a workload needs it.

## Decision

Option 2. Each environment gets its own workspace in its `core` resource group, named by the naming module. Retention is 30 days and ingestion is capped at 0.15 GB a day (about 4.5 GB a month). The subscription activity log goes to the dev workspace only (`activity_log_enabled = true` in `dev.tfvars`), matching how dev owns the subscription budget (ADR 0006). Each workspace also sends its own audit log (queries run) to itself.

## Consequences

- prod logs never mix with dev logs, and access can be granted per environment.
- Logging is in place before the resources that produce logs, so nothing has to be retrofitted.
- The daily cap is a hard stop: if a noisy resource fills it, logs are dropped until the next UTC day. That is acceptable for a lab. A volume alert before the cap is on the roadmap's "Later" list.
- If the platform moves to a subscription per environment, set `activity_log_enabled = true` in each environment.
- Workspace query and ingestion endpoints stay public for now. Private Link for Azure Monitor is deferred to the private endpoints work.
