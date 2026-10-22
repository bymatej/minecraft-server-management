# Creating and managing instances

The following labels/workflows were checked against Crafty 4.11.0 source and official
documentation. They are not a claim that a browser or Minecraft client was exercised.
The initial deployment leaves instance creation to the owner after the first secure
panel login. Do not automatically import any historical world.

## Creation in Crafty

1. Open **Servers → Create New Server**, choose **Minecraft Java**. Use the download
   form, select the server software and its explicit version from the available
   catalog. Give the server its name, minimum/maximum memory (GiB) and port, then
   **Build Server**. Read/accept Mojang's EULA when prompted if you agree to it.
2. Wait for download/install completion. Open the server's **Config** tab. Check the
   execution command, Java binary, heap and stop command (`stop`). Keep autostart off
   while configuring and checking authentication. Set monitoring host `127.0.0.1` and
   the correct port; this is inside the Crafty container, not the VPS loopback binding.
3. In **Files**, edit `server.properties` while the instance is stopped. Merge the
   corresponding example. Keep `server-ip=` empty so Docker forwarding reaches it.
   World name is set here before first generation, not necessarily in the creation
   wizard. Later changes create/select a different world rather than rename old data.
4. Start from the dashboard/server **Terminal**, inspect startup messages and send
   `list` to confirm console operation. Stop and wait for saved worlds before file edits.
5. Configure a unique port on every server. Temporary bootstrap ports in `.env` must
   also be set here. Final ports are 25565/25566/25567.

The upstream catalog changes independently of the image. If a version/type is absent,
download from its official project and use Crafty's **Upload Zip** import: include
the server directory contents, select the archive's root directory and executable
JAR, give a name, heap and port, and import. Do not write Crafty's internal database.

## Personal Vanilla

Name **Personal Vanilla**, final TCP 25565, online mode, enforced whitelist, independent
`PersonalVanilla` world. Start at 512 MiB / 1.5 GiB heap, view 8 / simulation 6.
Initial pin: **Vanilla 26.3, Java 25**, verified as Mojang's stable release in the
[official version manifest](https://piston-meta.mojang.com/mc/game/version_manifest_v2.json)
on 2026-10-22. Select `/usr/lib/jvm/java-25-openjdk-amd64/bin/java`. Its release
metadata requires Java major 25. Do not interpret the family version requirement
as a recommendation to use an obsolete Vanilla release forever. Add approved
Microsoft-authenticated names through the console. On later installations, review
whether a newer stable release is appropriate rather than silently following latest.

## Family Paper

Name **Family Paper**, version **1.21.4**, Java
`/usr/lib/jvm/java-21-openjdk-amd64/bin/java`, 512 MiB / 2 GiB heap, final TCP 25566.
Paper's official download API listed stable **build 232** for that version during
inspection. This is an old version explicitly retained for the family requirement;
it is not Paper's current supported release line. Plan a tested future upgrade.

Use `examples/family-paper/server.properties` and follow [authentication](authentication.md)
before opening the listener. The original view distance 18 is a preference to revisit
after measuring, not this deployment's default. No obsolete `snooper-enabled` or
`max-build-height` is copied. Never point the new server at the old griefed Ubuntoo2.

## Friends Forge / Fabric / Spigot

Name **Friends Forge**, final TCP 25567, online mode and independent `FriendsForge`
world. Choose Minecraft, Forge, Java and mod versions as a matched set. Modpacks
often need matching mods/configs on every client; server-only mods are exceptions.
Start at 512 MiB / 2–3 GiB only if the chosen pack can fit; measure before public play.

Crafty's catalog supports modded creation paths, but not every installer/version is
one-click. For an unavailable Forge version, use the official Forge installer on a
trusted staging Linux machine with the matching Java: `java -jar forge-INSTALLER.jar
--installServer`. Package the **whole resulting directory**, including `libraries`,
argument files and scripts; upload/import into Crafty. Modern Forge generally uses
Java's `@user_jvm_args.txt @libraries/net/minecraftforge/forge/VERSION/unix_args.txt
nogui`, not a standalone runnable Forge JAR. Set the Config execution command to the
installer-generated launch form using the correct Java path; avoid backgrounding it
so Crafty owns the process/stdin. Set heap in the argument file where applicable.
Confirm `stop` works before relying on coordinated shutdown/backup.

Fabric can be downloaded from its official installer/catalog and imported similarly.
Spigot can use Crafty's available catalog or an official BuildTools-built JAR. Do not
download unofficial Spigot binary mirrors. Paper plugins do not work on Vanilla or
ordinary Forge. Future offline-mode Forge needs its own verified authentication design;
AuthMe is not a Forge mod.

## Plugin/mod file workflow

Stop the relevant instance. Open its **Files** tab, enter `plugins` for Paper/Spigot or
`mods` for Forge, then use **Upload** to upload the compatible JAR. If the directory
doesn't exist, start the correctly configured server once privately to generate it,
then stop. Never upload plugins into `/crafty/app/config` or another server's directory.

When the JARs were downloaded on the VPS rather than on the workstation running the
browser, they can be installed through the Compose bind mount instead. Stop the server
first, then use `bash scripts/install-auth-plugins.sh`; it discovers Crafty server names
and UUIDs from the read-only Crafty catalog, selects the target, verifies a supported
version profile, and copies the JARs into that server's `plugins` directory. The host
path is `runtime/servers/<server-id>/plugins`, while Crafty sees the same directory as
`/crafty/servers/<server-id>/plugins`. This avoids copying into Crafty's application
configuration directory.

Start, inspect **Terminal** and **Logs** (also `logs/latest.log`). Stop again before
editing a generated plugin's `plugins/PLUGIN/config.yml` through Files. For upgrades,
first take a cold backup, download the old configuration/JAR as an additional quick
rollback copy, remove the old JAR through Files, upload exactly one replacement, then
restart. Do not use Bukkit `/reload` or hot-load plugin managers. Remove a plugin by
stopping, backing up, removing its JAR, then starting; preserve its data until no longer
needed. Never remove AuthMe from an exposed offline server.

## API evaluation

Crafty **does** provide a supported authenticated v2 API, including `POST /api/v2/servers`
for creation/import and server actions for start/stop. The 4.11.0 schema requires
creation type, monitoring type, and nested software/version/memory/port data; access
is controlled by server-creation and server permissions. An API token created after
securing the administrator account can automate future provisioning. This deployment
does not create an administrative token, mutate internal DB tables or emulate clicks.
GUI provisioning is intentionally the initial owner workflow, including EULA acceptance
and selecting the unspecified Forge/modpack version.

Sources: [creation](https://docs.craftycontrol.com/pages/user-guide/server-creation/minecraft/),
[API](https://docs.craftycontrol.com/pages/developer-guide/api-reference/v2/),
[4.11.0 API schema](https://gitlab.com/crafty-controller/crafty-4/-/blob/v4.11.0/app/classes/web/routes/api/servers/index.py),
[Paper downloads API](https://docs.papermc.io/misc/downloads-api/),
[Forge downloads](https://files.minecraftforge.net/).
