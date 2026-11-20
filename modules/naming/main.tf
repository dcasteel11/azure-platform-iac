# -----------------------------------------------------------------------------
# Naming and tagging
#
# One place decides what every resource is called and how it is tagged.
# Other modules take the names and tags as inputs instead of building their own,
# so the whole estate stays consistent and searchable.
#
# Pattern (based on the Microsoft Cloud Adoption Framework):
#   <type abbreviation>-<workload>-<environment>-<region>-<instance>
#   example: rg-plat-dev-eus-001
#
# Two resource types do not allow hyphens or must be globally unique, so they
# get their own pattern (see "Globally unique names" below).
# -----------------------------------------------------------------------------

locals {
  # Short region codes keep names readable and within Azure length limits.
  # Keep this map in sync with the location validation in variables.tf.
  location_short = {
    eastus      = "eus"
    eastus2     = "eus2"
    centralus   = "cus"
    westus2     = "wus2"
    westus3     = "wus3"
    northeurope = "neu"
    westeurope  = "weu"
    uksouth     = "uks"
  }

  region = local.location_short[var.location]

  # Shared middle part of every standard name, for example "plat-dev-eus-001".
  base = join("-", [var.workload, var.environment, local.region, var.instance])

  # Resource type abbreviations from the Cloud Adoption Framework:
  # https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations
  abbreviations = {
    resource_group          = "rg"
    log_analytics_workspace = "log"
    virtual_network         = "vnet"
    subnet                  = "snet"
    network_security_group  = "nsg"
    user_assigned_identity  = "id"
    static_web_app          = "stapp"
    function_app            = "func"
    app_service_plan        = "asp"
    action_group            = "ag"
    budget                  = "budget"
  }

  # Standard names: "<abbr>-<base>", for example "log-plat-dev-eus-001".
  standard_names = {
    for type, abbr in local.abbreviations : type => "${abbr}-${local.base}"
  }

  # Globally unique names.
  # Storage account: 3-24 chars, lowercase letters and digits only, no hyphens.
  #   Longest case: "st" + 6 + 4 + 4 + 3 + 4 = 23 characters.
  # Key Vault: 3-24 chars, letters, digits and hyphens. The instance is left out
  #   so the name fits. Longest case: "kv-" + 6 + "-" + 4 + "-" + 4 + 4 = 23.
  # The input validations in variables.tf are what guarantee these limits.
  unique_names = {
    storage_account = "st${var.workload}${var.environment}${local.region}${var.instance}${var.unique_suffix}"
    key_vault       = "kv-${var.workload}-${var.environment}-${local.region}${var.unique_suffix}"
  }

  names = merge(local.standard_names, local.unique_names)

  # Tags every resource must carry. Azure Policy (roadmap step 10) will deny
  # resources that are missing these keys, so the keys are also an output.
  required_tags = {
    environment   = var.environment
    workload      = var.workload
    owner         = var.owner
    "cost-center" = var.cost_center
    "managed-by"  = "terraform"
  }

  # Required tags are merged last so a caller cannot override them by accident.
  tags = merge(var.extra_tags, local.required_tags)
}
