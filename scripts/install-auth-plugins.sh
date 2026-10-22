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

# This is deliberately a reviewed compatibility profile, not a blind latest-version installer.
# Add a new profile only after checking the plugin manifests against the exact server version.
profile=''
if [[ "$update_url" == */paper/1.21.4/* ]]; then
  profile='paper-1.21.4'
fi
if [[ -z "$profile" ]]; then
  echo "ERROR: no verified AuthMe/CoreProtect profile for '$server_name'." >&2
  echo "       Crafty reports update URL: ${update_url:-unknown}" >&2
  echo '       Do not install the 1.21.4 AuthMe build into this server.' >&2
  exit 1
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
if [[ ! -f "$DOWNLOAD_DIR/AuthMe-5.7.0.jar" ]]; then
  echo 'Downloading and verifying AuthMe 5.7.0...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    https://github.com/AuthMe/AuthMeReloaded/releases/download/5.7.0/AuthMe-5.7.0.jar \
    -o "$DOWNLOAD_DIR/AuthMe-5.7.0.jar.part"
  printf '%s\n' '67cc5c1923315cedc152616abce81cf79d004d44cb8fe9ab4d0b262728f23e08  '"$DOWNLOAD_DIR"'/AuthMe-5.7.0.jar.part' | sha256sum --check
  mv "$DOWNLOAD_DIR/AuthMe-5.7.0.jar.part" "$DOWNLOAD_DIR/AuthMe-5.7.0.jar"
fi
if [[ ! -f "$DOWNLOAD_DIR/CoreProtect-CE-24.1.jar" ]]; then
  echo 'Downloading and verifying CoreProtect CE 24.1...'
  curl --fail --location --proto '=https' --tlsv1.2 \
    https://cdn.modrinth.com/data/Lu3KuzdV/versions/3sehX6Sg/CoreProtect-CE-24.1.jar \
    -o "$DOWNLOAD_DIR/CoreProtect-CE-24.1.jar.part"
  printf '%s\n' '76aad727528ddb990bbee5069f8ef3fcd018ae0bcdea89b965be2485e828633eb068672e841be64e550c8474f901a24d8c15c7bd44c2bd6c96244e1e58de0c95  '"$DOWNLOAD_DIR"'/CoreProtect-CE-24.1.jar.part' | sha512sum --check
  mv "$DOWNLOAD_DIR/CoreProtect-CE-24.1.jar.part" "$DOWNLOAD_DIR/CoreProtect-CE-24.1.jar"
fi

same=1
[[ -f "$plugin_dir/AuthMe-5.7.0.jar" ]] || same=0
[[ -f "$plugin_dir/CoreProtect-CE-24.1.jar" ]] || same=0
if ((same)); then
  echo "Already installed for '$server_name': AuthMe 5.7.0 and CoreProtect CE 24.1."
  exit 0
fi

for old in "$plugin_dir"/AuthMe-*.jar "$plugin_dir"/CoreProtect*.jar; do
  [[ -e "$old" ]] || continue
  echo "Replacing old plugin: $(basename "$old")"
  rm -f -- "$old"
done
install -m 0644 "$DOWNLOAD_DIR/AuthMe-5.7.0.jar" "$plugin_dir/"
install -m 0644 "$DOWNLOAD_DIR/CoreProtect-CE-24.1.jar" "$plugin_dir/"
echo "Installed AuthMe 5.7.0 and CoreProtect CE 24.1 into '$server_name'."
echo 'Start the server in Crafty and inspect its console; keep it private until AuthMe tests pass.'
