# Stylized 2D water with a boat wake: one surface, not two layers

**When it applies:** any top down 2D game with painted water and something that leaves a wake (a boat, a swimmer, a sea creature). Distilled from Reedway Ferry (Makko art, Godot 4.7.2, 2026-09-24), where the water went through five of Marco's feedback rounds before it read as the concept's sea.

Scripts in `scripts/` are the Reedway originals, kept as reference (constants tuned for that game):

| File | What it is |
| :-- | :-- |
| `water.gdshader` | The world space water: animated cell network, swell warp, and the foam built from the mask with the water's own cells. |
| `foam_mask.gdshader` | Paints the foam mask: density in RGB, coverage in alpha, age from UV.x. |
| `foam_trail.gd` | The wake as a triangle strip through the `RenderingServer`, each point carrying its exact age. `clear_trail()` for teleports. |
| `sea.gd` | Wiring: duplicates the shared water material, binds the foam viewport, keeps the mask viewport in sync with the main camera. |

---

## 1. ⛔ Water and foam are ONE surface (Marco)

A foam sprite or a `Line2D` drawn on top of the water reads as a sticker, whatever its shader. What passed:

- **A world space water shader.** A `ColorRect` inside a `CanvasLayer` with `follow_viewport_enabled`, so the pattern stays put in the world under any camera move, zoom or rotation. It draws an animated cell network from a seamless cellular `NoiseTexture2D` (two copies drifting in different directions), warped by a seamless swell texture, so the lines wobble and the cells breathe.
- **The boat paints a foam MASK, not foam.** The mask is a half resolution `SubViewport` whose `canvas_transform` mirrors the main camera's canvas transform (times 0.5) every frame, so it sees the world exactly like the screen does.
- **The water shader reads the mask by `SCREEN_UV` and makes the foam with its own cells:** dense foam covers the cells, thinning foam keeps only the cell centres, the churned water underneath goes paler, and the cell network is **pushed outward along the mask gradient**, so the sea visibly parts around the wake.

## 2. ⛔ How the foam must look (Marco)

- **Foam fades from white to fully transparent as it ages.** Never a flat 100% white sheet.
- **No bow wave "arrow" arms**, only the stern trail. (`foam_trail.gd` still has `spread_ratio` for arms; it stays at 0.)

## 3. Draw the trail as a triangle strip with the age in UV.x

`RenderingServer.canvas_item_add_triangle_array`, oldest point first, with UV.x = the exact age of each point (0 at the stern, 1 when it dies) and UV.y across the ribbon. A `Line2D` stretches its UVs over the whole length, so the foam jumps every time the trail grows or shrinks.

## 4. ⚠️ Mask blending: two failures before the right one

1. **Additive mixing** doubled the ribbon into bright streaks where it folds over itself in a turn.
2. **`blend_disabled`** fixed that, but let the transparent edges of newer segments punch holes in older foam (Marco saw gaps behind the boat).
3. **Correct:** density in RGB, coverage in alpha, **normal mixing**, and the water reads `.r`. The newer part replaces the older density instead of adding to it, and its transparent edges leave the older foam alone.

## 5. Small rules that each cost a round

- **Clear the trail on every teleport** (respawn, debug jumps, scene travel), or the next frame draws foam across the whole map.
- **A shared water material must be `duplicate()`d by any scene that binds a scene owned texture** (the foam viewport). Otherwise the other scenes that use the same material (the town) sample a freed texture.
- The same material serves every scene with water; the scenes without a wake simply bind no mask.

## 6. Verify

- Frame contact sheets during a sharp turn and a stop (the streaks and the holes of §4 only show in motion).
- A teleport with the debug panel: no foam line across the map.
- Switch scenes back and forth: the water of the other scene still renders (no freed texture).
