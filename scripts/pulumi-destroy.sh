#!/bin/bash
set -e

# Add Pulumi to PATH if installed
if [ -d "$HOME/.pulumi/bin" ]; then
    export PATH="$HOME/.pulumi/bin:$PATH"
fi

# Pulumi infrastructure destruction script
# Usage: ./scripts/pulumi-destroy.sh [environment]
# Example: ./scripts/pulumi-destroy.sh dev

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Pulumi Infrastructure Destruction"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo "⚠️  WARNING: This will destroy all infrastructure in the $ENVIRONMENT environment!"
echo ""

# Check if required environment variables are set
echo "Checking Azure credentials..."
if [ -z "$ARM_CLIENT_ID" ]; then
    echo "❌ ERROR: ARM_CLIENT_ID environment variable is not set"
    exit 1
fi
if [ -z "$ARM_CLIENT_SECRET" ]; then
    echo "❌ ERROR: ARM_CLIENT_SECRET environment variable is not set"
    exit 1
fi
if [ -z "$ARM_TENANT_ID" ]; then
    echo "❌ ERROR: ARM_TENANT_ID environment variable is not set"
    exit 1
fi
if [ -z "$ARM_SUBSCRIPTION_ID" ]; then
    echo "❌ ERROR: ARM_SUBSCRIPTION_ID environment variable is not set"
    exit 1
fi
echo "✅ Azure credentials are set"

# Check if PULUMI_CONFIG_PASSPHRASE is set
if [ -z "$PULUMI_CONFIG_PASSPHRASE" ]; then
    echo "⚠️  WARNING: PULUMI_CONFIG_PASSPHRASE is not set. If your stack has secrets, this will fail."
    echo "   Set it with: export PULUMI_CONFIG_PASSPHRASE='your-passphrase'"
fi

# Navigate to project root
cd "$PROJECT_ROOT"

# Check if Python dependencies are installed
echo "Checking Python dependencies..."
if ! python -c "import pulumi" 2>/dev/null; then
    echo "Installing Python dependencies..."
    pip install -r requirements.txt
else
    echo "✅ Pulumi SDK is installed"
fi

# Login to Pulumi (uses Azure blob storage backend)
echo "Logging into Pulumi Azure backend..."
if [ -z "$AZURE_STORAGE_ACCOUNT" ]; then
    echo "❌ ERROR: AZURE_STORAGE_ACCOUNT environment variable is not set"
    echo "   Set it with: export AZURE_STORAGE_ACCOUNT=pulumistate3033355"
    exit 1
fi

if [ -z "$AZURE_STORAGE_KEY" ]; then
    echo "Fetching storage account key..."
    export AZURE_STORAGE_KEY=$(az storage account keys list --account-name $AZURE_STORAGE_ACCOUNT --resource-group pulumi-state-rg --query '[0].value' -o tsv)
fi

pulumi login azblob://pulumi-state

# Select stack
echo "Selecting stack: $ENVIRONMENT"
if ! pulumi stack select $ENVIRONMENT; then
    echo "❌ ERROR: Stack '$ENVIRONMENT' does not exist"
    exit 1
fi

# Show current resources
echo ""
echo "=========================================="
echo "Current resources in stack:"
echo "=========================================="
pulumi stack --show-urns

# Preview destruction
echo ""
echo "=========================================="
echo "Preview - showing resources to be destroyed"
echo "=========================================="
pulumi preview --diff

# Prompt for confirmation
echo ""
echo "⚠️  ⚠️  ⚠️  WARNING ⚠️  ⚠️  ⚠️"
echo "This will PERMANENTLY DELETE all resources in the $ENVIRONMENT environment!"
echo ""
read -p "Type 'destroy-$ENVIRONMENT' to confirm destruction: " CONFIRM
if [ "$CONFIRM" != "destroy-$ENVIRONMENT" ]; then
    echo "Destruction cancelled."
    exit 0
fi

# Destroy infrastructure
echo ""
echo "=========================================="
echo "Destroying infrastructure..."
echo "=========================================="
pulumi destroy --yes

# Ask if user wants to remove the stack
echo ""
read -p "Do you want to remove the stack '$ENVIRONMENT' as well? (yes/no): " REMOVE_STACK
if [ "$REMOVE_STACK" = "yes" ]; then
    pulumi stack rm $ENVIRONMENT --yes
    echo "✅ Stack removed"
fi

echo ""
echo "✅ Destruction completed successfully!"
