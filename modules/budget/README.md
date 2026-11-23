# budget module

Creates a subscription-wide [Azure consumption budget](https://learn.microsoft.com/azure/cost-management-billing/costs/tutorial-acm-create-budgets) that emails people when spend crosses a percentage of a limit. Budgets are free.

## Why

- **First guardrail before any billable resource.** On a free account the $200 credit runs out quietly. A budget turns a surprise invoice into an email.
- **Actual and forecast alerts.** "Actual" fires when money has been spent. "Forecasted" fires when Azure predicts you will hit the limit by the end of the month, which gives time to react.
- **No personal data in code.** Alerts go to everyone with the `Owner` role on the subscription by default. Extra email addresses are optional, marked `sensitive` and passed in at run time.

A budget only alerts. It never stops or deletes resources. To enforce a hard stop you would add an action group that runs automation, which is out of scope for a lab.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | required | Budget name, for example `module.naming.names.budget` |
| `subscription_id` | string | required | `/subscriptions/<guid>`. Pass `data.azurerm_subscription.current.id` |
| `amount` | number | required | Limit per period, in the billing currency |
| `time_grain` | string | `"Monthly"` | `Monthly`, `Quarterly` or `Annually` |
| `start_date` | string | `null` | `YYYY-MM-01T00:00:00Z`. Null means the first day of the current month |
| `notifications` | list(object) | 50% and 80% actual, 100% forecast | 1 to 5 alerts, each `{ threshold, threshold_type }` |
| `contact_emails` | list(string), sensitive | `[]` | Extra recipients |
| `contact_roles` | list(string) | `["Owner"]` | Subscription roles whose members are emailed |

## Outputs

| Name | Description |
|------|-------------|
| `id` | Resource ID of the budget |
| `name` | Budget name |
| `amount` | Limit per period |

## Usage

```hcl
data "azurerm_subscription" "current" {}

module "budget" {
  source = "./modules/budget"

  name            = module.naming.names.budget
  subscription_id = data.azurerm_subscription.current.id
  amount          = 10

  # Optional: someone other than the subscription owner
  # contact_emails = var.budget_contact_emails
}
```

## Design notes

- **Start date.** Azure needs the first day of a month. With no `start_date`, the module uses `timestamp()` to pick the current month and `ignore_changes` on `time_period` so later plans do not try to replace the budget. Changing the start date on purpose therefore needs `terraform apply -replace=module.budget[0].azurerm_consumption_budget_subscription.this`.
- **Same recipients for every alert.** Simpler to read and enough for a lab. Split into per-threshold recipients if, for example, only the 100% alert should page a manager.
- **Precondition.** The plan fails if both `contact_emails` and `contact_roles` are empty, because an alert nobody receives is worse than no alert: it looks like protection but is not.
- **Offer types.** Budgets work on Pay-As-You-Go, the Azure free account after upgrade, and most paid offers. If your subscription offer does not support budgets, apply fails with a clear Azure error. Set `budget_enabled = false` in the root module to skip it.

## Tests

```bash
cd modules/budget
terraform init -backend=false
terraform test
```

The tests use `mock_provider "azurerm"`, so they need no Azure account. They check the defaults (three alerts to Owners) and that bad input is rejected: a zero amount, a start date that is not the first of a month, more than five alerts, and no recipients.
