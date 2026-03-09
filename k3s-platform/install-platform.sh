#!/usr/bin/env bash
###############################################################################
# install-platform.sh
# ---------------------------------------------------------------------------
# Fully automated provisioning script for a single-node k3s Kubernetes
# platform on an Azure VM (Ubuntu 22.04 LTS, Standard_B4ms recommended).
#
# Capabilities:
#   - Installs Docker CE
#   - Installs k3s (latest stable)
#   - Configures kubectl for the current user
#   - Installs Helm 3
#   - Configures ACR authentication (imagePullSecrets)
#   - Creates the default namespace and service-account wiring
#   - Applies resource limits suitable for 50 microservices on 4 vCPU/15 GB
#
# Usage:
#   chmod +x install-platform.sh
#   sudo ./install-platform.sh \
#       --acr-name   <acr-name>          \
#       --acr-user   <service-principal>  \
#       --acr-pass   <sp-password>
#
# Environment variables (alternative to flags):
#   ACR_NAME, ACR_USERNAME, ACR_PASSWORD
###############################################################################
set -euo pipefail
IFS=$'\n\t'

# ─── Colour helpers ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Pre-flight checks ──────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && { err "This script must be run as root (sudo)."; exit 1; }

# ─── Parse arguments ────────────────────────────────────────────────────────
ACR_NAME="${ACR_NAME:-}"
ACR_USERNAME="${ACR_USERNAME:-}"
ACR_PASSWORD="${ACR_PASSWORD:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --acr-name)  ACR_NAME="$2";     shift 2 ;;
    --acr-user)  ACR_USERNAME="$2";  shift 2 ;;
    --acr-pass)  ACR_PASSWORD="$2";  shift 2 ;;
    --help|-h)
      grep '^#' "$0" | head -30 | sed 's/^#\s\?//'
      exit 0 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

# Default ACR name if not provided
ACR_NAME="${ACR_NAME:-opsstellardevacr}"
ACR_SERVER="${ACR_NAME}.azurecr.io"

if [[ -z "$ACR_USERNAME" || -z "$ACR_PASSWORD" ]]; then
  warn "ACR credentials not provided. ACR pull-secret will NOT be created."
  warn "You can create it later with:"
  warn "  kubectl create secret docker-registry acr-secret \\"
  warn "    --docker-server=${ACR_SERVER} \\"
  warn "    --docker-username=<SP_APP_ID> \\"
  warn "    --docker-password=<SP_PASSWORD>"
  SKIP_ACR=true
else
  SKIP_ACR=false
fi

PLATFORM_NS="platform"
K3S_VERSION="v1.29.4+k3s1"
HELM_VERSION="v3.14.4"

###############################################################################
# 1. System prerequisites
###############################################################################
info "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  jq \
  unzip \
  software-properties-common \
  open-iscsi \
  nfs-common
ok "System packages installed."

###############################################################################
# 2. Install Docker CE
###############################################################################
install_docker() {
  if command -v docker &>/dev/null; then
    ok "Docker already installed: $(docker --version)"
    return
  fi

  info "Installing Docker CE..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -qq
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  # Allow the calling user to use docker without sudo
  CALLING_USER="${SUDO_USER:-$USER}"
  usermod -aG docker "$CALLING_USER" 2>/dev/null || true
  ok "Docker installed: $(docker --version)"
}

install_docker

###############################################################################
# 3. Install k3s
###############################################################################
install_k3s() {
  if command -v k3s &>/dev/null; then
    ok "k3s already installed: $(k3s --version)"
    return
  fi

  info "Installing k3s ${K3S_VERSION}..."

  # k3s install with Docker as container runtime and optimised for single node
  curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION="${K3S_VERSION}" \
    INSTALL_K3S_EXEC="server \
      --docker \
      --disable traefik \
      --write-kubeconfig-mode 644 \
      --kube-apiserver-arg=default-not-ready-toleration-seconds=30 \
      --kube-apiserver-arg=default-unreachable-toleration-seconds=30 \
      --kubelet-arg=max-pods=110 \
      --kubelet-arg=eviction-hard=memory.available<256Mi,nodefs.available<5% \
      --kubelet-arg=system-reserved=cpu=500m,memory=512Mi \
      --kubelet-arg=kube-reserved=cpu=500m,memory=512Mi" \
    sh -

  # Wait for k3s to be ready
  info "Waiting for k3s node to become Ready..."
  for i in $(seq 1 60); do
    if k3s kubectl get node 2>/dev/null | grep -q ' Ready'; then
      break
    fi
    sleep 2
  done
  ok "k3s installed: $(k3s --version)"
}

install_k3s

###############################################################################
# 4. Configure kubectl for the calling user
###############################################################################
configure_kubectl() {
  info "Configuring kubectl..."
  CALLING_USER="${SUDO_USER:-$USER}"
  CALLING_HOME=$(eval echo "~${CALLING_USER}")

  mkdir -p "${CALLING_HOME}/.kube"
  cp /etc/rancher/k3s/k3s.yaml "${CALLING_HOME}/.kube/config"
  chown -R "${CALLING_USER}:${CALLING_USER}" "${CALLING_HOME}/.kube"
  chmod 600 "${CALLING_HOME}/.kube/config"

  # Symlink for root as well
  mkdir -p /root/.kube
  ln -sf /etc/rancher/k3s/k3s.yaml /root/.kube/config

  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  ok "kubectl configured for user '${CALLING_USER}'."
}

configure_kubectl

###############################################################################
# 5. Install Helm 3
###############################################################################
install_helm() {
  if command -v helm &>/dev/null; then
    ok "Helm already installed: $(helm version --short)"
    return
  fi

  info "Installing Helm ${HELM_VERSION}..."
  curl -fsSL https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | \
    tar -xzf - --strip-components=1 -C /usr/local/bin linux-amd64/helm
  chmod +x /usr/local/bin/helm
  ok "Helm installed: $(helm version --short)"
}

install_helm

###############################################################################
# 6. Install NGINX Ingress Controller via Helm
###############################################################################
install_ingress() {
  info "Installing NGINX Ingress Controller..."
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || true
  helm repo update

  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx --create-namespace \
    --set controller.kind=DaemonSet \
    --set controller.hostPort.enabled=true \
    --set controller.service.type=NodePort \
    --set controller.resources.requests.cpu=100m \
    --set controller.resources.requests.memory=128Mi \
    --set controller.resources.limits.cpu=250m \
    --set controller.resources.limits.memory=256Mi \
    --set controller.admissionWebhooks.enabled=false \
    --wait --timeout 120s

  ok "NGINX Ingress Controller installed."
}

install_ingress

###############################################################################
# 7. Create platform namespace & ACR pull-secret
###############################################################################
configure_acr() {
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  info "Creating namespace '${PLATFORM_NS}'..."
  kubectl create namespace "${PLATFORM_NS}" --dry-run=client -o yaml | kubectl apply -f -

  if [[ "${SKIP_ACR}" == "false" ]]; then
    info "Creating ACR imagePullSecret 'acr-secret' in namespace '${PLATFORM_NS}'..."
    kubectl create secret docker-registry acr-secret \
      --namespace="${PLATFORM_NS}" \
      --docker-server="${ACR_SERVER}" \
      --docker-username="${ACR_USERNAME}" \
      --docker-password="${ACR_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f -

    # Also create in the default namespace
    kubectl create secret docker-registry acr-secret \
      --namespace=default \
      --docker-server="${ACR_SERVER}" \
      --docker-username="${ACR_USERNAME}" \
      --docker-password="${ACR_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f -

    ok "ACR imagePullSecret created in '${PLATFORM_NS}' and 'default' namespaces."
  else
    warn "Skipping ACR secret creation (no credentials provided)."
  fi

  # Patch default service account to always use the pull secret
  if [[ "${SKIP_ACR}" == "false" ]]; then
    for ns in default "${PLATFORM_NS}"; do
      kubectl patch serviceaccount default -n "${ns}" \
        -p '{"imagePullSecrets": [{"name": "acr-secret"}]}' 2>/dev/null || true
    done
    ok "Default service accounts patched with imagePullSecrets."
  fi
}

configure_acr

###############################################################################
# 8. Apply resource quotas & limit ranges
###############################################################################
apply_resource_policies() {
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  info "Applying ResourceQuota and LimitRange to '${PLATFORM_NS}'..."

  cat <<'EOF' | kubectl apply -n "${PLATFORM_NS}" -f -
apiVersion: v1
kind: ResourceQuota
metadata:
  name: platform-quota
spec:
  hard:
    requests.cpu: "3"
    requests.memory: "12Gi"
    limits.cpu: "3500m"
    limits.memory: "13Gi"
    pods: "60"
    services: "55"
    configmaps: "100"
    secrets: "100"
    persistentvolumeclaims: "20"
EOF

  cat <<'EOF' | kubectl apply -n "${PLATFORM_NS}" -f -
apiVersion: v1
kind: LimitRange
metadata:
  name: platform-limits
spec:
  limits:
  - default:
      cpu: "100m"
      memory: "256Mi"
    defaultRequest:
      cpu: "25m"
      memory: "64Mi"
    max:
      cpu: "500m"
      memory: "512Mi"
    min:
      cpu: "10m"
      memory: "32Mi"
    type: Container
EOF

  ok "Resource policies applied."
}

apply_resource_policies

###############################################################################
# 9. Install metrics-server (if not present)
###############################################################################
install_metrics_server() {
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

  if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
    ok "metrics-server already present."
    return
  fi

  info "Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

  # Patch for single-node (insecure TLS to kubelet)
  kubectl patch deployment metrics-server -n kube-system \
    --type='json' \
    -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]' \
    2>/dev/null || true

  ok "metrics-server installed."
}

install_metrics_server

###############################################################################
# 10. Summary
###############################################################################
echo ""
echo "============================================================"
echo -e "${GREEN}  k3s DevOps Platform — Installation Complete${NC}"
echo "============================================================"
echo ""
echo "  Kubernetes API : https://127.0.0.1:6443"
echo "  KUBECONFIG     : /etc/rancher/k3s/k3s.yaml"
echo "  ACR Server     : ${ACR_SERVER}"
echo "  Namespace      : ${PLATFORM_NS}"
echo ""
echo "  Quick checks:"
echo "    kubectl get nodes"
echo "    kubectl get pods -A"
echo "    helm list -A"
echo ""
echo "  Deploy a sample service:"
echo "    kubectl apply -f manifests/sample-service.yaml"
echo ""
echo "============================================================"
