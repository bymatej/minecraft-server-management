# VPS preflight — 2026-10-22

- Ubuntu 20.04.6 LTS, x86_64, 6 vCPUs, 15.62 GiB RAM, 2 GiB unused swap.
- Approximately 9.8 GiB RAM used, 5.4 GiB available before Crafty.
- Root filesystem: 392 GiB total, 270 GiB available.
- Docker Engine 28.1.1, Compose 2.35.1. No global daemon changes required.
- `server2.bymatej.com` A record: 5.189.183.30, matching eth0. No AAAA answer.
- SSH listens on 22, Nginx on 80/443, Nginx active. Crafty port 8443 was free.
- **25565 and 25566 are occupied.** Both old McMyAdmin containers are running:
  `McMyAdmin_1.21.10_paper_pillagers` (about 2.8 GiB) and
  `McMyAdmin_1.21.4_paper_matija` (about 2.1 GiB). The latter is not dead as assumed.
- They mount their same-named named volumes at `/McMyAdmin`. Other historical volumes
  include `McMyAdmin_1.20.4_paper_matija` and `MCMA2_Forge_1.19.2_Hanuted`. None deleted,
  modified or imported. The old Ubuntoo2 world's integrity is unverified.
- `/minecraft/` and `/minecraft/private/` still proxy to 8080/8081, which these live
  containers publish. These routes are not proven obsolete. Leave them unchanged.
- Existing stacks include Hermes/Open WebUI, Vedro/PostGIS/MinIO, Pompejska/Postgres,
  Guacamole, Portainer and you-todoo. Running and stopped containers/networks/volumes
  were inventoried. No unrelated resources are used by this project.
- The old Minecraft working tree was clean. The new repository contained an existing
  LICENSE/initial commit on main (not literally empty). Its SSH remote was verified.
- `contabo-vps-notes` has pre-existing edits under `notes/installation/hermes/`.
  No edits, commits or deployment made there.
- UFW, iptables and ip6tables inspection could not run: sudo requires an interactive
  password. Firewall policy and Contabo firewall rules remain **unverified**.

Decision: deploy only the private panel on a dedicated Compose bridge. Gameplay
activation is deferred until approved legacy cutover and family security acceptance.
This preserves existing addresses and avoids interference. Nginx needs no change.

Host OS support/ESM status merits separate review. Do not interpret the successful
container deployment as a security audit of every existing public service.
