#!/usr/bin/env bash
# Switch to a machine profile: create the machine if it doesn't exist, stop
# whatever other machine is running (only one runs at a time), start the
# target and make it the default connection.
#
# Usage: scripts/machine-switch.sh <profile> [--dry-run]
#   <profile>   name of machines/<profile>.conf
#   --dry-run   print the podman commands instead of running them
set -euo pipefail

usage() { echo "usage: $0 <profile> [--dry-run]" >&2; exit 2; }
[[ $# -ge 1 && $# -le 2 ]] || usage
PROFILE=$1
DRY_RUN=false
if [[ $# -eq 2 ]]; then [[ $2 == --dry-run ]] || usage; DRY_RUN=true; fi

PODMANAGER_ROOT=$(cd "$(dirname "$0")/.." && pwd)
PROFILE_FILE=$PODMANAGER_ROOT/machines/$PROFILE.conf
LOCAL_ENV=$PODMANAGER_ROOT/machines/local.env

run() {
  if $DRY_RUN; then printf '+'; printf ' %q' "$@"; printf '\n'; else "$@"; fi
}
die() { echo "machine-switch: $*" >&2; exit 1; }

[[ -f $PROFILE_FILE ]] || die "no profile $PROFILE_FILE"
[[ -f $LOCAL_ENV ]] || die "no $LOCAL_ENV (copy machines/local.env.example and fill in this host's paths)"
# shellcheck source=/dev/null
source "$LOCAL_ENV"
# shellcheck source=/dev/null
source "$PROFILE_FILE"

# --- Volumes -----------------------------------------------------------------
volume_args=()
ro_targets=()
while read -r vol; do
  [[ -z $vol ]] && continue
  src=${vol%%:*}
  [[ -d $src ]] || die "volume source $src does not exist (profile $PROFILE)"
  volume_args+=(--volume "$vol")
  if [[ $vol == *:ro ]]; then rest=${vol#*:}; ro_targets+=("${rest%:ro}"); fi
done <<< "$VOLUMES"
if [[ ${SHARED:-false} == true ]]; then
  [[ -n ${PODMANAGER_SHARED:-} ]] || die "SHARED=true but PODMANAGER_SHARED is not set in $LOCAL_ENV"
  run mkdir -p "$PODMANAGER_SHARED"
  volume_args+=(--volume "$PODMANAGER_SHARED:/shared")
fi
# With no --volume, podman machine init shares its defaults (/Users, /private,
# /var/folders, ~/.config/containers, read-write) with the VM. Never allow that.
[[ ${#volume_args[@]} -gt 0 ]] || die "profile $PROFILE lists no volumes;" \
  "podman would share its defaults (/Users etc.) with the VM"

# The machine's mounts must be exactly the profile's, as source:target:ro|rw.
expected_mounts() {
  local i vol
  for ((i = 1; i < ${#volume_args[@]}; i += 2)); do
    vol=${volume_args[i]}
    if [[ $vol == *:ro ]]; then echo "${vol%:ro}:ro"; else echo "$vol:rw"; fi
  done | sort
}
check_mounts() {
  local dir actual
  dir=$(podman machine inspect "$MACHINE_NAME" --format '{{.ConfigDir.Path}}')
  actual=$(jq -r '.Mounts // [] | .[] |
    "\(.Source):\(.Target):\(if .ReadOnly then "ro" else "rw" end)"' \
    "$dir/$MACHINE_NAME.json" | sort)
  [[ $actual == "$(expected_mounts)" ]] && return
  echo "machine-switch: $MACHINE_NAME mounts differ from profile $PROFILE" >&2
  diff <(expected_mounts) <(echo "$actual") | sed -n 's/^</  profile only:/p; s/^>/  machine only:/p' >&2
  die "not starting $MACHINE_NAME; recreate it from the profile (export its data first)"
}

# --- Create if missing ---------------------------------------------------------
if podman machine inspect "$MACHINE_NAME" >/dev/null 2>&1; then
  check_mounts
  # Resources can drift from the profile (warn only); volumes are checked above.
  actual=$(podman machine inspect "$MACHINE_NAME" \
    --format '{{.Resources.CPUs}} {{.Resources.Memory}} {{.Resources.DiskSize}} {{.Rootful}}')
  wanted="$CPUS $MEMORY_MIB $DISK_GIB $ROOTFUL"
  [[ $actual == "$wanted" ]] || echo "machine-switch: warning: $MACHINE_NAME has" \
    "cpus/mem/disk/rootful '$actual', profile says '$wanted'" >&2
else
  init_args=(--cpus "$CPUS" --memory "$MEMORY_MIB" --disk-size "$DISK_GIB")
  [[ $ROOTFUL == true ]] && init_args+=(--rootful)
  # ${a[@]+...}: macOS bash 3.2 treats an empty array as unset under set -u.
  run podman machine init "$MACHINE_NAME" "${init_args[@]}" "${volume_args[@]}"
  $DRY_RUN || check_mounts
fi

# --- Stop any other running machine, start the target --------------------------
target_running=false
while read -r name running; do
  name=${name%\*}
  if [[ $name == "$MACHINE_NAME" ]]; then
    target_running=$running
  elif [[ $running == true ]]; then
    run podman machine stop "$name"
  fi
done < <(podman machine list --format '{{.Name}} {{.Running}}')

# Default first: Podman Desktop warns if the target runs while another is default.
run podman system connection default "$MACHINE_NAME"
[[ $target_running == true ]] || run podman machine start "$MACHINE_NAME"

# applehv ignores :ro on machine volumes (virtiofs mounts rw), so enforce it in
# the VM. Lost on reboot: a machine started outside this script has rw mounts.
for target in ${ro_targets[@]+"${ro_targets[@]}"}; do
  run podman machine ssh "$MACHINE_NAME" "sudo mount -o remount,ro $target"
done
$DRY_RUN || echo "machine-switch: $MACHINE_NAME is running and is the default connection"
