# Splatwalk lessons (Godot 4.7.2, third person paint shooter, MCP build, 2026-10-11)

Distilled from the autonomous Splatwalk build (Meshy 7 video 5). Each point cost real time and none of them was in a spec. Source of the numbers: `docs/BUILD_NOTES.md` and `docs/evidence/tests/` of that repo.

## 1. One continuous playthrough plus a log read finds what feature tests do not

Per feature tests were green for hours. The first continuous run on a fresh boot (title, Play, every weapon, pause, a real fall, wipe and retry, the door, the whole boss fight, victory, back to the title) followed by reading every non info line of the game log found two real defects in minutes. Do it at every milestone, not only at the end, and read the log, not just the pass counts.

* **Jolt refuses non uniform scale on spheres and capsules.** The boss's mouth hurtbox was a `SphereShape3D` under a wrapper root that the AnimationPlayer squashes with `scale (1.1, 0.86, 1.1)`. Every squash logged `Failed to correctly scale body`. Keep hurtboxes outside animated roots, or use a `BoxShape3D` (Jolt scales boxes freely).
* **An arena clamp circle must be proven against the deck.** The boss clamp (16.5 m around an arena center offset from the island center) poked 2.2 m past the 20 m deck, so the boss walked off the rim and fell into the clouds: the fight became impossible to finish and a scripted run only showed it as a stall. Test it by placing the actor at 8 points of the clamp circle and reading its y after 1.5 s.
* **A camera moved in `_process` needs `physics_interpolation_mode` OFF** when the project enables physics interpolation, or the log fills with `Interpolated Camera3D triggered from outside physics process` (title camera cuts).

## 2. Test the real input path, and prove a hit rate problem before blaming the game

* Probe a weak point before calling its hit rate unfair: freeze the target in the pose, aim at the center from 4 distances and 6 angles off its front, fire one real ball per row and print which collider ended it. The mouth took the ball from a 60 degree cone each side at 3.5 to 7.5 m; side on it clinked, as designed. The direction of the target's front is the line from its axis to the mouth, not the root basis (the visual yaws, the root does not).
* A fire bot that never moves stalls on the boss attacks that end facing away. Say so in the log header; do not read it as a game failure, and keep one clean accounted run (balls fired, hits, double hits, hits while closed) as the evidence.

## 3. Saturated translucent paint (the Spring gel)

Alpha blending a gel over a cream floor adds the floor: each 1 percent of see through added 7 to 19 units of blue at the saturated end and the amber read pale peach (20 percent off the sampled color). Fix: `hint_screen_texture`, multiply what is behind the gel by an amber tint, keep a clear window over the coil, mirror less sky (specular 0.12, clearcoat 0.15). Result: 5.8 percent off the sampled amber with the coil visible. Measure paint colors on the paint pixels only; the hero's coat sits in the same hue family and pulls a hue range sample.

## 4. Small things that cost an hour each

* HUD widgets saved as scenes and instanced in a Control tree save `layout_mode 0` plus `anchors_preset 0` overrides that reset the anchors at load. Set `layout_mode 1` on the instances.
* GDScript in eval snippets: a local named `done` shadows the task's member and hangs the poll; lambdas must be declared before use; a coroutine called without `await` needs a lambda wrapper; a typed local of the wrong class (a `CanvasLayer` typed as `Control`) puts the running game in a debugger break (read the reason with `editor_state`).
* Editor tabs of renamed scenes re-create the old files on every save all. Close them with a temporary `test_run` suite (`EditorInterface.open_scene_from_path` then `close_scene`), delete the files, delete the suite.
* Never run two test sweeps against one game instance: both talk to the same editor and each restarts the game under the other.
* Count tokens for the build notes from the session transcript: sum `message.usage` per assistant message id (input, output, cache read, cache write by TTL). The harness only shows the remaining budget.

## 5. Recording gameplay video of a scripted run with Movie Maker (no focus theft, no cursor trap, window off screen)

Worked end to end for a 1080p reel of four clips with sound while the user kept working.

* **Command.** `godot --path <copy> --write-movie out.avi --fixed-fps 60 --resolution 1920x1080 --script driver.gd -- <args>`. The frames render on the GPU and the audio of the Master bus is written into the AVI (MJPEG plus PCM). Re encode with ffmpeg (`libx264 -crf 17`, `aac`, `-pix_fmt yuv420p`, `loudnorm`). It renders at about 10 percent of real time at 1080p with this project.
* **`--no-window` does not hide the window in 4.7.2.** A real window titled `MovieWriter: Frame N` appeared over half of the user's screen (visible, not the foreground window). A small hidden PowerShell watcher that finds the process by that title and calls `SetWindowPos(h, 0, -32000, -32000, 0, 0, SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE)` every 300 ms moves it off screen; it keeps rendering at the same speed. Start the watcher before the first take.
* **`window_width_override` and `window_height_override` in project.godot win over `--resolution`.** The first movie came out 1280 by 720 until the overrides were set to 1920 by 1080 in the copy.
* **Never let the recording process set `Input.MOUSE_MODE_CAPTURED`.** The Windows display server clips the real cursor to the main window's rectangle even when it is hidden: the user's mouse would be trapped for the whole render. Record from a scratch copy of the project (robocopy without `docs`, `.git`, `skills`; mind that `/XD ui` also skips `scenes/ui` and `scripts/ui`) with the capture lines patched out (`MOUSE_MODE_CAPTURED` to `VISIBLE`, the can fire and mouse look guards removed) and a custom user dir (`config/use_custom_user_dir=true`) so the user's settings and best time are not touched. Delete the copy's `settings.cfg` before every take: a dry run that wins writes a best time that shows on the title.
* **The driver is a `SceneTree` script and must stay untyped.** Naming a game class (`Pip`, `CameraRig`) at the top of the driver compiles the game scripts before the autoloads exist (`Identifier not found: RunState`). Use `var pip` and dynamic calls, and `root.get_node("RunState")`. A typed array argument needs a typed variable (`Array[RID]`). `SceneTree` has no `get_node`, use `root.get_node`.
* **A fast deterministic dry run.** `--headless --fixed-fps 60` plays the same script 20 to 100 times faster than real time with the same physics steps, so search the take offline (parameters, offsets, the clip that fails) and record only a take that finished. Cut the reel into one clip per section (a process each), print `marker` lines with the frame time, then trim and fade each clip with ffmpeg and concat.
* **Bots that look good on camera need a different aim loop.** The helper that turns the camera until the reticle ray hits a point spins forever when the target is closer than the camera shoulder offset (a hero hanging on a wall). Aim pitch only there, or place the last part of a trail by script and say so.
