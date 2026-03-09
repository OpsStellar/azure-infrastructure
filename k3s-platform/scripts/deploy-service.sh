#!/usr/bin/env bash
###############################################################################
# deploy-service.sh
# ---------------------------------------------------------------------------
# Helper script to deploy a microservice from ACR to the k3s platform.
#
# Usage:
#   ./deploy-service.sh <service-name> [image-tag] [namespace]
#
# Example:
#   ./deploy-service.sh auth-service v1.2.3 platform
###############################################################################
set -euo pipefail

ACR_SERVER="${ACR_SERVER:-opsstellardevacr.azurecr.io}"

SERVICE_NAME="${1:?Usage: $0 <service-name> [image-tag] [namespace]}"
IMAGE_TAG="${2:-latest}"
NAMESPACE="${3:-platform}"
IMAGE="${ACR_SERVER}/${SERVICE_NAME}:${IMAGE_TAG}"

echo "[INFO] Deploying ${SERVICE_NAME} (${IMAGE}) to namespace '${NAMESPACE}'..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${SERVICE_NAME}
    managed-by: k3s-platform
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${SERVICE_NAME}
  template:
    metadata:
      labels:
        app: ${SERVICE_NAME}
    spec:
      imagePullSecrets:
        - name: acr-secret
      containers:
        - name: ${SERVICE_NAME}
          image: ${IMAGE}
          ports:
            - containerPort: 8080
              name: http
          resources:
            requests:
              cpu: "25m"
              memory: "64Mi"
            limits:
              cpu: "100m"
              memory: "256Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 10
            periodSeconds: 15
          readinessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: ${SERVICE_NAME}
  namespace: ${NAMESPACE}
  labels:
    app: ${SERVICE_NAME}
spec:
  type: ClusterIP
  selector:
    app: ${SERVICE_NAME}
  ports:
    - name: http
      port: 80
      targetPort: http
EOF

echo "[OK]   ${SERVICE_NAME} deployed. Check with:"
echo "       kubectl get pods -n ${NAMESPACE} -l app=${SERVICE_NAME}"
