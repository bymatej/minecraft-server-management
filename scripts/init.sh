#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p runtime recovery .secrets .tools
chmod 700 runtime recovery .secrets
# The official wrapper prepares these five mounts. Do not recursively chown data.
for mount in backups logs servers config import; do
  if [[ ! -e runtime/$mount ]]; then mkdir -m 750 "runtime/$mount"; fi
done
if [[ ! -e .env ]]; then cp .env.example .env; fi
printf '%s\n' 'Directories ready. Run bash scripts/verify.sh before docker compose up -d.'
