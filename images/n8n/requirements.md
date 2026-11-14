# n8n — requirements record

## Purpose
Evaluate n8n (workflow automation) locally, to see whether it is worth running in the
OpenShift lab (T-PROJ-07). A learning instance, not a service: it runs only while the
operator uses it, and switching machines stops it.

## Image
- Upstream `docker.io/n8nio/n8n`, used as is (nothing built here). Pinned by tag, never
  `:latest`; the digest pulled is recorded in `catalogue.md`.
- arm64 natively on the Mac. Upstream is multi-arch, so amd64 for OpenShift needs no
  build.
- Data (SQLite, settings) in the podman volume `n8n_data` at `/home/node/.n8n`.

## Machine
- n8n publishes no CPU or memory figures (production-requirements and memory-errors
  pages, checked 2026-11-13). 2 CPU / 4 GiB is podmanager's own choice for a learning
  instance; raise it if workflows handle large data (`NODE_OPTIONS=--max-old-space-size`).
- Built-in SQLite: upstream says it "suits testing and small setups" and recommends
  PostgreSQL for production. Enough here; PostgreSQL is an OpenShift-time question.

## Task runners
- Code nodes run in a task runner. With nothing set, 2.x runs it in internal mode (a
  child process), which upstream calls insecure and deprecates from 3.0. Fine for
  learning. From 3.x, or on OpenShift, use external mode: an `n8nio/runners` sidecar at
  the same version as `n8nio/n8n`.

## Secrets
- `N8N_ENCRYPTION_KEY` from the vault (`-e N8N_ENCRYPTION_KEY`). n8n encrypts stored
  credentials with it. Without it n8n generates its own key inside the volume, and
  credentials die with the volume. Becomes an OpenShift Secret if this moves there.

## Network
- UI and API on `127.0.0.1:5678` only. No inbound webhooks from outside yet.

## Files
- An inbox (read-only) and an outbox (writable) from the host, mounted at
  `/home/node/.n8n-files/{inbox,outbox}`. Nothing else from the host reaches the machine
  or the container. A profile with no volumes is not "no host access": podman then
  shares its defaults (`/Users`, `/private`, `/var/folders`).
- What it talks to (local model servers, cluster APIs, SaaS) is unknown until the
  operator has seen what it is for.

## Acceptance
- `/healthz` and `/healthz/readiness` return HTTP 200; the UI loads at
  `http://localhost:5678`.
- The running image's digest matches the one recorded in `catalogue.md`.
- A workflow created in the UI survives `podman rm` + re-run (data is in the volume).
- The key comes from the environment: the recipe fails, naming `N8N_ENCRYPTION_KEY`,
  when it is missing.
