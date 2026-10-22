"""PIE: queue a high resolution screenshot of the game viewport (no widgets). argv: name [width height].
Output lands in <project>/Saved/Screenshots/WindowsEditor/GD_<name>.png (tools/pie.py shot copies it to docs/evidence/ue-shots/)."""
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
name = sys.argv[1]
res = f"{sys.argv[2]}x{sys.argv[3]}" if len(sys.argv) > 3 else "1920x1080"
unreal.SystemLibrary.execute_console_command(w, f"HighResShot {res} filename=GD_{name}")
print("queued", name, res)
