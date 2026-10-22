"""PIE: set the global time dilation (slow motion so the one second screenshot latency catches a hit, a muzzle flash, a burst). argv: factor.
Always set it back to 1.0 when the proof is done."""
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
x = float(sys.argv[1]) if len(sys.argv) > 1 else 1.0
unreal.GameplayStatics.set_global_time_dilation(w, x)
print("time dilation", x)
