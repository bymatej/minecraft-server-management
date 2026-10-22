# Recovery and CoreProtect

## CoreProtect CE 24.1

Use the free community release from [the official Modrinth project](https://modrinth.com/plugin/coreprotect).
Its version metadata explicitly lists Minecraft 1.21.4; the JAR declares Bukkit API
1.16. Source license: Artistic-2.0. No paid features or external DB are needed here.

Pinned URL:
https://cdn.modrinth.com/data/Lu3KuzdV/versions/3sehX6Sg/CoreProtect-CE-24.1.jar

SHA-512 from Modrinth's API, checked against the staged download:

```text
76aad727528ddb990bbee5069f8ef3fcd018ae0bcdea89b965be2485e828633eb068672e841be64e550c8474f901a24d8c15c7bd44c2bd6c96244e1e58de0c95
```

Staged at `.tools/downloads/CoreProtect-CE-24.1.jar`. Upload to Family Paper's `plugins`
directory and start privately. Check it enables and creates `plugins/CoreProtect/`.
Stop and configure that version's generated config: `use-mysql: false` for embedded
SQLite; keep block placement/breaking, container transactions and relevant entity
logging. Disable `player-messages` and `player-commands` logging to avoid recording
authentication passwords and unnecessary private text. Keep block/container history.
Do not copy current 25.x DuckDB/ClickHouse settings into the pinned 24.1 config.

The minimal overlay is `examples/family-paper/coreprotect-settings.yml`; keys were
checked against the pinned JAR. Merge it with the generated file, preserving the
other logging options. Do this before registering accounts.

The DB `plugins/CoreProtect/database.db` belongs with the server's persistent files.
Keep normal players non-OP and do not grant `coreprotect.*`, rollback or inspection
permissions. The plugin's administrative permissions default to OP; verify denial
on a normal player and an unauthenticated connection impersonating the operator.

Start with **90 days** history, reviewed monthly. After a cold snapshot and checking
for unresolved griefing, an administrator may run `/co purge t:90d`. Purge is
irreversible within that database; do not automate it until storage growth is known.
Check directory sizes regularly. There is no automatic purge configured by this repo.
Keep monthly snapshots and the separate known-good baseline even after purging logs.

## Investigating and undoing damage

Freeze access if griefing is ongoing, preserve a backup of the damaged state, then
use an authenticated administrator near the affected area:

```text
/co inspect
/co lookup u:PLAYER t:2h r:20
/co lookup t:1h-2h r:20
/co rollback u:PLAYER t:2h r:20 #preview
/co rollback u:PLAYER t:2h r:20
/co restore u:PLAYER t:2h r:20
```

`t:1h-2h` selects changes between one and two hours ago; `t:2h` covers the last two
hours. A radius limits collateral changes. Inspect/preview first, then repeat without
`#preview` to apply. `restore` re-applies changes that a rollback removed. Broad
world-wide rollbacks deserve a backup and careful review. Logged offline names identify
the account presented, not necessarily the person using it before authentication was fixed.

Controlled acceptance test: an ordinary authenticated player places/breaks a distinctive
test block; administrator inspection identifies it; preview a narrow five-minute,
five-block rollback, apply it and verify the block, then test restoration. Recreate
Crafty and confirm the history is still queryable. A normal player must be denied the
same commands. These tests require a real client and are not fabricated here.

## Restoring files / complete instances

For accidental damage, prefer a narrow CoreProtect rollback. For world corruption,
broken plugin state or unknown damage, use a cold snapshot from [backups](backups.md).

```bash
bash scripts/restore.sh SNAPSHOT_ID recovery/restore-YYYYMMDD
# Or the protected repository:
bash scripts/restore.sh SNAPSHOT_ID recovery/baseline-YYYYMMDD --baseline
```

The script refuses every existing target and verifies restored bytes. It never
overwrites live data. Restic restores the original relative tree under the target;
inspect it before copying. First preserve the current damaged state with a new cold
snapshot, stop the affected instance/Crafty, and explicitly choose the restoration.
Keep the old live directory under a dated quarantine path until recovery is accepted.
Restore the whole instance (world dimensions, playerdata, properties, whitelist/OP,
plugins including AuthMe/limbo and CoreProtect DBs), not only its overworld region files.

For panel failure, restore **config and servers from the same snapshot** with the
same pinned Crafty version and all five mount paths. For a broken upgrade restore its
pre-upgrade state and previous image together. An old image over a newly migrated DB
is not a reliable rollback. A simple container failure needs only recreation with
the existing mounts, provided they are healthy.

Before replacing production, run a restored copy on different **loopback-only** ports
and a different Compose project/container name, with all game autostarts disabled until
checked. Verify panel login/MFA, server starts, world location/inventory, AuthMe accounts,
CoreProtect history and graceful stop. Never run restored production worlds publicly
in parallel. Do not downgrade a world across Minecraft data-version changes; restore
the complete pre-upgrade world instead.

References: [CoreProtect commands](https://docs.coreprotect.net/commands/),
[permissions](https://docs.coreprotect.net/permissions/).
