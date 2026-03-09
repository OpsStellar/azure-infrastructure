#!/usr/bin/env bash
###############################################################################
# setup-github-secrets.sh
# ---------------------------------------------------------------------------
# Uses the GitHub CLI (gh) to configure all required secrets for k3s CI/CD
# deployments across every service repository.
#
# Prerequisites:
#   - GitHub CLI installed: https://cli.github.com/
#   - Run: gh auth login
#   - The k3s VM is provisioned and export-kubeconfig.sh has been run
#
# Usage:
#   ./setup-github-secrets.sh \
#       --org           <github-org>       \
#       --vm-ip         <vm-public-ip>     \
#       --acr-username  <sp-app-id>        \
#       --acr-password  <sp-password>
#
# Secrets created in each repo:
#   K3S_KUBECONFIG  — base64-encoded kubeconfig (VM IP substituted)
#   ACR_USERNAME    — Service principal App ID
#   ACR_PASSWORD    — Service principal password
#   ACR_NAME        — ACR registry hostname (e.g. opsstellardevacr)
###############################################################################
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ─── Parse flags ─────────────────────────────────────────────────────────────
GITHUB_ORG=""
VM_IP=""
ACR_USERNAME=""
ACR_PASSWORD=""
ACR_NAME="${ACR_NAME:-opsstellardevacr}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org)          GITHUB_ORG="$2";     shift 2 ;;
    --vm-ip)        VM_IP="$2";          shift 2 ;;
    --acr-username) ACR_USERNAME="$2";   shift 2 ;;
    --acr-password) ACR_PASSWORD="$2";   shift 2 ;;
    --acr-name)     ACR_NAME="$2";       shift 2 ;;
    *) err "Unknown option: $1"; exit 1 ;;
  esac
done

for v in GITHUB_ORG VM_IP ACR_USERNAME ACR_PASSWORD; do
  [[ -z "${!v}" ]] && { err "--${v,,} is required"; exit 1; }
done

# Check gh is available
command -v gh &>/dev/null || { err "GitHub CLI (gh) not found. Install from https://cli.github.com/"; exit 1; }
gh auth status &>/dev/null  || { err "Not authenticated with gh. Run: gh auth login"; exit 1; }

# ─── Generate kubeconfig ─────────────────────────────────────────────────────
KUBECONFIG_B64=$(sed "s/127.0.0.1/${VM_IP}/g" /etc/rancher/k3s/k3s.yaml 2>/dev/null | base64 -w 0 || \
                 cat /root/.kube/config 2>/dev/null | sed "s/127.0.0.1/${VM_IP}/g" | base64 -w 0)

if [[ -z "$KUBECONFIG_B64" ]]; then
  err "Could not read k3s kubeconfig. Provide it manually as K3S_KUBECONFIG env var."
  exit 1
fi

# ─── Service repos ───────────────────────────────────────────────────────────
SERVICES=(
  "apm-agent"
  "apm-service"
  "audit-logs"
  "auth-service"
  "chatbot"
  "code-commit"
  "cost-service"
  "db-service"
  "devops-core"
  "dora-service"
  "frontend"
  "incident-service"
  "infrastructure-service"
  "logging-service"
  "metrics-collector"
  "microgenie"
  "postgres"
  "redis"
  "release-management"
  "security-service"
  "settings-service"
  "testing-services"
)

# ─── Set secrets in each repo ────────────────────────────────────────────────
for svc in "${SERVICES[@]}"; do
  REPO="${GITHUB_ORG}/${svc}"
  info "Setting secrets in ${REPO}..."

  gh secret set K3S_KUBECONFIG  --repo "$REPO" --body "$KUBECONFIG_B64"        2>/dev/null && \
  gh secret set ACR_NAME        --repo "$REPO" --body "$ACR_NAME"              2>/dev/null && \
  gh secret set ACR_USERNAME    --repo "$REPO" --body "$ACR_USERNAME"          2>/dev/null && \
  gh secret set ACR_PASSWORD    --repo "$REPO" --body "$ACR_PASSWORD"          2>/dev/null && \
  ok "Secrets set for ${svc}" || echo "  SKIP: ${REPO} not found or no access"
done

echo ""
ok "All secrets configured. Trigger a deploy with:"
echo "  gh workflow run deploy-k3s.yml --repo <org>/<service>"
