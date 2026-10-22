#!/usr/bin/env python3
"""Mutual exclusion for GLOBAL editor state shared by parallel agents.

The open editor has exactly one current level, one viewport and one PIE session. Anything that changes or depends
on those must hold this lock: loading or switching a level, spawning actors in the open level, starting or stopping
PIE, moving the viewport camera, capturing viewport screenshots. Asset level work (imports, property edits on assets,
Blueprint, UMG, Niagara and material authoring, StudioTwin jobs) does NOT need the lock.

  python tools/editor_lock.py acquire NAME [--wait 600] [--ttl 900]
  python tools/editor_lock.py release NAME
  python tools/editor_lock.py status

The lock expires (ttl, default 900 s): acquire with --ttl 7200 for a long session, or another agent may take it
and open a different level under you.
"""
import argparse
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue_common as C  # noqa: E402

LOCK = os.path.join(C.SAVED_DIR, "editor.lock")


def read():
    try:
        with open(LOCK, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=["acquire", "release", "status"])
    p.add_argument("name", nargs="?", default="")
    p.add_argument("--wait", type=float, default=600.0)
    p.add_argument("--ttl", type=float, default=900.0)
    a = p.parse_args()
    C.ensure_dirs()

    if a.cmd == "status":
        cur = read()
        if not cur:
            print("FREE")
        else:
            age = time.time() - cur["t"]
            print(f"HELD by {cur['name']} for {age:.0f}s (ttl {cur['ttl']:.0f}s){' [EXPIRED]' if age > cur['ttl'] else ''}")
        return

    if a.cmd == "release":
        cur = read()
        if cur and cur["name"] == a.name:
            os.remove(LOCK)
            print("released")
        elif cur:
            print(f"not released: held by {cur['name']}", file=sys.stderr)
            sys.exit(1)
        else:
            print("already free")
        return

    t0 = time.time()
    while True:
        cur = read()
        if cur and cur["name"] == a.name:  # re-entrant: refresh
            cur["t"] = time.time()
            with open(LOCK, "w", encoding="utf-8") as f:
                json.dump(cur, f)
            print("acquired (refreshed)")
            return
        if cur and time.time() - cur["t"] > cur["ttl"]:
            try:
                os.remove(LOCK)
            except OSError:
                pass
            cur = None
        if not cur:
            try:
                fd = os.open(LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(fd, json.dumps({"name": a.name, "t": time.time(), "ttl": a.ttl}).encode())
                os.close(fd)
                print("acquired")
                return
            except FileExistsError:
                pass
        if time.time() - t0 > a.wait:
            print(f"TIMEOUT waiting for editor lock (held by {read()})", file=sys.stderr)
            sys.exit(2)
        time.sleep(1.0)


if __name__ == "__main__":
    main()
