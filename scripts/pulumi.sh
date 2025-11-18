#!/bin/bash
# Pulumi deployment script
# Usage: ./scripts/pulumi.sh [up|destroy] [environment]
# Example: ./scripts/pulumi.sh up dev

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ACTION=${1:-up}
ENVIRONMENT=${2:-dev}

# Validate action
case "$ACTION" in
    up|destroy)
        ;;
    *)
        echo "Usage: $0 [up|destroy] [environment]"
        echo ""
        echo "Actions:"
        echo "  up       - Preview and deploy infrastructure (default)"
        echo "  destroy  - Destroy infrastructure"
        echo ""
        echo "Environments: dev, staging, production (default: dev)"
        echo ""
        echo "Examples:"
        echo "  $0              # Preview and deploy to dev"
        echo "  $0 up staging   # Preview and deploy to staging"
        echo "  $0 destroy dev  # Destroy dev environment"
        exit 1
        ;;
esac

echo "=========================================="
echo "Pulumi Infrastructure Deployment"
echo "Action: $ACTION"
echo "Environment: $ENVIRONMENT"
echo "=========================================="
echo ""

# Load environment variables
echo "Loading environment variables..."
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ ERROR: .env file not found!"
    echo "   Create it: cp .env.example .env"
    exit 1
fi

set -a
source "$PROJECT_ROOT/.env"
set +a
echo "✅ Environment variables loaded"

# Fetch storage key if not set
if [ -z "$AZURE_STORAGE_KEY" ]; then
    if command -v az &> /dev/null; then
        echo "Fetching Azure Storage key..."
        AZURE_STORAGE_KEY=$(az storage account keys list \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --resource-group pulumi-state-rg \
            --query '[0].value' -o tsv 2>/dev/null)
        if [ -n "$AZURE_STORAGE_KEY" ]; then
            export AZURE_STORAGE_KEY
            echo "✅ Azure Storage key fetched"
        fi
    fi
fi

# Verify credentials
MISSING=""
[ -z "$ARM_CLIENT_ID" ] && MISSING="$MISSING ARM_CLIENT_ID"
[ -z "$ARM_CLIENT_SECRET" ] && MISSING="$MISSING ARM_CLIENT_SECRET"
[ -z "$ARM_TENANT_ID" ] && MISSING="$MISSING ARM_TENANT_ID"
[ -z "$ARM_SUBSCRIPTION_ID" ] && MISSING="$MISSING ARM_SUBSCRIPTION_ID"
[ -z "$AZURE_STORAGE_ACCOUNT" ] && MISSING="$MISSING AZURE_STORAGE_ACCOUNT"
[ -z "$PULUMI_CONFIG_PASSPHRASE" ] && MISSING="$MISSING PULUMI_CONFIG_PASSPHRASE"

if [ -n "$MISSING" ]; then
    echo "❌ ERROR: Missing required variables in .env:$MISSING"
    exit 1
fi

if [ -z "$AZURE_STORAGE_KEY" ]; then
    echo "❌ ERROR: AZURE_STORAGE_KEY not set. Add it to .env or ensure Azure CLI is configured"
    exit 1
fi

echo "✅ All required credentials verified"
echo ""

# Add Pulumi to PATH
if [ -d "$HOME/.pulumi/bin" ]; then
    export PATH="$HOME/.pulumi/bin:$PATH"
fi

# Navigate to project root
cd "$PROJECT_ROOT"

# Check virtual environment
if [ -d "venv" ] && [ -z "$VIRTUAL_ENV" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
fi

# Verify Pulumi is available
if ! command -v pulumi &> /dev/null; then
    echo "❌ ERROR: Pulumi not found. Run: ./scripts/setup-venv.sh"
    exit 1
fi

# Login to Pulumi backend
echo "Logging into Pulumi backend..."
pulumi login azblob://pulumi-state
echo "✅ Logged in to Pulumi backend"
echo ""

# Select or create stack
echo "Selecting stack: $ENVIRONMENT"
pulumi stack select $ENVIRONMENT 2>/dev/null || pulumi stack init $ENVIRONMENT
echo ""

# Execute action
case "$ACTION" in
    up)
        echo "=========================================="
        echo "Step 1: Preview Changes"
        echo "=========================================="
        pulumi preview --diff
        
        echo ""
        echo "=========================================="
        echo "Step 2: Deploy Infrastructure"
        echo "=========================================="
        read -p "Continue with deployment? (y/N): " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
            pulumi up --yes
            echo ""
            echo "=========================================="
            echo "✅ Deployment Complete!"
            echo "=========================================="
            pulumi stack output
        else
            echo "Deployment cancelled."
            exit 0
        fi
        ;;
    destroy)
        echo "=========================================="
        echo "⚠️  WARNING: Destroying Infrastructure"
        echo "=========================================="
        echo "This will permanently delete all resources in: $ENVIRONMENT"
        echo ""
        read -p "Type 'destroy' to confirm: " CONFIRM
        if [ "$CONFIRM" == "destroy" ]; then
            pulumi destroy --yes
            echo ""
            echo "=========================================="
            echo "✅ Resources Destroyed"
            echo "=========================================="
        else
            echo "Cancelled."
            exit 0
        fi
        ;;
esac

echo ""
