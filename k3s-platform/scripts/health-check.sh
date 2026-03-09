#!/usr/bin/env bash
###############################################################################
# health-check.sh
# ---------------------------------------------------------------------------
# Validates that the k3s platform is healthy and all critical components
# are running.
###############################################################################
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo -e "  ${GREEN}✓${NC} ${desc}"
    ((PASS++))
  else
    echo -e "  ${RED}✗${NC} ${desc}"
    ((FAIL++))
  fi
}

export KUBECONFIG="${KUBECONFIG:-/etc/rancher/k3s/k3s.yaml}"

echo ""
echo "═══════════════════════════════════════════════════"
echo "  k3s Platform Health Check"
echo "═══════════════════════════════════════════════════"
echo ""

echo "▸ Core Components"
check "k3s service running"      systemctl is-active k3s
check "Docker daemon running"    systemctl is-active docker
check "kubectl reachable"        kubectl cluster-info
check "Node is Ready"            kubectl get nodes -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' | grep -q True

echo ""
echo "▸ System Pods"
check "CoreDNS running"          kubectl get pods -n kube-system -l k8s-app=kube-dns -o jsonpath='{.items[0].status.phase}' | grep -q Running
check "metrics-server running"   kubectl get deployment metrics-server -n kube-system

echo ""
echo "▸ Ingress"
check "NGINX ingress installed"  helm status ingress-nginx -n ingress-nginx

echo ""
echo "▸ Platform Namespace"
check "Namespace 'platform' exists"   kubectl get namespace platform
check "ResourceQuota applied"         kubectl get resourcequota -n platform
check "LimitRange applied"            kubectl get limitrange -n platform

echo ""
echo "▸ ACR Authentication"
if kubectl get secret acr-secret -n platform &>/dev/null; then
  check "acr-secret exists (platform)"  true
else
  echo -e "  ${YELLOW}⚠${NC} acr-secret not found in 'platform' namespace"
  ((FAIL++))
fi

echo ""
echo "═══════════════════════════════════════════════════"
echo -e "  Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "═══════════════════════════════════════════════════"
echo ""

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
