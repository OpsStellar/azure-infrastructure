#!/bin/bash

# Script to verify Azure service principal setup
# Run this locally to ensure your service principal has proper access

set -e

echo "🔍 Verifying Azure Service Principal Setup..."
echo "=============================================="

# Check if required environment variables are set
echo "📋 Checking environment variables..."
if [ -z "$ARM_CLIENT_ID" ]; then
    echo "❌ ARM_CLIENT_ID is not set"
    echo "   Run: export ARM_CLIENT_ID=<your-client-id>"
    exit 1
fi

if [ -z "$ARM_CLIENT_SECRET" ]; then
    echo "❌ ARM_CLIENT_SECRET is not set"
    echo "   Run: export ARM_CLIENT_SECRET=<your-client-secret>"
    exit 1
fi

if [ -z "$ARM_SUBSCRIPTION_ID" ]; then
    echo "❌ ARM_SUBSCRIPTION_ID is not set"
    echo "   Run: export ARM_SUBSCRIPTION_ID=<your-subscription-id>"
    exit 1
fi

if [ -z "$ARM_TENANT_ID" ]; then
    echo "❌ ARM_TENANT_ID is not set"
    echo "   Run: export ARM_TENANT_ID=<your-tenant-id>"
    exit 1
fi

echo "✅ All environment variables are set"
echo "   Client ID: $ARM_CLIENT_ID"
echo "   Subscription ID: $ARM_SUBSCRIPTION_ID"
echo "   Tenant ID: $ARM_TENANT_ID"

echo ""
echo "🔐 Testing Azure login with service principal..."

# Login using service principal
az login --service-principal \
    --username "$ARM_CLIENT_ID" \
    --password "$ARM_CLIENT_SECRET" \
    --tenant "$ARM_TENANT_ID"

echo ""
echo "📊 Checking account information..."
az account show --output table

echo ""
echo "📝 Listing available subscriptions..."
az account list --output table

echo ""
echo "🔑 Checking role assignments for service principal..."
az role assignment list --assignee "$ARM_CLIENT_ID" --output table

echo ""
echo "🎯 Setting default subscription..."
az account set --subscription "$ARM_SUBSCRIPTION_ID"

echo ""
echo "✅ Azure setup verification complete!"
echo ""
echo "📌 Next steps for GitHub Secrets:"
echo "   1. Go to your GitHub repository"
echo "   2. Navigate to Settings > Secrets and variables > Actions"
echo "   3. Add these repository secrets:"
echo "      - ARM_CLIENT_ID: $ARM_CLIENT_ID"
echo "      - ARM_CLIENT_SECRET: [your-client-secret]"
echo "      - ARM_SUBSCRIPTION_ID: $ARM_SUBSCRIPTION_ID"
echo "      - ARM_TENANT_ID: $ARM_TENANT_ID"
echo ""
echo "📌 For environment-specific secrets:"
echo "   1. Go to Settings > Environments"
echo "   2. Create/edit the 'dev' environment"
echo "   3. Add the same secrets there if using environment protection rules"