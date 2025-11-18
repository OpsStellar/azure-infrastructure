#!/bin/bash
# Setup environment variables for Pulumi Azure backend
# Usage: source scripts/setup-env.sh

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load .env file
if [ ! -f "$PROJECT_ROOT/.env" ]; then
    echo "❌ ERROR: .env file not found!"
    echo ""
    echo "Create it from the template:"
    echo "  cp .env.example .env"
    echo "  nano .env  # Fill in your credentials"
    echo ""
    return 1
fi

# Source .env file
set -a
source "$PROJECT_ROOT/.env"
set +a

echo "✅ Environment variables loaded from .env"

# Fetch Azure Storage Key if not set
if [ -z "$AZURE_STORAGE_KEY" ] && [ -n "$AZURE_STORAGE_ACCOUNT" ]; then
    echo "Fetching Azure Storage key..."
    if command -v az &> /dev/null; then
        AZURE_STORAGE_KEY=$(az storage account keys list \
            --account-name "$AZURE_STORAGE_ACCOUNT" \
            --resource-group pulumi-state-rg \
            --query '[0].value' -o tsv 2>/dev/null)
        if [ -n "$AZURE_STORAGE_KEY" ]; then
            export AZURE_STORAGE_KEY
            echo "✅ AZURE_STORAGE_KEY fetched from Azure"
        else
            echo "⚠️  Failed to fetch AZURE_STORAGE_KEY. Set it manually in .env"
        fi
    else
        echo "⚠️  Azure CLI not found. Set AZURE_STORAGE_KEY manually in .env"
    fi
fi

# Add Pulumi to PATH
if [ -d "$HOME/.pulumi/bin" ]; then
    export PATH="$HOME/.pulumi/bin:$PATH"
fi

# Verify required variables
MISSING=""
[ -z "$ARM_CLIENT_ID" ] && MISSING="$MISSING ARM_CLIENT_ID"
[ -z "$ARM_CLIENT_SECRET" ] && MISSING="$MISSING ARM_CLIENT_SECRET"
[ -z "$ARM_TENANT_ID" ] && MISSING="$MISSING ARM_TENANT_ID"
[ -z "$ARM_SUBSCRIPTION_ID" ] && MISSING="$MISSING ARM_SUBSCRIPTION_ID"
[ -z "$AZURE_STORAGE_ACCOUNT" ] && MISSING="$MISSING AZURE_STORAGE_ACCOUNT"
[ -z "$PULUMI_CONFIG_PASSPHRASE" ] && MISSING="$MISSING PULUMI_CONFIG_PASSPHRASE"

if [ -n "$MISSING" ]; then
    echo "❌ ERROR: Missing required variables:$MISSING"
    echo "   Edit .env and set these values"
    return 1
fi

echo "✅ All required variables set"
echo "   Storage Account: $AZURE_STORAGE_ACCOUNT"
