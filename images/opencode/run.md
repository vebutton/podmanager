# OpenCode — run

Plain commands, run from the repo root on the Mac. Needs `OMLX_API_KEY` in the shell
(loaded from the vault, see `.env.local.example`) and oMLX running on the host (`:8000`).
The run contract behind these flags is in `requirements.md`.

## Start
```sh
scripts/machine-switch.sh opencode
: "${OMLX_API_KEY:?not set: load .env.local (see .env.local.example)}"

podman run -it --rm --userns keep-id \
  -e OMLX_API_KEY \
  -v /workspace:/workspace \
  localhost/podmanager-opencode:test
```
Works as of 2026-11-18. The image is the arm64 test build on the `opencode` machine,
the only OpenCode image there until T-OPENCODE-07 publishes one. `/workspace` is the
machine volume for the host workspace folder (`OPENCODE_WORKSPACE` in
`machines/local.env`). No `Z`: the virtiofs shares carry their own label. The container
starts in `/workspace` with `opencode` as entrypoint, straight into the TUI. `-e` passes
the key by name, so the value never appears on the command line. `--rm`: nothing
survives the session except what is written to `/workspace`.

All-providers config (cloud provider enabled): add before the image name
```sh
  -v /config/opencode-any.json:/etc/opencode/opencode.json:ro \
```
`:ro` without `Z`; `Z` fails on the read-only `/config` share.

SSD models (local-only, adds `omlx/gemma-4-12B-it-oQ4e-mtp`; the default stays
`omlx/Qwen3.5-9B-oQ4e-mtp`, which lives on the Mac's own disk): add before the image name
```sh
  -v /config/opencode-ssd.json:/etc/opencode/opencode.json:ro \
```
Pick the Gemma model in OpenCode's model picker (works with the SSD plugged in,
2026-11-18). Without the SSD plugged in, the
container and OpenCode still start; only a prompt to an SSD model fails (expected, not
yet tested). Edits to `overrides/` apply at the next container start, no rebuild.
`opencode-ssd.json` is generated from `opencode.json`; regenerate it after changing
the baked config:
```sh
jq '.provider.omlx.models["gemma-4-12B-it-oQ4e-mtp"] = {name: "gemma 4 12b it oq4e mtp 48k (SSD)", limit: {context: 49152, output: 8192}}' \
  images/opencode/opencode.json > images/opencode/overrides/opencode-ssd.json
```
The Gemma limits copy Qwen's 48k/8k as a conservative guess; check what oMLX allows.

## Check
- The model in use is `omlx/Qwen3.5-9B-oQ4e-mtp`. A config the container can't read
  makes OpenCode silently fall back to a cloud model.
- GPU Monitor shows GPU utilization while it answers (a human cross-check).
- Model ids: the model is `<provider>/<model>`. Provider `omlx` and model
  `Qwen3.5-9B-oQ4e-mtp` are both defined in `opencode.json`; the model id is the one
  oMLX's `/v1/models` lists.

## Stop
Quit OpenCode; `--rm` removes the container. Nothing else to stop before
`podman machine stop opencode` or a switch.
