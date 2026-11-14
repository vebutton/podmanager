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
  host model; scripted smoke test pending (T-OPENCODE-05). arm64-only for now; amd64
  waits on OpenCode on OpenShift (T-OPENCODE-11).
- **Location:** `images/opencode/`. Rebuilt from an existing image in another project
  (path in `CLAUDE.local.md`), which stays as it is.
- **What it is:** OpenCode coding-agent harness. Talks to a host-side oMLX model server;
  the model does not run in the container. Local-only config baked, all-providers config
  as a run-time override. Details: `images/opencode/requirements.md`.
- **Build:** `node:22-bookworm-slim` base, `opencode-ai` pinned via build arg (1.19.0).
  arm64 only (T-OPENCODE-04 deferred; amd64 in T-OPENCODE-11).
- **Machine:** `machines/opencode.conf` (machine `opencode`: 2 CPU, 2 GiB, `/workspace`
  rw, `/config` ro).
- **Registry:** not published yet (T-OPENCODE-07).
- **Digest:** none yet.
- **Quirks to check:** an unreadable config makes OpenCode silently fall back to a cloud
  model. Overrides from `/config` mount `:ro` without `Z` (`Z` fails on the share). `host.containers.internal` doesn't resolve on OpenShift, so pods there always
  need the config override.

### podmanager-probe
- **Status:** published 2026-11-09. Pulled and run on the OpenShift lab under default
  security settings, with a pull secret (T-OPENCODE-10).
- **Location:** `images/podmanager-probe/`.
- **What it is:** minimal shell image to prove the GHCR → OpenShift path. Stays up with
  `sleep infinity` so the operator can `oc rsh` in. Details:
  `images/podmanager-probe/requirements.md`.
- **Build:** `ubi9/ubi-minimal` base, amd64 only, built under emulation on the `opencode`
  machine. Recipe: `images/podmanager-probe/build.md`.
- **Machine:** `opencode` (build only).
- **Registry:** `ghcr.io/vebutton/podmanager-probe`, private; OpenShift pulls with a
  `GHCR_READ_TOKEN` pull secret (recipe in `build.md`).
- **Digest:** `sha256:4e42fe36867b428a68d32dd2539196b337ab1486076b9e921ceaaa931154e514`
  (tag `0.1`).
- **Quirks to check:** a new GHCR package starts private; visibility is changed in the
  GitHub UI only. Rootless podman can't run OpenShift's high UIDs locally; test with any
  unlisted UID in group 0.

### n8n
- **Status:** running locally, acceptance passed 2026-11-13 (T-PROJ-07). Learning instance
  to judge whether n8n belongs in the OpenShift lab.
- **Location:** `images/n8n/` (requirements record, run recipe and a handoff for projects
  that use the instance, `handoff.md`; no Containerfile).
- **What it is:** n8n workflow automation, upstream image used as is. Details:
  `images/n8n/requirements.md`.
- **Build:** none. `docker.io/n8nio/n8n`, pinned at `2.47.7` (upstream `stable` on
  2026-11-13); multi-arch upstream (amd64, arm64).
- **Machine:** `machines/n8n.conf` (machine `n8n`: 2 CPU, 4 GiB, no host volumes; data
  in the podman volume `n8n_data`).
- **Registry:** upstream Docker Hub; not mirrored to GHCR.
- **Digest:** `sha256:b4b90747b81fcda7e76550c0d3aa7f0f64917a1e9573cff40d6834eaf2e0f8ea`
  (tag `2.47.7`, multi-arch index; confirmed at the first pull 2026-11-13). arm64 platform
  manifest: `sha256:1d1113949e99d64ecf8da7f9504d65d083bc4d4404f9f920a31e47e2524410f2`.
- **Quirks to check:** credentials depend on `N8N_ENCRYPTION_KEY` from the vault, set
  before the first start. The data volume lives in the VM and is lost with
  `podman machine rm n8n` unless exported. Task runners run in internal mode
  (deprecated from 3.0; external mode needs an `n8nio/runners` sidecar). Secure cookies
  are on by default: browse via `localhost` (plain http works there). The Assistant
  reaches oMLX at `host.containers.internal:8000/v1`; the code sandbox service is not set
  up.

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
- **Machine:** none now. It probably ran in the old default Podman machine out of
  convenience (a test machine, not built for it). That machine was removed 2026-11-13,
  along with any image built there; `run.sh` rebuilds the image if missing. Settled in
  T-PROJ-05.
- **Quirks to check:** `run.sh` calls a bare `podman machine start`, which may not respect
  the one-machine-at-a-time rule. Its login helper reads a cluster map from outside the
  project.
