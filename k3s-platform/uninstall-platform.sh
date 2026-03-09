#!/usr/bin/env bash
###############################################################################
# uninstall-platform.sh
# ---------------------------------------------------------------------------
# Cleanly removes the k3s platform and all associated resources.
#
# Usage:
#   sudo ./uninstall-platform.sh [--keep-docker]
###############################################################################
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${YELLOW}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

KEEP_DOCKER=false
[[ "${1:-}" == "--keep-docker" ]] && KEEP_DOCKER=true

echo ""
echo -e "${RED}════════════════════════════════════════════════${NC}"
echo -e "${RED}  WARNING: This will destroy the k3s cluster!${NC}"
echo -e "${RED}════════════════════════════════════════════════${NC}"
echo ""
read -rp "Are you sure? (yes/no): " CONFIRM
[[ "$CONFIRM" != "yes" ]] && { echo "Aborted."; exit 0; }

# Uninstall k3s
if [[ -f /usr/local/bin/k3s-uninstall.sh ]]; then
  info "Uninstalling k3s..."
  /usr/local/bin/k3s-uninstall.sh
  ok "k3s removed."
else
  info "k3s uninstall script not found — skipping."
fi

# Remove Helm
if command -v helm &>/dev/null; then
  info "Removing Helm binary..."
  rm -f /usr/local/bin/helm
  ok "Helm removed."
fi

# Remove kubeconfig
info "Cleaning up kubeconfig files..."
rm -rf /root/.kube
CALLING_USER="${SUDO_USER:-$USER}"
CALLING_HOME=$(eval echo "~${CALLING_USER}")
rm -rf "${CALLING_HOME}/.kube"
ok "kubeconfig cleaned."

# Optionally remove Docker
if [[ "$KEEP_DOCKER" == "false" ]]; then
  info "Removing Docker..."
  apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
  apt-get autoremove -y 2>/dev/null || true
  rm -rf /var/lib/docker /etc/docker
  ok "Docker removed."
else
  info "Keeping Docker (--keep-docker flag)."
fi

echo ""
ok "Platform uninstalled successfully."
