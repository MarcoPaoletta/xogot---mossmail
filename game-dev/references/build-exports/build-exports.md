# Build exports: where they live, how many, and how a version is defined (Marco, 2026-10-21, AutoSprite video 2, Stormfield Fighters)

Two corrections of Marco's in one session, both measured on a real build. They replace the older habits "builds always in Downloads" and "every step of the GDD plan is a version".

## 1. Where builds go: inside the Godot project, in `build/`

- `<project>/build/` holds every export. It is gitignored and carries an empty `.gdignore`, so Godot never imports a 280 MB exe. Nothing goes to `C:\Users\Usuario\Downloads\` anymore (Marco: the builds go in the Godot project folder).
- Names: `<Game> vN.exe` and `<Game> vN.apk`.
- A build older than the last change of its version is a bug, same as before. The replaced file is deleted, never left stale next to the new one.

## 2. How many: one EXE per version, ONE APK for the final version

- **EXE:** one full screen Windows exe per version (`build/<Game> v1.exe`, `v2.exe`, ...), each exported from its own annotated tag with `git archive` into a scratch folder, so Marco can open and record any version without switching branches. Never `git checkout` in his working tree.
- **APK:** a single APK, only of the latest version. Older versions get no APK. The previous APK is deleted when the new one is built.
- Only the formats he asked for. An APK request does not add an EXE and vice versa. No export at all unless he asks (SKILL.md, "Builds").
- Scripts: `export_exe.sh` and `export_apk.sh` in this folder, copied to `<project>/tools/`. They are the Stormfield Fighters scripts generalized by name (game name from `project.godot`, engine from `$GODOT` or `.local-editor/`). The exe flow ran end to end there; the generalized copies have not been re-run on another project, so read them once before the first use.
- Traps measured earlier with the per version exe (Tripo Steam and Snow, 2026-10-16): gitignored assets are missing from the tag (copy them in with `cp -rn`), runtime scripts that call `EditorInterface` fail in an export (guard them in the scratch copy only), and the Godot AI helper autoload `_mcp_game_helper` must be removed from the scratch `project.godot`. Verify each exe with `--headless --quit-after 300` and read the console for `Cannot get class ''` and `Failed loading resource`.

## 3. What a VERSION is: the runs Marco shows, not the steps of the GDD plan

A GDD build order is often numbered V1 to V13 (Stormfield Fighters had thirteen). Tagging each of those as `v1` to `v13` produced 13 tags, 13 branches and a pile of exes nobody asked for. Marco, 2026-10-21: *"they should just be 2"*.

- **Version** = a run he shows or delivers as one piece of the video (for Stormfield: `v1` before the proposal website, `v2` everything after it). Each version is an annotated tag AND a branch `vN`, pushed with full refspecs (`refs/heads/vN`, `refs/tags/vN`). The branch can move forward while that run grows.
- **Step** = one phase of the GDD's own plan. It gets a commit and, to stay citable, a tag `steps/VN` (for example `steps/V4`). Never a `vN` tag, never a branch, never an exe.
- **Before the first tag, decide which is which.** Read the project's `AGENTS.md`: it wins over this file. If the GDD numbers its phases `V1..Vn` and nothing says how many versions the video has, ask Marco once ("how many versions are we showing, and where does each start?") instead of tagging every phase. When writing a new GDD, call the phases Step or Phase N and keep `vN` for versions, so the two never collide.
- The per version exe rule follows the versions, not the steps: with two versions there are two exes and one APK.

## 4. Order of operations when he asks for builds

1. Confirm the version tags exist and point where they should (`git tag -l`, `git branch`).
2. `tools/export_exe.sh v1`, `tools/export_exe.sh v2` (skip the versions he already recorded straight from Godot).
3. `tools/export_apk.sh v2` for the final version, then the Android delivery gate (install, launch, PID, crash buffer, screencap).
4. Do not export while he is recording: it competes for CPU and disk.
5. Write in the project's `AGENTS.md` which builds are live (`Live builds: exe v1, exe v2, apk v2`, folder `build/`) so the next agent keeps them fresh.
