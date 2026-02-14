#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo}"
KIND_CONFIG_FILE="${KIND_CONFIG_FILE:-k8s/kind-config.yaml}"
INGRESS_MANIFEST_URL="${INGRESS_MANIFEST_URL:-https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

need_cmd docker
need_cmd kubectl
need_cmd kind

if ! docker info >/dev/null 2>&1; then
  echo "error: Docker daemon not reachable. Start Docker and try again." >&2
  exit 1
fi

if [[ ! -f "$KIND_CONFIG_FILE" ]]; then
  echo "error: kind config not found: $KIND_CONFIG_FILE" >&2
  exit 1
fi

if kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "kind cluster already exists: $CLUSTER_NAME"
else
  echo "creating kind cluster: $CLUSTER_NAME"
  kind create cluster --name "$CLUSTER_NAME" --config "$KIND_CONFIG_FILE"
fi

echo "waiting for nodes to be Ready"
kubectl wait --for=condition=Ready nodes --all --timeout=180s

echo "installing ingress-nginx (kind provider manifest)"
kubectl apply -f "$INGRESS_MANIFEST_URL"

# The controller can take a bit on first start
kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s

echo "deploying nginx (Deployment + Service + Ingress)"
kubectl apply -f k8s/nginx-deployment.yaml
kubectl apply -f k8s/nginx-service.yaml
kubectl apply -f k8s/nginx-ingress.yaml

kubectl rollout status deployment/nginx --timeout=180s

cat <<'EOF'

Done.

Access options:
- If you add this entry to your HOST machine /etc/hosts:
    127.0.0.1 nginx.local
  then open:
    http://nginx.local/

- Or curl without editing hosts:
    curl -H 'Host: nginx.local' http://127.0.0.1/

If ports 80/443 are already in use on your machine, change hostPort values in k8s/kind-config.yaml.
EOF
