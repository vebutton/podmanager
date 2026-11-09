# podmanager — Requirements

Spec for the app. Tasks and open questions live in [TODO.md](../TODO.md) §1 and §3, not
here. Internal names, hosts and paths live in `CLAUDE.local.md`.

## Cross-cutting

### Scope
- Manages **Podman machines** (macOS VMs) and **container images**, for any kind of image.
- Two image classes:
  - **Own tools:** e.g. the OpenCode harness and the Claude Code sandbox. Built, run and
    published here.
  - **Customer-facing prototypes:** e.g. the S3 validator and DR-product hooks. Built and
    tested here in the lab. The employer's engineering team builds and ships the official
    versions. podmanager produces a handoff package for them.
- **Existing images stay in their own projects.** podmanager catalogues them (location,
  how each builds, quirks) and does not take over their source. New images are built
  natively here.
- **Out of scope:** official customer releases, host-side services such as model servers,
  and modifying other projects.

### Machines
- **Profiles.** Each image declares the machine profile it needs: CPUs, memory, disk,
  rootful/rootless, host volumes.
- **One machine at a time.** Switching profiles means stopping the running machine,
  starting the target and setting it as the default connection.
- Profiles must not commit host paths that contain the username. Resolve host paths from a
  gitignored local file or from variables.
- Several machines may exist. Different purposes have different requirements (e.g. a
  locked-down sandbox machine vs a larger lab machine).

### Requirements intake
- Requirements arrive as **natural language**: pasted by the operator or handed over by a
  sibling project. No formal spec file for now.
- podmanager **records what it understood** as `images/<name>/requirements.md`, so every
  image has a written record of its requirements.

### Build
- Multi-arch by default: `linux/arm64` (native) + `linux/amd64` (emulated), built locally
  on the Mac into a manifest list. No remote builder.
- Pin tool versions in Containerfiles and bump them deliberately.

### Test
- Every image gets a local smoke test before publishing: it runs, its mounts behave as
  declared, and it does its job. Run the amd64 variant under emulation at least once.

### Publish
- Most images go to **GHCR, pinned by digest**, so the OpenShift lab (x86) can pull them
  directly. Some stay local-only.
- Record the published digest in the image's catalogue entry.
- Signing comes later (TODO.md §5).

### Secrets (hard rule)
- Source: the operator's **Ansible Vault env file**, decrypted at run time into the process
  environment.
- Secrets never go into an image layer, a handoff package, a log, a CLI recipe or a
  committed file. CLI recipes reference secrets by variable name only.

### Outputs
- **Plain CLI recipes:** the scripted steps as copy-paste commands for people who don't use
  Claude. They feed the operator's Confluence-article workflow.
- **Engineering handoff package** (customer-facing images only), written to `output/`:
  Containerfile, build instructions, test results, in a form engineering can drop into
  their own pipeline. Exact contents and format are open (TODO.md §3).

### Public/private split
- The repo is **public**. Some images are public. Others must not appear in the repo, or
  only in obfuscated form.
- Proposed (to be settled in T-OPENCODE-01): private images live in a gitignored
  `images-private/` with the same shape as `images/`. Private catalogue entries go in a
  gitignored `catalogue.local.md`. Internal names map through `CLAUDE.local.md`.

### Repo layout (proposed, T-OPENCODE-01)
```
machines/<profile>.conf     machine profile (cpus, memory, disk, rootful, volumes by variable)
machines/local.env          gitignored: host paths and other per-host values
images/<name>/              public image: Containerfile, requirements.md, build.md, config
images-private/<name>/      gitignored: private images, same shape
catalogue.md                public catalogue: in-repo and external images, how each builds, digests
catalogue.local.md          gitignored: private catalogue entries
scripts/                    thin wrappers: machine switch, build, test, push, recipe/handoff export
output/                     gitignored: handoff packages, test results, recipe drafts
```

### Interface
- Main interface: Claude Code in this repo. Scripts are the execution layer and work
  without Claude.

## Track 1 — OpenCode pipeline proof

**Objective:** rebuild the existing OpenCode image end to end in podmanager. Local build
and test come first. GHCR push comes only after the local smoke test passes (GHCR tokens
already exist).

### What the existing image is (observed in the source project)
- `Containerfile`: `node:22-bookworm-slim` base. Installs git, ripgrep, ca-certificates,
  python3, python3-pytest. `npm install -g opencode-ai@1.19.0` (pinned).
- Config baked at `/etc/opencode/opencode.json` (`OPENCODE_CONFIG`), outside
  `/workspace`, so the agent can't edit its own permissions.
- `HOME=/home/agent`, mode 1777, so any UID works. Runs with `--userns keep-id`.
  `WORKDIR /workspace`, `ENTRYPOINT ["opencode"]`.
- The harness talks to a **host-side** OpenAI-compatible model server via
  `host.containers.internal`. The model runs natively on the Mac GPU, not in the
  container.
- OpenCode config sets permissions: edits are allowed except tests and fixtures, bash is
  allowlisted for read-only and pytest/git-read commands, autoupdate is off, sharing is
  disabled. A local-only variant disables the cloud provider.
- Tagged locally as `opencode-lab:1.19.0`. Single-arch (arm64) today, never published.
- Source is not a git repo.

### How it is run today (the manual process to replace)
- Machine: `podman machine init <name> --cpus 2 --memory 2048 --volume
  <host-dir>:/workspace`, then start it and set it as the default connection.
- Alternative config files are copied into the VM with `cat file | podman machine ssh
  <machine> 'cat > ~/file'`, then mounted over `/etc/opencode/opencode.json` with
  `:ro,Z`.
- Per task, specific test files and fixtures are mounted read-only on top of a writable
  `/workspace`.

### Requirements for the rebuild
- Same image behaviour, built from `images/opencode/` with a requirements record.
- Machine profile matches today's (2 CPU, 2 GiB, workspace volume), declared in
  `machines/`.
- Multi-arch manifest list (arm64 + amd64).
- Replace the `cat | ssh` config copy with a declared mechanism, e.g. a config directory
  mounted through a machine volume.
- Smoke test checks: startup under keep-id, mount modes, model endpoint reachability, and
  that **the configured model is the model in use**. Without `Z` the config is corrupted
  and OpenCode silently falls back to a cloud model.
- Then push to GHCR by digest and verify a pull by digest.
- Produce the plain CLI recipe for the whole flow.

### Config decisions (2026-11-08)
- **Baked default: the local-only config** (OpenCode's own cloud provider disabled), so
  the image can't reach a cloud model by accident. The all-providers config becomes a
  run-time override mounted `:ro,Z` over `/etc/opencode/opencode.json`.
- **Fix the model reference.** Both source configs set `"model"` to a name that their
  host-named provider doesn't define, and not in OpenCode's `provider/model` form. Rename
  the provider to the generic `omlx` and use `omlx/Qwen3.5-9B-oQ4e-mtp`.
- **oMLX only.** Ollama-backed configs (`:11434`) are dropped.
- The existing local image still bakes an old Ollama config. It only works because of
  the run-time mount.

### Known gaps
- Model names and the host endpoint are baked into config. Decide whether they're public
  or parameterised.
- **oMLX API key.** oMLX rejects requests without a key, and the configs set none. Today
  the operator enters it by hand with `/connect` in every session. OpenCode saves it under
  `$HOME`, and the `--rm` container throws that away on exit. Planned fix: set
  `"apiKey": "{env:OMLX_API_KEY}"` in the provider options and run with
  `podman run -e OMLX_API_KEY`, so the key comes from the vault-loaded shell and never
  lands in the image or in a file. Verify in T-OPENCODE-05.

## Track 2 — Claude Code sandbox image

**Objective:** a locked-down Claude Code image + machine profile for the sandbox project.

### Requirements as known so far (the sandbox project will hand over the full set)
- Agent (Claude Code) preinstalled.
- Read-only access to the directories it examines (enforcement layer open, TODO.md §3).
- Egress locked to the model endpoint.
- Scoped API key, injected at run time from the vault.
- Ephemeral containers.
- Published to GHCR pinned by digest.
- Expected to be a near-copy of the Track 1 image directory.
