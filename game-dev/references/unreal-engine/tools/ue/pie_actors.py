"""PIE read only: list actors of the running game world. argv: [class name substring]. Prints one ACTOR line per actor and an ACTORS json line.
Use it first to learn the real class names (BP_Hero_C) the other pie.py commands take."""
import json
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
flt = sys.argv[1].lower() if len(sys.argv) > 1 else ""
out = []
for a in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.Actor):
    cls = a.get_class().get_name()
    if flt and flt not in cls.lower():
        continue
    l = a.get_actor_location()
    out.append({"class": cls, "name": a.get_name(), "loc": [round(l.x), round(l.y), round(l.z)]})
for r in out[:80]:
    print("ACTOR", r["class"], r["name"], r["loc"])
print("ACTORS " + json.dumps({"world": w.get_name(), "count": len(out)}))
