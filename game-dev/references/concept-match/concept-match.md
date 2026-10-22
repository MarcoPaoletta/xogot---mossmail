# Concept match: the concept image is the acceptance test

**When it applies:** any build that starts from a concept image (a gameplay frame, a scene concept, a key frame the client saw). Every Letta collab video since Emberpine Cabin (Atlas AI Studio, 2026-09-11) and Tide Runner (Pixelfork, 2026-09-13) ships with one, so this applies by default.

**Why it exists (Marco, 2026-09-13):** *"clave comparar con fotos, tipo decirle el concept vs el gameplay, porque el concept está hermoso y quiero algo muy parecido a eso en tema de ángulos de cámara, lighting y world environment."* The concept is what the client approved and what the thumbnail will show. A build that "looks nice" but sits at a different camera height, with a greyer sky and a harder sun, reads as a different game, and the side by side in the video punishes it. Asking an agent to "match the concept" without a measured loop produces a vibe match. The loop below produces a pixel match.

## The protocol (paste the spec version from Skill 5 `patterns/concept-match.md` into the GDD; this doc is the how)

1. **Name the camera.** Create `ConceptCam` (a `Camera3D`, perspective, never orthographic) or, in a game whose gameplay camera already is the concept frame (a runner, a side scroller), a `Marker3D` named `ConceptPose` holding the transform the gameplay camera adopts at the start. Keep it in the saved scene. Bind a dev only action (`snap_concept_view`, Tab) that snaps the camera there. Remove the action from the final build.
2. **Author the concept region by hand.** The part of the world the concept shows is placed, not spawned: same props, same silhouette, same relative positions. In an endless game this is the first chunk. In a scene it is the whole scene.
3. **Shoot after every visual milestone** at 1920 x 1080 from the concept pose. Milestones: greybox baseline, props, background layers, water or terrain, `WorldEnvironment` and lights, UI, juice. Compose the side by side with `compose_comparison.py` (below) and save as `docs/evidence/comparison-NN.png`, numbered, never overwritten. The last one is `comparison-final.png`.
4. **Check in a fixed order, biggest mismatch first:** camera height and horizon line, camera distance and FOV (measure the subject's width as a percent of the frame), subject position in the frame, silhouettes of the main masses, secondary props, background landmarks, sky gradient, water or ground colour, sun direction and shadow softness, fog and depth haze, glow, colour grade, UI size and placement. One fix per round, re shoot, repeat. Expect five to ten rounds.
5. **Match light by value, not by feel.** Read the concept's sky top and horizon colours, the ground and water colours, the shadow softness and direction, and write target values into the GDD before building (hex colours, sun elevation and azimuth, fog start, tonemap, saturation, contrast). Write the final values in `docs/BUILD_NOTES.md`.
6. **The final comparison is item 1 of the definition of done.** A build without `comparison-final.png` is not done.

## How to shoot through the MCP

- **Editor viewport:** `editor_screenshot` (godot-ai) or `screenshot_scene` (Fennara) after selecting the concept camera as the preview camera. Good for the first rounds (props, silhouettes) because the editor viewport ignores gameplay state.
- **Running game:** `project_run` (godot-ai) or the Fennara equivalent, press the snap action, and capture with the runtime screenshot of the MCP, or have the game write `docs/evidence/_raw_NN.png` itself from a dev only script (`get_viewport().get_texture().get_image().save_png()`), which the project `.gitignore` excludes. Required for the rounds where lighting, glow, fog, animated water and UI are judged, because those only exist at runtime.
- **Always at the design resolution** (1920 x 1080). A comparison at a different aspect ratio lies about framing.
- **Do not judge from the MCP's downscaled thumbnail.** Open the composed PNG at full size before deciding the round.

## Compose the side by side

`compose_comparison.py` in this folder. Usage from the project root:

```
python "<skill>/references/concept-match/compose_comparison.py" docs/concept/concept.png docs/evidence/_raw_03.png docs/evidence/comparison-03.png
```

Concept left, screenshot right, both scaled to the same height, a 12 pixel white gutter, and the file name of each half burned into the bottom left corner. Needs Pillow (`pip install pillow`). The script refuses to overwrite an existing output so the history of rounds survives.

## What the rounds look like when it works

Emberpine Cabin (Atlas AI Studio): the first comparison had the cabin 30 percent too small and the horizon 15 percent too high; three rounds fixed the camera, four rounds fixed the light (the concept's pink horizon band came from fog colour, not from the sky), and by round eight the side by side read as the same place. Without the loop, the agent had declared round one "matching the concept".

## Related

- Skill 5, `1 - Build GDD/patterns/concept-match.md`: the drop in GDD section (the what).
- `Letta/Skills/Skill 5 - Proposal Writer/style-guide.md` §2.7: concept art perspective must match the real gameplay camera, so the loop above has a fair target.
- `launch-settings/`: the design canvas the comparison is shot at.
