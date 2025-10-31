# Infrastructure Structure Summary

## ✅ Completed Changes

### 1. **Folder Structure**

```
azure-infrastructure/
├── infrastructure/         # All Pulumi IaC code
│   ├── __main__.py        # Main AKS infrastructure
│   └── __main_aks.py      # Alternative configuration
├── Pulumi.yaml            # Project configuration
├── Pulumi.dev.yaml        # Dev environment config
├── Pulumi.staging.yaml    # Staging environment config
├── Pulumi.production.yaml # Production environment config
└── .github/workflows/
    └── provision-infrastructure.yml  # Simplified CI/CD
```

### 2. **Infrastructure Components** (No Monitoring)

- ✅ Resource Group
- ✅ Azure Container Registry (ACR)
- ✅ Virtual Network with dedicated AKS subnet
- ✅ Azure Kubernetes Service (AKS) with autoscaling
- ✅ ACR pull role assignment for AKS
- ❌ Log Analytics Workspace (removed)
- ❌ Container Insights (removed)

### 3. **Configuration Management**

- All parameters in stack config files at root (Pulumi.\*.yaml)
- Environment-specific network ranges
- Different VM sizes per environment
- ACR SKU varies by environment

### 4. **Simplified GitHub Actions**

- Single job for all operations
- Environment selection via dropdown
- Action selection: preview/up/destroy
- Automatic kubeconfig export
- Works from `infrastructure/` directory

## 🚀 Quick Start

### Local Testing

```bash
# Setup
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
az login

# Configure
export PULUMI_CONFIG_PASSPHRASE="your-passphrase"
pulumi login --local
pulumi stack select dev || pulumi stack init dev

# Deploy
pulumi preview
pulumi up
```

### GitHub Actions

1. Set secrets: `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `PULUMI_CONFIG_PASSPHRASE`
2. Go to Actions → Provision Azure Infrastructure → Run workflow
3. Select environment and action
4. Deploy!

## 📋 Environment Comparison

| Parameter         | Dev          | Staging      | Production      |
| ----------------- | ------------ | ------------ | --------------- |
| **VNet**          | 10.0.0.0/16  | 10.10.0.0/16 | 10.20.0.0/16    |
| **Node VM**       | Standard_B2s | Standard_B2s | Standard_D2s_v3 |
| **Initial Nodes** | 2            | 2            | 3               |
| **Min Nodes**     | 1            | 1            | 2               |
| **Max Nodes**     | 3            | 5            | 10              |
| **ACR SKU**       | Basic        | Standard     | Standard        |

## 📤 Outputs

```bash
# Get all outputs
pulumi stack output

# Get kubeconfig
pulumi stack output kubeconfig --show-secrets > ~/.kube/config

# Get ACR details
pulumi stack output acr_login_server
pulumi stack output acr_admin_username
```

## 🎯 Key Improvements

1. ✅ **Clean folder structure** - Infrastructure code separated from config
2. ✅ **Parameterized configs** - All settings in var/ folder
3. ✅ **No monitoring resources** - Cost-optimized for basic setup
4. ✅ **Simplified workflow** - One job, clear actions
5. ✅ **Environment isolation** - Separate network ranges per env
6. ✅ **Easy local testing** - Copy config and run
7. ✅ **Clear documentation** - README-STRUCTURE.md included

## 🔧 Modifying Infrastructure

1. Edit `infrastructure/__main__.py`
2. Update parameters in `var/Pulumi.<env>.yaml` if needed
3. Test locally: `pulumi preview`
4. Deploy: `pulumi up` or push to GitHub

## 📚 Documentation

- **README-STRUCTURE.md** - Detailed setup and usage guide
- **README.md** - Original project documentation
- **TROUBLESHOOTING.md** - Common issues and solutions
