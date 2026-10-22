#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for script in scripts/*.sh; do bash -n "$script"; done
docker compose config --quiet
docker compose config --format json | python3 scripts/check-compose.py
for path in runtime/config/default-creds.txt runtime/servers/world/level.dat recovery/test .secrets/token .env .tools/restic; do
  git check-ignore -q "$path" || { echo "Not ignored: $path" >&2; exit 1; }
done
for path in .env.example compose.yaml docs/backups.md examples/family-paper/server.properties; do
  rule=$(git check-ignore -v "$path" || true)
  if [[ -n "$rule" && "$rule" != *':!'* ]]; then echo "Unexpectedly ignored: $path" >&2; exit 1; fi
done
if [[ ${1:-} == --live ]]; then
  cid=$(docker compose ps -q crafty)
  test -n "$cid"
  docker inspect "$cid" --format '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}} {{json .HostConfig.PortBindings}}'
  test "$(docker inspect "$cid" --format '{{.State.Health.Status}}')" == healthy
  docker inspect "$cid" --format '{{json .HostConfig}}' | python3 -c 'import json,sys; c=json.load(sys.stdin); assert not c["Privileged"]; assert c["NetworkMode"]!="host"; assert all("docker.sock" not in p for p in c["Binds"]); assert c["PortBindings"]["8443/tcp"][0]["HostIp"]=="127.0.0.1"'
  port=$(docker compose port crafty 8443)
  curl --fail --silent --insecure --output /dev/null "https://$port/login"
  docker top "$cid" -eo uid,pid,comm
  docker stats --no-stream "$cid"
  systemctl is-active nginx
fi
echo 'Verification passed.'
