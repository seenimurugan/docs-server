# docs-server

nginx + Docsify static docs server for a self-hosted homelab — serves markdown docs from a hostPath via Tailscale ingress.

## What it does

Runs an nginx pod that mounts a local docs folder (`$DOCS_HOST_PATH`) and serves it as a browsable web site via [Docsify](https://docsify.js.org) (client-side markdown renderer). No build step — edit a `.md` file, refresh the page, see the change.

## Depends on

- **cluster-setup** — `homelab` namespace, Tailscale ingress controller: [`github.com/seenimurugan/homelab-cluster-setup`](https://github.com/seenimurugan/homelab-cluster-setup)

## Quick start

```bash
git clone https://github.com/seenimurugan/docs-server
cd docs-server

cp .env.example .env
# Adjust DOCS_HOST_PATH if your docs folder is not at the default location
# (default: /Users/nila/Developer/agents/docs)

./deploy.sh
```

`deploy.sh` is idempotent — safe to re-run. It verifies `$DOCS_HOST_PATH` exists, applies the manifest via `envsubst`, and waits for rollout.

## Access

| | |
|---|---|
| **Tailnet URL** | https://docs.stoat-perch.ts.net |
| **Debug port-forward** | `kubectl -n homelab port-forward svc/docs 8090:80` → http://localhost:8090 |
| **In-cluster** | http://docs.homelab.svc.cluster.local |

## How this pod serves your docs

The pod mounts `$DOCS_HOST_PATH` (a folder on the Mac filesystem) read-only, and serves everything in it at `https://docs.stoat-perch.ts.net`. Docsify renders `.md` files in the browser — no build, no restart needed after edits.

**Current docs source:** `$DOCS_HOST_PATH` defaults to `/Users/nila/Developer/agents/docs/`, which is the `agents/docs/` folder in the homelab repo. Per-app docs (chores, reminders, etc.) live there as subfolders.

The `docs/` folder in this repo is a copy for reference/portability — it does NOT feed the running pod.

## Future: git-sync migration

The current hostPath approach ties the pod to a specific Mac path. The planned evolution is to replace the hostPath PV with a [git-sync](https://github.com/kubernetes/git-sync) sidecar that pulls docs from per-app git repos into an `emptyDir` volume. This makes the server fully portable and docs version-controlled per app.

See [docs/MIGRATION-TO-GIT-SYNC.md](docs/MIGRATION-TO-GIT-SYNC.md) for the full plan.

## Tear down

```bash
./undeploy.sh   # removes deployment/service/ingress/configmap/pvc/pv
                # does NOT touch $DOCS_HOST_PATH — it's just a host folder
```

## Docs

- [docs/README.md](docs/README.md) — access URLs, overview
- [docs/USAGE.md](docs/USAGE.md) — add/edit/delete files, sidebar rules, URL routing, caching
- [docs/MAINTENANCE.md](docs/MAINTENANCE.md) — restart, config changes, troubleshooting
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — tech stack, data layout, design decisions
- [docs/MIGRATION-TO-GIT-SYNC.md](docs/MIGRATION-TO-GIT-SYNC.md) — planned git-sync migration TODO

Also rendered live at https://docs.stoat-perch.ts.net (sidebar → Homelab → Docs server).
