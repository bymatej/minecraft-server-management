# Configuration

The deployment pin is Crafty 4.11.0, official Docker Hub publisher
`arcadiatechnology/crafty-4`. Both that registry and GitLab are documented upstream.
The pulled multi-architecture manifest digest is
`sha256:7b6e87514259549647e15ceeaf73d238792e6d77e2c79fc744d5badc8d6e997c`.
It provides linux/amd64 and linux/arm64; this host uses amd64. The local `.env` pins
the digest as well as the release tag. Copy that pin when reproducing this deployment.

| Host path, relative to repository | Container path | Contents |
| --- | --- | --- |
| runtime/config | /crafty/app/config | Panel DB, settings, credentials, TLS material |
| runtime/servers | /crafty/servers | Independent instances, worlds, plugin/mod data |
| runtime/backups | /crafty/backups | Crafty's instance backup archives |
| runtime/logs | /crafty/logs | Panel logs |
| runtime/import | /crafty/import | Temporary import material |

Replace the container, not these directories. Back up all five. Keep the enclosing
`runtime` directory private. The upstream wrapper starts as root, sets mount group
permissions and invokes the application as UID 1000, group root. Membership in group
root does not grant UID 0 powers. This host's `matej` is also UID 1000. On a different
host, verify ownership/read access for backups; do not blindly force a different UID.

Keep `runtime/import` empty after importing. Upstream deliberately rechecks permissions
throughout `/crafty` when files remain there, which noticeably slows restarts. Downloaded
plugin assets are staged in `.tools/downloads` instead. Image `EXPOSE` metadata includes
large port ranges; this does not publish them. Inspect `HostConfig.PortBindings` for
actual host exposure, rather than interpreting every number in `docker ps` as public.

The six retained Linux capabilities are for the upstream permission wrapper,
sudo user/group transition and forwarding shutdown signals (`KILL`). All other
capabilities are dropped. No socket, host
network, privileged mode or extra service is configured. A blanket `user: 1000` or
`no-new-privileges` can break this upstream startup model; do not add them untested.

`.env` controls the image, total container memory limit, panel host port, gameplay
bind addresses and ports. Minecraft settings live in each instance, not environment
variables. Configure the instance's JVM command and heap in Crafty's **Config** tab.
The image contains Java 8, 11, 17, 21 and 25; verify installed executables with:

```bash
docker compose exec crafty sh -c 'ls /usr/lib/jvm'
docker compose exec crafty /usr/lib/jvm/java-21-openjdk-amd64/bin/java -version
```

Java 21 is the family 1.21.4 choice. Newer Minecraft versions can need Java 25; old
Forge can need Java 8/17. Match the chosen Minecraft/loader documentation and actual
image paths (arm64 paths differ). Do not install Java interactively in the container;
it disappears on recreation. Use a tested newer official image when needed.

The 4 GiB cgroup limit includes all Java processes and Crafty. Start with a 512 MiB
minimum heap and the README's maximums. Keep at least 1 GiB outside aggregate heaps.
Do not run all examples simultaneously at those maximums under the current limit.
Check `docker stats crafty-controller`, `free -h`, Crafty metrics and tick warnings.
An OOM kill can bypass graceful shutdown; the memory limit alone cannot ensure safety.

This host reports no Docker swap-limit capability. The 4 GiB memory limit is installed,
but per-container swap limits cannot be enforced here. No kernel/daemon settings were
changed. Monitor host swap too; do not treat the container limit as a complete resource
isolation guarantee.

See [updating](updating.md) for upgrades and [networking](networking.md) before
enabling gameplay ports. Use `docker compose config --quiet` after every edit.
