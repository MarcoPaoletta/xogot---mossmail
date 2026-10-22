"""Shared helpers for the Unreal tools of game-dev (project root, engine path, MCP endpoint).

The tools live in the skill snapshot (<project>/skills/game-dev/references/unreal-engine/tools/) but act on the
game project, so the project root is found by walking up from the current folder (or from UE_PROJECT_ROOT) until
a *.uproject appears. Nothing here touches the operating system's input: no focus, no mouse, no keyboard.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def find_project_root():
    env = os.environ.get("UE_PROJECT_ROOT")
    starts = [env] if env else [os.getcwd(), HERE]
    for start in starts:
        d = os.path.abspath(start)
        while True:
            if glob.glob(os.path.join(d, "*.uproject")):
                return d
            parent = os.path.dirname(d)
            if parent == d:
                break
            d = parent
    raise SystemExit("No .uproject found above the current folder. cd into the game project or set UE_PROJECT_ROOT.")


ROOT = find_project_root()
UPROJECT = glob.glob(os.path.join(ROOT, "*.uproject"))[0]
PROJECT_NAME = os.path.splitext(os.path.basename(UPROJECT))[0]
SAVED_DIR = os.path.join(ROOT, "Saved", "GD")  # locks and scratch files, ignored by the UE .gitignore (Saved/)
SHOT_DIR = os.path.join(ROOT, "docs", "evidence", "ue-shots")
NATIVE_SHOTS = os.path.join(ROOT, "Saved", "Screenshots", "WindowsEditor")
SHOT_PREFIX = "GD_"


def engine_root():
    """UE_ENGINE_ROOT wins; then the install the .uproject names (EngineAssociation); then the Epic launcher default."""
    env = os.environ.get("UE_ENGINE_ROOT")
    if env:
        return env
    try:
        with open(UPROJECT, "r", encoding="utf-8-sig") as f:
            assoc = json.load(f).get("EngineAssociation", "")
    except Exception:
        assoc = ""
    candidates = []
    if assoc:
        for base in ("D:/Epic Games/Epic Games", "C:/Program Files/Epic Games", "D:/Epic Games", "C:/Epic Games"):
            candidates.append(f"{base}/UE_{assoc}")
    candidates += glob.glob("D:/Epic Games/Epic Games/UE_*") + glob.glob("C:/Program Files/Epic Games/UE_*")
    for c in candidates:
        if os.path.isdir(os.path.join(c, "Engine")):
            return c
    raise SystemExit("Unreal install not found. Set UE_ENGINE_ROOT to the folder that holds Engine/.")


def engine_python_dir():
    return os.path.join(engine_root(), "Engine", "Plugins", "Experimental", "PythonScriptPlugin", "Content", "Python")


def mcp_endpoint():
    """UE_MCP_URL, then the project's .mcp.json (written by ModelContextProtocol.GenerateClientConfig), then the 5.8 default."""
    env = os.environ.get("UE_MCP_URL")
    if env:
        return env
    p = os.path.join(ROOT, ".mcp.json")
    if os.path.isfile(p):
        try:
            with open(p, "r", encoding="utf-8-sig") as f:
                servers = json.load(f).get("mcpServers", {})
            for v in servers.values():
                url = v.get("url", "")
                if re.match(r"https?://(127\.0\.0\.1|localhost)", url):
                    return url
        except Exception:
            pass
    return "http://127.0.0.1:8000/mcp"


def ensure_dirs():
    os.makedirs(SAVED_DIR, exist_ok=True)


if __name__ == "__main__":
    print(json.dumps({"root": ROOT, "project": PROJECT_NAME, "engine": engine_root(), "mcp": mcp_endpoint()}, indent=1))
