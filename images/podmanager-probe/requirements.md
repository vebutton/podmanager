# podmanager-probe — requirements record

## Purpose
Prove the GHCR → OpenShift path before any real image uses it (T-OPENCODE-10). A minimal
image the operator can shell into on the OpenShift lab. Not a tool in its own right.

## Image
- Base `ubi9/ubi-minimal`, plus bash, procps-ng, iputils, bind-utils, curl-minimal (basic
  shell and network checks).
- amd64 only (the OpenShift lab nodes are x86).
- Runs as an arbitrary non-root UID in group 0, as OpenShift's restricted SCC does:
  `HOME=/home/probe` is group-0 writable, default `USER 1001`.
- `CMD ["sleep", "infinity"]`: stays up so the operator can `oc rsh` in.
- No secrets, no config.

## Publishing
- `ghcr.io/vebutton/podmanager-probe`, **private**. OpenShift pulls it with a pull secret
  built from `GHCR_READ_TOKEN` (recipe: `build.md`). Planned public; kept private because
  that is the route private images need, and it is now proven.
- Pushed by digest, tag `0.1`. Current digest: `catalogue.md`.

## Acceptance
- Local (on the `opencode` machine, amd64 under emulation): `uname -m` is `x86_64`; runs
  as an unlisted UID in group 0 with a writable `HOME`; bash and the tools present;
  stays running.
- A pod in the OpenShift lab pulls it by digest with the pull secret, runs under the
  default (restricted) security settings, and `oc rsh` works. Passed 2026-11-09.
