#!/usr/bin/env bash
###############################################################################
# export-kubeconfig.sh
# ---------------------------------------------------------------------------
# Run this script ON the k3s VM to produce a base64-encoded kubeconfig that
# can be stored as a GitHub Actions secret (K3S_KUBECONFIG).
#
# Prerequisites:
#   - k3s is installed and running
#   - Run as root (sudo) or as a user that can read /etc/rancher/k3s/k3s.yaml
#
# Usage:
#   sudo ./export-kubeconfig.sh <VM_PUBLIC_IP>
#
# Example:
#   sudo ./export-kubeconfig.sh 20.10.5.123
#
# The output is the base64 string to paste into:
#   GitHub → Settings → Secrets → Actions → New repository secret
#   Name:  K3S_KUBECONFIG
#   Value: <printed base64 string>
###############################################################################
set -euo pipefail

VM_IP="${1:-}"
if [[ -z "$VM_IP" ]]; then
  echo "ERROR: Provide the VM public IP as the first argument."
  echo "Usage: sudo $0 <VM_PUBLIC_IP>"
  exit 1
fi

KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
if [[ ! -f "$KUBECONFIG_PATH" ]]; then
  echo "ERROR: k3s kubeconfig not found at ${KUBECONFIG_PATH}."
  echo "       Is k3s installed and running?"
  exit 1
fi

# Replace the loopback address with the VM's public IP so remote callers
# (GitHub Actions runners) can reach the API server.
KUBECONFIG_CONTENT=$(sed "s/127.0.0.1/${VM_IP}/g" "$KUBECONFIG_PATH")
KUBECONFIG_B64=$(echo "$KUBECONFIG_CONTENT" | base64 -w 0)

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  k3s Remote Kubeconfig — Base64 Encoded"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Add the following as a GitHub Actions secret:"
echo ""
echo "  Secret name:  K3S_KUBECONFIG"
echo "  Secret value: (see below)"
echo ""
echo "$KUBECONFIG_B64"
echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "IMPORTANT: Ensure Azure NSG allows inbound TCP 6443 from"
echo "GitHub Actions runner IP ranges (or 0.0.0.0/0 for lab use)."
echo ""
echo "GitHub Actions IP ranges:"
echo "  https://api.github.com/meta  (look for 'actions' key)"
echo ""
echo "Verify connectivity (from your local machine):"
echo "  curl -k https://${VM_IP}:6443/livez"
echo "════════════════════════════════════════════════════════════════"
