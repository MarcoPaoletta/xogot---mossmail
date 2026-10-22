"""Copy game-dev locally into a game project (Godot, Unity, Unreal or any engine) without publishing it in the game's Git repository.

Usage:  py -3 install_to_project.py "<path to the project root>" [--engine godot|unity|unreal|other]   (Mac: python3 ...)

The engine is detected from the project (project.godot, ProjectSettings/ProjectVersion.txt, *.uproject). Pass --engine other to install into a
project of any other engine. The skill text is written mostly for Godot: SKILL.md starts with an "Engine applicability" section that says
which parts hold for every engine.

The Hub copy (Marco's Hub/Letta/Skills/game-dev) is the source of truth. It is mirrored to the private repo
MarcoPaoletta/game-dev-skill (clone on the Mac at ~/Skills/game-dev), and this script works from either copy. The project gets a plain
ignored snapshot in <project>/skills/game-dev/ plus a local skills/README.md with the Hub commit it came from.
Re-running the script refreshes the snapshot. Plain markdown, no agent specific format: Claude, Codex and
any other agent read it the same way. Existing tracked copies require a separate history cleanup; this
installer refuses to overwrite them. It never migrates or rewrites a game's history.
"""
import datetime
import os
import shutil
import subprocess
import sys

SKIP_NAMES = {"__pycache__", "_INSTALL.md", "install_to_project.py", "sync_mirror.py", "desktop.ini", ".git", ".gitattributes"}
LOCAL_IGNORE = ("/skills/game-dev/", "/skills/godot-game-dev/", "/skills/README.md")

README = """# Skills

Plain markdown skills copied from Marco's Hub (`Letta/Skills/`). Every agent working on this project reads them
before touching the game: start with `game-dev/SKILL.md`, then the `references/` it points to for the task
at hand (UI with generated art: `game-dev/references/ui-art-pack/ui-art-pack.md`; 2D animation from sprite
sheets: `game-dev/references/sprite-animation-import/`).

This folder is a **snapshot**. The source of truth is Marco's Hub. A lesson learned while building this game goes
back into `Marco's Hub/Letta/Skills/game-dev/` (so the next game gets it), and this copy is refreshed with
`py -3 "<Marco's Hub>/Letta/Skills/game-dev/install_to_project.py" "<this project>"`. Do not edit files here
by hand.

This is private authoring material, kept locally and excluded from Git. Never commit or distribute this
folder or paste the full skill into public/shared project docs. The game runs without this folder.
Canonical versions live only in the private Hub and private game-dev-skill mirror.

| Skill | Copied from Hub commit | Date |
| :-- | :-- | :-- |
| game-dev | {commit} | {date} |
{engine_note}"""


def prepare_local_copy(project: str) -> bool:
    """Refuse tracked snapshots; append narrow ignore rules without ignoring other project skills."""
    tracked = subprocess.run(
        ["git", "-C", project, "ls-files", "--", "skills/game-dev", "skills/godot-game-dev", "skills/README.md"],
        capture_output=True, text=True,
    )
    if tracked.returncode == 0 and tracked.stdout.strip():
        print("game-dev or its provenance README is already tracked. Preserve the local copy and clean "
              "the exposed Git history separately before reinstalling. No project files changed.")
        return False
    if tracked.returncode != 0 and os.path.exists(os.path.join(project, ".git")):
        print("cannot inspect the project's Git index; no project files changed")
        return False
    ignore = os.path.join(project, ".gitignore")
    existing = b""
    if os.path.exists(ignore):
        with open(ignore, "rb") as f:
            existing = f.read()
    lines = existing.decode("utf-8-sig").splitlines()
    missing = [pattern for pattern in LOCAL_IGNORE if pattern not in lines]
    if missing:
        prefix = b"\n" if existing and not existing.endswith(b"\n") else b""
        addition = "# Private game-dev authoring skill, local only (Marco, 2026-10-07)\n" + "\n".join(missing) + "\n"
        with open(ignore, "ab") as f:
            f.write(prefix + addition.encode("utf-8"))
    return True


ENGINE_NOTES = {
    "godot": "",
    "unity": """
Engine of this project: **Unity**. `game-dev` is written mostly for Godot. Read its section "Engine applicability" first: the default bar, the polish
principles, the concept match protocol, the repo and version rules and the build rules hold for Unity. The Godot specific rules (MCP first, saved `.tscn`
scenes, GDScript, `project.godot` settings) do not; use the Unity equivalent (Aura or the project's Unity MCP, prefabs and scenes, C#).
""",
    "unreal": """
Engine of this project: **Unreal**. `game-dev` is written mostly for Godot. Read its section "Engine applicability" first: the default bar, the polish
principles, the concept match protocol, the repo and version rules and the build rules hold for Unreal. The Godot specific rules do not: read
`references/unreal-engine/unreal-engine.md` (the rules translated, the measured traps and the headless playtest that never takes the user's focus, mouse or
keyboard) and use its `tools/` from the project root. Setup of the MCP: `references/engines-and-mcp-setup/`.
""",
    "other": """
Engine of this project: **not Godot**. `game-dev` is written mostly for Godot. Read its section "Engine applicability" first and apply only the parts
marked as engine independent.
""",
}


def detect_engine(project: str, forced: str | None) -> str | None:
    if forced:
        return forced
    if os.path.isfile(os.path.join(project, "project.godot")):
        return "godot"
    if os.path.isfile(os.path.join(project, "ProjectSettings", "ProjectVersion.txt")) and os.path.isdir(os.path.join(project, "Assets")):
        return "unity"
    if any(n.endswith(".uproject") for n in os.listdir(project)):
        return "unreal"
    return None


def main() -> int:
    args = sys.argv[1:]
    forced = None
    if "--engine" in args:
        i = args.index("--engine")
        if i + 1 >= len(args) or args[i + 1] not in ENGINE_NOTES:
            print(__doc__)
            return 2
        forced = args[i + 1]
        del args[i:i + 2]
    if len(args) != 1:
        print(__doc__)
        return 2
    project = os.path.abspath(args[0])
    if not os.path.isdir(project):
        print(f"not a folder: {project}")
        return 1
    engine = detect_engine(project, forced)
    if engine is None:
        print(f"cannot tell the engine of {project} (no project.godot, Unity ProjectSettings/ProjectVersion.txt or .uproject). "
              "Pass --engine godot|unity|unreal|other.")
        return 1
    src = os.path.dirname(os.path.abspath(__file__))
    dst = os.path.join(project, "skills", "game-dev")
    old = os.path.join(project, "skills", "godot-game-dev")
    # Resolve recursive-delete targets before replacing a snapshot. A junction must not escape the game.
    project_root = os.path.realpath(project)
    for target in (dst, old):
        resolved = os.path.realpath(target)
        try:
            within_project = os.path.commonpath((project_root, resolved)) == project_root
        except ValueError:  # A junction may resolve onto a different Windows drive.
            within_project = False
        if not within_project or resolved == project_root:
            print(f"unsafe skill destination outside the project: {target}")
            return 1
    if not prepare_local_copy(project):
        return 1
    if os.path.isdir(dst):
        shutil.rmtree(dst)
    # The skill was called godot-game-dev until 2026-10-05.
    if os.path.isdir(old):
        shutil.rmtree(old)
    shutil.copytree(src, dst, ignore=lambda d, names: [n for n in names if n in SKIP_NAMES])
    try:
        commit = subprocess.run(["git", "-C", src, "rev-parse", "--short", "HEAD"], capture_output=True,
                                text=True, check=True).stdout.strip()
    except Exception:
        commit = "unknown"
    with open(os.path.join(project, "skills", "README.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(README.format(commit=commit, date=datetime.date.today().isoformat(), engine_note=ENGINE_NOTES[engine]))
    # The skill folder must be VISIBLE in Godot's FileSystem dock (Marco, 2026-09-24), so no .gdignore at
    # skills/. Only the folders holding reference code get one: their .gd files carry class_name and would
    # register as global classes (and clash with the game's own, e.g. paint_slime.gd) or fail to parse.
    # Unity and Unreal never see skills/ (it sits outside Assets/ and Content/), so only Godot needs the .gdignore dance.
    if engine == "godot":
        stale = os.path.join(project, "skills", ".gdignore")
        if os.path.exists(stale):
            os.remove(stale)
        code_ext = (".gd", ".tscn", ".scn", ".gdshader", ".tres", ".res")
        for root, _, files in os.walk(dst):
            if any(f.endswith(code_ext) for f in files):
                open(os.path.join(root, ".gdignore"), "w").close()
    count = sum(len(files) for _, _, files in os.walk(dst))
    print(f"installed local-only game-dev ({count} files, Hub commit {commit}, engine {engine}) -> {dst}; excluded from Git")
    return 0


if __name__ == "__main__":
    sys.exit(main())
