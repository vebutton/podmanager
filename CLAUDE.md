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
- **Triage sheets (`reminders/`) always cover the catalogue and the handoff.** Every new
  or updated sheet includes the state of `catalogue.md` (entries, what's pending) and of
  the handoff: the request file other projects use to ask for a machine and image
  (T-PROJ-06) and the engineering handoff package for customer-facing images (`output/`).
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
  profile → build → local smoke test → GHCR push by digest. This proves the whole
  pipeline against an image already known to work. OpenCode is arm64-only for now; the
  amd64 → OpenShift leg is proven by the probe (10), and OpenCode on OpenShift waits as
  T-OPENCODE-11.
- **Status:** In progress. Done: layout (01), `images/opencode/` (02), machine profile +
  switch script (03), GHCR → OpenShift probe (10); multi-arch build (04) deferred. Next:
  smoke test (05).
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

**Last (2026-11-13, session 6):** Short session. Recorded the sibling project
`n8n-sandbox` as a user of the n8n instance (catalogue **Used by** field). Key split
confirmed: podmanager holds `N8N_ENCRYPTION_KEY`; `n8n-sandbox` holds its own
`N8N_API_KEY` and reuses the stored oMLX credential. Also wrote up the post-close work
from session 5 (T-PROJ-07 closed, handoff, inbox/outbox). `machine-switch.sh` now
refuses podman's default shares and checks mounts against the profile before every
start. All commits pushed.

**Next session — pick up here:**
1. Cold start: re-read CLAUDE.md and CLAUDE.local.md. `n8n` is **running**
   (`opencode`, `opencode-lab` stopped). Switch only via `scripts/machine-switch.sh`;
   switching stops n8n, which `n8n-sandbox` depends on (tell the operator).
2. After the n8n event (2026-11-14): ask the operator whether n8n stays. Decide
   telemetry (`N8N_DIAGNOSTICS_ENABLED`) and whether to propose an OpenShift item (new
   ID, not a change to T-PROJ-07).
3. T-OPENCODE-05: scripted smoke test, arm64 only, on machine `opencode`. It also
   finishes T-OPENCODE-06 (fail on a missing variable, naming it, never a value). The
   operator watches GPU Monitor (`CLAUDE.local.md`) as a human cross-check.
4. After 05 passes: T-OPENCODE-09 (remove `opencode-lab`, only with explicit OK), then
   T-OPENCODE-07 (push the single-arch arm64 image; `images/podmanager-probe/build.md`
   holds the proven push recipe) and T-PROJ-06 (request handoff file; `images/n8n/
   handoff.md` is a usable model for the "using" side).

**Open items carried:**
- Latest triage sheet is v2 (`reminders/`, 2026-11-13). The next one should show
  T-PROJ-07 closed and must cover the catalogue and the handoff.
- Whether other GHCR namespaces need their own credentials (T-OPENCODE-07). The single
  `GHCR_*` set works for `vebutton`.
- Test images on the `opencode` machine: `podmanager-opencode:test`,
  `podmanager-probe:0.1`. The probe pod may still be in the operator's OpenShift
  namespace.
- web-terminal has no machine. Its `run.sh` bare `podman machine start` would start the
  default connection and build into it. Don't run it before T-PROJ-05 gives it a
  profile.
- `N8N_API_KEY` untested from podmanager (lives in `n8n-sandbox`); only the 401 without
  a key is tested. Fine unless `n8n-sandbox` reports a problem.
- The n8n volume export made during the recreation sits outside the repo; where is not
  recorded. Ask before relying on it.

**Continuity reminders:**
- Secrets come from the vault-loaded shell (`.env.local`, decrypted with the snippet in
  `.env.local.example`). `ansible.cfg` makes `ansible-vault` ask via a macOS dialog, so it
  also works from Claude's tool shell. Check variable names only, never print values.
- Tokens never go on a command line: stdin into `podman login` with a temporary
  `--authfile`, removed by `trap` (see `images/podmanager-probe/build.md`).
- Secrets template format is `export KEY="value"` only. Pass secrets to containers with
  `-e NAME`, never `--env-file` (podman keeps the quotes as part of the value).
- Don't set `GITHUB_TOKEN` in this repo: it overrides the `vebutton` keyring login for `gh`.
- New GHCR packages start private; visibility changes only in the GitHub UI.
- Machine volumes are fixed at `podman machine init`. applehv ignores `:ro` on them;
  `scripts/machine-switch.sh` remounts them read-only. Images live per machine.
- OpenCode config overrides come from the `/config` machine volume, mounted `:ro`
  **without** `Z` (`Z` fails on the read-only share). An unreadable config makes OpenCode
  silently fall back to a cloud model, so the smoke test must check the model in use.
- Rootless podman can't map OpenShift's high UIDs; test locally with any unlisted UID in
  group 0.
- The OpenCode image runs with `--userns keep-id`, home `/home/agent` (1777), config baked
  at `/etc/opencode` outside `/workspace`.
- The old `opencode-lab:1.19.0` image bakes a stale Ollama config. Don't use it as a
  reference.
- `podman-machine-default` (a test machine, removed 2026-11-13) probably also hosted
  web-terminal out of convenience. web-terminal has no machine now (T-PROJ-05).
- Third-party install instructions the operator brings (e.g. from Perplexity): check
  them against the vendor's docs before writing a recipe, and mark unverified claims.
- n8n data lives in the podman volume `n8n_data` inside the VM: export it
  (`images/n8n/run.md`) before any `podman machine rm n8n`.
- After `podman volume import n8n_data`, chown the volume root to `node` (recipe in
  `images/n8n/run.md`), or n8n exits with `EACCES`.
- An empty `VOLUMES=""` in a machine profile is not "no volumes": `podman machine init`
  then shares macOS defaults (`/Users` etc., rw). `scripts/machine-switch.sh` now refuses
  it and checks mounts against the profile before every start. Never create a machine
  with a bare `podman machine init`.
- Projects using a running instance are in the catalogue's **Used by** field. Check it
  before stopping, upgrading or recreating that instance.
- The oMLX model is shared with another project. Keep smoke-test prompts small.
- podmanager runs on both Apple Silicon hosts; each needs its own `machines/local.env`.
- Refresh `.atlas/overview.md` at end of session when the project moved. Two markers are
  open there, both waiting on T-OPENCODE-05/07.

**Session continuity:** Next session is a cold start, so re-read CLAUDE.md before doing
anything. Sessions are never re-entered. End-of-session updates cover three layers: this
brief, `docs/session-state.md`, and `TODO.md`.
Full archaeology: `docs/session-state.md` — consult when prior-thread depth, decision
reasoning, or ruled-out paths are needed.
