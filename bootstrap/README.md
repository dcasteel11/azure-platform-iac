# Bootstrap: remote state and GitHub OIDC

A one-time script that prepares an Azure subscription for this platform. Run it once per subscription, before the deploy pipeline (roadmap step 4).

## Why a script and not Terraform

Two chicken-and-egg problems:

- **State storage.** Terraform keeps its state in a storage account, so it cannot be the tool that creates that account.
- **CI identity.** GitHub Actions needs an Azure identity to log in before it can run Terraform at all.

The Azure CLI creates both once. Everything after this is managed by Terraform. See [ADR 0004](../docs/decisions/0004-bootstrap-oidc-and-remote-state.md).

## What it creates

| Resource | Name (defaults) | Notes |
|----------|-----------------|-------|
| Resource group | `rg-plat-tfstate-eus-001` | Holds only the state account |
| Storage account | `stplattfstateeus001<suffix>` | Standard LRS, versioning, 30 day soft delete, Entra ID auth only, TLS 1.2, no public access |
| Blob container | `tfstate` | One blob per environment, for example `platform.dev.tfstate` |
| Entra app and service principal | `github-<owner>-<repo>` | No client secret. Federated credentials only |
| Federated credentials | `main-branch`, `pull-requests`, `env-production` | Only this repo's main branch, PRs and `production` environment can log in |
| Role assignments | Contributor (subscription), Storage Blob Data Contributor (state account) | For the GitHub identity. You also get Storage Blob Data Contributor on the state account |

The `<suffix>` is 4 characters derived from your subscription ID, because storage account names must be unique across all of Azure. It is the same every run.

**Cost:** a few KB of state in LRS storage costs well under $0.10 a month. Entra app registrations and role assignments are free.

## Before you start

- An Azure subscription (the free account works) where you are **Owner**. Owner is needed to create role assignments.
- Permission to register apps in Entra ID. On a personal free account you have this by default.
- This repo on GitHub (fork or clone it under your own account).

## Run it

Open [Azure Cloud Shell](https://shell.azure.com) in **Bash**. The Azure CLI is already installed and signed in.

```bash
git clone https://github.com/<owner>/azure-platform-iac.git
cd azure-platform-iac

# Optional: pick the subscription if you have more than one
az account set --subscription "<subscription name>"

GITHUB_REPO=<owner>/azure-platform-iac bash bootstrap/bootstrap.sh
```

Optional settings, all with defaults:

| Variable | Default | Purpose |
|----------|---------|---------|
| `WORKLOAD` | `plat` | Same short name as the naming module |
| `LOCATION` | `eastus` | Any region in `modules/naming/main.tf` |
| `INSTANCE` | `001` | Instance number in names |
| `UNIQUE_SUFFIX` | from subscription ID | Override if the storage name is taken |
| `GITHUB_ENVIRONMENT` | `production` | GitHub environment allowed to apply |
| `SUBJECT_FORMAT` | `id` | `id` for the OIDC subject with owner and repo IDs (newer repos), `name` for the older name-only subject |

The script is safe to run again. Each step checks whether the resource already exists, and a federated credential with an outdated subject is updated in place.

## After it runs

The script prints the values to copy into GitHub and writes `backend.hcl` in the current folder (ignored by Git).

1. **Repository secrets** (Settings > Secrets and variables > Actions): `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`.
2. **Repository variables** (same page, Variables tab): `TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, `TFSTATE_CONTAINER`.
3. **Try the remote state** from Cloud Shell:

```bash
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
terraform init -backend-config=backend.hcl
terraform plan
```

`init` should say *Successfully configured the backend "azurerm"*. After a plan or apply, the state blob appears in the `tfstate` container in the portal.

## How OIDC works here

1. A workflow run asks GitHub for a short-lived OIDC token. The token says which repo, branch, PR or environment the run belongs to (the *subject*).
2. `azure/login` sends that token to Entra ID along with `AZURE_CLIENT_ID`.
3. Entra ID checks the token against the app's federated credentials. If the issuer, subject and audience match exactly, it returns an Azure access token valid for about an hour.

Nothing long-lived is stored in GitHub, so there is no secret to leak or rotate.

### Subject formats

GitHub now includes the numeric owner and repo IDs in the subject for newer repositories:

```text
repo:<owner>@<owner-id>/<repo>@<repo-id>:pull_request      # newer repos
repo:<owner>/<repo>:pull_request                           # older repos
```

The IDs never change, so if the repo is deleted and someone else creates one with the same name, their workflows cannot log in. The script looks up both IDs from the public GitHub API and registers this format by default. For an older repo that still sends the name-only subject, run it with `SUBJECT_FORMAT=name`.

## Troubleshooting

**`AADSTS700213: No matching federated identity record found for presented assertion subject '...'`** in the `azure login (OIDC)` step of `deploy.yml`.

The subject GitHub sent does not match any federated credential. The error prints the exact subject. Compare it with the subjects the script printed (or with `az ad app federated-credential list --id <AZURE_CLIENT_ID> -o table`). Usually the fix is to run the script again with the right `SUBJECT_FORMAT`; it updates the existing credentials in place.

**`check state access` fails with `AuthorizationPermissionMismatch`.** The GitHub identity is missing Storage Blob Data Contributor on the state account, or the role was assigned in the last few minutes. Run the script again, wait five minutes and re-run the job.

## Remove everything

```bash
az group delete --name rg-plat-tfstate-eus-001 --yes
az ad app delete --id <AZURE_CLIENT_ID>
```

Deleting the app also removes its service principal and role assignments. Destroy everything Terraform created **before** deleting the state account, or Terraform loses track of it.
