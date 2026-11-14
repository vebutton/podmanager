# n8n — handoff for a project that uses the instance

For a project that builds workflows on the local n8n learning instance. podmanager owns
the container, the machine and the data; the using project owns its workflows and its own
API key. Copy this file into that project (e.g. its `docs/`). State as of 2026-11-13.

## What is running
- n8n `2.47.7` (upstream `docker.io/n8nio/n8n`, digest
  `sha256:b4b90747b81fcda7e76550c0d3aa7f0f64917a1e9573cff40d6834eaf2e0f8ea`), container
  `n8n` in the Podman machine `n8n` on the Apple Silicon host.
- Bound to `127.0.0.1:5678` on the host only. Nothing outside the host can reach it.
- Data (SQLite, credentials, settings) in the podman volume `n8n_data` inside the VM.
- Owner account set up in the UI. Holds one test workflow (`My workflow`) and one
  credential (`n8n Assistant model`, the local model).

## Addresses (from the host)
| What | Address |
|---|---|
| UI | `http://localhost:5678` (use `localhost`: secure cookies are on) |
| Liveness | `http://localhost:5678/healthz` → 200 |
| Ready (DB migrated) | `http://localhost:5678/healthz/readiness` → 200 |
| Public REST API | `http://localhost:5678/api/v1/` (401 without a key: enabled) |
| API reference (Swagger) | `http://localhost:5678/api/v1/docs/` |
| Production webhooks | `http://localhost:5678/webhook/<path>` (workflow must be active) |
| Test webhooks | `http://localhost:5678/webhook-test/<path>` (while "listening" in the editor) |

Before doing anything, check it is up:
```sh
curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:5678/healthz/readiness
```
Anything but `200` (usually "connection refused"): n8n is not running. Don't start it from
the using project (see Rules).

## API access
1. In the UI: **Settings → n8n API → Create an API key**. Copy it once.
2. Store it in the using project's own secrets (vault or gitignored env file), e.g.
   `N8N_API_KEY`. Never commit it, never put it on a command line.
3. Call the API with the header `X-N8N-API-KEY`:
   ```sh
   curl -fsS -H "X-N8N-API-KEY: $N8N_API_KEY" http://localhost:5678/api/v1/workflows
   ```
   The header and the Settings path are from n8n's docs; only the 401 without a key was
   tested here.

Suggested workflow-as-code loop: keep workflow JSON in the using project's git, push it
with `POST`/`PUT /api/v1/workflows`, pull with `GET`. Exported workflow JSON references
credentials by ID and name, not by secret value, but check exports before committing
(pinned data and hard-coded values in nodes do get exported).

## What n8n can reach
- Host services at `host.containers.internal:<port>` (inside the container, `localhost`
  is the container itself).
- Local model: oMLX at `http://host.containers.internal:8000/v1`, already set up as the
  credential `n8n Assistant model` (OpenAI-compatible). Use that credential in AI nodes;
  don't create a second copy of the key. The model is shared with another project: keep
  prompts small.
- The internet: outbound is open (no egress limits on this instance).
- No host directories are mounted. Files in or out go through the API, webhooks, or
  `podman cp` (ask podmanager).

## Not available
- **Code sandbox service** (used by the Assistant and Agents to run code and handle
  files): not set up. Ordinary Code nodes work (built-in task runner, internal mode).
- **Inbound webhooks from outside the host:** no tunnel, no public URL.
- **Email:** no SMTP. No invites or password resets by email.
- **Paid features:** the free community activation key was skipped (no folders, no
  advanced debugging, no execution search).
- Telemetry to n8n is on (default). It may be turned off after 2026-11-14.

## Rules for the using project
- **Don't manage the container or the machine.** No `podman machine start/stop`, no
  `podman run/rm` of `n8n`, no changes to `n8n_data`. Only one Podman machine runs at a
  time on this host, and switching machines stops others. If n8n is down, the operator
  starts it from podmanager (`scripts/machine-switch.sh n8n`, then the Start block in
  `images/n8n/run.md`).
- **Ask podmanager for any change to the instance:** environment variables, ports, host
  mounts, the sandbox service, community nodes, upgrades (version is pinned), backups.
- **The encryption key is podmanager's.** The using project never needs
  `N8N_ENCRYPTION_KEY`; it only needs its own API key.
- **Data lives in the VM.** Treat workflows in git as the durable copy. podmanager exports
  the volume before any machine removal, but this is a learning instance, not a service.
- It runs only while the operator uses it. Expect it to be stopped when another machine
  (e.g. `opencode`) is in use.
