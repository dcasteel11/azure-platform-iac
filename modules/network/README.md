# network module

Creates a small hub-and-spoke network for one environment: a hub VNet for shared services, one or more spoke VNets for workloads, a network security group (NSG) on every subnet, and VNet peering between the hub and each spoke. Everything it creates is free until traffic crosses a peering.

Adapted from [azure-hub-spoke-terraform](https://github.com/dcasteel11/azure-hub-spoke-terraform). See [ADR 0009](../../docs/decisions/0009-network-module-adapted-from-hub-spoke.md) for why it is a local module for now.

## Why

- **Hub and spoke.** Shared services (Key Vault private endpoint, later a firewall or DNS) sit in the hub once. Each workload gets its own spoke, so it can be added, changed or deleted without touching the others.
- **Spokes cannot reach each other.** Peering is not transitive. app A and app B only talk if traffic is routed through the hub on purpose.
- **An NSG on every subnet.** Azure's default NSG rules allow traffic inside the VNet and from peered VNets, and deny every other inbound connection, including from the internet. Allow rules are added later, next to the resource that needs them, so each rule has an owner.
- **No default outbound internet.** `default_outbound_access_enabled = false` on every subnet. Azure is retiring implicit outbound access; an explicit path (NAT gateway, firewall) is easier to audit.
- **Names and resource groups come from outside.** The module takes VNet names and resource group names as inputs, so everything follows [modules/naming](../naming/) and lands in the groups from [modules/resource-groups](../resource-groups/).

## What it creates (dev example)

| Resource | Name | Resource group |
|----------|------|----------------|
| Hub VNet `10.10.0.0/24` | `vnet-plat-hub-dev-eus-001` | `rg-plat-core-dev-eus-001` |
| Hub subnet `10.10.0.0/26` | `snet-shared` | core |
| Spoke VNet `10.11.0.0/24` | `vnet-plat-app-dev-eus-001` | `rg-plat-app-dev-eus-001` |
| Spoke subnets | `snet-workload` (`10.11.0.0/26`), `snet-private-endpoints` (`10.11.0.64/26`) | app |
| NSGs | `nsg-plat-hub-dev-eus-001-shared`, `nsg-plat-app-dev-eus-001-workload`, ... | same as the subnet |
| Peering | `peer-hub-to-app`, `peer-app-to-hub` | one in each VNet |
| NSG diagnostic settings | `diag-to-log` on each NSG | sends NSG logs to the workspace |

## Cost

| Item | Price | In this lab |
|------|-------|-------------|
| VNets, subnets, NSGs | Free | Free |
| VNet peering (same region) | About $0.01 per GB in and out | Nothing runs yet, so $0 |
| NSG logs into Log Analytics | Counts toward the free 5 GB | A few KB a day |
| Azure Firewall, VPN gateway, Bastion | $100 to $900+ a month | Not created |
| VNet flow logs | Per GB plus storage | Not created |

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `location` | string | required | Azure region |
| `tags` | map(string) | required | Pass `module.naming.tags` |
| `hub` | object | required | `name`, `resource_group_name`, `address_space`, `subnets` |
| `spokes` | map(object) | `{}` | Same shape as `hub`, keyed by role, for example `app`. A spoke cannot be called `hub` |
| `diagnostics_enabled` | bool | `false` | Send NSG logs to `log_analytics_workspace_id` |
| `log_analytics_workspace_id` | string | `null` | Required when `diagnostics_enabled` is true |

Each subnet takes `address_prefixes`, and optionally `service_endpoints` (default `[]`, turned into azurerm 5.x `service_endpoint` blocks) and `private_endpoint_network_policies` (default `Enabled`, so NSGs also apply to private endpoints). Subnet keys become `snet-<key>`, except Azure's reserved names (`GatewaySubnet`, `AzureFirewallSubnet`, `AzureBastionSubnet`, ...), which keep their exact name and get no NSG.

## Outputs

| Name | Description |
|------|-------------|
| `hub_vnet_id` | Hub VNet resource ID |
| `hub_vnet_name` | Hub VNet name |
| `spoke_vnet_ids` | Spoke VNet IDs keyed by role |
| `subnet_ids` | Subnet IDs keyed by `role/subnet`, for example `subnet_ids["app/private-endpoints"]` |
| `nsg_ids` | NSG IDs keyed by `role/subnet`, for adding rules outside the module |

## Usage

```hcl
module "network" {
  source = "./modules/network"

  location = var.location
  tags     = module.naming.tags

  hub = {
    name                = "vnet-plat-hub-dev-eus-001"
    resource_group_name = module.resource_groups.names["core"]
    address_space       = ["10.10.0.0/24"]
    subnets = {
      shared = { address_prefixes = ["10.10.0.0/26"] }
    }
  }

  spokes = {
    app = {
      name                = "vnet-plat-app-dev-eus-001"
      resource_group_name = module.resource_groups.names["app"]
      address_space       = ["10.11.0.0/24"]
      subnets = {
        workload = { address_prefixes = ["10.11.0.0/26"] }
      }
    }
  }

  diagnostics_enabled        = true
  log_analytics_workspace_id = module.log_analytics.id
}

# Add a rule to one subnet's NSG from outside the module:
resource "azurerm_network_security_rule" "allow_https_from_hub" {
  name                        = "allow-https-from-hub"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.10.0.0/24"
  destination_address_prefix  = "*"
  resource_group_name         = module.resource_groups.names["app"]
  network_security_group_name = "nsg-plat-app-dev-eus-001-workload"
}
```

## Design notes

- **One for_each for every subnet.** Hub and spoke subnets are flattened into one map keyed `role/subnet`. Adding a subnet adds one resource and never renumbers or recreates the others, which `count` would.
- **Address plan.** Each environment gets its own `/24` hub and `/24` spoke range (dev `10.10` and `10.11`, prod `10.20` and `10.21`), set in [environments/](../../environments/). Ranges must not overlap, or peering fails. `/26` subnets leave room for more subnets later; Azure keeps 5 addresses per subnet.
- **NSG diagnostics use a plain bool.** `count` and `for_each` cannot depend on a value only known after apply, such as a new workspace ID, so `diagnostics_enabled` switches the settings on and an input validation checks that the ID is set. That validation refers to another variable, so the module needs Terraform 1.9+.
- **No route tables yet.** The original module sends spoke traffic through a hub firewall when one exists. There is no firewall here (Azure Firewall costs about $900 a month), so routing is left out until one is needed.

## Tests

```bash
cd modules/network
terraform init -backend=false
terraform test
```

The tests use `mock_provider "azurerm"`, so they need no Azure account. They check names, that every subnet has an NSG and no default outbound access, two-way peering, reserved subnet handling, service endpoint blocks, NSG diagnostics, and that bad input is rejected: an invalid CIDR, a spoke called `hub`, and diagnostics without a workspace.
