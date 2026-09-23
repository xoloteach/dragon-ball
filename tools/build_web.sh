#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
godot_binary="${GODOT_BIN:-$HOME/.local/bin/godot}"

cd "$repo_root"
mkdir -p builds/web
"$godot_binary" --headless --path . --editor --import --quit
"$godot_binary" --headless --path . --export-release Web builds/web/index.html
(
  cd builds/web
  python3 -c 'from pathlib import Path; Path("../solar-ascendant-web.zip").unlink(missing_ok=True)'
  zip -9 -q ../solar-ascendant-web.zip index.* -x '*.import'
)
printf 'Web build ready: %s\n' "$repo_root/builds/solar-ascendant-web.zip"
