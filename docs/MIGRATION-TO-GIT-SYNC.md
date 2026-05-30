# Migration to git-sync — TODO

## Current state

The docs-server pod mounts `$DOCS_HOST_PATH` (default `/Users/nila/Developer/agents/docs/`) directly via a hostPath PersistentVolume. This works well for a single-node OrbStack k3s setup where the Mac filesystem is always available, but it ties the pod to a specific host path and machine.

All per-app docs (chores, reminders, homelab-cluster-setup, etc.) live under this single directory on the Mac. They are NOT automatically sourced from their respective app repos.

## The problem

- **Not portable:** clone this repo on a different machine and the pod starts, but `$DOCS_HOST_PATH` is empty until you manually populate it.
- **Docs drift:** docs in `agents/docs/homelab-k8s-setup/apps/<app>/` can diverge from docs in each app's own repo (`/apps/<app>/docs/`). Right now the `agents/docs/` copies are authoritative.
- **Manual sync:** adding a new app's docs means manually copying files into `agents/docs/`.

## Planned future: git-sync sidecar

Replace the hostPath PV with a [git-sync](https://github.com/kubernetes/git-sync) sidecar that pulls docs from a dedicated `homelab-docs` git repo (or a mono-repo of symlinked submodule refs) into an `emptyDir` volume.

### Target architecture

```
git-sync sidecar
  ↓ clones/pulls
emptyDir shared volume (e.g. /docs)
  ↓ mounted into
nginx container at /usr/share/nginx/html/docs
```

Each app repo would own its `docs/` folder. A top-level `homelab-docs` repo (or git submodules) would aggregate them. git-sync polls on a configurable interval.

### Benefits

- Fully portable: works on any node with internet access
- Docs are version-controlled per app
- No manual file-copy step for new apps
- Pod restarts pick up the latest docs automatically

### Migration steps (when ready)

1. Create a `seenimurugan/homelab-docs` repo (or use submodules in this repo).
2. Move per-app docs from `agents/docs/<app>/` into `<app-repo>/docs/` and push.
3. Aggregate via `homelab-docs` with submodule or sparse-checkout.
4. Add git-sync sidecar to `k8s/docs-server.yaml`:
   - Replace PV/PVC with `emptyDir`
   - Add `initContainer` + sidecar for `registry.k8s.io/git-sync/git-sync:v4`
   - Mount the shared emptyDir into both git-sync and nginx containers
5. Remove hostPath PV/PVC from the manifest.
6. Update `.env.example` — `DOCS_HOST_PATH` becomes `DOCS_GIT_REPO` + `DOCS_GIT_BRANCH`.

### Not yet done because

- All app docs are currently in `agents/docs/` and have not been migrated to per-app repos yet.
- The live-edit benefit of hostPath (edit .md → refresh → see change) would be lost with git-sync unless a local git push workflow is set up.
- Single-node OrbStack setup: hostPath works perfectly today and has zero complexity.
