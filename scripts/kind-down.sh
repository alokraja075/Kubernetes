#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-demo}"

if command -v kind >/dev/null 2>&1; then
  kind delete cluster --name "$CLUSTER_NAME"
else
  echo "error: kind is not installed" >&2
  exit 1
fi
