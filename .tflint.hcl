# TFLint configuration
# Docs: https://github.com/terraform-linters/tflint

config {
  # Lint module calls too, not just the root module.
  call_module_type = "all"
}

# Core Terraform rules (naming, unused declarations, pinned versions, etc.).
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# Azure-specific rules, such as invalid VM sizes or SKU names.
plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}
