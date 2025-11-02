# Azure Permissions Required for Pulumi

This document describes the Azure permissions needed for Pulumi to manage infrastructure and export credentials.

## Problem

When running `pulumi preview` or `pulumi up`, you may encounter these errors:

```
AuthorizationFailed: The client 'live.com#your-email@example.com' with object id 'xxx' does not have authorization to perform action:
- 'Microsoft.ContainerRegistry/registries/listCredentials/action'
- 'Microsoft.ContainerService/managedClusters/listClusterUserCredential/action'
```

## Required Permissions

Your Azure account needs these specific permissions to export ACR credentials and AKS kubeconfig:

1. **ACR Credentials**: `Microsoft.ContainerRegistry/registries/listCredentials/action`
2. **AKS Kubeconfig**: `Microsoft.ContainerService/managedClusters/listClusterUserCredential/action`

## Solutions

### Option 1: Assign Built-in Roles (Recommended)

Assign these built-in roles to your Azure account:

#### 1. For ACR Access - Assign "Contributor" or "Owner" role on ACR

**Via Azure Portal:**

1. Go to Azure Portal → Resource Groups → `opsstellar-dev-rg`
2. Click on the ACR resource (`opsstellardevacr`)
3. Click "Access control (IAM)" in the left menu
4. Click "+ Add" → "Add role assignment"
5. Select Role: **"Contributor"** or **"Owner"**
6. Click "Next"
7. Click "+ Select members"
8. Search for your email: `samadhan.patil4067@gmail.com`
9. Click "Select" → "Review + assign"

**Via Azure CLI:**

```bash
# Get your user Object ID
YOUR_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Your Object ID: $YOUR_USER_OBJECT_ID"

# Assign Contributor role on ACR
az role assignment create \
  --assignee $YOUR_USER_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerRegistry/registries/opsstellardevacr

# Verify assignment
az role assignment list \
  --assignee $YOUR_USER_OBJECT_ID \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerRegistry/registries/opsstellardevacr \
  --output table
```

#### 2. For AKS Access - Assign "Azure Kubernetes Service Cluster User Role"

**Via Azure Portal:**

1. Go to Azure Portal → Resource Groups → `opsstellar-dev-rg`
2. Click on the AKS cluster (`opsstellar-dev-aks990bcc12`)
3. Click "Access control (IAM)" in the left menu
4. Click "+ Add" → "Add role assignment"
5. Select Role: **"Azure Kubernetes Service Cluster User Role"**
6. Click "Next"
7. Click "+ Select members"
8. Search for your email: `samadhan.patil4067@gmail.com`
9. Click "Select" → "Review + assign"

**Via Azure CLI:**

```bash
# Get your user Object ID (if not already done)
YOUR_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Your Object ID: $YOUR_USER_OBJECT_ID"

# Assign AKS Cluster User role
az role assignment create \
  --assignee $YOUR_USER_OBJECT_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerService/managedClusters/opsstellar-dev-aks990bcc12

# Verify assignment
az role assignment list \
  --assignee $YOUR_USER_OBJECT_ID \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg/providers/Microsoft.ContainerService/managedClusters/opsstellar-dev-aks990bcc12 \
  --output table
```

### Option 2: Assign at Resource Group Level (Simpler)

If you want to manage all resources in the resource group:

**Via Azure Portal:**

1. Go to Azure Portal → Resource Groups → `opsstellar-dev-rg`
2. Click "Access control (IAM)" in the left menu
3. Click "+ Add" → "Add role assignment"
4. Select Role: **"Contributor"**
5. Click "Next"
6. Click "+ Select members"
7. Search for your email: `samadhan.patil4067@gmail.com`
8. Click "Select" → "Review + assign"

**Via Azure CLI:**

```bash
# Get your user Object ID
YOUR_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Your Object ID: $YOUR_USER_OBJECT_ID"

# Assign Contributor role at Resource Group level
az role assignment create \
  --assignee $YOUR_USER_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg

# Verify assignment
az role assignment list \
  --assignee $YOUR_USER_OBJECT_ID \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg \
  --output table
```

### Option 3: Assign at Subscription Level (Most Permissive)

If you manage multiple resource groups:

**Via Azure CLI:**

```bash
# Get your user Object ID
YOUR_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
echo "Your Object ID: $YOUR_USER_OBJECT_ID"

# Assign Contributor role at Subscription level
az role assignment create \
  --assignee $YOUR_USER_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262

# Verify assignment
az role assignment list \
  --assignee $YOUR_USER_OBJECT_ID \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262 \
  --output table
```

## Quick Command Reference

### Check Your Current Permissions

```bash
# Get your Object ID
az ad signed-in-user show --query id -o tsv

# List all your role assignments
az role assignment list \
  --assignee $(az ad signed-in-user show --query id -o tsv) \
  --all \
  --output table
```

### After Assigning Permissions

```bash
# Refresh Azure CLI credentials
az account clear
az login

# Or if already logged in
az account get-access-token --query accessToken -o tsv > /dev/null

# Test Pulumi again
cd /mnt/d/2GitHub/azure-infrastructure
export PULUMI_CONFIG_PASSPHRASE="dev-test-passphrase-2024"
pulumi preview
```

## For Service Principal (GitHub Actions)

Your service principal already has the correct permissions if it's assigned "Contributor" role. The GitHub Actions workflow should work without issues.

To verify:

```bash
# Check service principal permissions
az role assignment list \
  --assignee 2f54ef99-beb9-4473-b696-6639d40dd76e \
  --all \
  --output table
```

## Recommended Approach

**For your personal account (local development):**

- Use **Option 2** (Resource Group level Contributor) - provides full access to manage all resources in the dev environment

**For CI/CD (GitHub Actions):**

- Service principal should have **Contributor** at subscription or resource group level
- This is already configured in your setup

## Verification

After assigning permissions, verify with:

```bash
# Test ACR credentials
az acr credential show \
  --name opsstellardevacr \
  --resource-group opsstellar-dev-rg

# Test AKS credentials
az aks get-credentials \
  --name opsstellar-dev-aks990bcc12 \
  --resource-group opsstellar-dev-rg \
  --overwrite-existing

# If both work, Pulumi will work too
cd /mnt/d/2GitHub/azure-infrastructure
export PULUMI_CONFIG_PASSPHRASE="dev-test-passphrase-2024"
pulumi preview
```

## Summary

**Quickest fix (recommended):**

```bash
# Assign Contributor role at Resource Group level
YOUR_USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)
az role assignment create \
  --assignee $YOUR_USER_OBJECT_ID \
  --role "Contributor" \
  --scope /subscriptions/459e1e2d-bfc3-4a33-b475-5c1923557262/resourceGroups/opsstellar-dev-rg

# Wait 1-2 minutes for permissions to propagate
# Then test
az login --scope https://management.azure.com/.default
pulumi preview
```
