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

## Secrets
- `N8N_ENCRYPTION_KEY` from the vault (`-e N8N_ENCRYPTION_KEY`). n8n encrypts stored
  credentials with it. Without it n8n generates its own key inside the volume, and
  credentials die with the volume. Becomes an OpenShift Secret if this moves there.

## Network
- UI and API on `127.0.0.1:5678` only. No inbound webhooks from outside yet.
- What it talks to (local model servers, cluster APIs, SaaS) is unknown until the
  operator has seen what it is for.

## Acceptance
- `/healthz` returns ok; the UI loads at `http://localhost:5678`.
- A workflow created in the UI survives `podman rm` + re-run (data is in the volume).
- The key comes from the environment: the recipe fails, naming `N8N_ENCRYPTION_KEY`,
  when it is missing.
