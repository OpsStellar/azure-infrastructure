#!/bin/bash
# Setup environment variables for Pulumi Azure backend
# Source this file: source scripts/setup-env.sh

# Azure Storage for Pulumi state
export AZURE_STORAGE_ACCOUNT=pulumistate3033355

# Fetch storage key if not already set
if [ -z "$AZURE_STORAGE_KEY" ]; then
    echo "Fetching Azure Storage key..."
    export AZURE_STORAGE_KEY=$(az storage account keys list \
        --account-name $AZURE_STORAGE_ACCOUNT \
        --resource-group pulumi-state-rg \
        --query '[0].value' -o tsv)
    echo "✅ AZURE_STORAGE_KEY set"
fi

# Add Pulumi to PATH
if [ -d "$HOME/.pulumi/bin" ]; then
    export PATH="$HOME/.pulumi/bin:$PATH"
fi

echo "✅ Environment configured for Pulumi with Azure backend"
echo "   Storage Account: $AZURE_STORAGE_ACCOUNT"
echo "   Backend URL: azblob://pulumi-state"
