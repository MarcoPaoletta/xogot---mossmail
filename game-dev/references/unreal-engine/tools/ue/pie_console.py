"""PIE: run console commands in the game world. argv: command [command ...]  (quote each command)."""
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
for c in sys.argv[1:]:
    unreal.SystemLibrary.execute_console_command(w, c)
    print("ran", c)
