# Mossmail: build notes

## Verified (2026-10-22, Xogot 1.7.5 / Godot 4.7.2, iPad)
- All 21 scripts pass `script_check` with zero diagnostics.
- Loop test (`tests/game/loop_test.gd.txt`, run with game eval): 10/10 PASS. Title at boot, shift start, letter spawn and pickup, home targeting (62 m), delivery scored 300, 3 missed tasks end the shift, results shown, courier stopped.
- Flight test (`tests/game/flight_test.gd.txt`): 6/6 PASS. Sky mail task, pad launch, glider opens at ~7 m, ring collected (+250).
- Runtime screenshots checked: title over the live forest, HUD in play, steering, glide with petal trail, results card.

## Tuned values
- Environment `materials/forest_environment.tres`: ACES, exposure 1.05, glow 0.55 @ threshold 0.92, fog density 0.0045 (0.016 washed the scene out), aerial perspective 0.15, contrast 1.08, saturation 1.1.
- Sun: rotation (-40, 35, 0), energy 1.35, warm (1, 0.9, 0.74), PSSM-2, shadow distance 42 m.
- Performance (iPad): 3D scale 0.6, FXAA (MSAA off), shadow atlas 2048, soft shadow quality low, LOD threshold 4 px.
- Courier: run 7 → 10 m/s, glide 12.5 m/s, glide fall cap 2.3 m/s, turn 115°/s (85° gliding), launch 19 m/s.
- Camera: rigid follow, distance 6.8, height 3.0 (+1.4 gliding), FOV 62 → 76 gliding, ray collision against layer 1.

## Collision layers
1 world (trees, rocks, home stems, floor) · 2 courier · 3 water (value 4) · 4 triggers (value 8: delivery zones, letters, rings, pads).

## Workarounds used (tool limits)
- Resource-valued properties on standalone resources could not be set through the editor tools. Ground textures therefore use **project shader globals** (`shader_globals/forest_*`, type `sampler2D`).
- The theme's `default_font`, the two Fredoka `FontVariation` files and `corner_detail = 8` were written in the `.tres` text. The stylebox tool also wrote `draw_center = false`; those lines were removed so panels and buttons draw their backgrounds.
- The courier's colours are applied at runtime from the exported `body_material` and `joint_material` (the imported mannequin is not editable).
- `game-dev/.gdignore` keeps the skill out of the Godot project. Its example scripts were registering broken global classes.

## Known limits
- Measured FPS in the Xogot embedded runner was 1 to 4 FPS. The same happens with a 3.5k-triangle test scene, so the cause is the agent-controlled embedded session, not this game. Check real FPS on device with the game in the foreground.
- No audio: no CC0 sound pack was provided. See the final report.

## v2 flight build (2026-10-22)
- Tests: loop test 10/10 and flight test 6/6 PASS, zero runtime errors. Updraft climb 10.5 m in 1.5 s, sky ring 44 m above ground, terrain samples −18 to +21 m.
- Crash root cause: `hang_glider.glb` has no vertex normals (verified in game: 8648 verts, no normals). With the default import (LODs, shadow meshes, tangents, compression), rendering it froze or restarted the Xogot editor. Fixed by turning those import options off and drawing the model unshaded.
- Glider orientation was measured from the vertex spread: wingtips at +X, keel nose at −X. The model is rotated 90° and scaled 0.016 (6 m span).
- Embedded-runner metrics while flying: about 800k primitives, about 500 draw calls, 8 FPS in the agent session (a 3.5k-triangle scene also runs at 1–4 FPS there). Check real FPS on device. If needed, set `Forest.radius` to 1, or lower `rendering/scaling_3d/scale`.
- Avoid in Xogot: unsaved scenes with instanced models, and `editor mode set` while heavy scenes are open. Both crashed the editor in this session.

## v3 (2026-10-22)
- `tests/game/v3_test.gd.txt`: 16/16 PASS, zero runtime errors.
  - **Landscape and LOD:** landscape is locked and LOD is off.
  - **Flow:** title → selection → flight, and there is no pause screen.
  - **Colours:** recolouring works.
  - **Flowers:** they spawn at 10.8 to 38.1 m above ground and none are inside a canopy. Flying 6 m above one does not collect it; touching it does.
  - **Lever:** from 7.6 m (or 15 m in a hilly spot) up to 51–54 m.
  - **Boost:** speed goes from 13 to 22.7 m/s.
  - **Hearts:** three missed waves lead to results.
- **Fix:** the additive halo and glow shaders use `fog_disabled`. With fog, the halo quads showed as grey squares.
- **Fix:** the low sky "ground" band was visible between ridges; `fog_sky_affect` is now 0.6.
- **Unchecked on device:** the pitch tilt direction. Set `SteerInput.invert_pitch` if tilting toward you dives.
- **Completion pass:**
  - Mushroom homes are pure scenery now: their delivery zone, beacon, confetti and script are removed.
  - Hearts are 104 × 98 px.
  - The results caption node and all remaining internal "delivery" and "updraft" wording are renamed.
  - The flight camera is centred; only the menus keep the right-hand framing.
  - The v3 test still passes 16/16 with zero runtime errors. Flowers spawned at 14.4–40 m; the lever spans 14.6–55.9 m.
- **v3 polish:**
  - **Smoother climbs:** the height target now eases toward the lever (`altitude_follow` 2.2), and vertical speed is acceleration-limited (`vertical_accel` 10 m/s²). Nose pitch is capped at 12° with its own smoothing.
    - Measured on a lever snap from 0.2 to 1.0: vertical speed changes at most 0.17 m/s per frame (before, up to 9 m/s in one frame), and pitch changes at most 0.22° per frame.
  - **Lever 40% bigger:** 154 × 560 px, track 64 px, knob radius 53 px.
  - **Calmer pickups:**
    - Lights at energy 1.0–1.2 and range 4.5–5.5 m (was 3.5–4.5, 9–11 m).
    - Rim glow 0.9 (was 1.6–1.8), halo strength 0.5–0.55.
  - **Tests:** the v3 test is still 16/16 with zero runtime errors.
- **v3 polish, round 2 (user feedback):**
  - **Lever smoothing reverted.** It made climbing slower and did not fix the glitch. The original response is back: about 8.8 m climbed in the first second after a lever snap.
  - **Climb glitch fix:** the camera rig now has `physics_interpolation_mode = OFF`. The rig is placed every rendered frame from the glider's interpolated transform; letting physics interpolation also smooth it between physics ticks makes it stutter (Godot's guidance for cameras moved in `_process`). Visual confirmation is pending on device, because the embedded runner only reaches a few FPS.
  - **Collectibles:** no glow overlay on the model and no spin, only a 0.35 m bob. The soft halo behind them stays. The flower face is tilted to −30° so it reads from every direction without spinning.
  - **Tests:** the v3 test is still 16/16 with zero runtime errors.
- **v3 polish, round 3: forest and editor preview** (20:09:59 to 20:14:38)
  - **Re-laid out all four chunks with canopy-aware spacing:**
    - Canopy radius per model, measured from the glTF footprints.
    - Trees at least 0.9 × (rA + rB) apart, so only leaf tips may touch.
    - Every canopy stays fully inside its 48 m chunk, so neighbouring chunks never clip.
  - **Denser and prettier:**
    - Grove 20 trees (was 14), pines 23 (was 15), pond 14 (was 8), meadow 12 (was 5).
    - Trees are grouped into groves with glades between them; undergrowth sits around the trunks; flower and grass patches come in clumps of 3 to 6.
  - **Editor preview (skill Rule 1c):** `TerrainField` and `ChunkStreamer` are `@tool`.
    - In the editor, the starting chunks sit on the hills and show all their detail.
    - `NOTIFICATION_EDITOR_PRE_SAVE` resets props to their authored height; `POST_SAVE` re-seats them.
    - Verified: 0 chunk-child overrides in main.tscn after saving.
  - **Load:** about 1.5M primitives per frame in flight (was about 0.8M), because of the extra trees and LOD being off. Check FPS on device. If needed, lower `Forest.radius` to 1 or remove some trees from the outer ring.
  - **Tests:** the v3 test is still 16/16 with zero runtime errors.
