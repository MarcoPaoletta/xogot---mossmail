#!/bin/bash
# Exports the full screen Windows build of ONE version: tools/export_exe.sh <vN>
# Generalized from the Stormfield Fighters script (AutoSprite video 2, 2026-10-21), where the flow ran end to end.
# Copy to <project>/tools/, keep it executable. The game name is read from project.godot, the engine from $GODOT or .local-editor/.
# Each version is exported from its own tag (git archive into a scratch folder, never a checkout of the working tree, because
# Marco records from that tree), without the Godot AI helper autoload, and lands inside the project: build/<Game> <vN>.exe
# (gitignored, with a .gdignore so Godot does not import it). Boots the exe once and prints any error line.
set -e
cd "$(dirname "$0")/.."
TAG="${1:?usage: tools/export_exe.sh vN}"
GAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' project.godot | head -1)"
G="${GODOT:-$(ls "$(pwd)"/.local-editor/Godot_v*win64.exe 2>/dev/null | grep -v console | head -1)}"
[ -x "$G" ] || { echo "Godot binary not found: set GODOT or put the editor in .local-editor/"; exit 1; }
OUT="$(pwd)/build/$GAME $TAG.exe"
S="${TEMP:-/tmp}/export_exe_$TAG"
mkdir -p build && touch build/.gdignore
rm -rf "$S" && mkdir -p "$S"
git archive "refs/tags/$TAG" | tar -x -C "$S"
# Gitignored assets are NOT in the tag (big GLBs, textures, raw art): copy them from the working tree before importing,
# never overwriting the tag's files. Example: cp -rn assets/models "$S/assets/"
sed -i '/^_mcp_game_helper=/d' "$S/project.godot"
sed -i 's|enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")|enabled=PackedStringArray()|' "$S/project.godot"
grep -q '^window/size/mode=' "$S/project.godot" || sed -i 's|^\[display\]$|[display]\n\nwindow/size/mode=3|' "$S/project.godot"
timeout 1200 "$G" --headless --path "$S" --import >/dev/null 2>&1 || true
rm -f "$OUT"
timeout 1200 "$G" --headless --path "$S" --export-release "Windows Desktop" "$OUT" 2>&1 | grep -iE "error" | tail -5 || true
ls -la "$OUT"
timeout 120 "$OUT" --headless --quit-after 300 2>&1 | grep -iE "error|failed|Cannot get class" | head -5 || true
echo "boot check done"
