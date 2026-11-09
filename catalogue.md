# podmanager — Image catalogue

Images podmanager knows about: built here, or living in other projects (catalogued, not
absorbed). Host paths are never written here; they live in `CLAUDE.local.md` → Paths.
Private entries go in the gitignored `catalogue.local.md`.

**Entry format** (one `###` per image, under *Images built here* or *External images*):
- **Status:** catalogued / surveyed / built here / published
- **Location:** `images/<name>/` or a generic description of where it lives (path in
  `CLAUDE.local.md`)
- **What it is:** purpose and main contents
- **Build:** base image, how it builds, tags and pins
- **Machine:** the machine profile it needs
- **Registry:** GHCR namespace and package visibility (published images only)
- **Digest:** the manifest-list digest last published (published images only)
- **Quirks to check:** anything surprising or unconfirmed

## External images

### web-terminal
- **Status:** Catalogued only. Not surveyed yet.
- **Location:** the operator's lab install area (path in `CLAUDE.local.md`). Not a git
  repo.
- **What it is:** browser-accessible lab terminal. `ttyd` serves a `tmux` session over
  TLS on `127.0.0.1:7681`, for split-screen demos beside a cluster console. Preinstalls
  the OpenShift, OpenStack and Ansible CLI toolchain plus a live cluster-login helper.
  No credentials baked in.
- **Build:** `fedora:41` base, arch-aware at build time. `run.sh` builds the image if
  missing (tag `lab-terminal:latest`, unpinned), generates a local cert (mkcert, or a
  self-signed fallback) and runs it `--rm`.
- **Machine:** probably the older default Podman machine (5 CPU, 2 GiB). Unconfirmed.
- **Quirks to check:** `run.sh` calls a bare `podman machine start`, which may not respect
  the one-machine-at-a-time rule. Its login helper reads a cluster map from outside the
  project.
