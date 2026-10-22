# Deliberate upgrades

No Watchtower, startup updater or moving `latest` tag. Review upstream release notes,
including security fixes, and keep a tested rollback snapshot before changing versions.

## Crafty and bundled Java

1. Notify players; stop instances gracefully. Run
   `bash scripts/backup.sh snapshot --stop-crafty` and verify a restore to a separate
   directory. Record the current image digest and commit, and preserve `.env`.
2. Read the target Crafty release notes and Docker upgrade instructions. Change the
   pinned tag **and manifest digest** in `.env.example`, Compose's default and local
   `.env`; inspect supported architectures and Java paths. Review/commit configuration.
3. `docker compose pull`, `bash scripts/verify.sh`, `docker compose up -d`.
   Check health, login/MFA, instance configuration, plugins, graceful stop and restart.
   Keep all five mounts unchanged. Do not use an in-panel source updater on Docker.
4. If rollback is needed, stop Crafty, preserve the failed state, restore the full
   pre-upgrade runtime and previous pinned image together. Do not run an older image
   against an already migrated panel DB and hope it works.

Java updates arrive with a new tested official image. Select the executable required
by each Minecraft version in its Config/start command. Do not apt-install Java into
the running container. If a required runtime isn't shipped, first investigate official
image support; a custom image is a last resort, not the default workflow.

## Minecraft, Paper, Forge and mods/plugins

Stop, cold-backup, restore a private test copy, then update **one component at a time**.
For Paper use the official pinned build for the selected version. Crafty's update
features/catalog may resolve a newer artifact: inspect the target before accepting.
For Forge choose a matching Minecraft/loader/modpack set and test client compatibility.
Keep installer-generated libraries and argument files together. For Spigot rebuild
with the official BuildTools as required; Fabric loader/API/mod versions must match.

For AuthMe/CoreProtect, save their configs and full DB state, fetch only an official
release, verify the advertised checksum, inspect `plugin.yml` API version and Java
requirements, replace one JAR while stopped, start privately and check logs. Re-run
authentication/OP impersonation and rollback tests. Authentication failure means keep
the family port private. Do not overwrite generated settings with a different version's
example. Restoring a previous plugin may also require restoring its pre-upgrade DB.

Minecraft world format upgrades can be irreversible. **Downgrading the JAR is not
world rollback.** Restore the complete earlier snapshot and matching software/mods.
Keep monthly history and a known-good baseline through every major upgrade.

Reference: [official Docker update procedure](https://docs.craftycontrol.com/pages/getting-started/installation/docker/#update-crafty-container).
