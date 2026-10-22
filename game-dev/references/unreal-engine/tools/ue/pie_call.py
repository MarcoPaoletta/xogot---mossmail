"""PIE: call a Blueprint function on every actor of a class. argv: class_name function [arg ...] (ints, floats and true/false are parsed).
This is the headless "input": call the SAME function the HUD button, the key binding or the interaction calls (PlayerChoose, Interact, StartWave...)
instead of sending a key. Only a test of the real key or click path itself needs real input, and then only with the user's OK."""
import sys

import unreal


def parse(s):
    if s.lower() in ("true", "false"):
        return s.lower() == "true"
    for t in (int, float):
        try:
            return t(s)
        except ValueError:
            pass
    return s


w = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
cls, fn = sys.argv[1], sys.argv[2]
args = tuple(parse(s) for s in sys.argv[3:])
n = 0
for a in unreal.GameplayStatics.get_all_actors_of_class(w, unreal.Actor):
    if a.get_class().get_name() == cls:
        r = a.call_method(fn, args=args)
        print("called", a.get_name(), fn, args, "->", r)
        n += 1
if not n:
    print("no actor of class", cls)
