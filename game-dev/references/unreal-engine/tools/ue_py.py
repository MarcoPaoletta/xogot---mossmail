#!/usr/bin/env python3
"""Run Python inside the OPEN Unreal editor through Python Remote Execution (no window, no focus, no input).

Why: the Unreal MCP toolsets expose no Python or console executor, and some operations (new or save level, console
variables and commands, reading the PIE world, anim notifies, retarget setup) have no structured MCP tool.

Needs, in the project's Config/DefaultEngine.ini (installed by `python tools/setup_project.py`):

  [/Script/PythonScriptPlugin.PythonScriptPluginSettings]
  bRemoteExecution=True
  RemoteExecutionMulticastBindAddress=127.0.0.1
  RemoteExecutionMulticastTtl=0

and the Python Editor Script Plugin enabled. It only attaches to an editor whose project root is THIS project.

  python tools/ue_py.py file tools/ue/some_script.py [arg ...]
  python tools/ue_py.py stmt "import unreal; print(unreal.SystemLibrary.get_project_directory())"
  python tools/ue_py.py nodes

Only for scripts that use the `unreal` module directly (tools/ue/*.py). NEVER for a script that talks to the MCP server
(mcp_client.py and anything built on it): it would run on the game thread and the HTTP request it sends to the same
editor can only be served by that blocked thread, so the editor shows "Not Responding" until the client timeout.
Run MCP client scripts from the shell. Use `python -I` for these editor tools; the playtest tools that need Pillow run
without -I.
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue_common as C  # noqa: E402

sys.path.insert(0, C.engine_python_dir())
import remote_execution as rx  # noqa: E402

PRE_LOCK = os.path.join(C.SAVED_DIR, "pre.lock")


class _PreMutex:
    """Python Remote Execution serves one command connection at a time; serialize callers."""

    def __enter__(self):
        C.ensure_dirs()
        t0 = time.time()
        while True:
            try:
                fd = os.open(PRE_LOCK, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
                os.write(fd, str(os.getpid()).encode())
                os.close(fd)
                return self
            except FileExistsError:
                try:
                    if time.time() - os.path.getmtime(PRE_LOCK) > 600:  # stale: a run never takes 10 minutes
                        os.remove(PRE_LOCK)
                        continue
                except OSError:
                    pass
                if time.time() - t0 > 900:
                    raise SystemExit("PRE mutex busy for 15 minutes")
                time.sleep(0.25)

    def __exit__(self, *exc):
        try:
            os.remove(PRE_LOCK)
        except OSError:
            pass


def find_node(re_, wait=20.0):
    deadline = time.time() + wait
    seen = []
    needle = C.PROJECT_NAME.lower()
    while time.time() < deadline:
        seen = re_.remote_nodes
        for n in seen:
            if needle in json.dumps(n).lower():
                return n, seen
        time.sleep(0.5)
    return None, seen


def run(mode, command, wait=20.0, attempts=6):
    """Node discovery and the command socket handshake fail intermittently on a busy editor; retry before giving up."""
    last = None
    with _PreMutex():
        for _ in range(attempts):
            try:
                return _run(mode, command, wait)
            except (SystemExit, RuntimeError) as e:
                msg = str(e)
                if "No " + C.PROJECT_NAME + " editor node" in msg or "command socket connection" in msg:
                    last = e
                    time.sleep(2.0)
                    continue
                raise
    raise last


def _run(mode, command, wait=20.0):
    cfg = rx.RemoteExecutionConfig()
    cfg.multicast_bind_address = "127.0.0.1"
    cfg.multicast_ttl = 0
    re_ = rx.RemoteExecution(cfg)
    re_.start()
    try:
        node, seen = find_node(re_, wait)
        if mode == "nodes":
            return {"nodes": seen}
        if node is None:
            raise SystemExit(f"No {C.PROJECT_NAME} editor node found. Nodes seen: " + json.dumps(seen)[:800])
        re_.open_command_connection(node["node_id"])
        em = {"file": rx.MODE_EXEC_FILE, "stmt": rx.MODE_EXEC_STATEMENT, "eval": rx.MODE_EVAL_STATEMENT}[mode]
        return re_.run_command(command, unattended=True, exec_mode=em)
    finally:
        re_.stop()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    mode = sys.argv[1]
    if mode == "nodes":
        print(json.dumps(run("nodes", ""), indent=1)[:3000])
        return
    if mode == "file":
        path = os.path.abspath(sys.argv[2]).replace("\\", "/")
        cmd = '"' + path + '"' + "".join(" " + ('"' + a.replace("\\", "/") + '"' if (" " in a or "\\" in a) else a) for a in sys.argv[3:])
        res = run("file", cmd)
    elif mode in ("stmt", "eval"):
        res = run(mode, sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)
    for line in res.get("output", []):
        print(f"[{line.get('type')}] {line.get('output', '').rstrip()}")
    if res.get("result") not in (None, "None", ""):
        print("RESULT:", res.get("result"))
    if not res.get("success"):
        print("FAILED:", res.get("result"), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
