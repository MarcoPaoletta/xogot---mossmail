#!/bin/bash
# Exports the Android debug APK of the FINAL (latest) version only: tools/export_apk.sh <label, e.g. v2>
# Generalized from the Stormfield Fighters script (AutoSprite video 2, 2026-10-21), where the flow ran end to end.
# The headless export does not run the Godot AI addon's export plugin that strips its helper autoload, so the export runs
# from a scratch copy of the project without that autoload and without the addon enabled. Output: build/<Game> <label>.apk
# (gitignored, with a .gdignore). The previous APK in build/ is deleted first: there is ONE apk, never a stale one next to the new one.
set -e
cd "$(dirname "$0")/.."
LABEL="${1:?usage: tools/export_apk.sh vN}"
GAME="$(sed -n 's/^config\/name="\(.*\)"/\1/p' project.godot | head -1)"
G="${GODOT:-$(ls "$(pwd)"/.local-editor/Godot_v*win64.exe 2>/dev/null | grep -v console | head -1)}"
[ -x "$G" ] || { echo "Godot binary not found: set GODOT or put the editor in .local-editor/"; exit 1; }
OUT="$(pwd)/build/$GAME $LABEL.apk"
mkdir -p build && touch build/.gdignore
find build -maxdepth 1 -name '*.apk*' -delete
S="${TEMP:-/tmp}/export_apk"
W=$(cygpath -w "$S"); P=$(pwd -W)
mkdir -p "$S"
# Adjust the excluded folders to the project (raw art, docs, the local editor, the local skill copy, previous builds).
powershell -NoProfile -Command "robocopy '$P' '$W' /MIR /XD '$P\.git' '$P\art_src' '$P\docs' '$P\.local-editor' '$P\skills' '$P\build' '$P\exports' /NFL /NDL /NJH /NJS /NP | Out-Null; exit 0"
sed -i '/^_mcp_game_helper=/d' "$S/project.godot"
sed -i 's|enabled=PackedStringArray("res://addons/godot_ai/plugin.cfg")|enabled=PackedStringArray()|' "$S/project.godot"
timeout 1200 "$G" --headless --path "$S" --import >/dev/null 2>&1 || true
timeout 1200 "$G" --headless --path "$S" --export-debug "Android" "$OUT" 2>&1 | grep -iE "error" | tail -5 || true
ls -la "$OUT"
timeout 120 "$G" --path "$S" --quit-after 600 --resolution 1280x720 2>&1 | grep -iE "error|failed" | head -5 || true
echo "boot check done (the Android delivery gate of references/mobile-ui-touch/ section 9 still applies)"
