#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# One-time bootstrap: remote state storage and the GitHub OIDC identity
#
# Terraform cannot create the storage account that holds its own state, and
# GitHub Actions cannot log in to Azure until an identity exists. This script
# solves both chicken-and-egg problems once, with the Azure CLI, so everything
# after it is managed by Terraform.
#
# What it creates (all free or a few cents a month):
#   1. Resource group      rg-<workload>-tfstate-<region>-<instance>
#   2. Storage account     st<workload>tfstate<region><instance><suffix>
#                          - blob versioning and 30 day soft delete
#                          - Entra ID auth only (shared keys turned off)
#                          - TLS 1.2, HTTPS only, no public blob access
#   3. Blob container      tfstate
#   4. Entra app + service principal for GitHub Actions, with federated
#      credentials (OIDC) for the main branch, pull requests and the
#      "production" environment. No client secret is ever created.
#   5. Role assignments    Contributor on the subscription and
#                          Storage Blob Data Contributor on the state account
#                          for the GitHub identity; Storage Blob Data
#                          Contributor on the state account for you.
#
# Run it in Azure Cloud Shell (Bash), signed in as an Owner of the subscription:
#   GITHUB_REPO=<owner>/<repo> ./bootstrap/bootstrap.sh
#
# It is safe to run again: every step checks whether the thing already exists.
# Nothing it prints is a secret, but the IDs are still kept out of Git.
# -----------------------------------------------------------------------------
set -euo pipefail

# --- Inputs (override with environment variables) ----------------------------
GITHUB_REPO="${GITHUB_REPO:?Set GITHUB_REPO to <owner>/<repo>, for example GITHUB_REPO=myname/azure-platform-iac}"
WORKLOAD="${WORKLOAD:-plat}"
LOCATION="${LOCATION:-eastus}"
INSTANCE="${INSTANCE:-001}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
GITHUB_ENVIRONMENT="${GITHUB_ENVIRONMENT:-production}"
APP_NAME="${APP_NAME:-github-${GITHUB_REPO//\//-}}"

# Short region codes, the same map as modules/naming/main.tf.
case "${LOCATION}" in
  eastus) REGION="eus" ;;
  eastus2) REGION="eus2" ;;
  centralus) REGION="cus" ;;
  westus2) REGION="wus2" ;;
  westus3) REGION="wus3" ;;
  northeurope) REGION="neu" ;;
  westeurope) REGION="weu" ;;
  uksouth) REGION="uks" ;;
  *)
    echo "Unsupported LOCATION '${LOCATION}'. Use one of the regions in modules/naming/main.tf." >&2
    exit 1
    ;;
esac

log() { printf '\n==> %s\n' "$*"; }

# --- Who and where ------------------------------------------------------------
log "Checking Azure CLI sign-in"
SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
SUBSCRIPTION_NAME="$(az account show --query name -o tsv)"
echo "Subscription: ${SUBSCRIPTION_NAME}"

# Storage account names are global across all of Azure, so add a short suffix
# derived from the subscription ID. It is the same on every run (idempotent)
# and different for every subscription.
SUFFIX="${UNIQUE_SUFFIX:-$(printf '%s' "${SUBSCRIPTION_ID}" | sha256sum | cut -c1-4)}"

RESOURCE_GROUP="rg-${WORKLOAD}-tfstate-${REGION}-${INSTANCE}"
STORAGE_ACCOUNT="st${WORKLOAD}tfstate${REGION}${INSTANCE}${SUFFIX}"
if ((${#STORAGE_ACCOUNT} > 24)); then
  echo "Storage account name '${STORAGE_ACCOUNT}' is longer than 24 characters. Use a shorter WORKLOAD or UNIQUE_SUFFIX." >&2
  exit 1
fi

# Same required tags as modules/naming, so Azure Policy (step 10) accepts them.
TAGS=(environment=shared "workload=${WORKLOAD}" owner=platform-team cost-center=lab managed-by=bootstrap-script)

# --- 1. Resource group ----------------------------------------------------------
log "Resource group ${RESOURCE_GROUP}"
az group create \
  --name "${RESOURCE_GROUP}" \
  --location "${LOCATION}" \
  --tags "${TAGS[@]}" \
  --output none

# --- 2. Storage account ---------------------------------------------------------
log "Storage account ${STORAGE_ACCOUNT}"
if ! az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" --output none 2>/dev/null; then
  az storage account create \
    --name "${STORAGE_ACCOUNT}" \
    --resource-group "${RESOURCE_GROUP}" \
    --location "${LOCATION}" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --min-tls-version TLS1_2 \
    --https-only true \
    --allow-blob-public-access false \
    --allow-shared-key-access false \
    --tags "${TAGS[@]}" \
    --output none
else
  echo "Already exists"
fi
STORAGE_ID="$(az storage account show --name "${STORAGE_ACCOUNT}" --resource-group "${RESOURCE_GROUP}" --query id -o tsv)"

# Versioning keeps every previous state file, so a bad apply can be rolled back.
# Soft delete protects against deleting the state blob or the whole container.
az storage account blob-service-properties update \
  --account-name "${STORAGE_ACCOUNT}" \
  --resource-group "${RESOURCE_GROUP}" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 30 \
  --output none

# Assign a role only if it is not already there.
assign_role() {
  local assignee_object_id="$1" principal_type="$2" role="$3" scope="$4"
  local existing
  existing="$(az role assignment list --assignee "${assignee_object_id}" --role "${role}" --scope "${scope}" --query 'length(@)' -o tsv)"
  if [[ "${existing}" == "0" ]]; then
    az role assignment create \
      --assignee-object-id "${assignee_object_id}" \
      --assignee-principal-type "${principal_type}" \
      --role "${role}" \
      --scope "${scope}" \
      --output none
    echo "Assigned '${role}'"
  else
    echo "'${role}' already assigned"
  fi
}

# Shared keys are off, so even you need a data-plane role to touch the blobs.
log "Giving you Storage Blob Data Contributor on the state account"
ME_OBJECT_ID="$(az ad signed-in-user show --query id -o tsv)"
assign_role "${ME_OBJECT_ID}" User "Storage Blob Data Contributor" "${STORAGE_ID}"

# --- 3. Container -----------------------------------------------------------------
# New role assignments can take a few minutes to apply, so retry.
log "Container ${STATE_CONTAINER} (retries while the new role assignment applies)"
for attempt in $(seq 1 12); do
  if az storage container create \
    --name "${STATE_CONTAINER}" \
    --account-name "${STORAGE_ACCOUNT}" \
    --auth-mode login \
    --output none 2>/dev/null; then
    echo "Ready"
    break
  fi
  if ((attempt == 12)); then
    echo "Could not create the container. Wait a few minutes and run the script again." >&2
    exit 1
  fi
  sleep 15
done

# --- 4. GitHub OIDC identity ----------------------------------------------------
log "Entra app registration ${APP_NAME}"
APP_ID="$(az ad app list --display-name "${APP_NAME}" --query '[0].appId' -o tsv)"
if [[ -z "${APP_ID}" ]]; then
  APP_ID="$(az ad app create --display-name "${APP_NAME}" --query appId -o tsv)"
  echo "Created"
else
  echo "Already exists"
fi

SP_OBJECT_ID="$(az ad sp list --filter "appId eq '${APP_ID}'" --query '[0].id' -o tsv)"
if [[ -z "${SP_OBJECT_ID}" ]]; then
  SP_OBJECT_ID="$(az ad sp create --id "${APP_ID}" --query id -o tsv)"
fi

# One federated credential per kind of workflow run that may log in.
# GitHub puts the "subject" in its OIDC token; Entra ID only accepts tokens
# whose subject matches exactly, so other repos and branches cannot log in.
add_federated_credential() {
  local name="$1" subject="$2"
  local existing
  existing="$(az ad app federated-credential list --id "${APP_ID}" --query "[?name=='${name}'] | length(@)" -o tsv)"
  if [[ "${existing}" != "0" ]]; then
    echo "Federated credential '${name}' already exists"
    return
  fi
  local params
  params="$(printf '{"name":"%s","issuer":"https://token.actions.githubusercontent.com","subject":"%s","audiences":["api://AzureADTokenExchange"]}' "${name}" "${subject}")"
  az ad app federated-credential create --id "${APP_ID}" --parameters "${params}" --output none
  echo "Federated credential '${name}' created"
}

log "Federated credentials for ${GITHUB_REPO}"
add_federated_credential "main-branch" "repo:${GITHUB_REPO}:ref:refs/heads/main"
add_federated_credential "pull-requests" "repo:${GITHUB_REPO}:pull_request"
add_federated_credential "env-${GITHUB_ENVIRONMENT}" "repo:${GITHUB_REPO}:environment:${GITHUB_ENVIRONMENT}"

# --- 5. Roles for the GitHub identity -----------------------------------------
# Contributor can create and change resources but cannot grant access to others.
# Policy assignments (step 10) need an extra role, added in that step.
log "Roles for the GitHub identity"
assign_role "${SP_OBJECT_ID}" ServicePrincipal "Contributor" "/subscriptions/${SUBSCRIPTION_ID}"
assign_role "${SP_OBJECT_ID}" ServicePrincipal "Storage Blob Data Contributor" "${STORAGE_ID}"

# --- Output -------------------------------------------------------------------------
cat >backend.hcl <<EOF
# Generated by bootstrap/bootstrap.sh. Not committed (see .gitignore).
resource_group_name  = "${RESOURCE_GROUP}"
storage_account_name = "${STORAGE_ACCOUNT}"
container_name       = "${STATE_CONTAINER}"
key                  = "platform.dev.tfstate"
EOF

cat <<EOF

==> Done

1. Add these as repository secrets in GitHub
   (Settings > Secrets and variables > Actions > New repository secret).
   They are identifiers, not passwords, but they stay out of the code.

   AZURE_CLIENT_ID        ${APP_ID}
   AZURE_TENANT_ID        ${TENANT_ID}
   AZURE_SUBSCRIPTION_ID  ${SUBSCRIPTION_ID}

2. Add these as repository variables (same page, Variables tab):

   TFSTATE_RESOURCE_GROUP   ${RESOURCE_GROUP}
   TFSTATE_STORAGE_ACCOUNT  ${STORAGE_ACCOUNT}
   TFSTATE_CONTAINER        ${STATE_CONTAINER}

3. Use the remote state from your own shell:

   export ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}
   terraform init -backend-config=backend.hcl
   terraform plan

backend.hcl was written to the current folder.
EOF
