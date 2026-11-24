# -----------------------------------------------------------------------------
# Unit tests for the resource-groups module, run with: terraform test
#
# mock_provider replaces azurerm with a fake, so nothing is created in Azure
# and no account is needed. "command = plan" checks the planned values and
# every validation rule.
# -----------------------------------------------------------------------------

mock_provider "azurerm" {}

variables {
  names = {
    core = "rg-plat-core-dev-eus-001"
    app  = "rg-plat-app-dev-eus-001"
  }
  location = "eastus"
  tags = {
    environment   = "dev"
    owner         = "platform-team"
    "cost-center" = "lab"
  }
}

run "creates_one_group_per_purpose" {
  command = plan

  assert {
    condition     = length(azurerm_resource_group.this) == 2
    error_message = "Expected one resource group per entry in names."
  }

  assert {
    condition     = azurerm_resource_group.this["core"].name == "rg-plat-core-dev-eus-001"
    error_message = "The core group should take its name from the names map."
  }

  assert {
    condition     = alltrue([for rg in azurerm_resource_group.this : rg.location == "eastus"])
    error_message = "Every group should be in the given location."
  }

  assert {
    condition     = alltrue([for rg in azurerm_resource_group.this : rg.tags["environment"] == "dev"])
    error_message = "Every group should carry the tags."
  }
}

run "rejects_missing_required_tags" {
  command = plan

  variables {
    tags = { environment = "dev" }
  }

  expect_failures = [var.tags]
}

run "rejects_name_ending_with_a_period" {
  command = plan

  variables {
    names = { core = "rg-plat-core." }
  }

  expect_failures = [var.names]
}

run "rejects_empty_map" {
  command = plan

  variables {
    names = {}
  }

  expect_failures = [var.names]
}
