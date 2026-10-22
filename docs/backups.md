# Backups that preserve an older clean state

Three different things matter: a consistent Minecraft save, the panel's control-plane
state, and an independent recovery copy. Crafty's per-server archives help with the
first, but do not by themselves capture the panel DB or protect against VPS disk loss.

This project uses **restic 0.19.1** on the host: encrypted, compressed, deduplicated
snapshots of all five mounts plus deployment configuration/docs. It is a binary,
not another permanent service/container. The password is in `.secrets/restic-password`
(0600) and must also be saved in your password manager outside this VPS. Losing it
means losing access to the backups. The repository itself is not a password backup.

## Consistency and schedule

`backup.sh snapshot --stop-crafty` stops only this project's Crafty container, waits
for a clean exit, snapshots all state, then starts it again even on backup errors.
It refuses exit codes other than zero. It never disables world saving. This handles
world files, AuthMe/CoreProtect SQLite data and the Crafty DB together without a live
database copy. Do not manually start the container during a backup; the advisory lock
serializes these scripts, not arbitrary operator commands.

The supplied systemd user timer runs **05:15 Europe/Zagreb daily**
(see validation for the actual enabled/lingering status).
This is a brief backup maintenance window, not an inactivity/midnight shutdown rule.
Minecraft instances resume according to their **Crafty autostart settings**. During
bootstrap keep autostart off. Before everyday use, enable it only for accepted servers
that should resume after backups, and account for their aggregate heaps. If you keep
an instance intentionally stopped, disable its autostart before the scheduled window.
This script does not preserve individual manually-running/stopped states through a
panel restart. Choose a manual maintenance backup if that tradeoff is unsuitable.

Retention keeps up to 7 daily, 4 weekly and 3 monthly buckets (`restic forget` calendar
semantics, not necessarily 14 distinct snapshots). A snapshot covering several buckets
counts once. Failed backups do not trigger retention. No snapshot can recreate history
from before backups began. Start collecting now, and retain the baseline indefinitely.

```bash
bash scripts/backup.sh snapshot --stop-crafty
bash scripts/backup.sh retention-preview
bash scripts/backup.sh check
```

Without `--stop-crafty`, backup refuses a running container. When already stopped it
stays stopped. Forced kills/unclean exits fail rather than being labeled consistent.
SIGINT/SIGTERM/error cleanup attempts restart; SIGKILL/power loss cannot run traps.
Inspect Crafty after any interrupted maintenance. Logs and return codes are the failure
signal; no email/Slack alert integration has been invented.

## Install restic on a new AMD64 host

Download the official binary and matching checksum file; the initial deployment verified
the archive against the release's SHA256SUMS. This protects against corruption/substitution
relative to the HTTPS release source, not against a compromised upstream account.

```bash
mkdir -p .tools
curl -fL https://github.com/restic/restic/releases/download/v0.19.1/restic_0.19.1_linux_amd64.bz2 -o .tools/restic_0.19.1_linux_amd64.bz2
curl -fL https://github.com/restic/restic/releases/download/v0.19.1/SHA256SUMS -o .tools/SHA256SUMS
(cd .tools && grep ' restic_0.19.1_linux_amd64.bz2$' SHA256SUMS | sha256sum -c -)
bzip2 -dk .tools/restic_0.19.1_linux_amd64.bz2
mv .tools/restic_0.19.1_linux_amd64 .tools/restic
chmod 700 .tools/restic
umask 077
# Once only: never replace the key for an existing repository!
openssl rand -base64 -out .secrets/restic-password 48
.tools/restic --password-file .secrets/restic-password -r recovery/restic init
.tools/restic --password-file .secrets/restic-password -r recovery/baseline init
```

Use the architecture-matching release for ARM64 and verify its corresponding checksum.
Existing keys/repos must be preserved. Do not put the password on command lines or in Git.

## Protected baseline

```bash
bash scripts/backup.sh baseline --stop-crafty
```

This writes to **recovery/baseline**, a separate encrypted repository never passed to
normal `forget`/`prune`. The command adds snapshots; it never replaces an older baseline.
The deployment baseline proves panel recovery only. After registration, controlled
gameplay and inspecting the fresh world, add a true **known-good world baseline**.
Do not call an uninspected restored/griefed world known-good.

Separate repositories protect against this project's rotation, not malicious deletion,
root access or disk loss. Keep an offsite/offline copy with independent credentials or
storage retention/immutability when possible. No Synology connectivity is assumed.

## Optional offsite repository

Create a private `.secrets/backup.env` (trusted Bash config, 0600), for example:

```bash
export RESTIC_REPOSITORY='sftp:backup-user@YOUR-BACKUP-HOST:/backups/minecraft'
export RESTIC_PASSWORD_FILE='/absolute/private/path/to/restic-password'
# Optional independently protected destination:
BASELINE_REPOSITORY='sftp:baseline-user@YOUR-BACKUP-HOST:/backups/minecraft-baseline'
```

Configure a dedicated SSH key, verify host keys, restrict the remote account to the
backup directory and initialize the repositories explicitly. For S3 use restic's
documented backend variables in this private file and least-privilege credentials.
Never place backups inside `runtime/` or they will recursively back themselves up.
Changing the destination does not copy old restore points. Preserve both repositories
until `restic copy`/restoration has been tested. Offsite storage is not configured here.

## Scheduling and verification

The repository provides `examples/systemd/minecraft-backup.service` and `.timer`.
Install under `~/.config/systemd/user/`, adjusting the absolute repository path if
necessary, then `systemctl --user daemon-reload` and
`systemctl --user enable --now minecraft-backup.timer`.
The timer uses an explicit Europe/Zagreb timezone and **Persistent=false**, so a boot
does not unexpectedly stop games to catch up a missed backup. User lingering is needed
for unattended execution after logout (`loginctl enable-linger matej`, administrator
authorization may be required). Check `loginctl show-user matej -p Linger` and
`systemctl --user list-timers`. Never claim unattended coverage without this check.

```bash
journalctl --user -u minecraft-backup.service --since yesterday
.tools/restic --password-file .secrets/restic-password -r recovery/restic snapshots
bash scripts/restore.sh latest recovery/restore-test-YYYYMMDD
```

Restoration verifies bytes into a **new** directory and refuses overwrite. See
[recovery](recovery.md) for controlled promotion to live state. Run the separate
retention/baseline regression test with `python3 -m unittest discover -s tests -v`.
Monthly, run the full repository integrity check and a restore drill. Gameplay recovery
requires actually opening the restored world and testing accounts, not just checksums.

Crafty's optional **Backups** tab can provide a few compressed per-instance quick
restore points. Configure shutdown-before-backup for SQLite/plugin consistency and
keep only 2–3; it is not the independent retention tier. Avoid overlapping Crafty
scheduled jobs with the host cold snapshot. No per-server schedules are pre-created.

Sources: [restic retention](https://restic.readthedocs.io/en/stable/060_forget.html),
[restic restore](https://restic.readthedocs.io/en/stable/050_restore.html),
[Crafty backup manager](https://docs.craftycontrol.com/pages/user-guide/backup-manager/).
