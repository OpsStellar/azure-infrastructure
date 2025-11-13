# Pulumi Deployment Scripts - Quick Start Guide

## ✅ WORKING SOLUTION - Azure Backend

This guide provides the **complete working setup** for deploying your Azure infrastructure using Pulumi with Azure Blob Storage backend.

## Prerequisites

- Azure CLI installed and logged in
- Python 3.12+ with venv
- Pulumi CLI installed at `~/.pulumi/bin/`
- Azure subscription with appropriate permissions

## Quick Start (5 Steps)

### 1. Setup Python Virtual Environment

```bash
cd /mnt/c/Users/SPatil3/OneDrive\ -\ A10\ Networks/git/azure-infrastructure
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 2. Set Required Environment Variables

```bash
# Azure Service Principal credentials (already set in your environment)
export ARM_CLIENT_ID="2f54ef99-beb9-4473-b696-6639d40dd76e"
export ARM_CLIENT_SECRET="yED28Q~***"
export ARM_SUBSCRIPTION_ID="459e1e2d-bfc3-4a33-b475-5c1923557262"
export ARM_TENANT_ID="185ef526-b6f9-4cd5-b6a3-4fa6039f3ae0"

# Pulumi configuration
export PULUMI_CONFIG_PASSPHRASE="strongpassphrase2024!"

# Azure Storage for Pulumi state (REQUIRED)
export AZURE_STORAGE_ACCOUNT="pulumistate3033355"
```

### 3. Load Environment (Simplified)

```bash
source scripts/setup-env.sh
```

This will automatically:
- Set `AZURE_STORAGE_ACCOUNT`
- Fetch `AZURE_STORAGE_KEY` from Azure
- Add Pulumi to PATH
- Verify configuration

### 4. Deploy Infrastructure (Preview First)

```bash
# Preview changes (safe - no actual deployment)
./scripts/pulumi-up.sh dev

# When ready, deploy for real
# The script will ask for confirmation before deploying
```

### 5. Destroy Infrastructure (When Done)

```bash
./scripts/pulumi-destroy.sh dev
```

## Azure Backend Details

Your Pulumi state is stored in Azure Blob Storage:
- **Storage Account**: `pulumistate3033355`
- **Resource Group**: `pulumi-state-rg`
- **Container**: `pulumi-state`
- **Location**: `eastus`
- **Backend URL**: `azblob://pulumi-state`

## What Gets Deployed

The `dev` environment deploys:
- ✅ Resource Group
- ✅ Azure Container Registry (ACR) with admin enabled
- ✅ Virtual Network (10.0.0.0/16)
- ✅ Subnet for AKS (10.0.0.0/20)
- ✅ Azure Kubernetes Service (AKS) cluster
  - Node VM Size: Standard_B2s
  - Node count: 2 (min: 1, max: 3)
  - Kubernetes version: 1.31.11
- ✅ Kubernetes provider
- ✅ Role assignment for AKS to pull from ACR

## Stack Configuration

Current `dev` stack configuration:
```yaml
azure-native:location: eastus
acr_sku: Basic
aks_subnet_prefix: 10.0.0.0/20
dns_service_ip: 10.1.0.10
environment: dev
k8s_version: 1.31.11
max_node_count: 3
min_node_count: 1
node_count: 2
node_vm_size: Standard_B2s
project_name: opsstellar
service_cidr: 10.1.0.0/16
vnet_address_space: 10.0.0.0/16
```

## Troubleshooting

### Issue: `pulumi: command not found`
**Solution**: Run `source scripts/setup-env.sh` to add Pulumi to PATH

### Issue: Azure Storage authentication errors
**Solution**: The script automatically fetches the storage key. Ensure you're logged into Azure CLI:
```bash
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
```

### Issue: Stack doesn't exist
**Solution**: First run will create the stack automatically. If you see encryption errors, the stack YAML files are backed up and new ones are created.

## One-Command Deployment (All Steps)

```bash
cd /mnt/c/Users/SPatil3/OneDrive\ -\ A10\ Networks/git/azure-infrastructure && \
source venv/bin/activate && \
source scripts/setup-env.sh && \
./scripts/pulumi-up.sh dev
```

## Estimated Costs

Running the `dev` environment in Azure:
- **AKS cluster**: ~$70-100/month (2x Standard_B2s nodes)
- **ACR Basic**: ~$5/month
- **Virtual Network**: Free
- **Storage for Pulumi state**: < $1/month

**Total: ~$75-105/month**

## Next Steps

1. ✅ Preview the infrastructure: `./scripts/pulumi-up.sh dev` (done automatically)
2. ✅ Deploy when ready: Answer 'yes' when prompted
3. ✅ Access outputs: `pulumi stack output kubeconfig --show-secrets`
4. ✅ Configure kubectl: `pulumi stack output kubeconfig --show-secrets > kubeconfig.yaml`
5. ✅ Destroy when done: `./scripts/pulumi-destroy.sh dev`

## Success Indicators

When the script works correctly, you'll see:
```
✅ Environment configured for Pulumi with Azure backend
✅ Azure credentials are set
✅ Python dependencies verified
Logged in to PC-SPatil3 as spatil3 (azblob://pulumi-state)
==========================================
Preview - showing planned changes
==========================================
Resources:
    + 8 to create
```

## Support

The scripts are now **fully tested and working** with Azure backend. All state is safely stored in Azure Blob Storage and can be shared across your team.
