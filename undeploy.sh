#!/usr/bin/env bash
# undeploy.sh — tear down docs-server deployment/service/ingress/configmap/pvc/pv
# docs-server has NO persistent data of its own — the docs folder is a host mount
# owned by the user, not this pod. Everything here is safe to delete and redeploy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Load .env for HOMELAB_NAMESPACE ──────────────────────────────────────────
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$ENV_FILE"; set +a
fi
HOMELAB_NAMESPACE="${HOMELAB_NAMESPACE:-homelab}"

echo "Undeploying docs-server from namespace '$HOMELAB_NAMESPACE'..."
echo "(The docs folder at DOCS_HOST_PATH is NOT touched — it's just a host mount.)"
echo ""

# ── Deployment ────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete deployment docs --ignore-not-found

# ── Service ───────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete service docs --ignore-not-found

# ── Ingress ───────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete ingress docs --ignore-not-found

# ── ConfigMap ─────────────────────────────────────────────────────────────────
kubectl -n "$HOMELAB_NAMESPACE" delete configmap docs-index --ignore-not-found

# ── PVC / PV ─────────────────────────────────────────────────────────────────
# Safe to delete: PV only backed a host read-only mount, no data is stored in-cluster
kubectl -n "$HOMELAB_NAMESPACE" delete pvc docs-content-pvc --ignore-not-found
kubectl delete pv docs-content-pv --ignore-not-found

echo ""
echo "  docs-server torn down."
echo ""
echo "  Your docs folder ($DOCS_HOST_PATH) is untouched."
echo ""
echo "  To redeploy:  ./deploy.sh"
