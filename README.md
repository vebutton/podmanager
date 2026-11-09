# podmanager

A lab tool for building and running Podman machines and container images on Apple Silicon
Macs. It turns hand-run Podman builds into a repeatable process. Each image declares a
machine profile, gets built for both arm64 and amd64, is smoke-tested locally, and is
published to GHCR pinned by digest so OpenShift clusters can pull it directly. It
catalogues images that live in other projects. For customer-facing prototypes it produces
a handoff package that an engineering team can take into its own pipeline.

Mainly driven through Claude Code, with plain shell scripts underneath that work on their
own.

## Pointers
- [docs/requirements.md](docs/requirements.md): what podmanager does and the constraints it
  is built against
- [TODO.md](TODO.md): task register, open questions, and what's next
- [CLAUDE.md](CLAUDE.md): project context for AI-assisted sessions
