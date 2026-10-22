"""PIE: teleport the first actor of a class. argv: class_name x y [z] [yaw]. Omit z to keep the current height."""
import sys

import unreal

w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
cls, x, y = sys.argv[1], float(sys.argv[2]), float(sys.argv[3])
for a in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.Actor):
    if a.get_class().get_name() == cls:
        z = float(sys.argv[4]) if len(sys.argv) > 4 else a.get_actor_location().z
        a.set_actor_location(unreal.Vector(x, y, z), False, True)
        if len(sys.argv) > 5:
            a.set_actor_rotation(unreal.Rotator(0, float(sys.argv[5]), 0), True)
        print(a.get_name(), "at", a.get_actor_location())
        break
else:
    print("no actor of class", cls)
