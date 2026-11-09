# opencode — requirements record

What podmanager understood this image must do. Project-level background and decision
history: `docs/requirements.md` → Track 1.

## Purpose
An OpenCode coding-agent harness in a container. The model runs natively on the host
(oMLX on the Mac GPU); the container only runs the harness and talks to the host's
OpenAI-compatible endpoint. Rebuilt from an existing, known-good image to prove the
podmanager pipeline (Track 1).

## Image contents
- Base `node:22-bookworm-slim`, plus git, ripgrep, ca-certificates, python3,
  python3-pytest.
- `opencode-ai`, pinned (build arg `OPENCODE_VERSION`, 1.19.0 today). Bump deliberately
  after reading release notes.
- Config baked at `/etc/opencode/opencode.json` (`OPENCODE_CONFIG`), outside
  `/workspace`, so the agent can't edit its own permissions.
- `HOME=/home/agent`, mode 1777, so any UID works. `WORKDIR /workspace`,
  `ENTRYPOINT ["opencode"]`.
- Multi-arch: arm64 and amd64 (T-OPENCODE-04).

## Config
- **Baked default (`opencode.json`): local-only.** OpenCode's own cloud provider is
  disabled, so the image can't reach a cloud model by accident. Provider `omlx`, model
  `omlx/Qwen3.5-9B-oQ4e-mtp`, endpoint `http://host.containers.internal:8000/v1`.
- **API key from the environment:** `"apiKey": "{env:OMLX_API_KEY}"`. The key is passed
  with `podman run -e OMLX_API_KEY` from the vault-loaded shell. It is never baked, never
  written to a file, and not entered by hand with `/connect`.
- **Permissions:** edits allowed except `*test_*.py` and `*fixtures/*`; bash asks by
  default, with read-only commands, pytest and read-only git allowlisted. Autoupdate off,
  sharing disabled.
- **Run-time override:** mount another config over `/etc/opencode/opencode.json`, e.g.
  `-v /config/opencode-any.json:/etc/opencode/opencode.json:ro`.
  `overrides/opencode-any.json` is the all-providers variant (identical except the cloud
  provider stays enabled).
- **OpenShift:** `host.containers.internal` only resolves under Podman on the Mac, so a
  pod in the OpenShift lab always mounts its own config at the same path.

## Run-time contract
- `--userns keep-id`.
- `/workspace` mounted writable; task-specific test files and fixtures mounted read-only
  on top of it.
- Config overrides from `/config` (a machine volume) mount `:ro` without `Z`; `Z` fails
  there. A file on the VM's own disk would need `Z`. Either way, a config the container
  can't read makes OpenCode silently fall back to a cloud model.
- Interactive (`-it`), ephemeral (`--rm`).

## Machine
Profile `machines/opencode.conf`: machine `opencode`, 2 CPU, 2 GiB, 100 GiB disk, rootless.
Volumes: host workspace → `/workspace` (rw), `images/opencode/overrides/` → `/config`
(ro). No `/shared`. Switch with `scripts/machine-switch.sh opencode`.

## Acceptance (smoke test, T-OPENCODE-05)
- Starts under `--userns keep-id`.
- `/workspace` writable, declared files read-only.
- Host model endpoint reachable with the key from `-e OMLX_API_KEY`, no `/connect`.
- **The configured model is the one actually in use.**
- amd64 variant run under emulation at least once.
- Keep prompts small: the host model is shared with other work.

## Publishing
GHCR by digest after the smoke test passes. Namespace and visibility are set in
T-OPENCODE-07 and recorded in `catalogue.md`.
