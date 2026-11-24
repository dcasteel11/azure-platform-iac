# -----------------------------------------------------------------------------
# Resource groups
#
# A resource group is a folder for Azure resources: everything inside shares a
# lifecycle, access (RBAC) and cost reporting. Resource groups are free.
#
# One environment gets several groups split by purpose, for example:
#   core  shared platform services (Log Analytics, Key Vault)
#   app   the workload (Static Web App)
#
# for_each on a map (not count on a list) keys every group by its purpose, so
# adding or removing one purpose never renames or recreates the others.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "this" {
  for_each = var.names

  name     = each.value
  location = var.location
  tags     = var.tags
}
