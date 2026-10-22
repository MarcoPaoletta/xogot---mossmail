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
