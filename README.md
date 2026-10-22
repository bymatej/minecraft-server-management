# Minecraft server management

I built my old Minecraft image around McMyAdmin2, a pile of installers, and environment
variables. It worked for its time. I would now rather play Minecraft than maintain
another Java installer and control panel integration.

This repository runs **Crafty Controller 4.11.0** using its official image. Crafty
provides the dashboard, console, server creation/import, file uploads and per-server
settings. Docker Compose provides the deployment. Restic provides independent,
encrypted recovery copies. No custom image, extra database, marketplace or file browser.

## Current deployment

Crafty is staged alongside the old servers, with **only 127.0.0.1:8443 published**.
The audit found both old Minecraft containers running on 25565 and 25566; they have
not been stopped or migrated. `server2.bymatej.com:25566` still reaches the old server.
See [the preflight report](docs/preflight.md) and [test results](docs/validation.md).
The new family server must not be public until its authentication tests pass.

## How it fits together

One Crafty container manages multiple Java processes, each with its own directory,
world, port, plugins/mods and heap. These are **not separate containers**. Plugins can
run code as Crafty's service user and potentially access other instances' files.
Only trusted people get panel access, and only trusted JARs get uploaded.

| Instance | Port | Initial configuration | Suggested maximum heap |
| --- | --- | --- | --- |
| Personal Vanilla | 25565 | 26.3, Java 25, online mode, whitelist | 1.5 GiB |
| Family Paper | 25566 | 1.21.4, Java 21, offline mode, AuthMe, CoreProtect | 2 GiB |
| Friends Forge | 25567 | Version/modpack chosen together; online mode | 2–3 GiB initially |

These are alternatives within the current **4 GiB container limit**, not permission
to start everything at once. Leave at least 1 GiB beyond the active heaps for Crafty,
native JVM memory and filesystem activity. Raise the limit only after rechecking
host memory and the old servers. Heavy modpacks may need substantially more.

## Install and start

Linux, Docker Engine, Compose v2, Bash and Python 3 are required. The audited VPS is
AMD64 Ubuntu 20.04 with 6 vCPUs and 16 GB RAM; about 5.4 GB was available before deployment.
The host OS needs a separate support/ESM review; this project does not upgrade it.

```bash
git clone git@github.com:bymatej/minecraft-server-management.git
cd minecraft-server-management
bash scripts/preflight.sh
bash scripts/init.sh
bash scripts/verify.sh
docker compose pull
docker compose up -d
bash scripts/verify.sh --live
```

`init.sh` preserves an existing `.env`. The official image prepares its five bind
mounts on first startup and runs the application as `crafty`. Do not override `user`,
run a recursive chown, or use chmod 777. The private parent `runtime/` is mode 700.
See [configuration](docs/configuration.md) for persistent paths and resource tuning.

## Open the dashboard

From your computer:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:8443:127.0.0.1:8443 matej@server2.bymatej.com
```

Visit **https://127.0.0.1:8443**. Expect a self-signed certificate; verify its fingerprint
over your trusted SSH connection as described in [security](docs/security.md).
Read `runtime/config/default-creds.txt` privately on the VPS for initial credentials;
do not paste that file into chat, tickets or logs. Change the administrator password,
then enable TOTP under **Account Settings → Multi Factor Auth**. Save recovery codes
in your password manager. The optional public route is prepared in the separate
`contabo-vps-notes` repository at `https://crafty.bymatej.com`; it remains inactive
until DNS, a Let's Encrypt certificate and `/etc/nginx/.htpasswd-crafty` exist. Basic
Auth is an additional layer before Crafty's password and TOTP.

## Everyday use

```bash
docker compose logs -f --tail 50
docker compose restart
docker compose down
docker compose up -d
docker stats crafty-controller
```

For planned maintenance, stop Minecraft instances using Crafty's **Stop** control,
wait for their consoles to finish saving, then stop/restart Crafty. SIGTERM also invokes
Crafty's server shutdown routine; Compose allows three minutes. Increase the grace
period if a modpack needs longer. Power loss, OOM and forced kills can still corrupt data.
There is no midnight or inactivity shutdown automation.

Create servers using [the GUI walkthrough](docs/minecraft-servers.md). Upload plugin
JARs in that instance's **Files → plugins** directory, or Forge mods in **Files → mods**.
Stop the instance before changing JARs, keep one version of each plugin, then start and
check the console and `logs/latest.log`. The file manager also edits configuration.

For the reviewed family Paper profile, the server-side alternative is:

```bash
bash scripts/install-auth-plugins.sh
```

The installer reads Crafty's catalog, shows server names and ports, selects the target
when multiple servers exist, and refuses an unverified Minecraft/Paper version. It does
not blindly install the 1.21.4 AuthMe build into a newer or unknown Paper instance.

That refusal is intentional. For example, a server whose Crafty update URL is
`.../paper/26.2/paper.jar` is not treated as Paper 1.21.4, even if AuthMe JARs already
exist in its `plugins` directory. The script validates the compatibility profile first,
then checks whether the selected JAR versions are already installed. To use the pinned
family profile, create/configure the instance as Paper 1.21.4. To keep a newer Paper
instance, add a separately reviewed plugin profile; do not override the check or assume
that the latest plugin works with every Minecraft release.

## Family server: offline mode is intentional

The children use offline-mode clients. `online-mode=false` stays, but a username
whitelist alone cannot prove who is connecting. [The authentication guide](docs/authentication.md)
covers the compatible AuthMe 5.7.0 pin, private registration, impersonation tests and
the public-access gate. The latest 6.0.1 Paper JAR requires Minecraft API 1.21.11.
No accounts or passwords are invented by this deployment.

Paper starts with view distance 8 and simulation distance 6. My old preference of 18
is recorded, but is expensive on a shared VPS. Hard difficulty, flight allowance,
60-minute player idle timeout and spawn protection 10 are preserved. The idle timeout
kicks an idle player; it does not shut down the server. Command blocks remain disabled.

CoreProtect CE 24.1 gives administrators investigation and rollback tools:

```text
/co inspect
/co lookup u:PLAYER t:2h r:20
/co rollback u:PLAYER t:2h r:20 #preview
/co rollback u:PLAYER t:2h r:20
/co restore u:PLAYER t:2h r:20
```

Replace `PLAYER` with the actual name and inspect the preview before applying it.
Read [recovery](docs/recovery.md) before a large rollback. CoreProtect does not replace backups.

## Networking, backups and upgrades

Gameplay uses direct TCP, no HTTP proxy. [Networking](docs/networking.md) documents
port activation, the legacy-container cutover and optional `kids.bymatej.com` SRV records.
No DNS change is needed for `server2.bymatej.com:25566` after cutover.

[Backups](docs/backups.md) use restic with 7 daily, 4 weekly and 3 monthly restore
points, plus a separate baseline repository that normal rotation cannot touch.
Snapshots include the entire Crafty state, worlds and plugin databases. A cold
snapshot briefly stops Crafty; the scripts restart it on errors. Offsite storage
is optional but strongly recommended: another directory on this disk is not disaster recovery.

[Updating](docs/updating.md) describes deliberate Crafty/Java/Minecraft/plugin upgrades
and rollback. Nothing downloads new Minecraft or authentication-plugin versions at startup.
[Docker Hub](docs/docker-hub.md) explains why there is no custom image to publish.

## Troubleshooting

- **Port already allocated:** run `ss -tlpn` and `docker ps`. Do not kill the owner;
  the old McMyAdmin instances currently own 25565/25566. Panel-only Compose avoids this.
- **Dashboard unavailable:** confirm SSH forwarding, `docker compose ps`, and logs.
  A self-signed TLS warning is expected; a different fingerprint merits investigation.
- **Permission denied:** inspect mount ownership and the wrapper logs. Do not override
  the image user. New bind mount roots must be accessible to the supported wrapper.
- **Can't keep up / OOM:** reduce view distance/heap concurrency, check `docker stats`
  and `free -h`. Giving every JVM more heap can make the whole host less stable.
- **AuthMe did not load:** keep the family listener private, stop the instance and
  inspect the plugin exception. Do not open the port just because Paper started.
- **Backup failed:** inspect the service journal, confirm Crafty resumed and run
  `bash scripts/backup.sh check`. Never rotate away the baseline to make space.

## References

- [Crafty Docker installation](https://docs.craftycontrol.com/pages/getting-started/installation/docker/)
- [Crafty 4.11.0 source/release](https://gitlab.com/crafty-controller/crafty-4/-/releases/v4.11.0)
- [AuthMe 6.0.1](https://github.com/AuthMe/AuthMeReloaded/releases/tag/6.0.1)
- [CoreProtect](https://modrinth.com/plugin/coreprotect) and [commands](https://docs.coreprotect.net/commands/)
- [Restic](https://restic.readthedocs.io/) and [Docker firewall behavior](https://docs.docker.com/engine/network/packet-filtering-firewalls/)

This is my personal setup. It deliberately leaves account enrollment and gameplay
acceptance to a person with a real Minecraft client. See the validation record for
what was actually tested, rather than treating configuration files as proof of security.
