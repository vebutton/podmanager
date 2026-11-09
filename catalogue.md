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

## Images built here

### opencode
- **Status:** built here. arm64 test build (2026-11-09) ran interactively against the
  host model; multi-arch build and scripted smoke test pending (T-OPENCODE-04/05).
- **Location:** `images/opencode/`. Rebuilt from an existing image in another project
  (path in `CLAUDE.local.md`), which stays as it is.
- **What it is:** OpenCode coding-agent harness. Talks to a host-side oMLX model server;
  the model does not run in the container. Local-only config baked, all-providers config
  as a run-time override. Details: `images/opencode/requirements.md`.
- **Build:** `node:22-bookworm-slim` base, `opencode-ai` pinned via build arg (1.19.0).
  Multi-arch build script: T-OPENCODE-04.
- **Machine:** 2 CPU, 2 GiB, workspace volume (profile: T-OPENCODE-03).
- **Registry:** not published yet (T-OPENCODE-07).
- **Digest:** none yet.
- **Quirks to check:** config mounts need `Z`, or OpenCode silently falls back to a cloud
  model. `host.containers.internal` doesn't resolve on OpenShift, so pods there always
  need the config override.

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
