#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_binary="${GODOT_BIN:-$HOME/.local/bin/godot}"

cd "$repo_root"
mkdir -p builds
"$godot_binary" --headless --path . --editor --import --quit
"$godot_binary" --headless --path . --script scripts/smoke_test.gd
"$godot_binary" --headless --path . --export-release Linux builds/solar-ascendant-linux.x86_64
chmod +x builds/solar-ascendant-linux.x86_64
"$repo_root/builds/solar-ascendant-linux.x86_64" --headless --quit-after 90
zip -j -9 -q builds/solar-ascendant-linux-x86_64.zip \
  builds/solar-ascendant-linux.x86_64 README.md assets/CREDITS.md assets/fonts/OFL.txt
printf 'Build ready: %s\n' "$repo_root/builds/solar-ascendant-linux-x86_64.zip"
