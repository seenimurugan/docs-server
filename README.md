# docs-server

nginx + Docsify docs server for a self-hosted homelab — auto-discovers all `seenimurugan/*` GitHub repos with a `docs/` folder and serves them via Tailscale ingress.

## Architecture

Single pod, two containers sharing an `emptyDir` volume:

```
git-puller sidecar (bitnami/git)
  ↓  queries GitHub API for seenimurugan/* repos with docs/
  ↓  clones/pulls each into /docs-aggregated (emptyDir)
  ↓  auto-generates _sidebar.md from the discovered tree

emptyDir (/docs-aggregated)  ← shared between both containers

nginx container
  ↓  serves /usr/share/nginx/html → /docs-aggregated (read-only)
  ↓  docsify renders .md in the browser (no build step)
```

### Auto-discovery

The git-puller queries `https://api.github.com/users/seenimurugan/repos` every `SYNC_INTERVAL_SECONDS` (default: 5 min) and filters to repos with a `docs/` folder. **No manual repo list needed** — push a `docs/` folder to any repo under `seenimurugan/` and it appears automatically within 5 minutes.

### Top-level landing page

[`seenimurugan/homelab-docs`](https://github.com/seenimurugan/homelab-docs) is a dedicated repo that holds the landing page (`docs/README.md`). The puller symlinks its files into the aggregated root. The `_sidebar.md` in that repo is a human-edited reference; the served sidebar is always auto-generated.

### Auth: gh CLI token (no PAT)

`deploy.sh` extracts the OAuth token from your `gh` CLI session at deploy time:

```bash
GITHUB_TOKEN=$(gh auth token)
kubectl create secret generic docs-puller-secret ...
```

No manual PAT creation or rotation. If you re-authenticate with `gh`, just re-run `./deploy.sh` to refresh the cluster secret.

## Depends on

- **cluster-setup** — `homelab` namespace, Tailscale ingress controller: [`github.com/seenimurugan/homelab-cluster-setup`](https://github.com/seenimurugan/homelab-cluster-setup)
- **gh CLI** — logged in (`gh auth login`) to provide the GitHub token at deploy time

## Quick start

```bash
git clone https://github.com/seenimurugan/docs-server
cd docs-server

cp .env.example .env
# Defaults are fine for gitsync mode — no edits needed

./deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It extracts the gh token, creates the cluster secret, applies the manifest via `envsubst`, and waits for rollout.

## Access

| | |
|---|---|
| **Tailnet URL** | https://docs.stoat-perch.ts.net |
| **Debug port-forward** | `kubectl -n homelab port-forward svc/docs-server 8090:80` → http://localhost:8090 |
| **In-cluster** | http://docs-server.homelab.svc.cluster.local |

## Watch the puller

```bash
kubectl logs -n homelab deploy/docs-server -c git-puller -f
```

Expect `sync cycle complete` within 60s of first deploy.

## DOCS_SOURCE switch

Set `DOCS_SOURCE=hostpath` in `.env` to revert to the legacy mode (mounts a local folder instead of pulling from GitHub). The legacy manifest is preserved at `k8s/docs-server-legacy-hostpath.yaml`.

## Tear down

```bash
./undeploy.sh
```

## Docs

- [docs/README.md](docs/README.md) — access URLs, overview
- [docs/USAGE.md](docs/USAGE.md) — add/edit docs, sidebar rules, URL routing
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) — restart, config changes, troubleshooting
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — tech stack, data layout, design decisions
- [docs/MIGRATION-TO-GIT-SYNC.md](docs/MIGRATION-TO-GIT-SYNC.md) — migration notes (DONE)

Also rendered live at https://docs.stoat-perch.ts.net (sidebar → Docs Server).
