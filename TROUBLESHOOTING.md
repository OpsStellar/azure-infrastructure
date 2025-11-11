# Azure Service Principal Troubleshooting Guide

## Error: "No subscriptions found"

This error typically occurs when:

### 1. Service Principal doesn't have subscription access

**Solution**: Assign the service principal to the subscription with appropriate role:

```bash
# List available subscriptions
az account list --output table

# Set the subscription
az account set --subscription "<your-subscription-id>"

# Assign Contributor role to the service principal
az role assignment create \
    --assignee "<your-client-id>" \
    --role "Contributor" \
    --scope "/subscriptions/<your-subscription-id>"

# Verify the assignment
az role assignment list --assignee "<your-client-id>" --output table
```

### 2. Incorrect Client ID or Secret

**Solution**: Verify your service principal credentials:

```bash
# Test login locally
az login --service-principal \
    --username "<your-client-id>" \
    --password "<your-client-secret>" \
    --tenant "<your-tenant-id>"
```

### 3. Service Principal not found or expired

**Solution**: Check if the service principal exists:

```bash
# Check if service principal exists
az ad sp show --id "<your-client-id>"

# If it doesn't exist, create a new one
az ad sp create-for-rbac \
    --name "OpsStellar-Azure-Infrastructure" \
    --role "Contributor" \
    --scopes "/subscriptions/<your-subscription-id>" \
    --sdk-auth
```

### 4. GitHub Secrets Configuration

Ensure you have set these secrets in your GitHub repository:

**Repository Secrets** (Settings > Secrets and variables > Actions):
- `ARM_CLIENT_ID`: Your service principal's application (client) ID
- `ARM_CLIENT_SECRET`: Your service principal's client secret
- `ARM_SUBSCRIPTION_ID`: Your Azure subscription ID
- `ARM_TENANT_ID`: Your Azure tenant ID

**Environment Secrets** (if using environment protection):
- Go to Settings > Environments
- Select/create the `dev` environment
- Add the same secrets there

### 5. Service Principal Permissions

Your service principal needs these minimum permissions:

1. **Subscription Level**: Contributor role
2. **Resource Group**: Contributor (if pre-existing resource groups)
3. **Azure AD**: User.Read (for basic operations)

```bash
# Check current permissions
az role assignment list --assignee "<your-client-id>" --output table

# Add additional permissions if needed
az role assignment create \
    --assignee "<your-client-id>" \
    --role "User Access Administrator" \
    --scope "/subscriptions/<your-subscription-id>"
```

### 6. Testing the Complete Flow

Use the provided `verify-azure-setup.sh` script:

```bash
# Set environment variables
export ARM_CLIENT_ID="<your-client-id>"
export ARM_CLIENT_SECRET="<your-client-secret>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
export ARM_TENANT_ID="<your-tenant-id>"

# Run verification script
./verify-azure-setup.sh
```

### 7. Workflow-Specific Issues

If the issue persists in GitHub Actions:

1. **Check environment configuration**: Ensure the `dev` environment exists and has the secrets
2. **Verify secret names**: They must match exactly (case-sensitive)
3. **Check repository permissions**: Ensure Actions can access secrets
4. **Review workflow syntax**: Ensure proper YAML structure

### 8. Common Azure CLI Commands for Debugging

```bash
# Login and test
az login --service-principal --username $ARM_CLIENT_ID --password $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

# Check current account
az account show

# List all subscriptions accessible to the service principal
az account list

# Set specific subscription
az account set --subscription $ARM_SUBSCRIPTION_ID

# Check resource groups (test permissions)
az group list

# Check role assignments
az role assignment list --assignee $ARM_CLIENT_ID
```

### 9. Creating a New Service Principal

If you need to create a fresh service principal:

```bash
# Create service principal with SDK output (useful for GitHub secrets)
az ad sp create-for-rbac \
    --name "OpsStellar-Infrastructure-SP" \
    --role "Contributor" \
    --scopes "/subscriptions/<your-subscription-id>" \
    --sdk-auth

# The output will look like:
# {
#   "clientId": "xxx",
#   "clientSecret": "xxx", 
#   "subscriptionId": "xxx",
#   "tenantId": "xxx"
# }
```

Copy these values to your GitHub secrets.

## Next Steps

1. Run `./verify-azure-setup.sh` locally first
2. Ensure all tests pass locally
3. Update GitHub secrets with verified values
4. Re-run the GitHub Actions workflow
5. Check the new debug output in the workflow logs