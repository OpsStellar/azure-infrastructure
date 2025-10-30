#!/bin/bash
# Quick Setup Script for Azure Deployment

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║   OpsVerse SaaS - Azure Deployment Setup                 ║"
echo "║   Budget: $1000 for 6 months (~$88-104/month)           ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI not found${NC}"
    echo "Install from: https://aka.ms/az-cli"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI installed${NC}"

# Check Pulumi CLI
if ! command -v pulumi &> /dev/null; then
    echo -e "${RED}❌ Pulumi CLI not found${NC}"
    echo "Install from: https://www.pulumi.com/docs/install/"
    exit 1
fi
echo -e "${GREEN}✅ Pulumi CLI installed${NC}"

# Check Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}❌ Python 3 not found${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Python 3 installed${NC}"

echo ""

# Azure Login
echo "🔐 Azure Login..."
if ! az account show &> /dev/null; then
    echo "Please login to Azure:"
    az login
else
    ACCOUNT=$(az account show --query name -o tsv)
    echo -e "${GREEN}✅ Already logged in to: $ACCOUNT${NC}"
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo "Using subscription: $SUBSCRIPTION_ID"
echo ""

# Pulumi Login
echo "🔐 Pulumi Login..."
if ! pulumi whoami &> /dev/null; then
    echo "Please login to Pulumi:"
    pulumi login
else
    PULUMI_USER=$(pulumi whoami)
    echo -e "${GREEN}✅ Logged in as: $PULUMI_USER${NC}"
fi
echo ""

# Setup virtual environment
echo "🐍 Setting up Python virtual environment..."
cd azure-infrastructure

if [ ! -d "venv" ]; then
    python3 -m venv venv
    echo -e "${GREEN}✅ Virtual environment created${NC}"
else
    echo -e "${YELLOW}⚠️  Virtual environment already exists${NC}"
fi

# Activate virtual environment
source venv/bin/activate 2>/dev/null || . venv/Scripts/activate 2>/dev/null

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Initialize or select stack
echo "📚 Pulumi Stack Setup..."
STACK_NAME="production"

if pulumi stack ls 2>/dev/null | grep -q "$STACK_NAME"; then
    echo -e "${YELLOW}⚠️  Stack '$STACK_NAME' already exists${NC}"
    pulumi stack select $STACK_NAME
else
    pulumi stack init $STACK_NAME
    echo -e "${GREEN}✅ Stack '$STACK_NAME' created${NC}"
fi
echo ""

# Configuration
echo "⚙️  Configuration Setup..."
echo ""

# Set Azure location
read -p "Azure Region [eastus]: " AZURE_REGION
AZURE_REGION=${AZURE_REGION:-eastus}
pulumi config set azure-native:location $AZURE_REGION
echo -e "${GREEN}✅ Region set to: $AZURE_REGION${NC}"

# Set environment
pulumi config set environment production
echo -e "${GREEN}✅ Environment set to: production${NC}"

# PostgreSQL Password
echo ""
echo "🔒 Setting up secrets..."
read -sp "PostgreSQL admin password (min 8 chars, mixed case, numbers): " POSTGRES_PASSWORD
echo ""
if [ -z "$POSTGRES_PASSWORD" ]; then
    POSTGRES_PASSWORD="OpsVerse2024!Strong"
    echo -e "${YELLOW}⚠️  Using default password (CHANGE IN PRODUCTION!)${NC}"
fi
pulumi config set --secret postgres_password "$POSTGRES_PASSWORD"
echo -e "${GREEN}✅ PostgreSQL password configured${NC}"

# JWT Secret
JWT_SECRET=$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64)
pulumi config set --secret jwt_secret_key "$JWT_SECRET"
echo -e "${GREEN}✅ JWT secret key generated${NC}"

# Optional Jenkins config
echo ""
read -p "Configure Jenkins integration? (y/N): " CONFIGURE_JENKINS
if [[ "$CONFIGURE_JENKINS" =~ ^[Yy]$ ]]; then
    read -p "Jenkins URL: " JENKINS_URL
    read -p "Jenkins Username: " JENKINS_USERNAME
    read -sp "Jenkins API Token: " JENKINS_TOKEN
    echo ""
    
    pulumi config set jenkins_url "$JENKINS_URL"
    pulumi config set jenkins_username "$JENKINS_USERNAME"
    pulumi config set --secret jenkins_api_token "$JENKINS_TOKEN"
    echo -e "${GREEN}✅ Jenkins configuration set${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "🎉 Setup Complete!"
echo ""
echo "Next steps:"
echo ""
echo "1️⃣  Preview infrastructure:"
echo "   ${GREEN}pulumi preview${NC}"
echo ""
echo "2️⃣  Deploy infrastructure (10-15 minutes):"
echo "   ${GREEN}pulumi up${NC}"
echo ""
echo "3️⃣  Get service URLs:"
echo "   ${GREEN}pulumi stack output frontend_url${NC}"
echo "   ${GREEN}pulumi stack output auth_service_url${NC}"
echo ""
echo "4️⃣  Build and push Docker images:"
echo "   ${GREEN}../scripts/build-and-push.sh${NC}"
echo ""
echo "5️⃣  Test auth service:"
echo "   ${GREEN}curl \$(pulumi stack output auth_service_url)/healthz${NC}"
echo ""
echo "📖 Full documentation: ../docs/AZURE_DEPLOYMENT_GUIDE.md"
echo ""
echo "💰 Estimated monthly cost: $88-104"
echo "💰 6-month total: $528-624 (within $1000 budget!)"
echo ""
echo "═══════════════════════════════════════════════════════════"
