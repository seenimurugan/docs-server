# Migration to git-sync — DONE

> **Status: COMPLETED** — The migration from hostPath to a git-puller sidecar was completed on 2026-05-30.

**On this page:** [What changed](#what-changed) · [New architecture](#new-architecture) · [Auth: gh CLI token (not a PAT)](#auth-gh-cli-token-not-a-pat) · [Repo for top-level docs](#repo-for-top-level-docs) · [Auto-discovery](#auto-discovery) · [Old state (for reference)](#old-state-for-reference) · [Fallback](#fallback)

## What changed

| Before | After |
|--------|-------|
| hostPath PV mounting `/Users/nila/Developer/agents/docs/` | `emptyDir` shared between nginx + git-puller sidecar |
| Tied to specific Mac path | Fully portable |
| Manual file copy for new apps | Auto-discovered from GitHub |
| No versioning | Per-app docs version-controlled in each app repo |
| Single `_sidebar.md` maintained by hand | Auto-generated on every sync cycle |

## New architecture

```
git-puller sidecar (bitnami/git)
  ↓  queries GitHub API for seenimurugan/* repos with docs/
  ↓  clones/pulls each into emptyDir at /docs-aggregated
  ↓  auto-generates _sidebar.md

emptyDir (/docs-aggregated)  ← shared between both containers
  ↓  mounted read-only

nginx container
  ↓  serves /usr/share/nginx/html → /docs-aggregated
  ↓  docsify renders .md files in the browser
```

## Auth: gh CLI token (not a PAT)

The GitHub token is extracted from the user's existing `gh` CLI session at deploy time:

```bash
GITHUB_TOKEN=$(gh auth token)
kubectl create secret generic docs-puller-secret \
  -n homelab \
  --from-literal=GITHUB_TOKEN="$GITHUB_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -
```

No manual PAT creation. If you re-authenticate with `gh`, re-run `./deploy.sh` to refresh the secret.

## Repo for top-level docs

A new repo [`seenimurugan/homelab-docs`](https://github.com/seenimurugan/homelab-docs) holds the landing page (`docs/README.md`) and sidebar reference (`docs/_sidebar.md`). The puller symlinks its files into the aggregated root and auto-generates the live sidebar from the full repo tree.

## Auto-discovery

The puller queries `https://api.github.com/users/seenimurugan/repos` and filters to repos that have a `docs/` folder. No manual repo list — push a `docs/` folder to any `seenimurugan/*` repo and it appears automatically within 5 minutes.

## Old state (for reference)

Previously: all per-app docs lived under `/Users/nila/Developer/agents/docs/` as subfolders, served via a hostPath PV. The `docs/` folders in each app repo existed but were NOT served by the live site.

## Fallback

The legacy manifest is preserved at `k8s/docs-server-legacy-hostpath.yaml`. To revert:
1. Set `DOCS_SOURCE=hostpath` in `.env`
2. Re-run `./deploy.sh`
