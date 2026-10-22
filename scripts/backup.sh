#!/usr/bin/env bash
# Cold snapshot of all persistent state; never uses save-off.
source "$(dirname "$0")/backup-common.sh"
mode=${1:-snapshot}
case "$mode" in snapshot|baseline|check|retention-preview) ;; *) echo 'Usage: backup.sh snapshot|baseline|check|retention-preview [--stop-crafty]' >&2; exit 2;; esac
if [[ $mode == check ]]; then exec "$RESTIC" check --read-data; fi
if [[ $mode == retention-preview ]]; then
  exec "$RESTIC" forget --tag rotation --group-by host,paths,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --dry-run
fi
cid=$(docker compose ps -aq crafty)
test -n "$cid" || { echo 'Create the Crafty container before taking a backup' >&2; exit 1; }
running=$(docker inspect -f '{{.State.Running}}' "$cid")
restart=0
resume() {
  rc=$?
  trap - EXIT
  if [[ $restart == 1 ]]; then docker compose start crafty || rc=1; fi
  exit "$rc"
}
trap resume EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if [[ $running == true ]]; then
  [[ ${2:-} == --stop-crafty ]] || { echo 'Stop Crafty first, or explicitly use --stop-crafty for maintenance downtime.' >&2; exit 1; }
  restart=1
  docker compose stop crafty
fi
# Do not bless a force-killed or failed shutdown as a consistent snapshot.
test "$(docker inspect -f '{{.State.Running}}' "$cid")" == false
test "$(docker inspect -f '{{.State.ExitCode}}' "$cid")" == 0 || { echo 'Unclean shutdown: investigate before backup' >&2; exit 1; }
args=(runtime compose.yaml compose.gameplay.yaml .env.example README.md docs scripts examples)
[[ ! -f .env ]] || args+=(.env)
if [[ $mode == baseline ]]; then
  # Separate repository, never passed to forget/prune. Baselines are append-only here.
  "$RESTIC" -r "$BASELINE_REPOSITORY" backup --tag baseline "${args[@]}"
else
  "$RESTIC" backup --tag rotation "${args[@]}"
fi
# Minimize downtime: start before retention work.
if [[ $restart == 1 ]]; then docker compose start crafty; restart=0; fi
if [[ $mode == snapshot ]]; then
  "$RESTIC" forget --tag rotation --group-by host,paths,tags --keep-daily 7 --keep-weekly 4 --keep-monthly 3 --prune
fi
