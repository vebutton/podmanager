# podmanager — Project Context for Claude Code

## Environment
- First started: CLI
- Date: 2026-11-08

## User
The operator: a solutions architect who builds lab environments on Apple Silicon Macs and
an OpenShift lab, and is comfortable with Podman, containers and Kubernetes. Committed
files never name the user or their employer: both live in `CLAUDE.local.md`, so this file
reads correctly in any teammate's session.

## This Project
A lab factory for Podman **machines** and container **images** on the operator's Apple
Silicon hosts. It replaces hand-run Podman builds with a repeatable process: pick a
machine profile, build the image for both architectures, test it, publish it to GHCR by
digest so the OpenShift lab can pull it. It covers any image: the operator's own dev tools
(an OpenCode harness, a Claude Code sandbox for a sibling project) and prototypes of
customer-facing images (an S3 validator, hook containers for the employer's DR product).
For the customer-facing ones, the employer's engineering team builds the official
versions. podmanager hands them a package to work from.

- **Full requirements:** [docs/requirements.md](docs/requirements.md)
- **Task register:** [TODO.md](TODO.md) is the only durable task list. Read it before
  planning any work.
- **Internal details:** `CLAUDE.local.md` is gitignored. Read it every session. It holds
  the user's name and employer, internal product names, the sandbox project's real name,
  hosts, the vault path, and paths to collateral in other projects.

## Input / Output
- **Input:** Natural-language image requirements, pasted by the operator or handed over by
  another project. podmanager writes down what it understood as
  `images/<name>/requirements.md`.
- **Output:**
  - machine profiles and running Podman machines
  - multi-arch images (local, then GHCR pinned by digest)
  - plain CLI recipes for people who don't use Claude
  - for customer-facing images, an engineering handoff package in `output/`

## Interface
Mainly Claude Code in this repo ("build me a machine and an image for X"). Thin shell
scripts underneath do the work, and they double as the plain CLI recipes.

## Key Integrations
- Podman / `podman machine` on macOS (applehv VMs)
- GHCR (push by digest; the OpenShift lab pulls from it)
- Ansible Vault env file (secrets at run time only)
- Existing image projects elsewhere on disk: catalogued, not absorbed

## Tech / Tooling
- **Declarative files + thin shell scripts.** Machine profiles are small config files.
  Each image is a directory: Containerfile, requirements record, build notes. Scripts wrap
  `podman machine`, `podman build --platform`, `podman manifest`. Claude drives this
  layer.
- **Python only if the logic gets heavy.** Then use pyenv + uv (`pyproject.toml`,
  `.python-version`, `uv.lock` committed). Never venv directly, Poetry, Conda or Pipenv.
- **Multi-arch on the Mac.** arm64 runs natively and amd64 under emulation. No remote
  builder: the images are small and slow amd64 builds are acceptable.

## Hard Rules
- **Secrets never land in an image layer, a handoff package, a log, or a committed file.**
  They come from the vault env file at run time.
- **Public repo.** Some images are public, others are kept out of the repo or obfuscated.
  Private material goes in gitignored locations (see requirements → public/private split).
  Host paths containing the username never get committed.
- **Only one Podman machine runs at a time.** Switching means stopping the current machine
  and starting the target.
- **Test locally before publishing.** Nothing goes to GHCR until the local build passes
  its smoke test.
- **Don't modify other projects.** Image projects elsewhere on disk are read-only to
  podmanager unless the operator says otherwise.

## How to Work With This User
- Be direct and concise. Ask questions in batches.
- Before doing something non-trivial, say briefly why.
- Confirm before anything destructive, e.g. `podman machine rm` or image prune.
- Commit with `git commit -F <file>`. Never amend, never `--no-verify`.
- **Git identity:** this repo uses a repo-local identity that differs from the global git
  config. See `CLAUDE.local.md` → Git / GitHub identity, and verify it before every
  commit.

---

## Tracks

> Tracks say what the project is trying to do. Work items live in `TODO.md`, with IDs
> prefixed `T-<SLUG>-<nn>`. Slugs are permanent.

### Track 1 — OpenCode pipeline proof (OPENCODE)
- **Objective:** Rebuild the existing OpenCode image end to end inside podmanager: machine
  profile → multi-arch build → local smoke test → GHCR push by digest. This proves the
  whole pipeline against an image already known to work.
- **Status:** Not started.
- **Depends on:** Nothing. This is the first track.

### Track 2 — Claude Code sandbox image (SANDBOX)
- **Objective:** A locked-down Claude Code image and machine profile that meets the sandbox
  project's requirements: read-only workspace, egress limited to the model endpoint,
  scoped key at run time, ephemeral.
- **Status:** Not started. It is unsettled whether the image gets built here or in the
  sandbox project (TODO.md §3).
- **Depends on:** Track 1. It reuses the pipeline and is nearly a copy of the OpenCode
  image.

**Further tracks:** none yet. Whether each future image gets its own track is an open
question (TODO.md §3).

---

## Session State

> Forward-looking operating context only. Archaeology lives in `docs/session-state.md`.
> Task state lives in `TODO.md`.

**Last (2026-11-08):** Surveyed the existing OpenCode image and the `opencode-lab` VM.
Config decisions recorded (requirements → Config decisions). Added `.env.local.example`,
a first `catalogue.md` entry (web-terminal), and T-PROJ-05. GHCR namespace is now per
image. Also made a first triage sheet (`reminders/`) and the Atlas overview (`.atlas/`);
both are gitignored. No code yet. Everything is pushed.

**Next session — pick up here:**
1. Cold start: re-read CLAUDE.md and CLAUDE.local.md.
2. T-OPENCODE-01: settle the repo layout and the public/private split. `catalogue.md`
   already exists at the root, so the layout should keep it there or move it deliberately.
3. T-OPENCODE-02: write `images/opencode/` with the fixed local-only config (provider
   `omlx`, model `omlx/Qwen3.5-9B-oQ4e-mtp`, `apiKey: {env:OMLX_API_KEY}`). Still open:
   do the model name and host endpoint go public or get parameterised?
4. `.env.local` exists and is vault-encrypted in place. Load it with the snippet in
   `.env.local.example`, not `source <(ansible-vault view …)` (T-OPENCODE-06).

**Continuity reminders:**
- Secrets template format is `export KEY="value"` only. Pass secrets to containers with
  `-e NAME`, never `--env-file` (podman keeps the quotes as part of the value).
- Don't set `GITHUB_TOKEN` in this repo: it overrides the `vebutton` keyring login for `gh`.
- The existing local `opencode-lab:1.19.0` image bakes an old Ollama config. It only
  works because a config is mounted over it at run time. Don't use it as a reference for
  the config.
- `podman-machine-default` probably runs web-terminal. Leave it alone until T-PROJ-05.
- The oMLX model is shared with another project. Keep smoke-test prompts small.
- GHCR namespaces differ per image. Whether each one needs its own credentials in
  `.env.local` is still open; settle it at T-OPENCODE-07.
- podmanager runs on both Apple Silicon hosts, not only this one.
- Refresh `.atlas/overview.md` at end of session when the project moved. Two markers are
  open there, both waiting on T-OPENCODE-05/07.
- Containers mount OpenCode config `:ro,Z`. Without `Z` the config is corrupted and
  OpenCode silently falls back to a cloud model. The smoke test must check which model is
  actually in use.
- The OpenCode image runs with `--userns keep-id`. Its home is a world-writable
  `/home/agent`, and its config is baked at `/etc/opencode`, outside `/workspace`, so the
  agent can't edit its own permissions.

**Session continuity:** Next session is a cold start, so re-read CLAUDE.md before doing
anything. Sessions are never re-entered. End-of-session updates cover three layers: this
brief, `docs/session-state.md`, and `TODO.md`.
Full archaeology: `docs/session-state.md` — consult when prior-thread depth, decision
reasoning, or ruled-out paths are needed.
