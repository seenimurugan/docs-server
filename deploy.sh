#!/usr/bin/env bash
# deploy.sh — idempotent deploy for docs-server (nginx + git-puller sidecar)
# Usage: ./deploy.sh
# Safe to re-run; existing resources are patched, not replaced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Load .env ─────────────────────────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env not found."
  echo "       Copy .env.example to .env and adjust values, then re-run."
  echo "         cp .env.example .env"
  exit 1
fi
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

# ── 2. Determine DOCS_SOURCE mode ────────────────────────────────────────────
DOCS_SOURCE="${DOCS_SOURCE:-gitsync}"

# ── 3. Prereq checks ─────────────────────────────────────────────────────────
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

# ── 4. Ensure namespace exists ───────────────────────────────────────────────
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"
if ! kubectl get namespace "$HOMELAB_NAMESPACE" &>/dev/null; then
  echo "Namespace '$HOMELAB_NAMESPACE' not found — creating it."
  kubectl create namespace "$HOMELAB_NAMESPACE"
else
  echo "Namespace '$HOMELAB_NAMESPACE' already exists."
fi

# ── 5. Mode-specific steps ───────────────────────────────────────────────────
if [[ "$DOCS_SOURCE" == "gitsync" ]]; then
  echo "Mode: gitsync (git-puller sidecar)"

  # -- 5a. gh CLI check -------------------------------------------------------
  if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI not found. Run 'brew install gh && gh auth login' first."
    exit 1
  fi
  if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: gh CLI not authenticated. Run 'gh auth login' first."
    exit 1
  fi

  # -- 5b. Extract OAuth token from gh CLI ------------------------------------
  GITHUB_TOKEN=$(gh auth token)
  if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "ERROR: gh auth token returned empty."
    exit 1
  fi
  echo "GitHub token extracted from gh CLI (${#GITHUB_TOKEN} chars)."

  # -- 5c. Create/update the docs-puller-secret --------------------------------
  kubectl create secret generic docs-puller-secret \
    -n "$HOMELAB_NAMESPACE" \
    --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "docs-puller-secret created/updated."

  # -- 5d. Apply the gitsync manifest -----------------------------------------
  K8S_FILE="$SCRIPT_DIR/k8s/docs-server.yaml"
# ── Apply SealedSecrets (GitOps secrets, encrypted-in-git) ────────────────────
# SealedSecrets in k8s/sealed/ are committed encrypted; the in-cluster
# sealed-secrets controller (kube-system) decrypts them into real Secrets with
# identical values. This is ADDITIVE and the SAFE DR path on a rebuilt cluster.
#
# NOTE: the .env → `kubectl create secret` step above is intentionally KEPT as a
# documented FALLBACK (no big-bang cutover). On a cluster where a plain Secret
# of the same name already exists, the controller will NOT overwrite it unless
# it carries the annotation sealedsecrets.bitnami.com/managed=true — so applying
# these is non-disruptive. See cluster-setup/secrets-dr/README.md for cutover.
SEALED_DIR="$SCRIPT_DIR/k8s/sealed"
if [ -d "$SEALED_DIR" ] && kubectl get crd sealedsecrets.bitnami.com >/dev/null 2>&1; then
  echo "[deploy] Applying SealedSecrets from k8s/sealed/ (controller present)..."
  for f in "$SEALED_DIR"/*.yaml; do
    [ -e "$f" ] || continue
    echo "  → $f"
    kubectl apply -f "$f"
  done
else
  echo "[deploy] SealedSecrets controller not found (crd sealedsecrets.bitnami.com missing) — skipping k8s/sealed/; relying on .env-created Secrets above."
fi

  echo "Applying k8s manifest (envsubst → kubectl apply)..."
  # Export all required env vars for envsubst
  # IMPORTANT: pass an explicit substitution list so that $GITHUB_TOKEN and other
  # shell vars in the sync.sh bash script are NOT substituted by envsubst.
  export HOMELAB_NAMESPACE NGINX_IMAGE NGINX_TAG GITHUB_USER SYNC_INTERVAL_SECONDS
  envsubst '${HOMELAB_NAMESPACE} ${NGINX_IMAGE} ${NGINX_TAG} ${GITHUB_USER} ${SYNC_INTERVAL_SECONDS}' \
    < "$K8S_FILE" | kubectl apply -f -

elif [[ "$DOCS_SOURCE" == "hostpath" ]]; then
  echo "Mode: hostpath (legacy — mounts $DOCS_HOST_PATH directly)"

  # -- 5a. Verify DOCS_HOST_PATH exists ----------------------------------------
  DOCS_HOST_PATH="${DOCS_HOST_PATH:-/Users/nila/Developer/agents/docs}"
  if [[ ! -d "$DOCS_HOST_PATH" ]]; then
    echo "ERROR: DOCS_HOST_PATH does not exist: $DOCS_HOST_PATH"
    echo "       Create the folder or update DOCS_HOST_PATH in .env"
    exit 1
  fi
  echo "Docs path verified: $DOCS_HOST_PATH"

  # -- 5b. Apply the legacy hostPath manifest ----------------------------------
  K8S_FILE="$SCRIPT_DIR/k8s/docs-server-legacy-hostpath.yaml"
  echo "Applying legacy k8s manifest (envsubst → kubectl apply)..."
  export HOMELAB_NAMESPACE DOCS_HOST_PATH NGINX_IMAGE NGINX_TAG
  envsubst < "$K8S_FILE" | kubectl apply -f -

else
  echo "ERROR: Unknown DOCS_SOURCE='$DOCS_SOURCE'. Must be 'gitsync' or 'hostpath'."
  exit 1
fi

# ── 6. Wait for rollout ───────────────────────────────────────────────────────
echo "Waiting for docs-server rollout..."
if [[ "$DOCS_SOURCE" == "gitsync" ]]; then
  kubectl -n "$HOMELAB_NAMESPACE" rollout status deployment/docs-server --timeout=5m
else
  kubectl -n "$HOMELAB_NAMESPACE" rollout status deployment/docs --timeout=3m
fi

# ── 7. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "  Docs at https://docs.stoat-perch.ts.net"
echo ""
echo "  Debug port-forward:"
echo "    kubectl -n $HOMELAB_NAMESPACE port-forward svc/docs-server 8090:80"
echo ""
if [[ "$DOCS_SOURCE" == "gitsync" ]]; then
  echo "  Watch first sync:"
  echo "    kubectl logs -n $HOMELAB_NAMESPACE deploy/docs-server -c git-puller -f"
  echo ""
  echo "  NOTE: GITHUB_TOKEN is extracted from 'gh auth token' at deploy time."
  echo "  If you re-authenticate with gh, re-run ./deploy.sh to refresh the secret."
fi
