# Azure Infrastructure - Pulumi

Cost-effective Azure infrastructure for OpsVerse SaaS using Pulumi IaC.

## 📊 Cost Summary

**Budget**: $1000 for 6 months (~$166/month)

**Estimated Monthly Cost**: $88-104

| Service | Cost/Month |
|---------|------------|
| Container Apps (5 services) | $35-45 |
| PostgreSQL Flexible Server | $25 |
| Redis Cache (Basic C0) | $16.80 |
| Container Registry (Basic) | $5 |
| Key Vault | $0.50 |
| Networking & Storage | $5-12 |

**Total 6-month cost**: ~$528-624 (well within budget!)

## 🏗️ Architecture

```
Azure Container Apps Environment
├── Frontend (nginx)
├── Auth Service (FastAPI)
├── Jenkins Dashboard (FastAPI)
├── Chatbot Backend (FastAPI)
└── Audit Logs Service (FastAPI)

Azure Database for PostgreSQL (Flexible)
├── auth_service
├── audit_logs
└── opsverse

Azure Cache for Redis (Basic C0)
├── Session management
└── Caching

Azure Container Registry
└── Docker images

Azure Key Vault
└── Secrets & credentials
```

## 🚀 Quick Start

### Prerequisites

```bash
# Install tools
- Azure CLI: https://aka.ms/az-cli
- Pulumi CLI: https://www.pulumi.com/docs/install/
- Python 3.11+

# Login
az login
pulumi login
```

### Deploy Infrastructure

```bash
# 1. Setup environment
cd azure-infrastructure
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# 2. Initialize stack
pulumi stack init production

# 3. Configure
pulumi config set azure-native:location eastus
pulumi config set environment production
pulumi config set --secret postgres_password "YourStrongPassword123!"
pulumi config set --secret jwt_secret_key "your-jwt-secret-key"

# 4. Preview changes
pulumi preview

# 5. Deploy
pulumi up
```

### Get Service URLs

```bash
pulumi stack output frontend_url
pulumi stack output auth_service_url
pulumi stack output jenkins_dashboard_url
```

## 📁 Project Structure

```
azure-infrastructure/
├── __main__.py          # Main Pulumi program
├── Pulumi.yaml          # Project configuration
├── requirements.txt     # Python dependencies
├── .gitignore          # Git ignore file
└── README.md           # This file
```

## 🔐 Required Secrets

Configure these secrets using Pulumi config:

```bash
# Required
pulumi config set --secret postgres_password "StrongPassword123!"
pulumi config set --secret jwt_secret_key "your-secret-jwt-key"

# Optional (for Jenkins integration)
pulumi config set jenkins_url "https://jenkins.example.com"
pulumi config set jenkins_username "your-username"
pulumi config set --secret jenkins_api_token "your-api-token"

# Optional (for Azure AD OAuth)
pulumi config set azure_ad_tenant_id "tenant-id"
pulumi config set azure_ad_client_id "client-id"
pulumi config set --secret azure_ad_client_secret "client-secret"
```

## 📤 Deploy Services

### Build and push Docker images:

```bash
# Login to ACR
ACR_SERVER=$(pulumi stack output acr_login_server)
az acr login --name opserseproductionacr

# Tag and push
docker tag opsverse-saas-frontend $ACR_SERVER/opsverse-frontend:latest
docker push $ACR_SERVER/opsverse-frontend:latest

docker tag opsverse-saas-auth-service $ACR_SERVER/opsverse-auth-service:latest
docker push $ACR_SERVER/opsverse-auth-service:latest

docker tag opsverse-saas-jenkins-dashboard $ACR_SERVER/opsverse-jenkins-dashboard:latest
docker push $ACR_SERVER/opsverse-jenkins-dashboard:latest

# Update container apps
pulumi up --yes
```

## 🧪 Testing

### Test Auth Service:

```bash
AUTH_URL=$(pulumi stack output auth_service_url)

# Health check
curl $AUTH_URL/healthz

# Register user
curl -X POST $AUTH_URL/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","username":"testuser","password":"Test123!","full_name":"Test User"}'

# Login
curl -X POST $AUTH_URL/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"Test123!"}'
```

## 💰 Cost Optimization

### Stop resources when not needed:

```bash
# Stop PostgreSQL (saves ~$25/month when stopped)
az postgres flexible-server stop \
  --resource-group opsverse-production-rg \
  --name opsverse-production-postgres

# Start when needed
az postgres flexible-server start \
  --resource-group opsverse-production-rg \
  --name opsverse-production-postgres

# Scale Container Apps to 0
az containerapp update \
  --name opsverse-production-frontend \
  --resource-group opsverse-production-rg \
  --min-replicas 0
```

### Monitor costs:

```bash
# View current month costs
az consumption usage list \
  --start-date $(date -u +%Y-%m-01) \
  --end-date $(date -u +%Y-%m-%d) \
  --output table

# Set budget alert
az consumption budget create \
  --budget-name opsverse-budget \
  --amount 166 \
  --time-grain Monthly
```

## 🔄 CI/CD with GitHub Actions

GitHub Actions workflow automatically:
1. Provisions infrastructure with Pulumi
2. Builds Docker images
3. Pushes to Azure Container Registry
4. Deploys to Container Apps
5. Runs health checks

### Setup GitHub Secrets:

```
AZURE_CREDENTIALS          # Service principal JSON
PULUMI_ACCESS_TOKEN        # Pulumi access token
PULUMI_CONFIG_PASSPHRASE   # Pulumi encryption password
POSTGRES_PASSWORD          # Database password
JWT_SECRET_KEY             # JWT secret
JENKINS_API_TOKEN          # Jenkins token (optional)
```

## 🗑️ Cleanup

```bash
# Destroy all resources
pulumi destroy

# Delete stack
pulumi stack rm production
```

## 📚 Documentation

- [Complete Deployment Guide](../docs/AZURE_DEPLOYMENT_GUIDE.md)
- [Cost Estimation](../docs/AZURE_COST_ESTIMATION.md)
- [Pulumi Docs](https://www.pulumi.com/docs/)
- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)

## 🆘 Troubleshooting

### Container App not starting:

```bash
az containerapp logs show \
  --name opsverse-production-auth-service \
  --resource-group opsverse-production-rg \
  --follow
```

### Database connection issues:

```bash
az postgres flexible-server show \
  --resource-group opsverse-production-rg \
  --name opsverse-production-postgres
```

### Pulumi state issues:

```bash
pulumi refresh
pulumi stack export > backup.json
```

## 📞 Support

- GitHub Issues: [Create an issue](https://github.com/samadhanpatil4067/opsverse-saas/issues)
- Pulumi Community: https://slack.pulumi.com/
- Azure Support: https://azure.microsoft.com/support/

---

**Cost-effective. Production-ready. Easy to maintain.**
