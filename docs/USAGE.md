# Docs site — Usage

How to add, edit, and manage content on the docs site at https://docs.stoat-perch.ts.net.

**On this page:** [Read on phone / laptop](#read-on-phone--laptop) · [Add a new file](#add-a-new-file) · [Add to the sidebar](#add-to-the-sidebar) · [Edit existing files](#edit-existing-files) · [Delete files](#delete-files) · [URL routing rules](#url-routing-rules) · [Caching gotcha](#caching-gotcha)

## Read on phone / laptop

Just open the URL. Docsify-powered, fully responsive, dark mode follows system. Search bar at top-left works.

## Add a new file

Drop the file into `$DOCS_HOST_PATH` (default: `/Users/nila/Developer/agents/docs/`) or any subfolder. It's instantly accessible — no rebuild, no restart.

| File type | URL pattern | What browser does |
|---|---|---|
| `.md` (markdown) | `…/#/path/file` (hash routing) | Rendered with Docsify |
| `.txt`, `.json`, `.yaml` | `…/docs/path/file.txt` | Plain text |
| `.html` | `…/docs/path/page.html` | Renders as HTML |
| `.pdf` | `…/docs/path/file.pdf` | Opens inline |
| `.xlsx`, `.csv` | `…/docs/path/sheet.xlsx` | Downloads (browsers can't render) |
| `.png`, `.jpg` | `…/docs/path/img.png` | Inline display |

## Add to the sidebar

Edit `$DOCS_HOST_PATH/_sidebar.md` (the global nav).

```markdown
* **My new section**
  * [My new page](/homelab-k8s-setup/my-new-page.md)
```

> Sidebar links must use **absolute paths with a leading slash** — see [MAINTENANCE](MAINTENANCE.md#update-sidebar) for the full rule.

Save → refresh page. No restart.

## Edit existing files

Open with any editor:
```bash
code /Users/nila/Developer/agents/docs/homelab-k8s-setup/MAINTENANCE.md
```

Save → refresh page on phone → see update.

## Delete files

```bash
rm /path/to/file.md
```
Also remove any sidebar reference (otherwise broken link sits there).

## URL routing rules

- `https://docs.stoat-perch.ts.net/` → loads `/docs/README.md` (the home)
- `https://docs.stoat-perch.ts.net/#/homelab-k8s-setup/MAINTENANCE` → loads `/docs/homelab-k8s-setup/MAINTENANCE.md`
- `https://docs.stoat-perch.ts.net/docs/anything.txt` → direct file fetch

## Caching gotcha

Docsify uses a service worker that aggressively caches. If you don't see your edits:
- Hard refresh: Cmd+Shift+R (desktop) or hold reload icon on Safari iPhone → "Request without service worker"
- Or DevTools → Application → Storage → Clear site data
- Or open in private/incognito window
