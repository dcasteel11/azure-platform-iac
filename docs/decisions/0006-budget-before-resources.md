# 0006. A subscription budget with Owner alerts before any billable resource

- Status: Accepted
- Date: 2026-11-23

## Context

The platform runs on an Azure free account. Free credit and free-tier limits are easy to pass without noticing: a forgotten resource, a log ingestion spike or a SKU that is not actually free. Azure does not warn by default.

Options: check Cost Management by hand, set a budget in the portal, or manage the budget as code. Alerts also need recipients, and this repo is public, so email addresses cannot be committed.

## Decision

- Manage a subscription-scope consumption budget in Terraform (`modules/budget`), deployed in step 5, before any billable resource exists.
- Default limit $10 a month with three alerts: 50% and 80% of actual spend, and 100% of forecast spend. The forecast alert gives a warning before the money is spent.
- Send alerts to the subscription `Owner` role by default. No email address is needed in code.
- Allow extra recipients through a `sensitive` variable, set from the `BUDGET_ALERT_EMAILS` GitHub secret in CI or `TF_VAR_budget_contact_emails` locally.
- Read the subscription ID from `data.azurerm_subscription.current` at plan time.
- Default the start date to the current month with `timestamp()` and ignore later changes to `time_period`, so plans stay clean.
- A `budget_enabled` flag skips the budget on subscription offers that do not support budgets.

## Consequences

- Cost surprises arrive as email in the same month, not on the invoice.
- A budget only alerts. It never stops spending. A hard stop would need an action group with automation, listed under Later in the roadmap.
- Cost data in Azure lags by up to about a day, so alerts are not instant.
- One budget covers the whole subscription. Per-environment budgets (filtered by resource group or tag) can be added once environments exist in step 6.
