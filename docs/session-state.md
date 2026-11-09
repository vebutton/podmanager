# Session State — Archaeology

> Backward-looking detail: thread-by-thread work, decisions and reasoning, ruled-out
> paths, commits, memories banked. The forward-looking brief lives in CLAUDE.md ->
> Session State. Consult this file on demand when depth is needed.

## 2026-11-08 — Session 2: OpenCode image survey, secrets template

### Survey (read-only: source projects, `opencode-lab` VM, local image)
- The "missing" `opencode-qwen-mlx.json` exists in the older sibling source project and in
  the VM home. Not needed anyway after the config decision below.
- The local `opencode-lab:1.19.0` image bakes `opencode-qwen.json`
  (`ollama/qwen3.5:9b` via Ollama on `:11434`, from when the models were on the external
  SSD). It works only because of the `:ro,Z` run-time mount.
- Both current run-time configs (`any`, `local-only`) set `"model": "Qwen3.5-9B-MLX-4bit"`.
  The provider (named after the host) defines only `Qwen3.5-9B-oQ4e-mtp`, and the value
  isn't in `provider/model` form. local-only probably works because that model is the only
  fallback. any could fall back to an OpenCode cloud model without saying so. That is
  inferred from the config, not tested.
- VM home holds 5 configs. gemma and qwen point at Ollama `:11434` and are stale.
- `podman-machine-default` (about 13 months old, 5 CPU / 2 GiB) was not started because
  only one machine runs at a time. The operator thinks it runs web-terminal.
- oMLX `/v1/models` rejects requests without an API key. Today the operator enters the
  key by hand with `/connect` each session. It's saved under `$HOME` in the `--rm`
  container and lost on exit.
- The operator confirmed that Claude in OpenCode needs an Anthropic API key. A Claude
  subscription login can't be used there.

### Decisions
- Bake local-only as the default. all-providers is a run-time override.
- Drop the Ollama configs. oMLX only.
- Fix the model reference: rename the provider to the generic `omlx` (the old name was
  the host's name, and the repo is public) and use `omlx/Qwen3.5-9B-oQ4e-mtp`.
- oMLX key: `"apiKey": "{env:OMLX_API_KEY}"` plus `podman run -e OMLX_API_KEY`. Not yet
  verified (T-OPENCODE-05). The agent can read its own environment. Accepted as low risk
  for a local key.
- Secrets template: `export KEY="value"` only. Reasons: `source` would try to run YAML or
  bare-value lines and echo the secret, and podman `--env-file` keeps quotes in the value.
  `vault_ghcr_*` became `GHCR_USER` / `GHCR_WRITE_TOKEN` / `GHCR_READ_TOKEN`.
  `GITHUB_TOKEN` was removed because it overrides the `vebutton` gh keyring login. The
  Slack token is kept as optional. Target is `source <(ansible-vault view .env.local)`.
- `podman-machine-default` is left alone for now. web-terminal is catalogued (stub) and
  surveyed later as T-PROJ-05.

### Later in the session
- **Triage sheet v1** made at `reminders/20261108_podmanager_Triage_Sheet_v1.pdf` (HTML
  printed with headless Chrome, one Letter page). `reminders/` is gitignored.
- **Atlas overview** created at `.atlas/overview.md` (gitignored): slug/title
  `podmanager`, visibility public, role_fit ai-lead + innovation-lead. The operator
  answered: self-initiated; DR-product hooks feature is publicly announced; podmanager
  runs on both Apple Silicon hosts. Two `[NEEDS]` markers remain (measurable result, proof
  link), both waiting on T-OPENCODE-05/07.
- **GHCR namespace is per image**, not one project namespace. Recorded in requirements
  (Publish) and T-OPENCODE-07. Left open on purpose ("figure out as we go"): whether
  each namespace needs its own credentials, given the env template has one GHCR set.
  To settle at T-OPENCODE-07.

### Commits
- `0816ebb` T-OPENCODE-02: record OpenCode config decisions; add env template, catalogue,
  T-PROJ-05.
- `313a08c` Session close: CLAUDE.md brief + this file.
- `d9c6f88` T-OPENCODE-07: GHCR namespace per image; gitignore `reminders/`. All three
  pushed.
- Final session-close commit (this update).
