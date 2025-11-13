# Pulumi Deployment Scripts

These scripts help you deploy and destroy Azure infrastructure using Pulumi locally.

## Prerequisites

1. **Azure CLI** - Install from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
2. **Pulumi CLI** - Install from https://www.pulumi.com/docs/get-started/install/
3. **Python 3.11+** - With pip installed
4. **Azure Service Principal credentials**

## Setup

### 1. Set up Azure credentials

Export your Azure service principal credentials:

```bash
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="your-tenant-id"
export ARM_SUBSCRIPTION_ID="your-subscription-id"
```

### 2. Set Pulumi passphrase (optional but recommended)

```bash
export PULUMI_CONFIG_PASSPHRASE="your-strong-passphrase"
```

### 3. Install Python dependencies

```bash
pip install -r requirements.txt
```

### 4. Make scripts executable

```bash
chmod +x scripts/pulumi-up.sh
chmod +x scripts/pulumi-destroy.sh
```

## Usage

### Deploy Infrastructure

Deploy to the default environment (dev):
```bash
./scripts/pulumi-up.sh
```

Deploy to a specific environment:
```bash
./scripts/pulumi-up.sh production
./scripts/pulumi-up.sh staging
./scripts/pulumi-up.sh dev
```

The script will:
1. Check Azure credentials
2. Install dependencies if needed
3. Show a preview of changes
4. Prompt for confirmation
5. Deploy the infrastructure
6. Export kubeconfig (if AKS is deployed)

### Destroy Infrastructure

Destroy the default environment (dev):
```bash
./scripts/pulumi-destroy.sh
```

Destroy a specific environment:
```bash
./scripts/pulumi-destroy.sh dev
```

The script will:
1. Check Azure credentials
2. Show current resources
3. Preview destruction
4. Require typed confirmation (`destroy-<environment>`)
5. Destroy all infrastructure
6. Optionally remove the Pulumi stack

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `ARM_CLIENT_ID` | Yes | Azure Service Principal Application ID |
| `ARM_CLIENT_SECRET` | Yes | Azure Service Principal Secret Value |
| `ARM_TENANT_ID` | Yes | Azure AD Tenant ID |
| `ARM_SUBSCRIPTION_ID` | Yes | Azure Subscription ID |
| `PULUMI_CONFIG_PASSPHRASE` | No | Passphrase for encrypting Pulumi secrets |
| `PULUMI_BACKEND_URL` | No | Custom Pulumi backend (default: local) |

## Examples

### Complete deployment workflow

```bash
# Set credentials
export ARM_CLIENT_ID="xxx"
export ARM_CLIENT_SECRET="xxx"
export ARM_TENANT_ID="xxx"
export ARM_SUBSCRIPTION_ID="xxx"
export PULUMI_CONFIG_PASSPHRASE="my-secure-passphrase"

# Deploy to dev
./scripts/pulumi-up.sh dev

# Use the kubeconfig
export KUBECONFIG=./kubeconfig-dev.yaml
kubectl get nodes

# When done, destroy
./scripts/pulumi-destroy.sh dev
```

### Using Pulumi Cloud backend

```bash
# Login to Pulumi Cloud
pulumi login

# Set backend URL
export PULUMI_BACKEND_URL="https://api.pulumi.com"

# Deploy
./scripts/pulumi-up.sh dev
```

## Troubleshooting

### "ARM_CLIENT_ID is not set"
Export your Azure credentials before running the scripts.

### "No module named 'pulumi'"
Install dependencies: `pip install -r requirements.txt`

### "incorrect passphrase"
Your `PULUMI_CONFIG_PASSPHRASE` doesn't match the one used to encrypt secrets in the stack.
Either set the correct passphrase or remove secrets from the stack config.

### "authentication failed"
Your `ARM_CLIENT_SECRET` might be incorrect. Verify it in Azure Portal:
1. Go to Azure AD → App registrations → Your App
2. Certificates & secrets
3. Create a new secret and copy the VALUE (not the ID)

## Safety Features

- Both scripts check for required credentials before proceeding
- `pulumi-up.sh` requires confirmation before applying changes
- `pulumi-destroy.sh` requires typing `destroy-<environment>` to confirm
- Preview is always shown before changes are made
- All operations use `set -e` to fail fast on errors

## Output Files

- `kubeconfig-<environment>.yaml` - Kubernetes configuration file (if AKS is deployed)
- `.pulumi/` - Local Pulumi state (if using local backend)

## Best Practices

1. Always review the preview before confirming deployment
2. Use separate environments (dev, staging, production)
3. Keep your `ARM_CLIENT_SECRET` secure and rotate regularly
4. Use a strong `PULUMI_CONFIG_PASSPHRASE` and store it securely
5. Commit stack config files (Pulumi.*.yaml) to version control
6. Never commit credentials or kubeconfig files
