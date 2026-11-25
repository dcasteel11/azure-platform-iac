# log-analytics module

Creates a [Log Analytics workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview), the central place where platform logs land and can be searched with KQL, plus diagnostic settings that send logs into it. Sized to stay inside the free allowance.

## Why

- **One place to look.** When something breaks or someone asks "who deleted that?", the answer should be one query away. Later steps (Key Vault, networking, policy, the workload) send their diagnostics to this workspace.
- **Activity log as an audit trail.** The subscription activity log records every create, change and delete, policy decision and service health event. Azure shows it in the portal for 90 days, but only a workspace makes it queryable, joinable and alertable. Activity log ingestion is free.
- **Workspace audit.** The workspace logs who ran which queries against it. Low volume, and it answers "who looked at this data?" in a security review.

## Free tier limits

| Item | Free allowance | What this module does |
|------|----------------|-----------------------|
| SKU | `PerGB2018` is the only SKU for new workspaces. The legacy `Free` SKU is retired | Uses `PerGB2018` |
| Ingestion | First 5 GB per billing account per month | `daily_quota_gb = 0.15` (about 4.5 GB a month) |
| Retention | First 31 days | `retention_in_days = 30` |
| Activity log | Ingestion is free | Sent when `activity_log_enabled = true` |

The daily quota is a hard stop, not an alert: once it is reached, new data is dropped until the next UTC day. For a lab that is the right trade. For production you would raise or remove the cap and alert on volume instead.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `name` | string | required | Workspace name, 4 to 63 characters. Pass `module.naming.names.log_analytics_workspace` |
| `location` | string | required | Azure region |
| `resource_group_name` | string | required | Usually the `core` group: `module.resource_groups.names["core"]` |
| `tags` | map(string) | required | Pass `module.naming.tags` |
| `retention_in_days` | number | `30` | 30 to 730. Free up to 31 |
| `daily_quota_gb` | number | `0.15` | Daily ingestion cap. `-1` for no cap, otherwise at least `0.023` |
| `activity_log_enabled` | bool | `false` | Send the subscription activity log here. Enable in one environment only |
| `subscription_id` | string | `null` | `/subscriptions/<guid>`, required when `activity_log_enabled` is true |
| `activity_log_categories` | list(string) | all eight | Activity log categories to send |
| `workspace_audit_enabled` | bool | `true` | Send the workspace audit log (queries run) to itself |

## Outputs

| Name | Description |
|------|-------------|
| `id` | Resource ID. Pass to `log_analytics_workspace_id` in other diagnostic settings |
| `name` | Workspace name |
| `workspace_id` | Workspace GUID used by agents and some APIs |
| `activity_log_enabled` | True when this workspace receives the subscription activity log |

## Usage

```hcl
data "azurerm_subscription" "current" {}

module "log_analytics" {
  source = "./modules/log-analytics"

  name                = module.naming.names.log_analytics_workspace
  location            = var.location
  resource_group_name = module.resource_groups.names["core"]
  tags                = module.naming.tags

  activity_log_enabled = true
  subscription_id      = data.azurerm_subscription.current.id
}

# A later module sends its own logs to the same workspace:
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  name                       = "diag-to-log"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = module.log_analytics.id

  enabled_log {
    category_group = "audit"
  }
}
```

## Design notes

- **One workspace per environment, one activity log setting per subscription.** dev and prod each get a workspace, so prod data never mixes with dev. The activity log setting is subscription-wide and this lab has one subscription, so only dev creates it (`activity_log_enabled = true` in `environments/dev.tfvars`). With a subscription per environment, both would turn it on. See ADR 0008.
- **Precondition on the workspace.** If `activity_log_enabled` is true but `subscription_id` is missing, the plan stops with a clear message instead of a provider error.
- **No `log_analytics_destination_type`.** The activity log always lands in the `AzureActivity` table, so the setting does not apply at subscription scope.
- **Public query and ingestion are left on.** Private Link for the workspace (Azure Monitor Private Link Scope) is on the "Later" list with private endpoints. Access is still controlled by Entra ID and RBAC.
- **Retention lowered later costs nothing, raised costs money.** Changing `retention_in_days` is an in-place update, not a replacement.

## Tests

```bash
cd modules/log-analytics
terraform init -backend=false
terraform test
```

The tests use `mock_provider "azurerm"`, so they need no Azure account. They check that the defaults stay inside the free tier, that the activity log setting sends all eight categories to the subscription, and that bad input is rejected: retention under 30 days, a daily cap below 0.023 GB, an unknown category, and activity log enabled without a subscription.

## Useful queries

Run these in the portal under the workspace, **Logs**:

```kusto
// Who changed what in the last day
AzureActivity
| where TimeGenerated > ago(1d)
| where ActivityStatusValue == "Success"
| project TimeGenerated, Caller, OperationNameValue, ResourceGroup, _ResourceId
| order by TimeGenerated desc

// How much data each table ingested this month (watch the free 5 GB)
Usage
| where TimeGenerated > startofmonth(now())
| summarize GB = sum(Quantity) / 1024 by DataType
| order by GB desc
```
