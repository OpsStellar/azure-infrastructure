# k3s DevOps Platform — Single-Node Kubernetes on Azure

Production-grade, lightweight Kubernetes environment for running up to **50 microservices** on a single Azure VM, pulling images from Azure Container Registry (ACR).

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                     Azure Cloud (Resource Group)                    │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │              Azure VM — Standard_B4ms                         │  │
│  │              Ubuntu 22.04 LTS                                 │  │
│  │              4 vCPU │ 15 GB RAM │ 128 GB SSD                  │  │
│  │                                                               │  │
│  │  ┌─────────────────────────────────────────────────────────┐  │  │
│  │  │                   Docker CE Runtime                     │  │  │
│  │  │                                                         │  │  │
│  │  │  ┌───────────────────────────────────────────────────┐  │  │  │
│  │  │  │              k3s Kubernetes (v1.29)               │  │  │  │
│  │  │  │              Single-Node Control Plane            │  │  │  │
│  │  │  │                                                   │  │  │  │
│  │  │  │  ┌─────────────┐  ┌────────────────────────────┐ │  │  │  │
│  │  │  │  │ kube-system │  │   ingress-nginx            │ │  │  │  │
│  │  │  │  │             │  │   (NGINX Ingress)          │ │  │  │  │
│  │  │  │  │ • CoreDNS   │  │   :80 / :443 → Services   │ │  │  │  │
│  │  │  │  │ • metrics   │  └────────────────────────────┘ │  │  │  │
│  │  │  │  │   -server   │                                 │  │  │  │
│  │  │  │  └─────────────┘  ┌────────────────────────────┐ │  │  │  │
│  │  │  │                   │   platform namespace       │ │  │  │  │
│  │  │  │                   │                            │ │  │  │  │
│  │  │  │                   │   ┌──────────────────────┐ │ │  │  │  │
│  │  │  │                   │   │  Microservices ×50   │ │ │  │  │  │
│  │  │  │                   │   │  (Deployments +      │ │ │  │  │  │
│  │  │  │                   │   │   Services +         │ │ │  │  │  │
│  │  │  │                   │   │   Ingress routes)    │ │ │  │  │  │
│  │  │  │                   │   └──────────────────────┘ │ │  │  │  │
│  │  │  │                   │                            │ │  │  │  │
│  │  │  │                   │   imagePullSecrets:        │ │  │  │  │
│  │  │  │                   │     → acr-secret           │ │  │  │  │
│  │  │  │                   │                            │ │  │  │  │
│  │  │  │                   │   ResourceQuota:           │ │  │  │  │
│  │  │  │                   │     CPU 3 / Mem 12Gi       │ │  │  │  │
│  │  │  │                   │     Pods: 60               │ │  │  │  │
│  │  │  │                   └────────────────────────────┘ │  │  │  │
│  │  │  └───────────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │           Azure Container Registry (ACR)                      │  │
│  │           opsstellardevacr.azurecr.io                         │  │
│  │                                                               │  │
│  │   Images:                                                     │  │
│  │     • auth-service:latest                                     │  │
│  │     • apm-service:latest                                      │  │
│  │     • frontend:latest                                         │  │
│  │     • ... (50 microservices)                                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow

```
Client Request
      │
      ▼
Azure VM (Public IP :80/:443)
      │
      ▼
NGINX Ingress Controller (DaemonSet, hostPort)
      │
      ▼ (route by Host / Path)
      │
      ├──→ auth-service.local      → auth-service     (ClusterIP :80)
      ├──→ apm-service.local       → apm-service      (ClusterIP :80)
      ├──→ sample-service.local    → sample-service    (ClusterIP :80)
      └──→ ...                     → service-N         (ClusterIP :80)
```

---

## Folder Structure

```
k3s-platform/
├── install-platform.sh           # Main provisioning script
├── uninstall-platform.sh         # Clean teardown
├── README.md                     # This file
│
├── manifests/
│   ├── namespace.yaml            # Platform namespace
│   ├── resource-policies.yaml    # ResourceQuota + LimitRange
│   └── sample-service.yaml       # Sample ACR deployment
│
├── helm/
│   └── ingress-nginx-values.yaml # Helm values for ingress
│
└── scripts/
    ├── create-acr-secret.sh      # ACR secret helper
    ├── deploy-service.sh         # Quick service deployer
    └── health-check.sh           # Platform health check
```

---

## Prerequisites

| Component | Requirement |
|-----------|-------------|
| **Azure VM** | Standard_B4ms (4 vCPU / 15 GB RAM) |
| **OS** | Ubuntu 22.04 LTS |
| **Disk** | ≥ 128 GB Premium SSD |
| **ACR** | Azure Container Registry with Service Principal credentials |
| **Network** | NSG allowing inbound ports 80, 443, 6443 (API), 22 (SSH) |

### Create an Azure Service Principal for ACR

```bash
# Create SP with AcrPull role
ACR_NAME="opsstellardevacr"
ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)

SP=$(az ad sp create-for-rbac \
  --name "k3s-acr-pull" \
  --role AcrPull \
  --scopes $ACR_ID \
  --query '{appId:appId, password:password}' -o json)

echo "SP_APP_ID: $(echo $SP | jq -r .appId)"
echo "SP_PASSWORD: $(echo $SP | jq -r .password)"
```

---

## Installation

### 1. SSH into the Azure VM

```bash
ssh azureuser@<VM_PUBLIC_IP>
```

### 2. Upload the k3s-platform folder

```bash
scp -r k3s-platform/ azureuser@<VM_PUBLIC_IP>:~/
```

### 3. Run the installer

```bash
cd ~/k3s-platform
chmod +x install-platform.sh

sudo ./install-platform.sh \
  --acr-name  opsstellardevacr \
  --acr-user  <SP_APP_ID> \
  --acr-pass  <SP_PASSWORD>
```

The script will:
1. Install Docker CE
2. Install k3s (v1.29) with Docker as the container runtime
3. Configure `kubectl` for the current user
4. Install Helm 3
5. Deploy NGINX Ingress Controller
6. Create the `platform` namespace
7. Configure ACR `imagePullSecrets`
8. Apply ResourceQuota and LimitRange (optimised for 50 services)
9. Install metrics-server

### 4. Verify the installation

```bash
# Quick check
kubectl get nodes
kubectl get pods -A

# Full health check
chmod +x scripts/health-check.sh
./scripts/health-check.sh
```

---

## Deploying a Sample Microservice

### Option A: Using the manifest

```bash
kubectl apply -f manifests/sample-service.yaml

# Verify
kubectl get pods -n platform
kubectl get svc -n platform
kubectl get ingress -n platform
```

### Option B: Using the deploy helper script

```bash
chmod +x scripts/deploy-service.sh

# Deploy any ACR image
./scripts/deploy-service.sh auth-service v1.0.0 platform
./scripts/deploy-service.sh apm-service  latest  platform
./scripts/deploy-service.sh frontend     latest  platform
```

---

## Helm Commands Reference

### NGINX Ingress Controller

```bash
# Install / upgrade with custom values
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f helm/ingress-nginx-values.yaml \
  --wait --timeout 120s

# Check status
helm status ingress-nginx -n ingress-nginx

# Uninstall
helm uninstall ingress-nginx -n ingress-nginx
```

### Optional: cert-manager (TLS)

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true \
  --set resources.requests.cpu=25m \
  --set resources.requests.memory=64Mi
```

---

## ACR Secret Management

### Create secret in additional namespaces

```bash
chmod +x scripts/create-acr-secret.sh

./scripts/create-acr-secret.sh opsstellardevacr <SP_APP_ID> <SP_PASSWORD> \
  default platform monitoring
```

### Rotate credentials

```bash
# Re-run the same script with new credentials
./scripts/create-acr-secret.sh opsstellardevacr <NEW_APP_ID> <NEW_PASSWORD> platform

# Restart deployments to pick up new secret
kubectl rollout restart deployment -n platform
```

---

## Resource Budget (50 Services)

| Resource | Budget | Per Service (avg) |
|----------|--------|-------------------|
| **CPU Requests** | 3,000m | 25m (+ 500m system) |
| **CPU Limits** | 3,500m | 100m |
| **Memory Requests** | 12 Gi | 64 Mi (+ 1 Gi system) |
| **Memory Limits** | 13 Gi | 256 Mi |
| **Max Pods** | 60 | — |

System reservation: 1 vCPU + 1 GB RAM for kubelet, Docker, and OS.

---

## Troubleshooting

### k3s won't start
```bash
sudo systemctl status k3s
sudo journalctl -u k3s -f
```

### Pods stuck in ImagePullBackOff
```bash
# Check if secret exists
kubectl get secret acr-secret -n platform

# Verify the secret can auth
kubectl get secret acr-secret -n platform -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d

# Re-create if needed
./scripts/create-acr-secret.sh opsstellardevacr <APP_ID> <PASSWORD> platform
```

### Node resource pressure
```bash
kubectl describe node | grep -A5 "Conditions"
kubectl top nodes
kubectl top pods -n platform --sort-by=memory
```

---

## Uninstall

```bash
# Remove everything (including Docker)
sudo ./uninstall-platform.sh

# Remove k3s but keep Docker
sudo ./uninstall-platform.sh --keep-docker
```

---

## GitHub Actions CI/CD Integration

### How It Works

```
  Service Repo (any of 22 services)
       │
       │  push to main / workflow_dispatch
       ▼
  ┌─────────────────────────────────────┐
  │  build-test.yml                     │
  │  "Build & Push to ACR"              │
  │  → builds Docker image              │
  │  → pushes to opsstellardevacr       │
  └──────────────┬──────────────────────┘
                 │  on: workflow_run (success)
                 ▼
  ┌─────────────────────────────────────┐
  │  deploy-k3s.yml                     │
  │  "Deploy to k3s VM"                 │
  │  → writes kubeconfig from secret    │
  │  → helm upgrade --install           │
  │  → confirms rollout                 │
  └──────────────┬──────────────────────┘
                 │  kubectl / Helm (port 6443)
                 ▼
  ┌─────────────────────────────────────┐
  │  Azure VM — k3s cluster             │
  │  Namespace: platform                │
  │  Pulls image from ACR               │
  └─────────────────────────────────────┘
```

### One-time Setup

#### Step 1 — Open port 6443 on the Azure NSG

The GitHub Actions runner must reach the k3s API server. Add an NSG inbound rule:

```
Priority : 310
Name     : Allow-k3s-API
Source   : Any   (tighten to GitHub IP ranges for production)
Port     : 6443
Protocol : TCP
Action   : Allow
```

#### Step 2 — Export the kubeconfig from the VM

SSH into the VM and run:

```bash
sudo ./k3s-platform/scripts/export-kubeconfig.sh 20.10.5.123
```

Copy the printed base64 string.

#### Step 3 — Add GitHub Secrets

Add the following secrets to **each service repo** (or once at the organisation level):

| Secret | Value | How to obtain |
|--------|-------|---------------|
| `K3S_KUBECONFIG` | base64 kubeconfig | Output of `export-kubeconfig.sh` |
| `ACR_NAME` | `opsstellardevacr` | Your ACR name |
| `ACR_USERNAME` | Service Principal App ID | `az ad sp create-for-rbac` |
| `ACR_PASSWORD` | Service Principal password | Same command above |

Using GitHub CLI (bulk setup):

```bash
./k3s-platform/scripts/setup-github-secrets.sh \
  --org          my-github-org        \
  --vm-ip        20.10.5.123          \
  --acr-username <SP_APP_ID>          \
  --acr-password <SP_PASSWORD>
```

#### Step 4 — The `deploy-k3s.yml` is already in every service

The generator has stamped a ready-to-use `deploy-k3s.yml` into each service's
`.github/workflows/` directory. Commit and push:

```bash
# From workspace root
git -C apm-service     add .github/workflows/deploy-k3s.yml
git -C auth-service    add .github/workflows/deploy-k3s.yml
# ... repeat or use a loop:
for svc in apm-agent apm-service audit-logs auth-service chatbot code-commit \
           cost-service db-service devops-core dora-service frontend           \
           incident-service infrastructure-service logging-service             \
           metrics-collector microgenie postgres redis release-management      \
           security-service settings-service testing-services; do
  git -C "$svc" add .github/workflows/deploy-k3s.yml
  git -C "$svc" commit -m "ci: add k3s deployment workflow"
  git -C "$svc" push
done
```

### Triggering Deployments

**Automatic** — fires after every successful `Build & Push to ACR` run.

**Manual** — from the GitHub UI or CLI:

```bash
# Deploy latest HEAD to platform namespace
gh workflow run deploy-k3s.yml \
  --repo my-org/frontend \
  --field environment=platform

# Deploy a specific tag
gh workflow run deploy-k3s.yml \
  --repo my-org/auth-service \
  --field environment=platform \
  --field image_tag=a1b2c3d4
```

### Regenerating Workflows After Template Changes

If the template changes, re-run the generator:

```powershell
# From workspace root
.\azure-infrastructure\k3s-platform\scripts\Generate-K3sWorkflows.ps1 -Force
```

---

## Security Notes

- The k3s API server is bound to `0.0.0.0:6443`. Restrict access via Azure NSG.
- ACR credentials are stored as Kubernetes Secrets. Consider using Azure Key Vault CSI driver for production.
- Traefik is disabled in favour of NGINX Ingress for consistency with production AKS.
- The `kubeconfig` is readable by the provisioning user only (`chmod 600`).
