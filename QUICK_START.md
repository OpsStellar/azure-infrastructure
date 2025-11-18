# Azure Infrastructure - Quick Start

Simplified Pulumi deployment for Azure infrastructure.

## 🚀 Quick Setup (3 Steps)

### 1. Setup Python Environment

```bash
./scripts/setup-venv.sh
source venv/bin/activate
```

### 2. Create Environment File

```bash
# Copy template
cp .env.example .env

# Edit with your credentials
nano .env
```

Fill in these values in `.env`:

- `ARM_CLIENT_ID` - Azure Service Principal App ID
- `ARM_CLIENT_SECRET` - Service Principal Secret
- `ARM_TENANT_ID` - Azure AD Tenant ID
- `ARM_SUBSCRIPTION_ID` - Azure Subscription ID
- `AZURE_STORAGE_ACCOUNT` - Storage account for Pulumi state (default: pulumistate3033355)
- `AZURE_STORAGE_KEY` - Storage account key (or will be fetched automatically)
- `PULUMI_CONFIG_PASSPHRASE` - Passphrase for Pulumi secrets

### 3. Deploy

```bash
./scripts/pulumi.sh up dev
```

## 📋 Commands

| Command                             | Description                         |
| ----------------------------------- | ----------------------------------- |
| `./scripts/setup-venv.sh`           | Setup Python virtual environment    |
| `./scripts/pulumi.sh`               | Preview and deploy to dev (default) |
| `./scripts/pulumi.sh up [env]`      | Preview and deploy to environment   |
| `./scripts/pulumi.sh destroy [env]` | Destroy infrastructure              |

**Environments:** `dev`, `staging`, `production` (default: `dev`)

## 🔄 Daily Workflow

```bash
# Deploy to dev (loads env, previews, confirms, deploys)
./scripts/pulumi.sh

# Deploy to staging
./scripts/pulumi.sh up staging

# Deploy to production
./scripts/pulumi.sh up production

# Destroy dev environment
./scripts/pulumi.sh destroy dev
```

## 📁 Project Structure

```
azure-infrastructure/
├── infrastructure/
│   ├── __main__.py         # Container Apps deployment
│   └── __main_aks.py       # AKS deployment
├── scripts/
│   ├── setup-venv.sh       # Setup Python environment
│   └── pulumi.sh           # Main deployment script (loads env + deploys)
├── .env.example            # Environment template
├── .env                    # Your credentials (git-ignored)
├── Pulumi.yaml             # Pulumi project config
└── Pulumi.*.yaml           # Stack configs (dev/staging/production)
```

## 🔑 Getting Azure Credentials

### Create Service Principal

```bash
az login

az ad sp create-for-rbac --name "pulumi-deployer" \
  --role="Contributor" \
  --scopes="/subscriptions/YOUR_SUBSCRIPTION_ID"

# Output shows:
# - appId → ARM_CLIENT_ID
# - password → ARM_CLIENT_SECRET
# - tenant → ARM_TENANT_ID
```

### Create Storage Account (for Pulumi state)

```bash
az group create --name pulumi-state-rg --location eastus

az storage account create \
  --name pulumistate3033355 \
  --resource-group pulumi-state-rg \
  --location eastus \
  --sku Standard_LRS

az storage container create \
  --name pulumi-state \
  --account-name pulumistate3033355

# Get storage key
az storage account keys list \
  --account-name pulumistate3033355 \
  --resource-group pulumi-state-rg \
  --query '[0].value' -o tsv
```

## ⚠️ Important

- **NEVER commit `.env` to git!** (it's in `.gitignore`)
- `.env.example` is the template (safe to commit)
- `AZURE_STORAGE_KEY` will be fetched automatically if you have Azure CLI configured
- All credentials are stored locally in `.env`

## 📚 More Info

- [README.md](README.md) - Full project documentation
- [Pulumi Documentation](https://www.pulumi.com/docs/)
- [Azure Documentation](https://docs.microsoft.com/azure/)

---

**That's it!** Just 3 commands to get started. 🎉
