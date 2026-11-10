# podmanager-probe — build, test, push

Plain commands, run from the repo root. Needs `GHCR_USER` and `GHCR_WRITE_TOKEN` in the
shell (loaded from the vault, see `.env.local.example`).

## Build (amd64, on the opencode machine)
```sh
scripts/machine-switch.sh opencode
podman build --platform linux/amd64 -t localhost/podmanager-probe:0.1 images/podmanager-probe
```

## Local test
Rootless podman can't map OpenShift's very high UIDs (e.g. 1000680000), so use any
unlisted UID in group 0:
```sh
podman run -d --rm --name probe-test --user 54321:0 localhost/podmanager-probe:0.1
podman exec probe-test bash -c 'uname -m; id; touch $HOME/x && echo HOME writable'
podman stop -t 2 probe-test
```
Expect `x86_64`, `gid=0(root)`, `HOME writable`.

## Push by digest
Log in with a throwaway auth file, so the token is never stored in the default one:
```sh
umask 077
authfile=$(mktemp); rm -f "$authfile"          # podman creates it fresh
trap 'rm -f "$authfile"' EXIT

printf '%s' "$GHCR_WRITE_TOKEN" \
  | podman login ghcr.io -u "$GHCR_USER" --password-stdin --authfile "$authfile"
podman push --authfile "$authfile" --digestfile probe.digest \
    localhost/podmanager-probe:0.1 docker://ghcr.io/vebutton/podmanager-probe:0.1
cat probe.digest; rm -f probe.digest
```
Run it in a subshell or script, as with the pull secret below.
A new GHCR package is private, and this one stays private. (To make one public: GitHub
UI → package → Package settings → Danger Zone → Change visibility → Public.)

## Pull secret on OpenShift (private package)
Needs `GHCR_READ_TOKEN` (classic PAT, `read:packages` only) in the shell, and `NS` set to
the target namespace. The token goes stdin → `podman login` → a temporary auth file,
never onto a command line. `podman login` also rejects a bad or expired token before
anything reaches the cluster. Tested on the OpenShift lab 2026-11-09.
```sh
umask 077
authfile=$(mktemp); rm -f "$authfile"          # podman creates it fresh
trap 'rm -f "$authfile"' EXIT                  # a failed oc create must not leave it behind

printf '%s' "$GHCR_READ_TOKEN" \
  | podman login ghcr.io -u "$GHCR_USER" --password-stdin --authfile "$authfile"

oc create secret generic ghcr-pull -n "$NS" \
  --type=kubernetes.io/dockerconfigjson \
  --from-file=.dockerconfigjson="$authfile"
oc secrets link default ghcr-pull --for=pull -n "$NS"
```
- Run it in a subshell or script: the `trap` and `umask` then don't stay in your shell.
- `oc secrets link … --for=pull` is required. Without it the pod gets `ImagePullBackOff`
  unless its spec names `imagePullSecrets` itself.
- Don't use `oc create secret docker-registry --docker-password=…`: the token sits in
  `oc`'s argv (visible in `ps`) for the life of the call.
- Keychain instead of the vault: replace the `printf` with
  `security find-generic-password -s ghcr-read-token -w`.
- A classic `read:packages` token reads every package the account can access. Fine for
  the lab; a dedicated bot account is cleaner for a shared tool.
- Deleting the namespace removes the secret.

## Run on OpenShift
```sh
oc run podmanager-probe -n "$NS" --restart=Never \
    --image=ghcr.io/vebutton/podmanager-probe@sha256:<digest>
oc wait -n "$NS" --for=condition=Ready pod/podmanager-probe --timeout=120s
oc rsh -n "$NS" pod/podmanager-probe bash
oc delete -n "$NS" pod podmanager-probe
```
