# Networking and cutover

Current `docker compose up -d` starts the panel only. Minecraft may listen within
the container, but no gameplay port is published. The optional Nginx management route
is separate and does not alter Minecraft TCP routing. A separate file adds exactly three
TCP mappings; they default to loopback. No Nginx Minecraft HTTP or stream proxy is involved.

## Private bootstrap while the old servers run

To test with clients without touching occupied ports, edit local `.env`:

```dotenv
COMPOSE_FILE=compose.yaml:compose.gameplay.yaml
VANILLA_BIND=127.0.0.1
FAMILY_BIND=127.0.0.1
FORGE_BIND=127.0.0.1
VANILLA_PORT=25665
FAMILY_PORT=25666
FORGE_PORT=25667
```

First verify these temporary ports are free. Set each instance's `server-port` and
Crafty monitoring port to the same temporary value, leaving `server-ip=` empty.
Stop Minecraft instances before applying `docker compose up -d`, which recreates
Crafty when mappings change. From a trusted computer:

```bash
ssh -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:25566:127.0.0.1:25666 matej@server2.bymatej.com
```

The family client joins `127.0.0.1:25566`. This is a bootstrap/testing tunnel, not a
VPN requirement for normal play. Finish all [authentication tests](authentication.md)
before public access. Connections through SSH share a source IP; disable AuthMe
sessions and keep the registration-per-IP limit sufficient for four family accounts.

## Current test cutover

The old `McMyAdmin_1.21.4_paper_matija` container was stopped (not removed), and the
Crafty gameplay overlay currently publishes the test instance as `0.0.0.0:25566`.
The direct address is therefore `server2.bymatej.com:25566` once the instance is
started in Crafty. The old `25565` container remains untouched. The local `.env` keeps
the unused Vanilla/Forge mappings on loopback placeholder ports to avoid collisions.

This is a controlled test exposure, not the completed family cutover: the test server
reports Paper `26.2`. The installer selects AuthMe `6.0.1` Paper and CoreProtect CE
`24.1` for that version, but real family accounts must remain off it until the full
registration, impersonation, restart and gameplay test matrix passes.

## Final cutover

1. Confirm old servers' players/owners and schedule downtime. Preserve their volumes
   and take a verified cold backup before any retirement. Do not import the old world
   without inspecting it; the new Ubuntoo2 is independent.
2. Stop only the two old instances cleanly via their consoles, then their containers,
   after explicit cutover authorization. Keep rollback containers and volumes.
3. Stop new instances. Change `.env` ports and per-instance `server-port`/Crafty
   monitoring ports to 25565, 25566, 25567. `server-ip` remains empty.
4. Open only ready servers by setting their bind to `0.0.0.0`; family requires passing
   registration/login/impersonation/restart checks. Keep unused servers on loopback
   or remove their optional mapping from the overlay.
5. Run `bash scripts/verify.sh`, `docker compose up -d`, then start ready instances.
   Check `docker compose port crafty 25566`, `ss -tlpn`, console logs and actual client
   connections from outside the VPS. The direct address is `server2.bymatej.com:25566`.
6. Rollback: stop new instances and Crafty, release their gameplay mappings, restore
   the previous `.env`, then start only the deliberately stopped old containers.
   New and old worlds are independent; do not merge files blindly.

Keeping `COMPOSE_FILE` in `.env` means ordinary `docker compose up/down/restart` use
the same deployment files. Avoid ad hoc `-f` overrides that accidentally remove ports.
More instances need explicit new mappings and distinct listener ports; no 100-port range.

## Firewall / IPv6

The audit could not read privileged rules. Before public cutover inspect:

```bash
sudo ufw status verbose
sudo iptables -S DOCKER-USER
sudo iptables -t nat -S DOCKER
sudo ip6tables -S
sudo nft list ruleset
```

Preserve existing rules and SSH. With Docker's iptables backend, published traffic
uses FORWARD/DOCKER chains and can bypass UFW INPUT rules. DOCKER-USER restrictions
need to account for DNAT (original destination via conntrack where appropriate).
Do not paste a global DROP policy into a shared host. For bootstrap, loopback bindings
are the restriction; do not substitute a plain `ufw deny 25566` and assume it works.

For a Contabo firewall, preserve all existing services and SSH; allow TCP 25565–25567
only for activated servers, with optional source restrictions. Do not allow 8443,
RCON 25575 or UDP for these Java examples. Contabo rules have not been inspected or
changed. Test from an external network; a request from the VPS is not an external test.

No public IPv6 address/AAAA answer was found in this audit. Bind `0.0.0.0` publishes
IPv4 only. If adding IPv6 later, configure explicit mappings, inspect ip6tables/nft
and provider rules, and test IPv6 before publishing AAAA. Never expose panel IPv6.

## Optional SRV records

```dns
_minecraft._tcp.vanilla.bymatej.com. IN SRV 0 5 25565 server2.bymatej.com.
_minecraft._tcp.kids.bymatej.com.    IN SRV 0 5 25566 server2.bymatej.com.
_minecraft._tcp.friends.bymatej.com. IN SRV 0 5 25567 server2.bymatej.com.
```

Service `_minecraft`, protocol `_tcp`, owner the desired short hostname. Priority 0
is preferred over larger numbers; weight 5 distributes among equal-priority records
(irrelevant for a single target). Port is the actual gameplay port. The target must
resolve directly to the VPS through A/AAAA, not an HTTP proxy/CDN.

Some providers want name `_minecraft._tcp.kids`, others separate service/protocol/name
fields. Avoid doubling `bymatej.com`. Use the full target hostname and trailing dot if
supported. Records have not been created; add them manually if wanted.

```bash
dig SRV _minecraft._tcp.kids.bymatej.com
dig @1.1.1.1 SRV _minecraft._tcp.kids.bymatej.com
dig A server2.bymatej.com
dig AAAA server2.bymatej.com
```

A record verified as 5.189.183.30, matching this VPS. SRV is convenience, not access
control; IP scanners do not need your DNS names. Explicit host:port works independently.

Reference: [Docker packet filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/).
