#!/usr/bin/env bash
# Sourced by backup/restore scripts. Configuration is local, trusted shell code.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
umask 077
export RESTIC_PASSWORD_FILE="$ROOT/.secrets/restic-password"
export RESTIC_REPOSITORY="$ROOT/recovery/restic"
BASELINE_REPOSITORY="$ROOT/recovery/baseline"
RESTIC="$ROOT/.tools/restic"
if [[ -f .secrets/backup.env ]]; then source .secrets/backup.env; fi
export RESTIC_REPOSITORY RESTIC_PASSWORD_FILE
test -x "$RESTIC" || { echo 'Install restic: see docs/backups.md' >&2; exit 1; }
test -s "$RESTIC_PASSWORD_FILE" || { echo 'Missing restic password file' >&2; exit 1; }
mkdir -p recovery
exec 9>recovery/operation.lock
flock -n 9 || { echo 'Another backup/restore operation holds the lock' >&2; exit 1; }
