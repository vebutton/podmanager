# n8n — run, check, back up

Plain commands, run from the repo root. Needs `N8N_ENCRYPTION_KEY` in the shell (loaded
from the vault, see `.env.local.example`) **before the first start**: unset, n8n
generates its own key into the volume instead.

Adapted for podman from n8n's Docker page (docs.n8n.io/hosting/installation/docker/, checked
2026-11-13). Upstream marks that page outdated in favour of Docker Compose and doesn't
mention podman. Same volume, mount path and variables; added: the vault key, a pinned
tag, and the `127.0.0.1` bind.

## Start
```sh
scripts/machine-switch.sh n8n
: "${N8N_ENCRYPTION_KEY:?not set: load .env.local (see .env.local.example)}"
tz=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')   # the Mac's timezone

podman volume exists n8n_data || podman volume create n8n_data
podman run -d --name n8n \
  -p 127.0.0.1:5678:5678 \
  -e TZ="$tz" -e GENERIC_TIMEZONE="$tz" \
  -e N8N_ENCRYPTION_KEY \
  -e N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true \
  -v n8n_data:/home/node/.n8n \
  docker.io/n8nio/n8n:2.47.7
```
Open `http://localhost:5678`, the address the docs use. Secure cookies are on by default
(`N8N_SECURE_COOKIE=true`); login over plain http on `localhost` works (2026-11-13). The
first visit creates the owner account. With no SMTP set up, its email is only a login
name; a lost password is reset with `podman exec n8n n8n user-management:reset`.

## Connect the local model (Assistant)
In n8n's "Connect a model" screen, pick "Self-hosted or OpenAI-compatible endpoint":
- Base URL `http://host.containers.internal:8000/v1` (oMLX on the host; `localhost` is
  the container itself)
- API key: the `OMLX_API_KEY` value from the vault; n8n stores it as an encrypted
  credential in `n8n_data`
- Model: the id that `/v1/models` lists

The "code sandbox" step that follows needs a separate n8n sandbox service, not the model
server. Not set up here; skip it.

## Check
```sh
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:5678/healthz            # 200: reachable
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:5678/healthz/readiness  # 200: DB connected and migrated
podman logs --tail 20 n8n
podman inspect --format '{{.ImageDigest}}' n8n                                  # multi-arch index digest
```
Expect digest `sha256:b4b90747b81fcda7e76550c0d3aa7f0f64917a1e9573cff40d6834eaf2e0f8ea`
(Docker Hub, 2026-11-13; confirmed at the first pull). Don't use
`podman image inspect --format '{{.Digest}}'`: it prints the arm64 platform manifest
(`sha256:1d1113…`), not the index. A deprecation warning about task runners in internal mode is
expected (see `requirements.md`).

## Stop / upgrade
```sh
podman stop n8n && podman rm n8n                 # data stays in n8n_data
```
To upgrade, change the tag in Start and run it again. Read the release notes first.

## Back up the data
The volume lives inside the VM, so `podman machine rm n8n` destroys it. Export it first,
to a host path outside the repo (it holds credentials, encrypted with the vault key):
```sh
podman stop n8n
podman volume export n8n_data --output /path/outside/repo/n8n_data.tar
podman start n8n
```
Restore into a fresh volume with `podman volume import n8n_data <file>`.
