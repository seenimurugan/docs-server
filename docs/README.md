# Docs site — homelab documentation server

Self-hosted nginx + Docsify static site that renders all the homelab markdown docs at `https://docs.stoat-perch.ts.net`. Content is live-mounted from `$DOCS_HOST_PATH` (default: `/Users/nila/Developer/agents/docs/`) — edit any `.md` on the Mac, refresh the browser, and the change is live immediately. No build, no restart.

Source: `/Users/nila/Developer/apps/docs-server/`

---

## Access

| Where | URL |
|---|---|
| **Phone / family on Tailscale** | https://docs.stoat-perch.ts.net |
| **Cluster DNS** (other pods / Mac shell) | http://docs-server.homelab.svc.cluster.local |
| **Ad-hoc debug port-forward** | `kubectl -n homelab port-forward svc/docs-server 8090:80` → http://localhost:8090 |

No credentials — the docs site is read-only and public within the tailnet.

---

## What it does

- Renders every `.md` file under `$DOCS_HOST_PATH` as a browsable Docsify site.
- Sidebar navigation (global `_sidebar.md`; per-folder sidebars for app-specific context).
- Client-side full-text search via the Docsify search plugin.
- Syntax highlighting (Prism.js) for bash, yaml, json blocks.
- Live mount — no restart needed for content changes.

---

## Stack & framework

| Layer | Tech |
|---|---|
| Web server | nginx (Alpine, ~25 MB) |
| Renderer | Docsify v4 (client-side JS) |
| Search | Docsify search plugin (client-side) |
| Content source | hostPath PV → `$DOCS_HOST_PATH` on the Mac filesystem |
| Config | nginx.conf + index.html in ConfigMap |
| Deploy | Kubernetes (`homelab` namespace), Tailscale Ingress |

---

## Storage

No database and no writable PVC. The docs pod mounts `$DOCS_HOST_PATH` **read-only** (hostPath PV). All writes happen on the Mac filesystem directly.

---

## See also

- [Usage guide](USAGE.md) — add/edit/delete files, sidebar updates, URL routing, caching gotchas
- [Maintenance](MAINTENANCE.md) — restart, config changes, troubleshooting
- [Architecture](ARCHITECTURE.md) — nginx + Docsify design, content layout, hash routing
- [Migration to git-sync](MIGRATION-TO-GIT-SYNC.md) — planned future move from hostPath to git-sync

## File reference

| File | Purpose |
|---|---|
| `/Users/nila/Developer/apps/docs-server/k8s/docs-server.yaml` | Deployment + Service + Ingress + ConfigMap (nginx.conf + index.html) |
| `$DOCS_HOST_PATH` (default: `/Users/nila/Developer/agents/docs/`) | Markdown content (live-mounted; NOT in this repo) |
