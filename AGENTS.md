# Agent guidance

This repository manages a real Crafty Controller deployment on a shared production VPS.
Treat runtime state and unrelated services as protected.

## Project rules

- Work only in `minecraft-server-management` unless the task explicitly concerns the
  version-controlled Nginx source in `../contabo-vps-notes`.
- Never commit `.env`, `.secrets/`, `.tools/`, `runtime/`, `recovery/`, worlds, plugin
  databases, downloaded JARs, backups, credentials, or private keys.
- Do not modify the old `../minecraft-server` repository.
- Do not stop, remove, restart, or reconfigure unrelated containers or services.
- Do not edit live Nginx configuration directly. Change its source repository, validate
  with `nginx -t`, then deploy only with an explicit safe procedure.
- Do not expose Crafty publicly without the configured TLS and Nginx authentication
  layers. Crafty still requires its own password and MFA.

## Crafty and Minecraft

- Compose uses the pinned official image in `compose.yaml` and persistent bind mounts
  under `runtime/`.
- Minecraft instances are processes managed inside the Crafty container, not separate
  Docker containers.
- Stop an instance before changing server JARs or plugin files; use Crafty's graceful
  stop and inspect its console after starting it again.
- The host path `runtime/servers/<server-id>/` is Crafty's `/crafty/servers/<server-id>/`.

## AuthMe/CoreProtect compatibility

Run `bash scripts/install-auth-plugins.sh` for the reviewed plugin installation path.
It discovers Crafty servers by name, selects a target, downloads checksum-verified JARs,
and installs only a reviewed compatibility profile.

The manifest selects AuthMe 5.7.0 plus CoreProtect CE 24.1 for Paper 1.21.4, and
AuthMe 6.0.1 Paper plus CoreProtect CE 24.1 for Paper 26.2. The installer derives the
Minecraft/Paper version from Crafty's update URL, verifies selected checksums, and
replaces mismatched plugin JARs. The 26.2 profile has passed plugin-load smoke testing;
its full AuthMe registration, impersonation, restart and gameplay matrix remains
required. The installer must refuse other unknown Paper versions. Do not weaken that
check, force a JAR to load by editing metadata, or assume that a plugin's latest release
supports every Minecraft version. Add a new profile only after checking the exact
server version, plugin manifest, release notes, and real startup/gameplay tests.

An error such as `no verified AuthMe/CoreProtect profile` is a safety result, not a
missing-file error. Leave the server private until compatibility and AuthMe registration
tests pass.

## Validation

Before committing, run at least:

```bash
docker compose config
bash -n scripts/*.sh
python3 -m unittest discover -s tests -v
bash scripts/verify.sh --live
```

Review `git diff`, `git status`, and staged paths for secrets before pushing. Use small,
focused commits and never force-push or rewrite unrelated history.
