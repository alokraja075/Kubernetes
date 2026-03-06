#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="$ROOT_DIR/.bin"
ISTIOCTL="$BIN_DIR/istioctl"

ISTIO_VERSION="${ISTIO_VERSION:-latest}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd kubectl
need_cmd tar
need_cmd uname
need_cmd awk
need_cmd grep
need_cmd tr

if ! kubectl get nodes >/dev/null 2>&1; then
  echo "error: kubectl cannot reach a cluster. Create a cluster first (e.g. ./scripts/kind-up.sh)." >&2
  exit 1
fi

resolve_latest_istio_version() {
  curl -sI https://github.com/istio/istio/releases/latest \
    | awk -F/ '/^location:/ {print $NF}' \
    | tr -d '\r'
}

ensure_istioctl() {
  mkdir -p "$BIN_DIR"

  local version="$ISTIO_VERSION"
  if [[ "$version" == "latest" ]]; then
    version="$(resolve_latest_istio_version)"
    if [[ -z "$version" ]]; then
      echo "error: could not resolve latest Istio version" >&2
      exit 1
    fi
  fi

  if [[ -x "$ISTIOCTL" ]]; then
    local current
    current="$($ISTIOCTL version --remote=false 2>/dev/null | awk '/client version:/ {print $3}' | tr -d '\r')" || true
    if [[ "$current" == "$version" ]]; then
      echo "istioctl already present: $ISTIOCTL (version $current)"
      return 0
    fi
  fi

  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      echo "error: unsupported architecture: $(uname -m)" >&2
      exit 1
      ;;
  esac

  local url
  url="https://github.com/istio/istio/releases/download/${version}/istio-${version}-${os}-${arch}.tar.gz"

  echo "downloading istioctl $version ($os/$arch)"
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  curl -fsSL "$url" -o "$tmpdir/istio.tar.gz"
  tar -xzf "$tmpdir/istio.tar.gz" -C "$tmpdir"

  if [[ ! -f "$tmpdir/istio-${version}/bin/istioctl" ]]; then
    echo "error: istioctl not found in downloaded archive" >&2
    exit 1
  fi

  cp "$tmpdir/istio-${version}/bin/istioctl" "$ISTIOCTL"
  chmod +x "$ISTIOCTL"

  echo "installed istioctl: $ISTIOCTL"
}

ensure_istioctl

echo "installing Istio (profile=demo)"
"$ISTIOCTL" install -y --set profile=demo

kubectl -n istio-system wait --for=condition=Available deployment/istiod --timeout=300s
kubectl -n istio-system wait --for=condition=Available deployment/istio-ingressgateway --timeout=300s

echo "deploying nginx with sidecar injection + Istio Gateway/VirtualService"
kubectl apply -f "$ROOT_DIR/k8s/istio/nginx-namespace.yaml"
kubectl apply -f "$ROOT_DIR/k8s/istio/nginx-deployment.yaml"
kubectl apply -f "$ROOT_DIR/k8s/istio/nginx-service.yaml"
kubectl apply -f "$ROOT_DIR/k8s/istio/nginx-gateway.yaml"
kubectl apply -f "$ROOT_DIR/k8s/istio/nginx-virtualservice.yaml"

kubectl -n nginx rollout status deployment/nginx --timeout=180s

cat <<'EOF'

Done.

Test it (recommended):
1) In one terminal:
     kubectl -n istio-system port-forward svc/istio-ingressgateway 8080:80

2) In another terminal:
     curl -H 'Host: nginx.local' http://127.0.0.1:8080/

Tip: to use a browser hostname, add this on your host machine:
  127.0.0.1 nginx.local
Then you can browse to: http://nginx.local:8080/
EOF
