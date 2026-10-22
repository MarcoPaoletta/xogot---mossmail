# Xogot `xo`: gotchas and recipes from a full game build

**Source.** The Container Yard build (Xogot for Mac video 2, Toon Shooter, 20 to 23 Sep 2026): Claude Opus 5.5 in the Claude desktop app, Xogot 1.7.2 / Godot 4.7.2 on macOS, Mobile renderer, empty project to a complete 3D third person shooter and a second version. 74 scenes built through `xo`, 30 scripts, 11 test suites, 211 `xo` calls, 49 with errors. Public repo `MarcoPaoletta/xogot---toon-shooter`. The full report (with Xogot feature requests) is `Collaborations\Videos\Xogot\3 - 3-Month Mac Agreement\2 - 3D Shooter from Scratch\Feedback\Xogot xo SKILL.md lessons.pdf`. Miguel de Icaza (Xogot developer) asked for it on 2026-09-27 and folded it into the next version of Xogot's own `xogot` skill, so recheck each item against the installed skill before relying on a workaround: some may be fixed.

Read this before any Xogot build driven through `xo`, together with Xogot's official skill that ships in the repo (`.claude/skills/xogot/`). Counts in brackets are how often it was hit.

## 1. Silent data loss (check these every time)

- **Scenes saved into a folder that does not exist.** `scene create`, `scene save` and `scene save-as` do not create folders. `scene create --path res://scenes/main.tscn` with no `scenes/` wrote `res://main.tscn`; `scene save` into a missing `props/` wrote nothing. Both replies showed the intended path. Create folders first, `xo file scan --wait`, and confirm with `xo file search --ext tscn` after the first save.
- **Editing a script resets the exported values of instances in open scenes, and the next save writes the defaults as overrides.** Fourteen weapons in `player.tscn` silently got the script's default damage; only a test caught it. After editing a script with exports, `scene reload --force` every open scene that instances it before saving, and read `git diff` of the scene after saving. Fix if it already happened: delete and recreate the instances.
- **Overrides on nodes inside an instanced glTF are lost unless the instance is editable.** `material assign` reports success but nothing is saved. Make it editable first (`root.set_editable_instance(model, true)` through `xo eval`; the file then shows `[editable path="Model"]`). An editable character instance also saves its skeleton pose as `bones/N/*` lines: harmless, noisy in diffs.
- **8 digit hex in `xo theme stylebox --bg`** renders nearly transparent (alpha read in another order). Set `bg_color` through `xo eval` with `Color("#rrggbbaa")`.

## 2. Instances and targeting

- `project run` starts a **second Xogot instance** (`launchKind: run`). From then on every command needs `--app <editor instance>`, including `game *` and `editor screenshot --source game`. [8]
- **Instance names change on restart** (`xogot-1` became `xogot-96`). Never hard-code: resolve on every call from `xo list` by `projectPath` and `launchKind != "run"` (a small wrapper did this).
- Nothing running: `xo launch --editor <project path>`, then poll `xo editor state` until it answers.

## 3. Arguments and batches

- **Negative numbers are parsed as flags.** [14] `--position -2,0,9` fails; use `--position=-2,0,9`, `--rotation=-32,125,0`. `node property set / ammo_max -1` has no working form: set it as the script default or in code. One bad negative sank a 309 step batch.
- **A batch cannot delete and recreate a node with the same name**: the validator ignores earlier deletes. Two batches, or move the node.
- **`batch --dry-run` has two output shapes**: an object (`ok`, `steps`) on success, a bare list of failing steps on failure. Parse both.
- **Script properties exist only after `script attach`**: attach in one call, set exported properties in the next.
- `resource inline` is for Resource typed properties only. Value types (AABB, Transform3D, Color) go through `node property set` with a Variant expression: `'AABB(-2, -1, -2, 4, 4, 4)'`.
- `scene list` returns bare names (`container_long_red`), not `res://` paths.

## 4. Scenes

- Open scenes cannot be renamed or deleted and there is no `scene close`: `scene save-as` then `scene delete` the old one; to rebuild, `scene activate` then `xo eval 'EditorInterface.close_scene()'`.
- `node fit-shape` cannot see inside an instanced glTF, even with `--source`: merge the meshes' AABBs with `xo eval`.
- A stray copy of an open scene can appear at `res://` root (seen twice with `main_menu.tscn`). Run `git status` at the end and look for files you did not create.

## 5. `xo eval` (editor)

- **It only answers `errParseError`, with no line or message** [43 failed evals, the biggest time sink]. The usual causes:
  - `:=` on a Variant: `var p := base + "/" + f` where `f` comes from an untyped Array. Write `var p: String = ...`.
  - `max`, `min`, `clamp` return Variant: use `maxf`, `clampf`, or an explicit type.
  - Methods on a variable typed only `Node`: `var space := player.get_world_3d().direct_space_state` needs `: PhysicsDirectSpaceState3D`.
  - `return 1` / `return x` (an int) in a bare body. `print()` the result instead of returning it.
- To get the line number: put the code in a temp file and run `xo script check`, or run it through `xo game eval`, which does report line and message.
- `output` interleaves empty strings and can pack several printed lines into one entry with `\n`: split every entry on newlines before matching `PASS` / `FAIL`. JSON escapes `/` as `\/`.
- Things that still need `xo eval` (no structured command): measuring glTF sizes, making an instance editable, baking a `NavigationRegion3D`, saving resources with nested sub resources (Environment + ProceduralSkyMaterial, ParticleProcessMaterial with curves, NoiseTexture2D, shader materials), the audio bus layout, a `BoneAttachment3D` under an instanced skeleton, typed array exports (`Array[PackedScene]`).

## 6. The running game

- **A runtime error pauses the game at a breakpoint**, including an error inside your own `game eval` script. Every later `game eval` fails until you read `xo debug errors` (and `debug stack`) and run `xo debug resume`. [6]
- `project run` returns before the game is ready: poll `game status` until live (2 to 3 s) before the first `game eval`.
- `game eval` accepts a **complete script** (`extends RefCounted`, `func _run():`, helpers, `await`, `--timeout` up to 500 s held). Inside it, `Engine.get_main_loop()` gives the tree and `tree.current_scene` is the robust entry point (`root.get_node("Arena")` fails behind a main scene slot).
- Every reply's `errors` carries harmless noise (`Unknown message: xogot:reply`, `xogot:hello`, `SHADOWED_VARIABLE`): filter before counting failures.
- Input: `game input key F1 --press/--release`, `game input action fire --press` and focus plus `Enter` on buttons all work. `game ui list` rects are in design canvas coordinates; clicking by mouse needs a conversion to window pixels, so prefer focus plus Enter.
- **Mouse look with `canvas_items` stretch:** `InputEventMouseMotion.relative` scales with window size (sensitivity changed on a 2816 px window). Read `screen_relative`; injected events must set both.

## 7. Testing gameplay

- **`xo test run` cannot test behaviour**: suites run in the editor as `@tool`, so the game's own `_ready`, `_physics_process` and input never run. It is fine for structure (scenes, named nodes, shapes, nav bounds, prefab values).
- **Pattern that worked (about 45 checks):** structural suites in `tests/editor/` via `xo test run --root res://tests/editor`. Behaviour suites in `tests/game/` with a `.gdignore` (otherwise `xo test run` discovers every `test_*.gd` and fails on them), as complete scripts printing `PASS name` / `FAIL name: reason`, each in a fresh `xo project run --scene ...` plus `xo game eval --file tests/game/<suite>.gd --timeout N`, looped by a shell runner.
- `Engine.time_scale` 2x to 5x simulates long stretches and physics stays stable. Add a negative control to differential tests (an enemy with speed 0 must fail the travel check).
- A test dummy must stay in the physics space: `process_mode = PROCESS_MODE_DISABLED` removes a CollisionObject3D (rays pass through, false "0 damage" failures). Use `set_physics_process(false)`.
- `xo script check` is excellent after writing scripts outside the editor (`file scan --wait` first), but register autoloads first or every autoload reference reads as undeclared.

## 8. Screenshots and visual evidence

- `editor screenshot --source game --max-resolution 0` returns the **window's native size** (2816 x 1638 on a Retina Mac), not the 1920 x 1080 canvas: rescale before comparing with a concept.
- `--source viewport` includes editor gizmos. For a clean top view, add a temporary orthographic Camera3D through `game eval` and shoot `--source game`.
- **Effects that live 0.05 s (muzzle flash, tracers) never land in a plain screenshot.** Pause handshake: the game sets `tree.paused = true` right after the effect and writes a "ready" file, a watcher runs `xo editor screenshot --source game` and writes "done", the game resumes. Reliable shots of every weapon firing and explosions at chosen frames.
- Duplicating a particle or flash material on every shot floods the Mobile renderer with `uniform_set is null`: cache one material per colour. `xo editor output --since <cursor>` around one action is how to trace an error flood to its cause.

## 9. What worked and should be the default

`xo batch` from JSON files for big scene assembly (a 520 step batch rebuilt the whole arena in seconds, with rollback); `node create --scene-type` for prefabs; `scene create` + `batch` + `script attach` as the scene pipeline; `game eval --file` with complete scripts; `game input`; `editor output --since`; `debug errors` / `debug stack`; `project autoload add` with a `.tscn`; `inputmap --ensure` for idempotent re-runs; `script check`; `launch --editor`.
