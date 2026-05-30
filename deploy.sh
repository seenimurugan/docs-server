#!/usr/bin/env bash
# deploy.sh — idempotent deploy for docs-server (nginx + Docsify homelab docs)
# Usage: ./deploy.sh
# Safe to re-run; existing resources are patched, not replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  echo "       Copy .env.example to .env and adjust values, then re-run."
  echo "         cp .env.example .env && \$EDITOR .env"
  exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# ── 2. Prereq checks ─────────────────────────────────────────────────────────
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl not found in PATH."
  exit 1
fi
if ! command -v envsubst &>/dev/null; then
  echo "ERROR: envsubst not found. Install via: brew install gettext"
  exit 1
fi
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: Cannot reach the Kubernetes cluster. Is OrbStack running?"
  exit 1
fi

# ── 3. Verify DOCS_HOST_PATH exists on the host ──────────────────────────────
DOCS_HOST_PATH="${DOCS_HOST_PATH:-/Users/nila/Developer/agents/docs}"
if [[ ! -d "$DOCS_HOST_PATH" ]]; then
  echo "ERROR: DOCS_HOST_PATH does not exist: $DOCS_HOST_PATH"
  echo "       Create the folder or update DOCS_HOST_PATH in .env"
  exit 1
fi
echo "Docs path verified: $DOCS_HOST_PATH"

# ── 4. Ensure namespace exists ───────────────────────────────────────────────
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"
if ! kubectl get namespace "$HOMELAB_NAMESPACE" &>/dev/null; then
  echo "Namespace '$HOMELAB_NAMESPACE' not found — creating it."
  kubectl create namespace "$HOMELAB_NAMESPACE"
else
  echo "Namespace '$HOMELAB_NAMESPACE' already exists."
fi

# ── 5. Apply manifest via envsubst ───────────────────────────────────────────
K8S_FILE="$SCRIPT_DIR/k8s/docs-server.yaml"
echo "Applying k8s manifest (envsubst → kubectl apply)..."
envsubst < "$K8S_FILE" | kubectl apply -f -

# ── 6. Wait for rollout ───────────────────────────────────────────────────────
echo "Waiting for docs rollout..."
kubectl -n "$HOMELAB_NAMESPACE" rollout status deployment/docs --timeout=3m

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "  Docs at https://docs.stoat-perch.ts.net"
echo ""
echo "  Debug port-forward:"
echo "    kubectl -n $HOMELAB_NAMESPACE port-forward svc/docs 8090:80"
echo ""
echo "  Note: docs are served live from $DOCS_HOST_PATH"
echo "  Edit any .md file there and refresh the page — no restart needed."
