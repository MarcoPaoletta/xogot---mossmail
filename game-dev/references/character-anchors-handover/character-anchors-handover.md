# Character anchors and seamless sprite hand-overs (2D)

**When it applies:** any 2D game where characters stand on painted places (docks, stalls, platforms, islands), sit in a vehicle, or move between two representations of themselves (standing on the ground, seated on a boat). Distilled from Reedway Ferry (Makko art, Godot 4.7.2, feedback rounds 2 to 7, 2026-09-24): passengers wait on the dock of each island, hop onto the ferry's benches and hop off at their destination.

Companion of `sprite-animation-import/` (per clip scale, offset and facing, §4 there). That doc makes a character keep its feet on one ground line across its own clips. This one makes it land on the right spot of the WORLD, and swap sprites without a visible jump.

Scripts in `scripts/` are the Reedway originals, kept as reference (their paths and constants are that project's):

| File | What it is |
| :-- | :-- |
| `measure_dock_anchors.py` | Finds the approved dock in every island painting by template matching and writes the red cross contact sheet. |
| `apply_dock_anchors.gd` | Headless `SceneTree` script that writes the measured `stand_point` into each `IslandData.tres`. |
| `apply_seat_anchors.gd` | Same for the seat points of each boat, measured on its benches. |
| `dock.gd` | The dock: waiting animal, speech bubble by the tail tip, the hop on and off with the cross faded seated copy, confetti. |

---

## 1. Anchors: at the feet, and one per place

- ⛔ **Characters are anchored at their feet, and every place they stand has its own anchor** (Marco, 2026-09-24: *"no puede ser el mismo anchor point para todos los puertos... a los animalitos les pones el anchor en los pies y en todas las islitas seteas un anchor point, un Marker2D literalmente"*). One shared "where the animal stands on a dock" offset worked on one island and left the others floating, because every painting draws its dock a little differently. The anchor lives with the place: a `Marker2D` in the scene, or its data equivalent (Reedway: `stand_point` in each `IslandData` resource, in art pixels from the art's centre, times `visual_scale`).
- ⛔ **Seated characters are anchored at their bottom centre, the point they sit on**, and each vehicle has its own seat points measured on its own art (the benches). Centre anchored seated sprites landed a passenger on the life ring.
- **Speech bubbles are positioned by the tail tip, not by the image centre.** When the bubble is scaled (Marco asked for 1.75x), scale the tail offset by the same factor, so the tip stays on the speaker's mouth. Mouth offsets are per character.
- ⛔ **UI attached to a world object never covers the object.** The building price tag went from centred on the building, to under it, to **on its top edge** (Marco's final choice), at half size and with no "Hold to build" text.

## 2. Measure anchors on the art, never by eye per place

Approving seven docks by eye, one at a time, is slow and drifts. The method that passed:

1. **Approve ONE by eye** (Reedway: the forest dock).
2. **Crop a template around it** that carries the distinctive shape (the lantern post plus the deck), on the alpha composited greyscale of the art.
3. **Find the same feature in every other painting** with OpenCV `matchTemplate` (`TM_CCOEFF_NORMED`). Scores of 0.39 to 0.85 were all correct matches; do not reject a match on the score alone, reject it on the contact sheet.
4. **Check with a red cross contact sheet before applying:** a cross drawn at each computed point, one crop per place, all in one image. Only then write the values (headless script into the data resources).

## 3. Verify every variant together

⛔ **A contact sheet of every place times every character** (Reedway: 7 docks x 3 animals = 21 cells) is the check, not one screenshot of one dock. It caught both the floating animals and a hidden art bug: a pocket of green chroma inside every dock lantern that stayed invisible until an animal stood in front of it (fixed in Skill 22, subskill 2).

## 4. Seamless hand-over between two representations

⛔ **When a character moves between two representations (standing on a dock, seated on a boat), it flies to the exact target, rotates and scales into the target pose, and only then the sprites swap: "1:1 with the seated sprite"** (Marco, round 5). The recipe that passed frame by frame:

- **Animate along an arc to the target point, re-aimed every frame** (the boat keeps moving). `tween_method` over `t`, the target read inside the callback, never captured at the start.
- **Lerp the rotation to the target's rotation and the height to the target's on-screen height** (compare heights in screen pixels, not scale fields: the two sprites have different canvases).
- **Cross fade with a copy of the target sprite** over the second half: same texture, same bottom anchor, same height, same rotation. At the end the copy and the real seated sprite are pixel identical, so the swap is invisible. Reverse for getting off.
- **One copy per direction** (`FlyingSeatedOn`, `FlyingSeatedOff`): a delivery and a boarding often happen at the same time on the same dock.
- **Draw the flying character above the vehicle** (`z_index = 1` during the hop), or it disappears behind the hull for a few frames.
- **Celebrate the landing** (Marco): a small confetti burst where the passenger lands, both on the seat and on the dock, with the same gradient as the game's other celebrations.

### The pitfall: one frame giant sprites

⛔ With `physics/common/physics_interpolation = true`, a sprite that is rescaled, teleported or shown again is drawn for ONE frame interpolated from its old transform (old scale 1.0 on a sprite that lives at 0.3 = a giant flash). Call `reset_physics_interpolation()` **after** making it visible and setting the new transform, never before. Reading properties never shows this bug; only a frame capture does (see the frame contact sheet in SKILL.md, MCP gotchas).

## 5. Checklist

- [ ] Every character's origin is its feet (standing) or its bottom centre (seated).
- [ ] Every place has its own anchor, measured on its art (template match plus red cross sheet), never one shared offset.
- [ ] Every vehicle has its own seat points, measured on its benches.
- [ ] Contact sheet of every place times every character, looked at before delivery.
- [ ] Bubbles by tail tip, tail offset scaled with the bubble.
- [ ] World attached UI sits beside or above its object, never over it.
- [ ] Hand-over: arc re-aimed per frame, rotation and on-screen height lerped, cross fade with a pixel identical copy, one copy per direction, `z_index` above the vehicle, confetti on landing.
- [ ] `reset_physics_interpolation()` after every show, teleport or rescale, verified on a frame capture.
