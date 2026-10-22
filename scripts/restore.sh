#!/usr/bin/env bash
# Restore only to a newly created directory. Never overwrite a working deployment.
source "$(dirname "$0")/backup-common.sh"
snapshot=${1:?Usage: restore.sh SNAPSHOT NEW_DIRECTORY [--baseline]}
target=${2:?Supply a NEW restore directory}
case "${3:-}" in '') ;; --baseline) export RESTIC_REPOSITORY="$BASELINE_REPOSITORY";; *) exit 2;; esac
[[ ! -e "$target" && ! -L "$target" ]] || { echo 'Restore target already exists; refusing overwrite' >&2; exit 1; }
mkdir -m 700 -- "$target"
"$RESTIC" restore "$snapshot" --target "$target" --verify
echo 'Restored and verified. Nothing has been copied over the live runtime directory.'
