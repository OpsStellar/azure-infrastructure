#!/bin/bash
set -e

# Add Pulumi to PATH if installed
if [ -d "$HOME/.pulumi/bin" ]; then
    export PATH="$HOME/.pulumi/bin:$PATH"
fi

# Pulumi deployment script
# Usage: ./scripts/pulumi-up.sh [environment]
# Example: ./scripts/pulumi-up.sh dev

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "Pulumi Infrastructure Deployment"
echo "Environment: $ENVIRONMENT"
echo "=========================================="

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

# Check if PULUMI_CONFIG_PASSPHRASE is set (optional but recommended for secrets)
if [ -z "$PULUMI_CONFIG_PASSPHRASE" ]; then
    echo "⚠️  WARNING: PULUMI_CONFIG_PASSPHRASE is not set. If your stack has secrets, this will fail."
    echo "   Set it with: export PULUMI_CONFIG_PASSPHRASE='your-passphrase'"
fi

# Navigate to project root
cd "$PROJECT_ROOT"

# Check if Python dependencies are installed
echo "Checking Python dependencies..."
if [ ! -f "requirements.txt" ]; then
    echo "⚠️  WARNING: requirements.txt not found, skipping dependency check"
else
    echo "ℹ️  Verifying Pulumi Python packages..."
    if ! python3 -c "import pulumi" 2>/dev/null; then
        echo "⚠️  WARNING: Pulumi packages not found. You may need to:"
        echo "   - Create a virtual environment: python3 -m venv venv && source venv/bin/activate"
        echo "   - Install dependencies: pip install -r requirements.txt"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        echo "✅ Python dependencies verified"
    fi
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

# Select or create stack
echo "Selecting stack: $ENVIRONMENT"
pulumi stack select $ENVIRONMENT || pulumi stack init $ENVIRONMENT

# Show current configuration
echo "Current stack configuration:"
pulumi config

# Preview changes
echo ""
echo "=========================================="
echo "Preview - showing planned changes"
echo "=========================================="
pulumi preview --diff

# Prompt for confirmation
echo ""
read -p "Do you want to apply these changes? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Deployment cancelled."
    exit 0
fi

# Deploy infrastructure
echo ""
echo "=========================================="
echo "Deploying infrastructure..."
echo "=========================================="
pulumi up --yes

# Show outputs
echo ""
echo "=========================================="
echo "Deployment complete! Outputs:"
echo "=========================================="
pulumi stack output

# Export kubeconfig if it exists
if pulumi stack output kubeconfig &>/dev/null; then
    echo ""
    echo "Exporting kubeconfig to ./kubeconfig-$ENVIRONMENT.yaml"
    pulumi stack output kubeconfig --show-secrets > "./kubeconfig-$ENVIRONMENT.yaml"
    echo "✅ Kubeconfig exported successfully"
    echo "   Use with: export KUBECONFIG=./kubeconfig-$ENVIRONMENT.yaml"
fi

echo ""
echo "✅ Deployment completed successfully!"
