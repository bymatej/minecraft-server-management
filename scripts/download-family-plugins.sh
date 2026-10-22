#!/usr/bin/env bash
# Download reviewed assets only; installation is an explicit GUI operation.
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .tools/downloads
cd .tools/downloads
curl --fail --location --proto '=https' --tlsv1.2 \
  https://github.com/AuthMe/AuthMeReloaded/releases/download/5.7.0/AuthMe-5.7.0.jar \
  -o AuthMe-5.7.0.jar.part
printf '%s\n' '67cc5c1923315cedc152616abce81cf79d004d44cb8fe9ab4d0b262728f23e08  AuthMe-5.7.0.jar.part' | sha256sum --check
mv AuthMe-5.7.0.jar.part AuthMe-5.7.0.jar
curl --fail --location --proto '=https' --tlsv1.2 \
  https://cdn.modrinth.com/data/Lu3KuzdV/versions/3sehX6Sg/CoreProtect-CE-24.1.jar \
  -o CoreProtect-CE-24.1.jar.part
printf '%s\n' '76aad727528ddb990bbee5069f8ef3fcd018ae0bcdea89b965be2485e828633eb068672e841be64e550c8474f901a24d8c15c7bd44c2bd6c96244e1e58de0c95  CoreProtect-CE-24.1.jar.part' | sha512sum --check
mv CoreProtect-CE-24.1.jar.part CoreProtect-CE-24.1.jar
echo 'Verified downloads in .tools/downloads; nothing installed in a Minecraft instance.'
