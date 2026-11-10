# podmanager — ToDo

> The single durable task register. Committed (and the repo is public), so every line
> stays generic: people's names, hosts, internal product names, credentials and
> customer-tied dates live in `CLAUDE.local.md` and are referenced, never copied here.
> Build and resolution dates are fine.

## Rules
- **ID:** `T-<SLUG>-<nn>`. Permanent, never reused, never renumbered. Numbered per track.
- **Slugs** come from CLAUDE.md → Tracks, plus `PROJ` for project/repo plumbing that
  belongs to no track. A new track is added to CLAUDE.md first, by agreement, never
  invented here.
- **An item is work that finishes.** Anything that recurs, or would never close, is a
  Standing operation (section 4): no ID, no checkbox.
- **Track and deliverable are fixed at creation.** If the deliverable changes, close the
  item with a pointer and open a new one that references the old ID. Don't retitle.
- **New items** append at the end of their track. Propose each one with a proposed ID
  and wait for agreement.
- **Closed items** stay in place, ticked: `(resolved YYYY-MM-DD: outcome)`. Move them to
  Archive only when the resolution no longer informs current work.
- **Item detail is current state only:** what's left, what it waits on, priority,
  dependencies, pointers. What happened and when goes in `docs/session-state.md`.
- **Open questions live only here** (section 3). Requirements and design docs point to
  this section instead of keeping their own lists.
- **This is the only durable task list.** The in-session todo tool is scratch. At end of
  session, reconcile it into this file, and give every open or next-step line written to
  `docs/session-state.md` an ID or an Unscheduled line, or drop it deliberately.
- **Refer to items by ID everywhere** (CLAUDE.md, docs, commit messages), never by
  position ("pickup item 3"). A commit that does an item's work names its ID.

## 1. Items

### PROJ — Project and repo plumbing
- [x] T-PROJ-01 Create the public GitHub repo (resolved 2026-11-08: github.com/vebutton/podmanager, public)
- [ ] T-PROJ-02 Survey and catalogue the S3 validator image (customer-facing)
- [ ] T-PROJ-03 Survey and catalogue the DR-product hook containers scattered across other projects
- [ ] T-PROJ-04 Record the sandbox project's container requirements once it hands them over
- [ ] T-PROJ-05 Survey and catalogue the web-terminal image
- [ ] T-PROJ-06 Handoff file for other projects to request a machine and image

### OPENCODE — Track 1: OpenCode pipeline proof
- [x] T-OPENCODE-01 Settle the repo layout, catalogue format and public/private split (resolved 2026-11-09: layout in requirements → Repo layout; gitignored `images-private/` + `catalogue.local.md`; `.conf` profiles; per-host `machines/local.env`; entry format in `catalogue.md`)
- [x] T-OPENCODE-02 Catalogue the existing OpenCode image and write its requirements record (resolved 2026-11-09: `images/opencode/` + catalogue entry; arm64 test build ran interactively against oMLX)
- [x] T-OPENCODE-03 Machine profile for OpenCode + machine-switch script (resolved 2026-11-09: `machines/opencode.conf`, `scripts/machine-switch.sh`; machine `opencode` created and running; overrides via `/config` volume)
- [ ] T-OPENCODE-04 Multi-arch build script (arm64 + amd64 manifest list)
- [ ] T-OPENCODE-05 Run recipe and local smoke test for the OpenCode image
- [ ] T-OPENCODE-06 Secrets loader from the Ansible Vault env file
- [ ] T-OPENCODE-07 Push to GHCR by digest and verify pull
- [ ] T-OPENCODE-08 Plain CLI recipe for non-Claude users
- [ ] T-OPENCODE-09 Remove the hand-made `opencode-lab` machine
- [x] T-OPENCODE-10 GHCR → OpenShift probe image (resolved 2026-11-09: private package pulled by digest on the OpenShift lab via a `GHCR_READ_TOKEN` pull secret, runs under default security; recipe in `images/podmanager-probe/build.md`)

### SANDBOX — Track 2: Claude Code sandbox image
- [ ] T-SANDBOX-01 Decide whether the Claude Code image is built here or in the sandbox project
- [ ] T-SANDBOX-02 Decide read-only enforcement for the sandbox workspace (machine volume scope, container mount, or both)

## 2. Item detail

### PROJ
- **T-PROJ-02:** Path not yet known (ask the operator). Read-only survey: where it lives,
  how it builds today, any intricacies of its own build. Write a catalogue entry. It's the
  first customer-facing image, so it is the likely first real handoff package (§3
  handoff-format question). Not part of Track 1.
- **T-PROJ-03:** Paths not yet known. Same shape as T-PROJ-02, one catalogue entry per
  hook container. Some may need to stay private (gitignored), so decide per entry.
- **T-PROJ-04:** Blocked on the sandbox project. The operator pastes natural-language
  requirements, and podmanager records them as `images/<name>/requirements.md`. Feeds
  Track 2.
- **T-PROJ-05:** Path in `CLAUDE.local.md`. A stub entry is already in `catalogue.md`.
  Read-only survey: confirm which machine it runs in and what that machine's profile
  should be, and check whether `run.sh`'s bare `podman machine start` breaks the
  one-machine rule. Low priority, not part of Track 1.
- **T-PROJ-06:** A file other projects copy, fill in and hand to podmanager, so a request
  arrives with what podmanager needs to pick or build a machine profile and an image.
  Likely fields: purpose; base image and tools; machine needs (CPU, memory, disk,
  `/workspace` source, `/shared` opt-in, `/config` overrides); secrets by variable name
  only; network/egress limits; public or private; customer-facing (handoff package) or
  not; publish target; acceptance checks. podmanager turns it into
  `images/<name>/requirements.md` and `machines/<profile>.conf`. Open: format (filled-in
  Markdown vs structured YAML, see §5 Unscheduled) and where it lives. Best drafted after
  T-OPENCODE-05, so it reflects a full pass through the pipeline. First user: the sandbox
  project (T-PROJ-04).

### OPENCODE
- **T-OPENCODE-04:** `podman build --platform linux/arm64,linux/amd64 --manifest`.
  Confirm `opencode-ai` installs under amd64 emulation (npm package with per-platform
  binaries). Keep the version pin (`opencode-ai@1.19.0` today).
- **T-OPENCODE-05:** The smoke test must cover:
  - the container starts under `--userns keep-id`
  - `/workspace` is writable and the declared files are read-only
  - the host model endpoint is reachable, with the key from `-e OMLX_API_KEY` (no
    `/connect`)
  - **the configured model is the one actually in use**: a config the container can't
    read falls back to a cloud model silently
  - an override from `/config` (`:ro`, no `Z`) is the config actually loaded

  Run the amd64 variant under emulation at least once.
- **T-OPENCODE-06:** Variable names and format are set in `.env.local.example`
  (`export KEY="value"` lines). `.env.local` is vault-encrypted in place, and the working
  load snippet is in `.env.local.example` (`ansible-vault decrypt --output -` into a
  variable, then `source /dev/stdin`). `source <(ansible-vault view …)` did not work.
  `ansible.cfg` sets `scripts/vault-pass.sh` (macOS dialog) as the vault password client,
  so `ansible-vault` also runs without a terminal. Decided (operator, 2026-11-09): scripts
  expect the values already in the shell (loaded before starting Claude Code). They don't
  decrypt the vault. A script with a missing required variable fails, naming the variable
  (never a value) and pointing at the load snippet. First
  consumers: `OMLX_API_KEY` (smoke test), then the GHCR tokens.
- **T-OPENCODE-07:** Depends on T-OPENCODE-05 passing and T-OPENCODE-06. Push the
  manifest list, record the digest in the image's catalogue entry, and pull by digest to
  verify (ideally from the OpenShift lab). GHCR namespaces differ per image, so set this
  image's namespace and package visibility. The route is proven by T-OPENCODE-10: push
  with a temporary auth file, private package, pull secret recipe in
  `images/podmanager-probe/build.md`.
- **T-OPENCODE-08:** The same steps as the scripts, written out as copy-paste commands.
  This is the input for the operator's Confluence-article skill.
- **T-OPENCODE-09:** Waits on T-OPENCODE-05 passing on the `opencode` machine. Until then
  `opencode-lab` stays stopped as a fallback. `podman machine rm` only with the operator's
  explicit OK. Its workspace is a host folder (shared with `opencode`), so it survives the
  removal; the VM's own files and images do not.

### SANDBOX
- **T-SANDBOX-01:** Resolves §3 question on where the Claude Code image lives. If it's
  built here, it's a near-copy of the OpenCode image directory.
- **T-SANDBOX-02:** Resolves §3 read-only question. On macOS there are two layers: what
  the VM can see of the host filesystem (machine volumes) and how the container mounts it.

## 3. Open questions
- **Read-only enforcement for the sandbox image:** machine-level volume scoping, a
  read-only container mount, or both? → T-SANDBOX-02.
- **Is the Claude Code sandbox image built in podmanager or in the sandbox project?**
  → T-SANDBOX-01.
- **Does each image get its own track?** For now, no. Images land as items under a track
  or PROJ. Revisit when a third image gets built natively here.
- **Handoff package contents and format** for the employer's engineering pipeline. Likely
  Containerfile, build steps and test results, but the shape is unsettled. → resolve with
  the first customer-facing image (T-PROJ-02).

## 4. Standing operations
Recurring work: no IDs, no checkboxes, tracked by last-run date.

| Operation | Cadence / trigger | Last run | Notes |
|---|---|---|---|
| Bump pinned tool versions in images | When a new release matters; read release notes first | — | e.g. `opencode-ai` pin |
| Prune stale images and stopped machines | When disk gets tight | — | Confirm before deleting |

## 5. Unscheduled
Ideas that came up but aren't committed work. No ID until promoted into a track.
- Image signing (planned for later; cosign or similar, GHCR-compatible).
- Formal requirements spec (e.g. YAML in the requesting repo) to replace natural-language
  hand-ins, if natural language starts to drift.
- Remote x86 builder, if amd64 emulation builds become too slow.
- Recipes for host-side model servers (oMLX/Ollama) that the OpenCode image talks to.
  Currently outside podmanager's scope.

## 6. Archive
Closed items whose resolution no longer informs current work.
