#!/bin/bash
# OpsStellar Azure Deployment Script
# Usage: ./scripts/pulumi.sh [up|build|deploy|destroy|all] [environment] [tag]
# Example: ./scripts/pulumi.sh up dev
# Example: ./scripts/pulumi.sh build dev v1.0.0
# Example: ./scripts/pulumi.sh all dev

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKSPACE_ROOT="$(dirname "$PROJECT_ROOT")"

ACTION=${1:-up}
ENVIRONMENT=${2:-dev}
IMAGE_TAG=${3:-""}

# ACR configuration
ACR_NAME="opsstellardevacr"
ACR_LOGIN_SERVER="opsstellardevacr.azurecr.io"

# Service definitions (name:helm-path:priority)
SERVICES=(
    "db-service:db-service/helm:1"
    "auth-service:auth-service/helm:2"
    "apm-service:apm-service/helm:3"
    "apm-agent:apm-agent/helm:4"
    "logging-service:logging-service/helm:5"
    "metrics-collector:metrics-collector/helm:6"
    "audit-logs:audit-logs/helm:7"
    "security-service:security-service/helm:8"
    "cost-service:cost-service/helm:9"
    "dora-service:dora-service/helm:10"
    "devops-core:devops-core/helm:11"
    "release-management:release-management/helm:12"
    "settings-service:settings-service/helm:13"
    "chatbot:chatbot/helm:14"
    "microgenie:microgenie/helm:15"
    "testing-services:testing-services/helm:16"
    "frontend:frontend/helm:17"
)

# Resolve image tag: parameter > git SHA > "latest"
if [ -z "$IMAGE_TAG" ]; then
    IMAGE_TAG=$(git -C "$WORKSPACE_ROOT" rev-parse --short HEAD 2>/dev/null || echo "latest")
fi

# Validate action
case "$ACTION" in
    up|build|deploy|destroy|all)
        ;;
    *)
        echo "Usage: $0 [up|build|deploy|destroy|all] [environment] [tag]"
        echo ""
        echo "Actions:"
        echo "  up       - Preview and deploy infrastructure (default)"
        echo "  build    - Build Docker images and push to ACR"
        echo "  deploy   - Deploy all services to AKS with Helm"
        echo "  destroy  - Destroy infrastructure"
        echo "  all      - Provision, build, and deploy in sequence"
        echo ""
        echo "Environments: dev, staging, production (default: dev)"
        echo ""
        echo "Examples:"
        echo "  $0                        # Provision dev infrastructure"
        echo "  $0 up staging             # Provision staging infrastructure"
        echo "  $0 build dev              # Build all images (tag: git SHA)"
        echo "  $0 build dev v1.0.0       # Build all images with custom tag"
        echo "  $0 deploy dev             # Deploy all services to dev AKS"
        echo "  $0 all dev                # Provision + build + deploy to dev"
        echo "  $0 destroy dev            # Destroy dev environment"
        exit 1
        ;;
esac

echo "=========================================="
echo "OpsStellar Azure Deployment Script"
echo "Action:      $ACTION"
echo "Environment: $ENVIRONMENT"
echo "Image Tag:   $IMAGE_TAG"
echo "=========================================="
echo ""

# Load environment variables
load_env() {
    echo "Loading environment variables..."
    if [ ! -f "$PROJECT_ROOT/.env" ]; then
        echo "[ERROR] .env file not found!"
        echo "   Create it: cp .env.example .env"
        exit 1
    fi

    set -a
    source "$PROJECT_ROOT/.env"
    set +a
    echo "[OK] Environment variables loaded"
}

# Verify required credentials
verify_credentials() {
    MISSING=""
    [ -z "$ARM_CLIENT_ID" ] && MISSING="$MISSING ARM_CLIENT_ID"
    [ -z "$ARM_CLIENT_SECRET" ] && MISSING="$MISSING ARM_CLIENT_SECRET"
    [ -z "$ARM_TENANT_ID" ] && MISSING="$MISSING ARM_TENANT_ID"
    [ -z "$ARM_SUBSCRIPTION_ID" ] && MISSING="$MISSING ARM_SUBSCRIPTION_ID"
    [ -z "$AZURE_STORAGE_ACCOUNT" ] && MISSING="$MISSING AZURE_STORAGE_ACCOUNT"
    [ -z "$PULUMI_CONFIG_PASSPHRASE" ] && MISSING="$MISSING PULUMI_CONFIG_PASSPHRASE"

    if [ -n "$MISSING" ]; then
        echo "[ERROR] Missing required variables in .env:$MISSING"
        exit 1
    fi

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
                echo "[OK] Azure Storage key fetched"
            fi
        fi
    fi

    if [ -z "$AZURE_STORAGE_KEY" ]; then
        echo "[ERROR] AZURE_STORAGE_KEY not set. Add it to .env or ensure Azure CLI is configured"
        exit 1
    fi

    echo "[OK] All required credentials verified"
}

# Setup Pulumi environment
setup_pulumi() {
    # Add Pulumi to PATH
    if [ -d "$HOME/.pulumi/bin" ]; then
        export PATH="$HOME/.pulumi/bin:$PATH"
    fi

    cd "$PROJECT_ROOT"

    # Check virtual environment
    if [ -d "venv" ] && [ -z "$VIRTUAL_ENV" ]; then
        echo "Activating virtual environment..."
        source venv/bin/activate
    fi

    # Verify Pulumi is available
    if ! command -v pulumi &> /dev/null; then
        echo "[ERROR] Pulumi not found. Run: ./scripts/setup-venv.sh"
        exit 1
    fi

    # Login to Pulumi backend
    echo "Logging into Pulumi backend..."
    pulumi login azblob://pulumi-state
    echo "[OK] Logged in to Pulumi backend"
    echo ""

    # Select or create stack
    echo "Selecting stack: $ENVIRONMENT"
    pulumi stack select $ENVIRONMENT 2>/dev/null || pulumi stack init $ENVIRONMENT
    echo ""
}

# Provision infrastructure
do_provision() {
    load_env
    verify_credentials
    setup_pulumi

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
        echo "[OK] Deployment Complete!"
        echo "=========================================="
        pulumi stack output

        # Configure kubectl
        RG=$(pulumi stack output resource_group_name 2>/dev/null || true)
        AKS=$(pulumi stack output aks_cluster_name 2>/dev/null || true)
        if [ -n "$RG" ] && [ -n "$AKS" ]; then
            az aks get-credentials --resource-group "$RG" --name "$AKS" --overwrite-existing
            echo "[OK] kubectl configured for AKS cluster: $AKS"
        fi
    else
        echo "Deployment cancelled."
        exit 0
    fi
}

# Build Docker images and push to ACR
do_build() {
    load_env

    echo "=========================================="
    echo "Building Docker Images - Tag: $IMAGE_TAG"
    echo "=========================================="
    echo ""

    # Login to ACR
    echo "Logging into Azure Container Registry..."
    az acr login --name "$ACR_NAME" 2>/dev/null
    echo "[OK] Logged into ACR: $ACR_LOGIN_SERVER"
    echo ""

    SUCCESS=0
    FAIL=0
    BUILT_IMAGES=""

    for entry in "${SERVICES[@]}"; do
        IFS=':' read -r SVC_NAME SVC_HELM SVC_PRIORITY <<< "$entry"

        DOCKER_CONTEXT="$WORKSPACE_ROOT/$SVC_NAME"
        DOCKERFILE="$DOCKER_CONTEXT/Dockerfile"

        if [ ! -f "$DOCKERFILE" ]; then
            echo "  [WARN] No Dockerfile for $SVC_NAME - skipping"
            FAIL=$((FAIL + 1))
            continue
        fi

        IMAGE_FULL="${ACR_LOGIN_SERVER}/${SVC_NAME}:${IMAGE_TAG}"
        IMAGE_LATEST="${ACR_LOGIN_SERVER}/${SVC_NAME}:latest"

        echo "  Building: $SVC_NAME"
        echo "    Image: $IMAGE_FULL"

        if docker build -t "$IMAGE_FULL" -t "$IMAGE_LATEST" "$DOCKER_CONTEXT" > /dev/null 2>&1; then
            echo "    [OK] Built successfully"

            if docker push "$IMAGE_FULL" > /dev/null 2>&1; then
                echo "    [OK] Pushed $IMAGE_FULL"
            else
                echo "    [FAIL] Push failed for $IMAGE_FULL"
                FAIL=$((FAIL + 1))
                continue
            fi

            if docker push "$IMAGE_LATEST" > /dev/null 2>&1; then
                echo "    [OK] Pushed $IMAGE_LATEST"
            fi

            SUCCESS=$((SUCCESS + 1))
            BUILT_IMAGES="$BUILT_IMAGES $IMAGE_FULL"
        else
            echo "    [FAIL] Build failed for $SVC_NAME"
            FAIL=$((FAIL + 1))
        fi
        echo ""
    done

    echo "=========================================="
    echo "Build Summary"
    echo "  Tag:        $IMAGE_TAG"
    echo "  Registry:   $ACR_LOGIN_SERVER"
    echo "  Successful: $SUCCESS"
    echo "  Failed:     $FAIL"
    echo "=========================================="

    if [ $SUCCESS -eq 0 ] && [ $FAIL -gt 0 ]; then
        echo "[ERROR] All builds failed."
        exit 1
    fi
}

# Deploy services with Helm
do_deploy() {
    load_env

    NAMESPACE="opsstellar-$ENVIRONMENT"

    echo "=========================================="
    echo "Deploying Services to AKS - $ENVIRONMENT"
    echo "=========================================="
    echo ""

    # Verify kubectl
    echo "Verifying Kubernetes connection..."
    CONTEXT=$(kubectl config current-context 2>/dev/null || true)
    if [ -z "$CONTEXT" ]; then
        echo "[ERROR] No Kubernetes context configured."
        echo "  Run: az aks get-credentials --resource-group <rg-name> --name <aks-name>"
        exit 1
    fi
    echo "[OK] Connected to: $CONTEXT"
    kubectl get nodes
    echo ""

    # Create namespace if it doesn't exist
    if kubectl get namespace "$NAMESPACE" --ignore-not-found 2>/dev/null | grep -q "$NAMESPACE"; then
        echo "[OK] Namespace '$NAMESPACE' already exists"
    else
        kubectl create namespace "$NAMESPACE"
        echo "[OK] Namespace '$NAMESPACE' created"
    fi
    echo ""

    SUCCESS=0
    FAIL=0

    for entry in "${SERVICES[@]}"; do
        IFS=':' read -r SVC_NAME SVC_HELM SVC_PRIORITY <<< "$entry"

        HELM_PATH="$WORKSPACE_ROOT/$SVC_HELM"

        if [ ! -d "$HELM_PATH" ]; then
            echo "  [WARN] Helm chart not found for $SVC_NAME at $HELM_PATH"
            FAIL=$((FAIL + 1))
            continue
        fi

        echo "  Deploying: $SVC_NAME"

        HELM_CMD="helm upgrade --install $SVC_NAME $HELM_PATH \
            --namespace $NAMESPACE \
            --create-namespace \
            --set environment=$ENVIRONMENT \
            --set image.tag=$IMAGE_TAG \
            --set image.repository=${ACR_LOGIN_SERVER}/${SVC_NAME} \
            --wait \
            --timeout 5m"

        # Add environment-specific values file if exists
        VALUES_FILE="$HELM_PATH/values-$ENVIRONMENT.yaml"
        if [ -f "$VALUES_FILE" ]; then
            HELM_CMD="$HELM_CMD -f $VALUES_FILE"
        fi

        if eval "$HELM_CMD" > /dev/null 2>&1; then
            echo "    [OK] $SVC_NAME deployed"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "    [FAIL] $SVC_NAME failed"
            FAIL=$((FAIL + 1))
        fi
    done

    echo ""
    echo "=========================================="
    echo "Deployment Summary"
    echo "  Successful: $SUCCESS"
    echo "  Failed:     $FAIL"
    echo "=========================================="
    echo ""
    echo "Deployed services:"
    kubectl get deployments -n "$NAMESPACE" 2>/dev/null || true
    echo ""
    kubectl get services -n "$NAMESPACE" 2>/dev/null || true
}

# Destroy infrastructure
do_destroy() {
    load_env
    verify_credentials
    setup_pulumi

    echo "=========================================="
    echo "[WARNING] Destroying Infrastructure"
    echo "=========================================="
    echo "This will permanently delete all resources in: $ENVIRONMENT"
    echo ""
    read -p "Type 'destroy' to confirm: " CONFIRM
    if [ "$CONFIRM" == "destroy" ]; then
        pulumi destroy --yes
        echo ""
        echo "=========================================="
        echo "[OK] Resources Destroyed"
        echo "=========================================="
    else
        echo "Cancelled."
        exit 0
    fi
}

# Execute action
case "$ACTION" in
    up)
        do_provision
        ;;
    build)
        do_build
        ;;
    deploy)
        do_deploy
        ;;
    destroy)
        do_destroy
        ;;
    all)
        do_provision
        echo ""
        echo "Waiting 30 seconds for AKS cluster to stabilize..."
        sleep 30
        do_build
        do_deploy
        ;;
esac

echo ""
