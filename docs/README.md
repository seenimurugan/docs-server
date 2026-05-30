# Docs site — overview

The page you're reading. Self-hosted nginx + Docsify static site that serves all the markdown docs under `$DOCS_HOST_PATH` (default: `/Users/nila/Developer/agents/docs/`).

## Access

| Where | URL |
|---|---|
| **iPhone / family on Tailscale** | https://docs.stoat-perch.ts.net |
| **Debug port-forward** | `kubectl -n homelab port-forward svc/docs 8090:80` → http://localhost:8090 |
| **In-cluster** | http://docs.homelab.svc.cluster.local |

## Detailed docs

- [USAGE](USAGE.md) — add/edit/delete files, sidebar updates, URL routing, caching gotchas
- [MAINTENANCE](MAINTENANCE.md) — restart, config changes, troubleshooting
- [ARCHITECTURE](ARCHITECTURE.md) — tech stack (nginx + Docsify), data layout, design decisions
- [MIGRATION-TO-GIT-SYNC](MIGRATION-TO-GIT-SYNC.md) — planned future move from hostPath to git-sync

## How content updates work

Live mount — edit any `.md` in `$DOCS_HOST_PATH`, refresh page, see the change. No build, no restart.

## How to deploy

```bash
git clone https://github.com/seenimurugan/docs-server
cd docs-server
cp .env.example .env
# Edit DOCS_HOST_PATH if your docs folder is not at the default location
./deploy.sh
```
