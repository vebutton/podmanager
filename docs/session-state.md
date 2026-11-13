# Session State — Archaeology

> Backward-looking detail: thread-by-thread work, decisions and reasoning, ruled-out
> paths, commits, memories banked. The forward-looking brief lives in CLAUDE.md ->
> Session State. Consult this file on demand when depth is needed.

## 2026-11-13 — Session 4: default machine removed, T-OPENCODE-04 deferred

### `podman-machine-default` removed
- The operator found that the machine was created as a test, to avoid using Red Hat's
  Validated Patterns container, and said it could be deleted. It was stopped and not
  the default connection; removed with `podman machine rm -f` (its two connections went
  with it). Not reversible: any images on that VM are gone.
- The operator then corrected themselves: web-terminal probably used it out of
  convenience. Records updated to say so. web-terminal has no machine now; `run.sh`
  rebuilds its image if missing. Its bare `podman machine start` would now start
  `opencode` (the default connection). Settled in T-PROJ-05.
- Red Hat's Validated Patterns utility container went into TODO §5 Unscheduled (may
  have reusable Ansible tooling). Promoting it to an item was offered (would be
  T-PROJ-07); not taken up.

### T-OPENCODE-04 deferred, T-OPENCODE-11 added
- The operator has no amd64 host with a GPU, so an amd64 OpenCode image has no use yet.
  The amd64 requirement had come only from the "multi-arch by default" rule, not from a
  stated OpenShift use case.
- Point made: OpenCode itself needs no GPU, only the model server does. So OpenCode on
  OpenShift is a model-endpoint design question, not a hardware blocker.
- Decided (operator): OpenCode stays arm64-only. T-OPENCODE-04 closed as deferred; the
  generic multi-arch build script comes with T-PROJ-02 (S3 validator, x86 OpenShift).
  T-OPENCODE-05 tests arm64 only; T-OPENCODE-07 pushes a single-arch image by digest.
  The amd64 → GHCR → OpenShift route is already proven by the probe (T-OPENCODE-10).
- New T-OPENCODE-11: OpenCode on OpenShift as an in-cluster troubleshooting agent,
  modelled on an engineering-team tool (real name in `CLAUDE.local.md`). The operator
  expects engineering to share it. Low priority.

### Commits (not pushed)
- `69fc1ec` T-OPENCODE-04 deferred: OpenCode arm64-only, add T-OPENCODE-11
- Session close commit (this entry and the CLAUDE.md brief).

## 2026-11-09 — Session 3: vault loading, layout, opencode image + machine, GHCR probe

### Secrets loading (T-OPENCODE-06)
- `source <(ansible-vault view .env.local)` did not load the variables in the operator's
  zsh. Likely cause (not tested, needs the password): the process substitution runs
  ansible-vault without the terminal for its password prompt. Working form, from the
  operator: `ansible-vault decrypt --output -` into a variable, then
  `source /dev/stdin <<< …`, then `unset`. Recorded in `.env.local.example`.
- `.env.local` is encrypted in place (`$ANSIBLE_VAULT` header) and gitignored. The
  operator briefly had `.env.local.example` gitignored by a misunderstanding; reverted:
  the template stays committed.
- Added `scripts/vault-pass.sh` (osascript hidden-answer dialog) + repo `ansible.cfg`
  (`vault_password_file`, resolved relative to the cfg). Lets ansible-vault run with no
  tty, e.g. from Claude's tool shell. Tested: decrypt to `/dev/null`, exit 0. This
  reconstructs how a previous project prompted the operator; that project was not read.
- Decision: scripts expect secrets already in the shell (loaded before starting Claude
  Code); they don't decrypt. Missing variable → fail naming it, never the value. Claude
  checks names with `printenv | cut -d= -f1`.

### Layout (T-OPENCODE-01, closed)
- Gitignored `images-private/` + `catalogue.local.md` (no separate private repo; trade-off:
  not versioned/backed up). `.conf` profiles as shell-sourceable `KEY=value`. Per-host
  `machines/local.env`. Catalogue entry format = web-terminal fields + Registry + Digest.

### OpenCode image (T-OPENCODE-02, closed)
- Model name and `host.containers.internal:8000` baked in public: nothing identifying,
  and anyone pulling from GHCR can read the baked file anyway. Mount override kept.
  OpenShift pods always need the override (that hostname only resolves under Podman).
- `images/opencode/`: Containerfile (version as build arg, OCI source label),
  `opencode.json` (provider `omlx`, model `omlx/Qwen3.5-9B-oQ4e-mtp`,
  `apiKey {env:OMLX_API_KEY}`), `overrides/opencode-any.json` generated from it (the
  source's copy still had the broken model ref), `requirements.md`.
- arm64 test build (~27 s): version 1.19.0, keep-id UID 501, HOME writable,
  `opencode models omlx` lists the model. Avoided `opencode debug config` (would print the
  substituted key). The operator then ran it interactively against oMLX: works.
- Operator's GPU Monitor app noted in `CLAUDE.local.md` (oMLX: watch GPU Utilization only).

### Machine profile + switch (T-OPENCODE-03, closed)
- Facts: Podman 6.1.4; `machine set` can't change volumes; `opencode-lab` shared one host
  folder at `/workspace`; virtiofs mounts carry `context=nfs_t`; SELinux enforcing.
- Operator decisions: config overrides from the repo shared read-only as `/config`; plus
  one fixed shared volume `/shared` (`PODMANAGER_SHARED`, next to the repo, rw in the VM,
  opt-in per profile; e.g. the sandbox machine stages dirs, scans, wipes). opencode does
  not opt in. New machine `opencode`; `opencode-lab` kept stopped. Same workspace folder.
- Findings: applehv ignores `:ro` (a test `touch` wrote into the repo; deleted) → the
  script remounts `:ro` targets in the VM after start (lost on reboot). Overrides from
  `/config` must be `:ro` without `Z` (Z → lsetxattr read-only error). The old "always Z"
  rule only applied to files on the VM disk.
- `machine list` `.Name` carries `*` for the default; the script strips it. bash 3.2
  empty-array guard added. Default connection now set before start (Podman Desktop popped
  a "not the default" warning in the gap).
- Proposed and added T-OPENCODE-09 (remove `opencode-lab` after T-OPENCODE-05).

### GHCR → OpenShift probe (T-OPENCODE-10, closed)
- The sibling project said GHCR is the easiest way into the OpenShift lab, so the
  operator asked for a simple amd64 shell image first. Operator choices: `vebutton`
  namespace, public, name `podmanager-probe`, build on `opencode`.
- `ubi9-minimal` + tools, USER 1001, group-0 HOME, `sleep infinity`. amd64 via the VM's
  qemu-x86_64 binfmt; built in ~14 s. Local test: `--user 1000680000:0` fails rootless
  (outside the userns map); `54321:0` passed.
- Pushed with a temporary auth file; digest
  `sha256:4e42fe36…154e514`. Anonymous pull → 403 (new packages are private).
- The operator pulled it on OpenShift with a `GHCR_READ_TOKEN` pull secret instead of
  making it public; runs under default security, `oc rsh` works. Kept private (the route
  private images need). The operator's tested recipe (collateral, Keychain-sourced) was
  adapted to the vault env; their actual first run had the token in `oc`'s argv, so the
  recipe warns against `--docker-password`.

### Other
- Added T-PROJ-06 (request handoff file for other projects) and a standing CLAUDE.md rule:
  triage sheets always cover the catalogue and both handoff directions.
- Rich-text clipboard summary of the `opencode` machine made for the operator (scratch).
- Clarified for the operator: the probe build used the `opencode` *machine*, not the
  OpenCode agent; any machine with the emulator would do.

### Commits (all pushed)
- `d62e0eb` vault load snippet + dialog password client
- `0627908` scripts expect secrets pre-loaded
- `67e8d5d` T-OPENCODE-01 closed; bake model/endpoint in public
- `58fc654` T-OPENCODE-02 `images/opencode`
- `1475ee8` T-OPENCODE-03 profile + switch script; T-OPENCODE-09
- `07d9330` T-PROJ-06
- `e0f18e2` triage-sheet rule
- `511bb9a` T-OPENCODE-10 probe image
- Final session-close commit (this update).

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
