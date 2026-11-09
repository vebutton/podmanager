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

### OPENCODE — Track 1: OpenCode pipeline proof
- [ ] T-OPENCODE-01 Settle the repo layout, catalogue format and public/private split
- [ ] T-OPENCODE-02 Catalogue the existing OpenCode image and write its requirements record
- [ ] T-OPENCODE-03 Machine profile for OpenCode + machine-switch script
- [ ] T-OPENCODE-04 Multi-arch build script (arm64 + amd64 manifest list)
- [ ] T-OPENCODE-05 Run recipe and local smoke test for the OpenCode image
- [ ] T-OPENCODE-06 Secrets loader from the Ansible Vault env file
- [ ] T-OPENCODE-07 Push to GHCR by digest and verify pull
- [ ] T-OPENCODE-08 Plain CLI recipe for non-Claude users

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

### OPENCODE
- **T-OPENCODE-01:** Proposed layout in `docs/requirements.md` → Repo layout. It covers:
  machine profile format, per-image directory shape, catalogue (public file + gitignored
  local file for private entries), `images-private/` gitignored, host paths resolved from
  a gitignored local file. Add the gitignore entries as part of this item.
- **T-OPENCODE-02:** Source project path is in `CLAUDE.local.md`. Blocker: its
  `opencode.json` is a symlink to a missing `opencode-qwen-mlx.json`. Recover it, or pick
  one of the present configs (`opencode-any.json`, `opencode-local-only.json`) as the
  baked default. An older sibling directory may hold the missing file. The baked config
  references a host model endpoint and model names. Decide whether those go public or get
  parameterised.
- **T-OPENCODE-03:** From the source history: 2 CPU, 2 GiB, one host directory mounted
  to `/workspace`. The script must stop whatever machine is running, start the target and
  set it as the default connection. Replace the `cat | podman machine ssh` config
  injection with a mounted config directory or a profile-declared volume.
- **T-OPENCODE-04:** `podman build --platform linux/arm64,linux/amd64 --manifest`.
  Confirm `opencode-ai` installs under amd64 emulation (npm package with per-platform
  binaries). Keep the version pin (`opencode-ai@1.19.0` today).
- **T-OPENCODE-05:** The smoke test must cover:
  - the container starts under `--userns keep-id`
  - `/workspace` is writable and the declared files are read-only
  - the host model endpoint is reachable
  - **the configured model is the one actually in use**: the missing-`Z` failure falls
    back to a cloud model silently

  Run the amd64 variant under emulation at least once.
- **T-OPENCODE-06:** Needs the vault file's path and variable names from the operator.
  Decrypt at run time into the process environment only, never to a file in the repo.
  The GHCR token is the first consumer.
- **T-OPENCODE-07:** Depends on T-OPENCODE-05 passing and T-OPENCODE-06. Push the
  manifest list, record the digest in the image's catalogue entry, and pull by digest to
  verify (ideally from the OpenShift lab). Confirm the GHCR namespace and package
  visibility.
- **T-OPENCODE-08:** The same steps as the scripts, written out as copy-paste commands.
  This is the input for the operator's Confluence-article skill.

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
- **Public/private mechanics:** gitignored `images-private/` + local catalogue in this
  repo, or a separate private repo? → T-OPENCODE-01.
- **Missing OpenCode config file** in the source project. → T-OPENCODE-02.

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
- OpenCode variant with all providers enabled (from the source project's own to-do).
- Recipes for host-side model servers (oMLX/Ollama) that the OpenCode image talks to.
  Currently outside podmanager's scope.

## 6. Archive
Closed items whose resolution no longer informs current work.
