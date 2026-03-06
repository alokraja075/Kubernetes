#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISTIOCTL="$ROOT_DIR/.bin/istioctl"

echo "deleting nginx + istio routing resources"
kubectl delete -f "$ROOT_DIR/k8s/istio/nginx-virtualservice.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/istio/nginx-gateway.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/istio/nginx-service.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/istio/nginx-deployment.yaml" --ignore-not-found
kubectl delete -f "$ROOT_DIR/k8s/istio/nginx-namespace.yaml" --ignore-not-found

if [[ -x "$ISTIOCTL" ]]; then
  echo "uninstalling Istio"
  "$ISTIOCTL" uninstall -y --purge || true
fi

kubectl delete namespace istio-system --ignore-not-found
