# Paint splash: the satisfying 3D paint module (Splatwalk, Godot 4.7.2, 2026-10-12)

Marco's verdict (2026-10-17): this is what makes any 3D paint game "feel GOD". Use it in EVERY game where the player throws, sprays or splats paint (Splatoon style shooters, painters, graffiti, ink, slime, goo). It was measured in Splatwalk (Meshy video 5) and tuned over four rounds of Marco's feedback. Do not improvise a splash from a sphere and a texture: the feel comes from stacking six layers that all fire on the frame of impact.

What Marco singles out as beautiful: **the paint puddle (the splat decal) and all the juice around it** (burst, pop, drips, sound, blink and fizz). Both are fully in this folder. Reference implementation (copy, then adapt names): `scripts/` (`paint_ball`, `paint_blob`, `paint_fx`, `paint_manager`, `paint_style`), `shaders/` (`paint_common.gdshaderinc`, `paint_blob`, `paint_gel`), `scenes/` (`paint_puddle`, `paint_blob`, `paint_ball`, `paint_manager`, `paint_burst`, `confetti_burst`), `materials/` and `resources/` (the paint styles and materials), `assets/` (six splat shapes plus the matte ORM texture), `reference-stills/` (the target look). In a build, rule 1c still applies: saved scenes, authored with the editor tools, never built node by node in code.

## 0. The part Marco loves: the splat itself

The thing that looks beautiful is the **splat decal**: a flat, glossy, saturated splash with arms and flung droplets, lying on whatever surface it lands on (see `reference-stills/grip_splat_floor.jpg`, `grip_splat_wall.jpg`, `grip_splat_pip_near.jpg`: those are the target look, compare against them). It is made of exactly these parts, all in this folder:

1. **The six splat shapes** (`assets/splat_0.png` to `splat_5.png`): white shape in the alpha, one picked per splash by seed, so no two look the same.
2. **The Decal** (`scenes/paint_puddle.tscn`, node `Splat`, `normal_fade` 0.2) tinted with `modulate` = paint color, `emission_energy` 1.2 using the same texture as emission, and the matte `assets/splat_orm.png`. That recipe is why the color stays vivid and identical on a lit floor, a shaded wall and a column.
3. **The pop in**: size 0.25 to 1.05 (back ease out) to 1.0 in 0.22 s (`_start_splat` and `activate` in `scripts/paint_blob.gd`).
4. **Characters ignore it** (`exempt_from_splats`, visual layer `1 << 19`, decal `cull_mask` 524287).
5. **Life**: the last 1.5 s it desaturates toward clay and blinks, then fades in 0.4 s with a fizz burst.
6. **The impact burst and sound** on the same frame (`scripts/paint_fx.gd`, `scenes/paint_burst.tscn`).

Where the glue lives: `scripts/paint_manager.gd` (`_place_on_surface`, `_spawn_puddle`, `_surface_basis`, `splash` signal) turns an impact (point plus normal) into a spawned splat; `_surface_basis` gives it a random spin around the normal, and it is lifted 0.004 m off the surface. That manager also carries Splatwalk game rules (docking, bridges, ink); for a new game keep only the impact to spawn path and the pools.

Drop in layout: every file sits in the same relative place as in Splatwalk, so copy `scripts/*` to `res://scripts/paint/`, `shaders/*` to `res://shaders/`, `materials/*` to `res://assets/materials/`, `resources/*` to `res://resources/`, `assets/*` to `res://assets/paint/`, and `scenes/paint_*.tscn` to `res://scenes/paint/`, `paint_burst`, `confetti_burst` to `res://scenes/fx/`, `fx_shrink_curve.tres` to `res://resources/`. The `.tscn` files have their baked MultiMesh buffers stripped (the drips are laid out at runtime by `_layout_drips`), and their `uid://` references re-resolve by path.

## 1. The six layers (all on the impact frame)

| # | Layer | What it is | Numbers that were measured |
| :-- | :-- | :-- | :-- |
| 1 | **The ball** | A glossy sphere in the paint color with a small particle trail. Fast and swept, never a hit scan. | 40 m/s, 7 m max path, sphere radius 0.13, trail 22 particles, lifetime 0.28 s, shrink curve. The ray is swept from the old to the new position every physics frame so it never tunnels. |
| 2 | **Burst** | A pooled `GPUParticles3D` of paint droplets, in the paint color, oriented with the surface normal. | 16 droplets, lifetime 0.55 s, `one_shot`, explosiveness 0.95, spread 62 degrees, velocity 2 to 5, gravity -15, scale 0.6 to 1.3 with a curve 1.0, 0.8, 0.0 (droplets shrink to nothing instead of popping out). Spawned 0.06 m off the surface along the normal. A wasted ball is the same burst at `amount_ratio` 0.3 so it never reads as a hit. |
| 3 | **Pop in** | The paint object scales from 0 to an overshoot and settles. Back ease out, then sine. | `pop_time` 0.22 s: the first 60 percent goes to 1.05 (back ease out), the last 40 percent settles to 1.0. The back ease adds about 10 percent, so the **measured peak is 1.15**. Never linear, never instant. |
| 4 | **The splat** | A solid wet blob (floor, bridges) or a **Decal** (walls, props, decorative puddles) with one of six splash shapes. | Sections 2 and 3. |
| 5 | **Drips and spatter** | Teardrops hanging from the rim, always along WORLD down, ray checked so they stop at the floor. A blob lying on a surface gets beads of spatter around it instead. | 7 drips, 5 spatter beads, one `MultiMesh`, one draw call per blob. |
| 6 | **Sound** | A wet slap with random pitch (about plus or minus 8 percent) and 3 variants, a thinner quieter one for a wasted ball, a fizz on dissolve. | `ball_splat` 3 wavs, `wasted_splat` -4 dB, puddle -6 dB, `blob_fizz` -4 dB. |

Bonus layers that sell it: a camera nudge on a launch (2.2 degrees up over 0.45 s), a ring of droplets for a bounce pad, hit stop and a 0.07 s white flash on a tagged enemy, an enemy pop = two bursts plus confetti (26 pieces, 1.1 s) plus a puddle.

## 2. The shader: paint is a wet slab, not a sphere (`shaders/`)

One mesh family, one shader, one material per paint color. The vertex stage reshapes a unit sphere into a thick pancake (superellipse profile, flat top, steep rounded side, flared rim, irregular outline), or into a teardrop for a drip, told apart by `INSTANCE_CUSTOM` (zero for the slab, the drip size for the MultiMesh).

* Look: clearcoat 1.0 on the plateau, roughness 0.1, a slight self illumination (`self_light` 0.22) so paint **never reads dark**, a rim tint, and a base that is 18 percent deeper at the side so the slab reads thick and wet.
* Per blob values are **instance uniforms** (`desaturate`, `drip_retract`, `bleach`, `flash`, `seed`, `splat`), so every blob of one paint shares ONE material and still blinks, bleaches and varies its outline by `seed`.
* The outline function exists twice, once in the shader and once in `paint_blob.gd` (`_outline`). They must stay in step or the drips float off the rim. Change both.
* Drips and spatter use the same material and the same instance uniforms (`_set_param` writes all of them), so a warning blink or a bleach hits the whole object together.

## 3. Decals for walls and decorative paint (`paint_blob.gd`, `_start_splat`)

A flat mesh slab on a wall or a floor looks like a sticker and clips on any uneven surface. Walls and puddles are a `Decal` that wraps whatever is under it (column, corner, crate edge, rubble).

* Six generated splat shapes: white shape in the alpha, so `modulate` tints them. Pick by seed: `int(seed * 1000) % 6`. They are in `assets/` (reuse as they are, or regenerate with the image tool in the same flat Splatoon style).
* Size: `radius * 2.8` wide (the shape fills about 90 percent), puddles 0.75 of that, depth 0.9 m so it reaches over a step. `normal_fade` 0.2.
* **Pop in the decal the same way**: size from 0.25 to 1.05 (back ease, 60 percent of `pop_time`) then to 1.0.
* **Same color on every structure (the lesson that cost a round):** a decal is lit like the surface under it, so a splat in shade came out grey blue next to the solid blob. Fix: `emission_energy` 1.2 with `texture_emission` set to the same splat texture, plus a matte ORM texture (`assets/splat_orm.png`: full roughness, no metal) so the wall adds no sheen. Overlapping splats stay opaque.
* **Characters must not be tinted.** Put every mesh of the player and the enemies on their own visual layer (`PaintBlob.exempt_from_splats(root)` sets layers to `1 << 19`) and set the decal `cull_mask` to everything except that layer (`524287`).
* Life cycle: in the last 1.5 s the splat desaturates toward clay and blinks; dissolve = alpha to 0 in 0.4 s; bleach = lerp to white then alpha 0 in 0.8 s. Pooled: 96 live blobs max, 12 decorative puddles with oldest first recycling.

## 4. The ball lands where the reticle is

The muzzle is off to one side of the camera, so a crate corner next to the hand stopped the ball and the splash came out as a sliver on a side face (3.2 to 4.0 m off the reticle). Fix (`aim_point`, `aim_slack`): when the reticle ray found a surface within range, the ball **flies through level surfaces farther than 0.9 m from that point** (enemies and hurtboxes still stop it) and lands on the reticle point. Measured 0.01 m off afterwards. Without this the splash never feels like "I put it there".

Also: a ball only stacks on top of an existing blob when it comes down steeper than 30 degrees, so holding fire along a bridge never builds pillars.

## 5. Squash and stretch on contact

For a bounce pad: scale to (1.18, 0.45, 1.18) in 0.06 s, then (0.88, 1.35, 0.88) in 0.1 s (sine), then rest with an elastic ease out in 0.22 s. For an enemy tag: white flash 0.07 s and hit stop. Everything is eased, nothing snaps.

## 6. Traps

* **Decals do not exist in the Compatibility renderer** (Forward+ and Mobile only). Check `rendering/renderer/rendering_method` first. For Compatibility (some Xogot and mobile exports), draw the splat as a flat `MeshInstance3D` quad with the same texture, alpha blend, unshaded, lifted 0.004 m off the surface along the normal, and accept that it does not wrap corners. The burst, the blob shader and the drips work everywhere.
* Pool everything (balls 6+, bursts 18, confetti 6, rings 3, blobs 96, puddles 12). Instancing a scene per shot stutters. When a pool runs out, recycle the oldest, never fail to splash.
* Lift the decal or puddle 0.004 m along the normal and read the `z-fighting` reference for coplanar surfaces.
* `flash` is added on top of the base emission, so a flash can never go below the resting glow.
* `GPUParticles3D.restart()` on a reused pooled burst needs `emitting = false` first, or the old burst keeps playing.
* Jolt refuses non uniform scale on spheres and capsules: keep hurtboxes out of squashed roots (see `splatwalk-lessons`).
* Stills prove shape and color, only play proves feel. Ask Marco to play. Count particles, read the pop peak (1.15), and measure paint color on the paint pixels only.

## 7. Porting checklist (new game)

1. Copy `shaders/`, `assets/`, `scenes/` into the project (`res://shaders`, `res://assets/paint`, `res://scenes/fx`) and fix the `res://` paths in the scripts.
2. Make one `PaintStyle` resource per color (color, highlight, lifetime, radius, thickness, `blob_material`, `ball_material`). Splatwalk's `paint_style.gd` is 27 lines: a `Resource` with those exports.
3. Build the saved scenes with the editor tools: ball (Mesh, Trail), blob (Mesh, Drips MultiMesh with `use_custom_data` and 14 instances, Splat Decal, Fizz), burst, confetti. Splatwalk's `paint_blob.tscn` stores baked MultiMesh buffers and is not copied here.
4. Wire the manager signal `splash(point, normal, kind, wasted)` to `PaintFx._on_splash`.
5. Put characters on the exempt visual layer.
6. Verify: burst on the first frame, pop peak 1.15, decal color identical on a lit floor, a shaded wall and a column, ball lands within 0.05 m of the reticle, blink in the last 1.5 s, the sound never repeats the same wav back to back.
