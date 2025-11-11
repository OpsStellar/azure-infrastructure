# Azure Infrastructure - IaC Structure

Clean and organized Infrastructure as Code using Pulumi for Azure AK5. **Initialize or select stack**:

```bash
pulumi stack select dev || pulumi stack init dev
```

6. **Preview changes**:yment.

## 📁 Project Structure

```
azure-infrastructure/
├── infrastructure/          # Pulumi infrastructure code
│   ├── __main__.py         # Main infrastructure definition (AKS)
│   └── __main_aks.py       # Alternative AKS configuration
├── .github/
│   └── workflows/
│       └── provision-infrastructure.yml  # CI/CD workflow
├── Pulumi.yaml             # Main Pulumi project configuration
├── Pulumi.dev.yaml         # Development environment config
├── Pulumi.staging.yaml     # Staging environment config
├── Pulumi.production.yaml  # Production environment config
├── requirements.txt        # Python dependencies
└── README-STRUCTURE.md     # This file
```

## 🚀 Infrastructure Components

### Resources Created

- **Resource Group** - Container for all Azure resources
- **Azure Container Registry (ACR)** - Docker image registry
- **Virtual Network** - Network isolation for resources
- **AKS Subnet** - Dedicated subnet for Kubernetes nodes
- **Azure Kubernetes Service (AKS)** - Managed Kubernetes cluster
  - Auto-scaling enabled
  - Azure CNI networking
  - System-assigned managed identity
- **Role Assignment** - ACR pull permissions for AKS

### No Monitoring Resources

- Log Analytics workspace removed (not included for cost optimization)
- Container Insights disabled

## ⚙️ Configuration

All configuration is managed through environment-specific YAML files in the `var/` folder:

### Development (`var/Pulumi.dev.yaml`)

- Location: `eastus`
- Node VM Size: `Standard_B2s`
- Node Count: 2 (min: 1, max: 3)
- VNet: `10.0.0.0/16`
- ACR SKU: `Basic`

### Staging (`var/Pulumi.staging.yaml`)

- Location: `eastus`
- Node VM Size: `Standard_B2s`
- Node Count: 2 (min: 1, max: 5)
- VNet: `10.10.0.0/16`
- ACR SKU: `Standard`

### Production (`var/Pulumi.production.yaml`)

- Location: `eastus`
- Node VM Size: `Standard_D2s_v3`
- Node Count: 3 (min: 2, max: 10)
- VNet: `10.20.0.0/16`
- ACR SKU: `Standard`

## 🛠️ Local Development

### Prerequisites

- Azure CLI (`az`)
- Pulumi CLI (`pulumi`)
- Python 3.11+
- Azure subscription with permissions

### Setup

1. **Clone and setup environment**:

   ```bash
   git clone <repo-url>
   cd azure-infrastructure
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Configure Azure authentication**:

   ```bash
   az login
   ```

3. **Set Pulumi passphrase**:

   ```bash
   export PULUMI_CONFIG_PASSPHRASE="your-secure-passphrase"
   ```

4. **Login to Pulumi (local backend)**:

   ```bash
   pulumi login --local
   ```

5. **Initialize or select stack**:

   ```bash
   pulumi stack select dev || pulumi stack init dev
   ```

6. **Preview changes**:

   ```bash
   pulumi preview
   ```

7. **Deploy infrastructure**:
   ```bash
   pulumi up
   ```

### Switching Environments

To switch between environments:

```bash
# Select the desired stack (config files already at root)
pulumi stack select staging

# Preview and deploy
pulumi preview
pulumi up
```

## 🔄 CI/CD with GitHub Actions

The workflow is triggered on:

- **Push to main** - Automatic preview and deploy
- **Pull Request** - Preview only
- **Manual dispatch** - Choose environment and action

### Required GitHub Secrets

Set these in your repository settings:

```
ARM_CLIENT_ID              # Azure Service Principal Client ID
ARM_CLIENT_SECRET          # Azure Service Principal Client Secret
ARM_SUBSCRIPTION_ID        # Azure Subscription ID
ARM_TENANT_ID              # Azure Tenant ID
PULUMI_CONFIG_PASSPHRASE   # Pulumi encryption passphrase
```

### Manual Workflow Dispatch

1. Go to **Actions** → **Provision Azure Infrastructure**
2. Click **Run workflow**
3. Select:
   - **Environment**: dev, staging, or production
   - **Action**: preview, up, or destroy
4. Click **Run workflow**

## 📤 Exported Outputs

After deployment, the following outputs are available:

```bash
pulumi stack output resource_group_name
pulumi stack output acr_login_server
pulumi stack output acr_admin_username
pulumi stack output aks_cluster_name
pulumi stack output aks_cluster_fqdn
pulumi stack output vnet_id
pulumi stack output aks_subnet_id
pulumi stack output kubeconfig --show-secrets
```

### Get kubeconfig

```bash
pulumi stack output kubeconfig --show-secrets > ~/.kube/config
kubectl get nodes
```

## 🧹 Cleanup

To destroy infrastructure:

```bash
pulumi destroy
```

Or via GitHub Actions workflow with action: `destroy`.

## 📝 Modifying Infrastructure

1. Edit `infrastructure/__main__.py`
2. Test locally with `pulumi preview`
3. Commit and push to trigger CI/CD
4. Or deploy manually with `pulumi up`

## 🔧 Configuration Parameters

All parameters defined in `Pulumi.yaml` can be overridden in environment-specific config files:

- `project_name` - Project name for resource naming
- `environment` - Environment identifier
- `k8s_version` - Kubernetes version
- `node_count` - Initial node count
- `node_vm_size` - VM size for nodes
- `min_node_count` - Minimum nodes for autoscaling
- `max_node_count` - Maximum nodes for autoscaling
- `vnet_address_space` - VNet CIDR
- `aks_subnet_prefix` - AKS subnet CIDR
- `service_cidr` - Kubernetes service CIDR
- `dns_service_ip` - Kubernetes DNS IP
- `acr_sku` - ACR SKU (Basic, Standard, Premium)

## 📚 Additional Resources

- [Pulumi Azure Native Provider](https://www.pulumi.com/registry/packages/azure-native/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
- [Pulumi Configuration](https://www.pulumi.com/docs/concepts/config/)
