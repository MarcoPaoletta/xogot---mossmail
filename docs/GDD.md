# Mossmail: Game Design Document

**Pitch:** A cozy, endless forest-delivery game for iPad. You fly the forest post's hang glider over rolling, wooded hills: catch leaf-letters, deliver them by flying over mushroom homes, and ride updrafts from glowing shelf mushrooms up through sky rings. Giant mountain ranges always close the horizon.

**Engine / target:** Godot 4.7 (Xogot), Mobile renderer (iPad target), Jolt physics, landscape, stretch `canvas_items` + aspect `expand`.

## Controls
| Input | Action |
|---|---|
| Hold left half of screen | Steer left |
| Hold right half of screen | Steer right |
| Tilt the iPad (accelerometer) | Steer (toggle on the title screen, recalibrated at shift start and on resume) |
| A / D or arrow keys | Steer (keyboard testing) |
| Esc / P or the pause button | Pause |

The courier always runs forward; the player only steers. Speed ramps from 7 to 10 m/s over 14 deliveries.

## Core loop
1. A task appears (task card, timer bar, compass arrow and a world beacon).
2. Steer through the forest: trees and rocks stagger you, ponds slow you to a swim.
3. Complete it before the timer runs out → points × combo, celebration.
4. Miss it → lose a stamp (3 per shift). No stamps left → shift results → play again.

### Tasks (pattern: Deliver, Gather, Deliver, Sky mail, repeating)
- **Mail for (resident):** grab the leaf-letter ahead, then reach the beaconed mushroom home (38–105 m away). 150 + 6 per second left.
- **Scattered letters:** collect 5 letters along a curving trail. 25 each + 120.
- **Sky mail:** run onto a shelf mushroom → launch (19 m/s) → leaf glider opens → glide through the petal ring. 250.
- Combo: +25% per consecutive success, reset on a miss.

## World
Endless 3×3 ring of 48 m authored chunks (`ChunkStreamer`), picked per cell by a stable hash and rotated by 90° steps:
- `chunk_grove`: giant twisted trees + mushroom home
- `chunk_pines`: pine stand + bounce mushroom
- `chunk_pond`: swimmable pond + mushroom home
- `chunk_meadow`: open flowers + home + bounce mushroom

Cells that hold the active target are pinned so they never unload mid-task.

## Scene map (each element is its own saved scene)
- `scenes/main.tscn`: environment, sun, ground, floor, Forest (streamer with the initial 3×3 chunks), Courier, CameraRig, Fireflies, DriftingPetals, SteerInput, DeliveryDirector, FX and UI layers.
- Actors: `actors/courier.tscn`, `actors/camera_rig.tscn`.
- Gameplay: `gameplay/mushroom_home.tscn`, `letter_pickup.tscn`, `sky_ring.tscn`, `bounce_mushroom.tscn`.
- World: `world/chunk_*.tscn`, `world/water_pond.tscn`, 20 prop scenes in `props/`.
- UI: `ui/title_screen.tscn`, `hud.tscn`, `pause_screen.tscn`, `results_screen.tscn`, `float_text.tscn`, `screen_fx.tscn`.

## Look
Golden late-afternoon forest: ACES tonemap, selective glow (threshold 0.92), light green exponential fog, tinted sky ambient, +8% contrast, +10% saturation. Fireflies and drifting petals around the courier. A full-screen mood pass adds a vignette, light grain, glide speed lines and colour flashes.
The Mobile renderer has no SSAO or volumetric fog, so depth comes from fog, shadows and glow.

## Juice
Spawn pops (TRANS_BACK), letter bursts, home squash + confetti + window flare, pad squash + spores, glider pop-open + petal trail, camera shake on bumps, FOV punch on launch and delivery, flashes, score count-up, banner, floating "+points", stamp shake on loss, button hover and press scaling, faded screen transitions, 0.75 s animation blends (0.25 s for contact clips).

## Flight version (v2, 2026-10-22)
- **Player:** the downloaded hang glider (`scenes/actors/glider.tscn`, `Glider`). It always flies. Left and right steer, and the glider banks up to 38°. It holds 26 m above the highest ground under it or 14 m ahead, so it climbs early for hills. Cruise speed 13 m/s, rising to 19.
- **Updrafts:** shelf mushrooms send up a glowing spore column. Flying through it adds 22 m of height for 3.5 s, then it fades at 3 m/s. Sky rings hang about 18 m above cruise height, 40 m past the mushroom.
- **Delivery:** fly anywhere over the beaconed home (9 m radius, 90 m tall zone).
- **Obstacles:** giant twisted trees have 24 m (scaled) colliders; hitting one staggers and deflects the glider.
- **Terrain:** `TerrainField` and `forest_ground.gdshader` share one sine-stack height function, about −26 to +26 m. Homes, ponds and mushrooms register flat zones, which go to the shader as a uniform array (up to 32).
- **Hidden world edge:** a 5×5 chunk ring (grass and plants only in the inner 3×3), plus `mountain_ring.tscn`: three rows of scaled rock ridges at 178, 212 and 238 m that follow the glider. With fog at 0.0062, the horizon is always mountains.

## Version 3 (2026-10-22): collect, customise, control the altitude
Supersedes the v2 task and UI sections where they differ.

- **Goal:** collect flowers. There is no delivery anymore.
  - **Waves:** 5 flowers at first, plus 1 every 2 waves, up to 9. They sit 20 m apart along a curving path, at 6–55 m above the ground and inside the lever range.
  - **Timer:** (path length / speed × 1.8) + 8 s. Missing a wave costs a heart; there are 3 hearts.
  - **Ramp:** speed climbs over 10 waves.
- **Real contact:** a pickup counts only when its sphere touches the glider's wing box (6.2 × 1.4 × 2.4 m, area layer 16). Flying 6 m above a flower does not collect it.
- **Clear of trees:** flowers are moved sideways or above any canopy (per-prefix canopy radius and top × prop scale, plus a 2 m margin). Speed clovers lift themselves above canopies too.
- **Visibility:** each flower has a rim-glow overlay, a fog-free soft halo (5.5 m), a light and sparkles.
- **Speed boost:** golden four-leaf clovers (Quaternius Clover_1) hover 10–40 m over clearings in the pines and meadow chunks. Touching one gives 4 s of super speed (×1.75), with a golden trail, speed lines and a FOV kick. Updrafts and sky rings are removed.
- **Altitude:** a lever in the bottom-right corner sets the height above the ground (0 = 6 m, 1 = 55 m). Tilting the iPad's top edge toward you raises it, away lowers it (0.55 lever per second at full tilt). W/S or ↑/↓ also work. Left/right steering is unchanged.
- **Flow:** title (MOSSMAIL + Start) → glider selection (spinning glider on the left, 5 colour squares, Play on the right) → flight → results (flowers collected, best, Fly again, Menu). There is no pause menu.
- **Glider colours:** sky blue (default), ember red, moss green, sun gold and dusk violet, made by a hue swap on the sail texture. The choice is saved.
- **HUD:**
  - **Top left:** the wave card ("Collect N flowers", "N left", timer bar).
  - **Top right:** three vector hearts and a green flower counter with a live render of the flower model.
  - **Centre:** a compass showing distance and ▲▼ for the height difference.
  - **Framing:** in flight the glider is centred. On the menus the camera lens shifts so the glider sits on the right, clear of the menu cards.
- **Device:** landscape is locked (orientation 0).
- **Quality:**
  - **LOD off:** trees appear whole, with no gradual leaf pop-in.
  - **Rendering:** 3D scale 0.85, MSAA 2×, shadow atlas 4096, soft shadows medium, shadow distance 90 m, debanding.
