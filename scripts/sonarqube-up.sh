#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo}"
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

if ! kind get clusters | grep -qx "$CLUSTER_NAME"; then
  echo "error: kind cluster '$CLUSTER_NAME' not found." >&2
  echo "hint: run ./scripts/kind-up.sh first (or set CLUSTER_NAME to your cluster name)." >&2
  exit 1
fi

# SonarQube requires vm.max_map_count for its embedded Elasticsearch.
NODE_NAME="$(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null | head -n1 || true)"
if [[ -z "$NODE_NAME" ]]; then
  echo "error: could not find kind node for cluster '$CLUSTER_NAME'. Is the cluster created?" >&2
  exit 1
fi

echo "setting sysctls on kind node: $NODE_NAME"
docker exec "$NODE_NAME" sysctl -w vm.max_map_count=524288 >/dev/null
docker exec "$NODE_NAME" sysctl -w fs.file-max=131072 >/dev/null

echo "deploying SonarQube (namespace + postgres + sonarqube + ingress)"

if ! kubectl get ns ingress-nginx >/dev/null 2>&1; then
  echo "ingress-nginx not found; installing (kind provider manifest)"
  kubectl apply -f "$INGRESS_MANIFEST_URL"
  kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s
fi

kubectl apply -f k8s/sonarqube/namespace.yaml
kubectl apply -f k8s/sonarqube/postgres-secret.yaml
kubectl apply -f k8s/sonarqube/postgres.yaml
kubectl apply -f k8s/sonarqube/sonarqube.yaml
kubectl apply -f k8s/sonarqube/ingress.yaml

echo "waiting for postgres to be ready"
kubectl -n sonarqube rollout status statefulset/sonarqube-postgresql --timeout=300s

echo "waiting for sonarqube to be ready (can take a few minutes on first run)"
kubectl -n sonarqube rollout status deployment/sonarqube --timeout=900s

cat <<'EOF'

Done.

Access options:
- If you add this entry to your HOST machine /etc/hosts:
    127.0.0.1 sonarqube.local
  then open:
    http://sonarqube.local/

- Or curl without editing hosts:
    curl -H 'Host: sonarqube.local' http://127.0.0.1/

Default SonarQube login (upstream defaults):
- username: admin
- password: admin
EOF
