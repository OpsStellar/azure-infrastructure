#!/usr/bin/env bash
###############################################################################
# create-acr-secret.sh
# ---------------------------------------------------------------------------
# Creates or updates the ACR imagePullSecret across one or more namespaces.
#
# Usage:
#   ./create-acr-secret.sh <acr-name> <sp-app-id> <sp-password> [namespace...]
#
# Example:
#   ./create-acr-secret.sh opsstellardevacr <app-id> <password> default platform
###############################################################################
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <acr-name> <sp-app-id> <sp-password> [namespace...]"
  exit 1
fi

ACR_NAME="$1"
ACR_SERVER="${ACR_NAME}.azurecr.io"
SP_APP_ID="$2"
SP_PASSWORD="$3"
shift 3

NAMESPACES=("${@:-default platform}")

for ns in "${NAMESPACES[@]}"; do
  echo "[INFO] Creating/updating acr-secret in namespace '${ns}'..."

  kubectl create namespace "${ns}" --dry-run=client -o yaml | kubectl apply -f -

  kubectl create secret docker-registry acr-secret \
    --namespace="${ns}" \
    --docker-server="${ACR_SERVER}" \
    --docker-username="${SP_APP_ID}" \
    --docker-password="${SP_PASSWORD}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Patch default ServiceAccount
  kubectl patch serviceaccount default -n "${ns}" \
    -p '{"imagePullSecrets": [{"name": "acr-secret"}]}' 2>/dev/null || true

  echo "[OK]   acr-secret ready in '${ns}'."
done

echo ""
echo "Done. Verify with:  kubectl get secret acr-secret -n <namespace>"
