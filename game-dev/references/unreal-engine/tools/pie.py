#!/usr/bin/env python3
"""Playtest an Unreal game WITHOUT touching the user's PC: Play In Editor inside the editor's own viewport, driven by MCP
and editor Python. No new window, no focus change, no mouse, no keyboard, no system keys. Hold the editor lock first.

  python tools/pie.py start                       StartPIE in the viewport (PlayMode_InViewPort)
  python tools/pie.py stop
  python tools/pie.py shot NAME [W H]             clean game frame, no widgets  -> docs/evidence/ue-shots/NAME.png
  python tools/pie.py shotui NAME                 frame WITH the UMG HUD (the editor window with the viewport in it; crop it)
  python tools/pie.py dilate F                    global time dilation (0.2 = slow motion for one shot effects, 1.0 restores)
  python tools/pie.py console "cmd" ["cmd" ...]   console commands in the PIE world
  python tools/pie.py actors [CLASS_SUBSTR]       list actors: class, name, location (PIE world)
  python tools/pie.py props CLASS_NAME PROP ...   read properties of the first actor of a class (e.g. BP_Hero_C Health State)
  python tools/pie.py call CLASS_NAME FUNC [ARG ...]   call a Blueprint function on every actor of that class (the same entry
                                                  point the HUD button or key calls: the "input" of a headless playtest)
  python tools/pie.py tp CLASS_NAME X Y [Z] [YAW] teleport the first actor of a class (starts an encounter, reaches a spot)
  python tools/pie.py py SCRIPT [ARG ...]         run any tools/ue/*.py script inside the PIE world

Real game frames come from HighResShot / Shot ShowUI. The MCP CaptureViewport tool renders the EDITOR world, not PIE.
Never leave Play running or time dilation below 1.0 when you finish.
"""
import os
import shutil
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ue_common as C  # noqa: E402

ENV = dict(os.environ, MSYS_NO_PATHCONV="1")


def py(script, *args, quiet=False):
    r = subprocess.run([sys.executable, "-I", os.path.join(HERE, "ue_py.py"), "file", os.path.join(HERE, "ue", script), *map(str, args)],
                       capture_output=True, text=True, env=ENV)
    if not quiet:
        print(r.stdout.strip()[-3000:])
        if r.returncode != 0:
            print(r.stderr.strip()[-800:])
    return r


def mcp(tool, args=None):
    from mcp_client import Mcp
    return Mcp().call("EditorToolset.EditorAppToolset", tool, args or {})


def _grab(prefix, name, wait=6.0):
    """Wait for the screenshot the console command queued, then copy it into docs/evidence."""
    target = os.path.join(C.NATIVE_SHOTS, f"{prefix}{name}.png")
    t0 = time.time()
    while time.time() - t0 < wait * 4:
        if os.path.exists(target) and time.time() - os.path.getmtime(target) < 30:
            time.sleep(0.6)
            break
        time.sleep(0.4)
    else:
        raise RuntimeError("screenshot did not appear: " + target)
    os.makedirs(C.SHOT_DIR, exist_ok=True)
    out = os.path.join(C.SHOT_DIR, name + ".png")
    shutil.copyfile(target, out)
    print("frame", os.path.relpath(out, C.ROOT))
    return out


def shot(name, w=1920, h=1080):
    old = os.path.join(C.NATIVE_SHOTS, f"{C.SHOT_PREFIX}{name}.png")
    if os.path.exists(old):
        os.remove(old)
    py("pie_hires.py", name, w, h, quiet=True)
    return _grab(C.SHOT_PREFIX, name)


def shotui(name):
    old = os.path.join(C.NATIVE_SHOTS, f"{C.SHOT_PREFIX}UI_{name}.png")
    if os.path.exists(old):
        os.remove(old)
    py("pie_shot_ui.py", name, quiet=True)
    return _grab(C.SHOT_PREFIX + "UI_", name)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    c = a[0]
    if c == "start":
        mcp("StartPIE", {"options": {"bSimulate": False, "playMode": "PlayMode_InViewPort"}})
        print("pie started")
    elif c == "stop":
        mcp("StopPIE")
        print("pie stopped")
    elif c == "shot":
        shot(a[1], *(int(v) for v in a[2:4]))
    elif c == "shotui":
        shotui(a[1])
    elif c == "dilate":
        py("pie_dilate.py", a[1])
    elif c == "console":
        py("pie_console.py", *a[1:])
    elif c == "actors":
        py("pie_actors.py", *a[1:])
    elif c == "props":
        py("pie_props.py", *a[1:])
    elif c == "call":
        py("pie_call.py", *a[1:])
    elif c == "tp":
        py("pie_tp.py", *a[1:])
    elif c == "py":
        py(*a[1:])
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
