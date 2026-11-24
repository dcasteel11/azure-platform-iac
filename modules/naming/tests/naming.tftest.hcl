# -----------------------------------------------------------------------------
# Unit tests for the naming module, run with: terraform test
#
# The module has no providers or resources, so "command = plan" evaluates all
# the locals and outputs without touching Azure. These tests are fast and free.
# -----------------------------------------------------------------------------

variables {
  workload    = "plat"
  environment = "dev"
  location    = "eastus"
  owner       = "platform-team"
  cost_center = "lab"
}

run "standard_names_follow_the_pattern" {
  command = plan

  assert {
    condition     = output.names.resource_group == "rg-plat-dev-eus-001"
    error_message = "Resource group name should be rg-plat-dev-eus-001, got ${output.names.resource_group}."
  }

  assert {
    condition     = output.names.log_analytics_workspace == "log-plat-dev-eus-001"
    error_message = "Log Analytics name does not follow the pattern."
  }
}

run "globally_unique_names_fit_azure_limits" {
  command = plan

  # Longest allowed inputs, to prove the length maths in main.tf.
  variables {
    workload      = "abcdef"
    environment   = "prod"
    location      = "westus2"
    instance      = "999"
    unique_suffix = "zz99"
  }

  assert {
    condition     = can(regex("^[a-z0-9]{3,24}$", output.names.storage_account))
    error_message = "Storage account name must be 3-24 lowercase letters or digits, got ${output.names.storage_account}."
  }

  assert {
    condition     = length(output.names.key_vault) <= 24
    error_message = "Key Vault name must be 24 characters or fewer, got ${output.names.key_vault}."
  }
}

run "required_tags_cannot_be_overridden" {
  command = plan

  variables {
    extra_tags = {
      environment = "prod"
      project     = "portfolio"
    }
  }

  assert {
    condition     = output.tags.environment == "dev"
    error_message = "Required tag environment was overridden by extra_tags."
  }

  assert {
    condition     = output.tags.project == "portfolio"
    error_message = "Extra tags should be kept."
  }

  assert {
    condition     = output.tags["managed-by"] == "terraform"
    error_message = "managed-by tag should always be terraform."
  }
}

run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "staging"
  }

  # The plan must fail on the environment validation rule.
  expect_failures = [var.environment]
}

run "resource_group_names_include_the_purpose" {
  command = plan

  variables {
    resource_group_purposes = ["core", "app"]
  }

  assert {
    condition     = output.resource_group_names.core == "rg-plat-core-dev-eus-001"
    error_message = "Core resource group should be rg-plat-core-dev-eus-001, got ${output.resource_group_names.core}."
  }

  assert {
    condition     = length(output.resource_group_names) == 2
    error_message = "There should be one name per purpose."
  }
}

run "rejects_repeated_resource_group_purpose" {
  command = plan

  variables {
    resource_group_purposes = ["core", "core"]
  }

  expect_failures = [var.resource_group_purposes]
}

run "rejects_invalid_resource_group_purpose" {
  command = plan

  variables {
    resource_group_purposes = ["Core-Services"]
  }

  expect_failures = [var.resource_group_purposes]
}
