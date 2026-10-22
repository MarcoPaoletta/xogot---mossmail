"""Mirror the game-dev skill to its own private GitHub repo (MarcoPaoletta/game-dev-skill).

Usage:  py -3 sync_mirror.py

Marco's Hub (Letta/Skills/game-dev) is the source of truth. The mirror is a plain copy of this folder so a Mac
(or any other machine) gets ONLY this skill with `git clone` / `git pull`, without the rest of the Hub.
Runs by itself from the Hub's post-commit hook whenever a commit touches this folder. Safe to run by hand.
"""
import os
import shutil
import subprocess
import sys

REPO = "MarcoPaoletta/game-dev-skill"
MIRROR = r"D:\_Programming\_skill-mirrors\game-dev-skill"
SKIP = {"__pycache__", "_INSTALL.md", "sync_mirror.py", "desktop.ini", ".git"}


def run(*args, cwd=None):
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True)


def main() -> int:
    src = os.path.dirname(os.path.abspath(__file__))
    if not os.path.isdir(os.path.join(MIRROR, ".git")):
        os.makedirs(os.path.dirname(MIRROR), exist_ok=True)
        r = run("gh", "repo", "clone", REPO, MIRROR)
        if r.returncode:
            print(r.stderr)
            return 1
    run("git", "pull", "--rebase", "--autostash", cwd=MIRROR)
    for name in os.listdir(MIRROR):
        if name == ".git":
            continue
        path = os.path.join(MIRROR, name)
        shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
    for name in os.listdir(src):
        if name in SKIP:
            continue
        s, d = os.path.join(src, name), os.path.join(MIRROR, name)
        if os.path.isdir(s):
            shutil.copytree(s, d, ignore=lambda _d, names: [n for n in names if n in SKIP])
        else:
            shutil.copy2(s, d)
    commit = run("git", "rev-parse", "--short", "HEAD", cwd=src).stdout.strip() or "unknown"
    run("git", "add", "-A", cwd=MIRROR)
    if not run("git", "status", "--porcelain", cwd=MIRROR).stdout.strip():
        print("mirror already up to date")
        return 0
    run("git", "commit", "-m", f"Sync from Marco's Hub {commit}", cwd=MIRROR)
    r = run("git", "push", "origin", "HEAD", cwd=MIRROR)
    print(r.stdout + r.stderr)
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
