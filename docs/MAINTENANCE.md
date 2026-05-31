# Docs site — Maintenance

**On this page:** [Deploy / redeploy](#deploy--redeploy) · [Common operations](#common-operations) · [Update sidebar](#update-sidebar) · [Update Docsify configuration](#update-docsify-configuration) · [Troubleshooting](#troubleshooting)

## Deploy / redeploy

```bash
./deploy.sh
```

Or manually:
```bash
cp .env.example .env  # first time only
envsubst < k8s/docs-server.yaml | kubectl apply -f -
kubectl rollout status deployment/docs -n homelab
```

## Common operations

### Restart
```bash
kubectl rollout restart deployment/docs -n homelab
```

### Logs
```bash
kubectl logs -n homelab deployment/docs --tail=30
```

### Status
```bash
kubectl get pod,svc,ingress -n homelab -l app=docs
```

## Update sidebar

Edit `$DOCS_HOST_PATH/_sidebar.md` (the global nav). Live mount — refresh page to see changes. No pod restart needed.

> **Two link-path rules that must both hold** (we re-learn these every few months):
>
> 1. **Sidebar entries must use absolute paths with a leading slash** — `[Maintenance](/homelab-k8s-setup/apps/foo/MAINTENANCE.md)`, NOT `(homelab-k8s-setup/apps/foo/MAINTENANCE.md)`. Without the leading slash and with `relativePath: true` (see config below), the link resolves relative to the *current page* — so it works from the home page but 404s (or worse, lands on the wrong app's page when path fragments overlap, e.g. `grocy` ↔ `reminders`) from everywhere else.
> 2. **`relativePath: true` must stay in the Docsify config** so that *in-content* relative links inside sub-folder READMEs (like `[Maintenance](MAINTENANCE.md)` in `homelab-k8s-setup/README.md`) resolve to the correct path. Without it, those bare names resolve from the docs root and 404.
>
> Quick check after editing the sidebar:
> ```bash
> grep -E '^\s*\*\s+\[' "$DOCS_HOST_PATH/_sidebar.md" \
>   | grep -v 'http\|target=_blank\|"/"' \
>   | grep -E '\((?!/)[^)]+\)'
> ```
> Anything matched is a missing leading slash.

## Update Docsify configuration

Configuration lives in the `docs-index` ConfigMap inside `k8s/docs-server.yaml`. To change anything (theme color, basePath, search behavior):

1. Edit `k8s/docs-server.yaml`
2. Re-run `./deploy.sh` (or `envsubst < k8s/docs-server.yaml | kubectl apply -f -`)
3. Restart pod: `kubectl rollout restart deployment/docs -n homelab` (ConfigMap update doesn't automatically restart)

## Troubleshooting

### Page shows 404 for a known-good file
- Check the file actually exists at the expected path under `$DOCS_HOST_PATH`.
- Hard refresh in browser (service worker may be cached).
- **If the link is in the sidebar:** it almost certainly lacks a leading `/`. See the [link-path rules](#update-sidebar) above.
- **If the link is from another markdown page:** ensure `relativePath: true` is still set in the Docsify config inside the `docs-index` ConfigMap.
- Check Docsify `basePath` config matches your folder structure.

### Sidebar link goes to the wrong page (e.g. clicking "Reminders → Overview" shows Grocy)
Same root cause as 404: a sidebar link without a leading `/` is treated as relative to the current page. Add the leading slash and the problem disappears.

### Port-forward returns 000
```bash
kubectl -n homelab port-forward svc/docs 8090:80 &
```

### Sidebar links broken after moving files
Update `$DOCS_HOST_PATH/_sidebar.md` to match the new locations.

### Pod won't start
Probably an nginx config syntax error in the ConfigMap:
```bash
kubectl logs -n homelab deployment/docs --tail=30
```

### Files don't appear (despite being in the folder)
The PV mounts the docs folder. Confirm the file is under `$DOCS_HOST_PATH`. Also confirm OrbStack passthrough is working:
```bash
kubectl exec -n homelab deployment/docs -- ls /usr/share/nginx/html/docs/
```

### Tailscale URL fails but port-forward works
```bash
kubectl get ingress docs -n homelab
kubectl logs -n tailscale -l app=operator --tail=30 | grep docs
```
