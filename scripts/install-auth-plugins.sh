#!/usr/bin/env bash
# Install a reviewed AuthMe/CoreProtect profile into one stopped Crafty server.
# The script intentionally refuses unknown Minecraft/Paper versions.
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
DB="$ROOT/runtime/config/db/crafty.sqlite"
DOWNLOAD_DIR="$ROOT/.tools/downloads"

if [[ ! -r "$DB" ]]; then
  echo "ERROR: Crafty database not found: $DB" >&2
  exit 1
fi

mapfile -t SERVERS < <(python3 - "$DB" <<'PY'
import sqlite3, sys
db = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
for row in db.execute("SELECT server_id, server_name, path, type, server_port, executable_update_url FROM servers ORDER BY server_name"):
    print("\t".join("" if value is None else str(value) for value in row))
PY
)

if ((${#SERVERS[@]} == 0)); then
  echo 'ERROR: no servers created in Crafty.' >&2
  exit 1
fi

echo 'Crafty servers:'
for i in "${!SERVERS[@]}"; do
  IFS=$'\t' read -r id name _path type port update_url <<<"${SERVERS[$i]}"
  printf '  %d) %s (%s, port %s, id %s)\n' "$((i + 1))" "$name" "$type" "$port" "$id"
done

if ((${#SERVERS[@]} == 1)); then
  choice=1
else
  read -r -p 'Select the server to install AuthMe/CoreProtect into: ' choice
fi
if [[ ! "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#SERVERS[@]})); then
  echo 'ERROR: invalid server selection.' >&2
  exit 1
fi

IFS=$'\t' read -r server_id server_name crafty_path server_type server_port update_url <<<"${SERVERS[$((choice - 1))]}"
if [[ "$server_type" != minecraft-java ]]; then
  echo "ERROR: '$server_name' is not a Minecraft Java server ($server_type)." >&2
  exit 1
fi

# Crafty's update URL carries the selected Minecraft/Paper version. Do not use the
# jar filename or the server name: both can be changed independently of the version.
if [[ "$update_url" =~ /paper/([^/]+)/paper\.jar ]]; then
  minecraft_version="${BASH_REMATCH[1]}"
else
  minecraft_version=''
fi

# This is a reviewed compatibility manifest, not a blind latest-version installer.
# Add a mapping only after checking the exact plugin release/manifests and testing it.
authme_version=''
authme_url=''
authme_sha256=''
coreprotect_version='24.1'
coreprotect_url='https://cdn.modrinth.com/data/Lu3KuzdV/versions/3sehX6Sg/CoreProtect-CE-24.1.jar'
coreprotect_sha512='76aad727528ddb990bbee5069f8ef3fcd018ae0bcdea89b965be2485e828633eb068672e841be64e550c8474f901a24d8c15c7bd44c2bd6c96244e1e58de0c95'

case "$minecraft_version" in
  1.21.4)
    authme_version='5.7.0'
    authme_url='https://github.com/AuthMe/AuthMeReloaded/releases/download/5.7.0/AuthMe-5.7.0.jar'
    authme_sha256='67cc5c1923315cedc152616abce81cf79d004d44cb8fe9ab4d0b262728f23e08'
    ;;
  26.2)
    # AuthMe 6.0.1 Paper declares support through the 26.2 line. CoreProtect CE
    # 24.1 is the matching reviewed release for 26.2. Full gameplay/security tests
    # are still required before using this profile for the family server.
    authme_version='6.0.1'
    authme_url='https://github.com/AuthMe/AuthMeReloaded/releases/download/6.0.1/AuthMe-6.0.1-Paper.jar'
    authme_sha256='7704335e9e73a634d9d926344f77897f4c74f78f82453a59f5aa0f8d2722450a'
    ;;
esac

if [[ -z "$authme_version" ]]; then
  echo "ERROR: no verified AuthMe/CoreProtect profile for '$server_name'." >&2
  echo "       Crafty reports update URL: ${update_url:-unknown}" >&2
  echo '       The detected Paper version is not present in the compatibility manifest.' >&2
  exit 1
fi
echo "Detected Paper/Minecraft version: $minecraft_version"
echo "Selected AuthMe $authme_version and CoreProtect CE $coreprotect_version"
if [[ "$minecraft_version" == 26.2 ]]; then
  echo 'WARNING: complete AuthMe registration, impersonation, restart and gameplay tests remain required.'
fi

# The Compose bind mount maps Crafty's /crafty/servers to this host directory.
# Resolve by UUID rather than depending on the container's absolute path.
host_path="$ROOT/runtime/servers/$server_id"
if [[ ! -d "$host_path" ]]; then
  echo "ERROR: server directory not found: $host_path" >&2
  exit 1
fi

plugin_dir="$host_path/plugins"
mkdir -p "$plugin_dir"

mkdir -p "$DOWNLOAD_DIR"
authme_jar="$DOWNLOAD_DIR/AuthMe-$authme_version.jar"
if [[ ! -f "$authme_jar" ]] || [[ "$(sha256sum "$authme_jar" | awk '{print $1}')" != "$authme_sha256" ]]; then
  echo "Downloading and verifying AuthMe $authme_version..."
  curl --fail --location --proto '=https' --tlsv1.2 \
    "$authme_url" -o "$authme_jar.part"
  printf '%s  %s\n' "$authme_sha256" "$authme_jar.part" | sha256sum --check
  mv "$authme_jar.part" "$authme_jar"
fi
coreprotect_jar="$DOWNLOAD_DIR/CoreProtect-CE-$coreprotect_version.jar"
if [[ ! -f "$coreprotect_jar" ]] || [[ "$(sha512sum "$coreprotect_jar" | awk '{print $1}')" != "$coreprotect_sha512" ]]; then
  echo 'Downloading and verifying CoreProtect CE 24.1...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    "$coreprotect_url" -o "$coreprotect_jar.part"
  printf '%s  %s\n' "$coreprotect_sha512" "$coreprotect_jar.part" | sha512sum --check
  mv "$coreprotect_jar.part" "$coreprotect_jar"
fi

same=1
[[ -f "$plugin_dir/AuthMe-$authme_version.jar" ]] || same=0
[[ -f "$plugin_dir/CoreProtect-CE-$coreprotect_version.jar" ]] || same=0
if ((same)); then
  echo "Already installed for '$server_name': AuthMe $authme_version and CoreProtect CE $coreprotect_version."
  exit 0
fi

for old in "$plugin_dir"/AuthMe-*.jar "$plugin_dir"/CoreProtect*.jar; do
  [[ -e "$old" ]] || continue
  echo "Replacing old plugin: $(basename "$old")"
  rm -f -- "$old"
done
install -m 0644 "$authme_jar" "$plugin_dir/"
install -m 0644 "$coreprotect_jar" "$plugin_dir/"
echo "Installed AuthMe $authme_version and CoreProtect CE $coreprotect_version into '$server_name'."
echo 'Start the server in Crafty and inspect its console; keep it private until AuthMe tests pass.'
