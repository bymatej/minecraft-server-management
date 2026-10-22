# Deployment and acceptance record — 2026-10-22

## Implemented and tested

- Verified upstream Crafty stable release 4.11.0, official registries, five mount paths,
  image startup wrapper and linux/amd64 + linux/arm64 manifest. Pinned official Docker
  Hub image by version and manifest digest. GitLab registry request failed authentication;
  no credentials were displayed or changed. Docker Hub worked.
- Deployed `crafty-controller` in Compose project `minecraft-management`, isolated
  default bridge. Only published mapping: `127.0.0.1:8443 → 8443/tcp`.
- Compose validation passes for panel-only and optional gameplay configurations.
  Security assertions check no privilege/socket/host networking, five bind mounts,
  TCP-only publication, private dashboard and matching gameplay host/container ports.
- Crafty application process runs as UID 1000, with upstream sudo wrapper at UID 0.
  Java 21.0.12 and 25.0.4 executables verified inside the image.
- HTTPS `/login` returns 200 over loopback. Connection to 5.189.183.30:8443 from the
  host fails. Host listeners and Docker bindings confirm no public/IPv6 panel mapping.
  An independent off-host port scan and desktop SSH-tunnel test were not performed.
- Clean shutdown and restart tested, including successful exit code 0 before backup;
  container recreation retains configuration, DB and generated credential file.
- Roughly 90 MiB steady-state container memory before Minecraft instances. Host remains
  at approximately 5.3 GiB available RAM with no swap in use; no OOM observed.
- Official plugin downloads and checksums verified: AuthMe 5.7.0 SHA-256 and
  CoreProtect CE 24.1 SHA-512. JAR manifests inspected; staged files are private,
  ignored and **not installed into a server**.
- Full real cold snapshot created: initial rotation snapshot `586cff81`. Separate
  baseline snapshot `91798519`. These are **panel-only** recovery points, not world
  baselines. Later snapshots may additionally exist after final validation.
- Both repositories passed `restic check --read-data`. Both restored into new private
  directories with restic byte verification. Restored panel SQLite `PRAGMA quick_check`
  returned `ok`. No live data was overwritten.
- Real restic regression test generated dated synthetic restore points, applied 7/4/3
  retention, confirmed dry-run made no changes, confirmed pruning reduced the normal
  snapshot set, verified baseline preservation and restored both repositories.
- Negative tests: backup refuses a running container without `--stop-crafty`; restore
  refuses an existing directory. Injected restic failure propagated a nonzero result
  and restarted Crafty. Temporary fault-injection configuration was removed.
- User systemd backup timer enabled, scheduled 05:15 Europe/Zagreb; `Linger=yes`.
  Timer/service unit definitions are version controlled, linked from the user unit
  directory. Existing Hermes cron entry remains unchanged. First timed run is pending;
  manual invocation of the same backup script was tested.
- Original `.gitignore` content preserved with appended section. Runtime, secrets,
  recovery and tool files are ignored; `.env.example` and deployment/docs are tracked.
- Existing McMyAdmin containers retain their original three-day uptime and mappings.
  Nginx is active and serves HTTPS status 200 locally. Source and deployed Nginx config
  hashes match: `9fc04aa441d8612b1f13fc90729fff0b4ae1dff0a192836072a0e49fd09c80f4`.
  Neither file was modified. Old Minecraft repository remains clean; unrelated
  pre-existing `contabo-vps-notes` edits remain untouched.

## Failures found and corrected / limitations

- Initial capability set omitted KILL; upstream sudo could not forward SIGTERM across
  UIDs. Added the required capability and re-tested clean lifecycle/backup behavior.
  During that investigation, an overlapping recreation/backup attempt failed without
  creating a snapshot. Final successful backups ran sequentially after recreation.
- A first ignore-check implementation misread a Git negation as ignored; fixed the
  validator and verified `.env.example` appears in the tracked candidate set.
- Latest AuthMe 6.0.1 Paper **and** Spigot-1.21 assets declare API 1.21.11, incompatible
  with Paper 1.21.4. Selected the earlier stable 5.7.0 manifest-compatible build and
  version-specific configuration. Actual plugin loading remains an acceptance gate.
- Old Paper v2 downloads API returned HTTP 410; current v3 official API was used to
  confirm 1.21.4 build 232. Mojang manifest confirmed Vanilla 26.3 / Java 25.
- Privileged UFW/iptables/ip6tables audit unavailable without sudo password. No firewall
  or provider rules were changed. Docker reports swap limiting unsupported by host.

## Not performed / owner acceptance

No Minecraft instance/world was created, imported or started. Vanilla 26.3, Family
Paper 1.21.4 and configurable Forge are documented examples awaiting GUI setup.
No old world was treated as clean. Crafty's API creation schema was inspected; no
internal database edits or browser automation were used.

The following require the owner: first-login password change, TOTP enrollment/recovery
codes, Minecraft EULA acceptance and instance creation, actual family usernames/passwords,
plugin loading, client login/registration and impersonation/OP checks, CoreProtect block
inspection/rollback and real-world restoration. Follow the exact test tables in
[authentication](authentication.md) and [recovery](recovery.md).

The old containers still own 25565/25566. **No gameplay cutover or public opening of
the new family server occurred.** Its existing direct address still reaches the old
server; this deployment does not retrofit authentication to that server. New gameplay
connectivity and world persistence through recreation cannot be claimed without an
actual instance. Forge version/modpack choice is intentionally unspecified.

Offsite storage and DNS SRV records are not configured. No new public gameplay port,
Nginx route, custom image, Docker Hub push, database service or file browser was added.

## Repeatable checks

```bash
bash scripts/verify.sh --live
docker compose -f compose.yaml -f compose.gameplay.yaml config --format json |
  python3 scripts/check-compose.py
python3 -m unittest discover -s tests -v
bash scripts/backup.sh check
systemctl --user list-timers minecraft-backup.timer
```

Completion of infrastructure tests is not completion of the family authentication
acceptance gate. Keep the endpoint private until every client test passes.
