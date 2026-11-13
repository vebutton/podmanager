# n8n — run, check, back up

Plain commands, run from the repo root. Needs `N8N_ENCRYPTION_KEY` in the shell (loaded
from the vault, see `.env.local.example`).

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
Open `http://localhost:5678` (`localhost`, not `127.0.0.1`: n8n's secure cookie
accepts plain http only on localhost). The first visit creates the owner account.

## Check
```sh
curl -fsS http://localhost:5678/healthz          # {"status":"ok"}
podman logs --tail 20 n8n
podman image inspect --format '{{.Digest}}' docker.io/n8nio/n8n:2.47.7
```

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
