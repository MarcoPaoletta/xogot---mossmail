"""PIE read only: read editor properties of the first actor of a class. argv: class_name prop [prop ...]. Prints PROPS {...}.
A property that is not exposed to Python reads as '?'."""
import json
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
cls = sys.argv[1]
out = {}
for a in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.Actor):
    if a.get_class().get_name() == cls:
        out["actor"] = a.get_name()
        for k in sys.argv[2:]:
            try:
                v = a.get_editor_property(k)
                out[k] = round(v, 3) if isinstance(v, float) else (v if isinstance(v, (int, bool, str, type(None))) else str(v))
            except Exception:
                out[k] = "?"
        break
else:
    out["error"] = "no actor of class " + cls
print("PROPS " + json.dumps(out))
