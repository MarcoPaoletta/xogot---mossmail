"""PIE: screenshot of the editor window with the game viewport in it, INCLUDING the UMG widgets (HighResShot leaves them out).
argv: name. Output: Saved/Screenshots/WindowsEditor/GD_UI_<name>.png. Crop the viewport out of it (it sits inside the editor chrome)."""
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
name = sys.argv[1]
cmd = f"shot showui filename=GD_UI_{name}"
unreal.SystemLibrary.execute_console_command(w, cmd)
print("queued", cmd)
