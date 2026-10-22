# Tycoon juice: the satisfying tycoon module (fishing tycoon first, 2026-10-17)

Marco's brief (2026-10-17): a complete module for the whole feel of a tycoon, the "stacking on the back" madness, cutting fish, all of it, so this skill can produce more tycoon games and every one of them feels as satisfying as the genre's best. Use it in EVERY game whose loop is gather, carry, process, sell, spend, unlock (fishing, mining, farming, burger and shop tycoons, factories, idle miners with a physical world).

Honest status: the scripts here compile and pass three headless tests in Godot 4.7.2 (`scripts/tests/`, section 14). The feel numbers are **starting values from the genre's conventions, not yet tuned inside a Letta build**; each section says which numbers are structural (keep) and which are dials (tune by screenshot and by playing). The first Letta tycoon to use this module should record its tuned values back here.

## 0. The thesis: value you can SEE move

A tycoon is satisfying because **every unit of value is a physical object that visibly travels, and every arrival is acknowledged**. A fish leaves the water on an arc, lands on your back with a squash, the whole tower ripples, a pitched pickup sound ladders up. You walk to the table and the stack empties onto it faster and faster. The knife chops, a tick per chop, fillets pop onto a tray. You scoop them, carry them to the counter, a customer takes one, a pile of cash grows, you walk over it, bills fly to the counter at the top of the screen and the number rolls up as each one lands. You stand on a glowing square and the money drains out of you while the price counts down, and a new building pops into the world with a camera cut to show it.

Nothing in that loop is a menu, a bar filling by itself or a number changing without an object behind it. That is the rule that separates a tycoon that feels like a toy from one that feels like a slot machine: **no value changes without a visible carrier, and no carrier arrives without feedback**.

The five feedback layers on every arrival (the tycoon version of paint splash's six layers). Fire all of them on the frame of the landing, never staggered by accident:

1. **Motion:** arc flight with a stretch at mid flight (`ItemFlight.fly`), never a teleport, never a straight line.
2. **Squash and pop:** the receiver or the item squashes wide on landing, overshoots tall, settles (`ItemFlight.squash`). Back ease, never linear.
3. **Ripple:** the thing it joined acknowledges it (the stack ripples up the tower, the tray bounces, the counter punches).
4. **Sound with a pitch ladder:** each consecutive pickup is a little higher than the last (+5 to 6 percent per step, capped at 2.0), resetting when the chain breaks. The ladder is what makes spamming pickups feel like a melody.
5. **Number:** a floating "+12" at the spot (`PopNumber`), and the HUD counter rolls to the new value (`MoneyCounter`).

Plus the layers that sell big moments only: camera trauma, FOV kick, a camera focus beat, confetti, a dust ring when something is built.

## 1. The loop and the world are the UI

```
GATHER  ->  CARRY  ->  PROCESS  ->  SELL  ->  SPEND  ->  UNLOCK  ->  (more of everything)
fish        stack on    cut fish    customer   stand on    new spot,
jump out    the back    to fillets  pays cash  the pad     worker, tool
of water                            pile
```

The fishing tycoon chain, concretely:

| Stage | World object | What the player does | Output |
| :-- | :-- | :-- | :-- |
| Gather | Fishing spot on the dock (rod, net, boat) | Stands in the spot zone. Catches arrive on a timer. | Fish jump out of the water and fly onto the stack. |
| Carry | `CarryStack` on the back | Runs. | Up to `capacity` fish, trailing and wobbling. |
| Process | Cutting table (`StationProcessor`) | Stands in the input zone. | Fish become fillets (2 per fish), plus optional bones for a second station. |
| Collect | Output tray (`ItemTray`) | Walks into the output zone. | Fillets fly back onto the stack. |
| Sell | Counter or display case with a customer queue | Stands at the counter. | Customer takes fillets, pays. Cash lands on a cash tray. |
| Collect | Cash tray (`ItemTray` of bills) | Walks over it. | Bills fly to the HUD, counter rolls. |
| Spend | `UnlockPad` | Stands on it. | Drains money, then the new thing appears. |
| Automate | Worker hire pad | Stands on it. | An NPC runs the same stack and station APIs by itself. |

**Rules of the loop:**

- ⛔ **No menu to progress.** Buying, upgrading, hiring and unlocking happen by standing on pads in the world. A shop screen is allowed only as a secondary list (skins, settings), never as the way to grow the business.
- **Workers use the same objects as the player.** An NPC worker owns a `CarryStack`, walks to the same `StationProcessor` zones and the same trays. Automation is then free, always correct, and visibly identical to what the player does, which is why it feels earned.
- **Every stage is a bottleneck candidate.** The income per second equals the slowest link (catch rate, stack capacity, chop time, customer rate). Each upgrade moves the bottleneck to the next link, so every purchase changes what the player looks at. Same principle as the idle miner chain in the Retired Heroes Mining Co notes.
- **One viewpoint, one screen.** The player sees the whole production line from one fixed angle perspective camera. If it needs to scroll, scroll along the line.

## 2. The stack on the back (the signature image)

`scripts/carry_stack.gd`. This is what Marco means by the "falopa of stacking on the back". It is the single most important piece, so it gets the longest section.

**Structure (keep):**

- A node `BackStack` on the character's back, +Y up. Items are children with `top_level = true`, so they move in world space and can lag behind the character. The script never builds anything: it is handed instances of a saved item scene.
- **Per item stiffness.** Every item chases its slot with its own stiffness `k`, stiff at the bottom (`follow_k_bottom` 40) and loose at the top (`follow_k_top` 11): `pos = lerp(pos, slot, 1 - exp(-k * delta))`. At speed `v` an item trails its slot by about `v / k`. The tower bends smoothly, never overlaps, needs no spring simulation and is framerate independent. **Measured 2026-10-17 with a 3 item stack at 5 m/s: bottom trailed 0.09 m, top 0.39 m.**
- **Hand stacked, not machined.** Each item gets a random yaw offset (plus or minus 0.2 rad) when it joins, so no two stacks look the same. Lay items the way they would lie (fish flat, crates axis aligned).
- **Alive at the top.** A sway sideways that grows with height and speed (`sway_amount` 0.03 x index x speed), and an idle wobble roll of 4 degrees (a fish flopping, a bag shifting).
- **Teleport safety.** If an item is farther than 3 m from its slot (respawn, teleport), it snaps. Otherwise the tower stretches across the map.

**Pickup (keep):** `add_item(item)` reserves a slot immediately and flies the item along an arc to the LIVE slot position (the slot moves with the player), 0.3 s, apex 0.7 m, half a turn of spin. On landing: squash (0.28), a ripple up the tower (a 1.08 scale pulse per item, 20 ms staggered from the bottom), the pickup sound at the next pitch of the ladder, and `item_added`. The reservation means a full stack rejects the next item at once (`rejected_full`), even while others are still in the air.

**Drop (keep):** `send_top(target, ...)` pops the topmost item of a kind (the middle of the tower works too: the ones above settle down into the gap, which looks great) and flies it to a target Callable, 0.24 s. Stations and counters call this on a cadence.

**Cadence (the part that feels like a machine gun):** the first item moves at 0.22 s, and each following item multiplies the interval by 0.85 down to a floor of 0.06 s. Stand longer and it empties faster. Resets when you leave the zone. Same idea for picking up from a tray (0.16 s, x0.88, floor 0.05 s).

**Dials (tune by screenshot):** `capacity` (start 6, upgrade steps of +2 or +4 up to 20 to 30), `item_height` (match the item mesh, about 0.2 m for a fish), `follow_k_top` (lower = more lag, more drama; below 7 the tower looks drunk), `pitch_step`, `pickup_duration`.

**Traps:**

- ⚠️ **Items spawn in the world first.** `add_item` needs the item already in the tree. The producer (the water, a tray, a customer) spawns the instance at its own position, then hands it to the stack. Spawning at the origin makes the flight start from (0,0,0).
- ⚠️ **Do not parent the items to the character's skeleton.** They would inherit the run animation's bob and kill the independent lag. `BackStack` hangs off the character root, offset to the back (a `Marker3D` authored in the player scene), not a bone.
- ⚠️ **A full stack must be legible.** At capacity show a big "MAX" over the head (a `Label3D` in the player scene, popped with a back ease) and a reject cue on the next attempt (shake plus a low thud). A silent refusal reads as a bug.
- ⚠️ **Carrying pose.** Blend the character into a carry pose (arms forward or up) with the 0.75 s blend rule of the skill, driven by `count() > 0`. Contact frames (the pickup) blend in at 0.2.
- ⚠️ **Do not read speed from the character's `velocity` property.** The script derives velocity from the node's own position delta, which is correct for any mover (CharacterBody, tween, vehicle, worker).
- **Pitch ladder reset:** `pitch_scale` is derived from the stack count, so it naturally resets when the player drops items. For chains of rapid pickups from a tray the ladder should instead follow the chain; keep a `_chain` counter that resets after 0.6 s without a pickup if the count based ladder feels too flat.

## 3. Flight, squash and pop (the verbs of the genre)

`scripts/item_flight.gd`, three static functions used everywhere.

- `fly(item, target_callable, duration, apex_height, spin_turns, on_land)`: quadratic bezier whose control point is the midpoint raised by `2 x apex`, so the curve peaks `apex` above the straight line. `TRANS_SINE` in and out. A 12 percent stretch at mid flight. The target is a Callable re-read every frame, so it follows a moving player. Sets `top_level = true` so the world space motion is exact.
- `squash(item, strength 0.28, time 0.22)`: sets the scale wide and short immediately, tweens back with `TRANS_BACK` ease out, so it overshoots tall and settles.
- `pop_in(node, time 0.35, overshoot 1.15)`: 0.01 to overshoot with back ease in 60 percent of the time, settle in 40 percent. Builds, reveals, spawned props, the objective arrow.

**Durations (dials, but keep the ordering):** water to stack 0.3 to 0.4 s with a high apex (1.0 to 1.4 m) so a fish clearly jumps; stack to station 0.22 s; station to tray 0.28 s; tray to stack 0.3 s; coin to HUD 0.55 s; a coin from the player to a pad 0.3 s. **Short and snappy beats floaty**: anything over 0.6 s on a world transfer reads as lag.

## 4. Stations: cutting fish

`scripts/station_processor.gd` plus `scripts/item_tray.gd`. One generic machine: input zone, buffer, timed recipe with chop ticks, output tray, output zone.

**Authored in the station scene (Rule 1c, editor tools):** the table mesh, `InputZone` and `OutputZone` (`Area3D`), `InputPoint` and `OutputPoint` (`Marker3D`), an `ItemTray` with its grid, a progress ring (`Label3D` or a shader quad), the knife or tool as a child with its own animation, hit particles, audio players. The script wires the signals; FX hang off them.

**The cycle (keep):**

1. Player enters the input zone. The feeder asks the player's `CarryStack` for the top item of `accepts_kind` on the accelerating cadence of section 2.
2. Each fish flies to `InputPoint` (0.22 s). On arrival it is consumed (`queue_free`, or return it to a pool), `buffer` goes up, `input_received` fires (squash the table, a puff).
3. If idle and the buffer has something, a cycle starts: `cycle_started`, `progress_changed` 0 to 1 over `process_time` (1.2 s base), and `chop(i, total)` fires three times, evenly, on `chops_per_cycle` (the last chop is guaranteed even on a very short recipe).
4. On completion, `outputs_per_input` pieces (2 fillets) are instantiated at `OutputPoint`, pop in, and each flies to the next tray slot, 80 ms apart. `cycle_completed` fires and the next buffered fish starts at once, so a full buffer is a continuous chopping rhythm.
5. If the tray is full the station waits and `blocked_changed(true)` fires: show a red tray outline and a "FULL" pop. It resumes by itself when the player empties the tray.
6. Player enters the output zone and the tray empties onto the stack on its own cadence (`transfer_to_stack`), until the stack is full.

**What to hang on the signals (this is where "cut fish" gets its juice):**

| Signal | Layers to fire |
| :-- | :-- |
| `input_received` | Table squash, small splash or puff, soft thud sound at the ladder pitch. |
| `cycle_started` | Knife lifts, progress ring appears with a pop. |
| `chop(i, n)` | Knife slams down on the beat. A `tick` sound with pitch rising per chop, a burst of 6 to 10 scale shreds or droplets, camera `add_trauma(0.12)`, the board squashes 6 percent. The third chop is the strongest (louder, bigger burst, trauma 0.2). |
| `progress_changed` | Ring fill. Colour from amber to green near the end. |
| `cycle_completed` | Fillets pop in glossy, a sparkle or wet glint, a small "ding". |
| `blocked_changed` | Red outline, "FULL", shake. |

**Dials:** `process_time` (upgrade path: base / (1 + 0.25 x level)), `outputs_per_input`, `buffer_capacity` 10, `chops_per_cycle` 3. A visible chopping rhythm of about 2 to 3 chops per second is the sweet spot for the base station; faster stations look frantic.

**Variants of the same machine:** grill (raw to cooked, tint changes), furnace, sorting table (kind A to tray A), packing station (4 fillets to 1 box), a cash register is a station whose output is cash. Do not write a new class for each: change the recipe and the FX.

## 5. Customers, selling and the cash pile

- **Queue:** customers walk in a line to the counter, stop at marked slots (`Marker3D` queue points authored in the shop scene), and show an **order bubble** above the head (the icon of the product and the number wanted, big and readable). A satisfied customer does a small hop.
- **Serving:** the player stands in the counter zone and the stack feeds fillets to the counter exactly like a station input (reuse the cadence). Each fillet flies to the customer, the bubble count ticks down with a pop, and at zero the customer is happy: hop, heart or coin burst, and **the cash lands on the cash tray**.
- **Cash is an object.** Money from sales spawns bills in an `ItemTray` (columns 2 to 3, layers up to 10). The pile visibly grows and the player is rewarded for coming back to it. Bill value is data on the item; a pile of 12 bills is a satisfying thing to walk through.
- **Collect:** walking onto the cash tray zone sends bills on arcs to the HUD via `HudCoinFlight.collect` (section 6). One bill per 0.05 s, speeding up.
- **Patience:** an order bubble with a slow depleting ring, never a hard fail. A customer who waits too long leaves with a small sad pop, no punishment beyond lost income.
- **Fishing flavour:** customers can be animals (cats, gulls, a bear), chefs, tourists. A rare customer (golden cat) pays a multiple and gets a camera focus beat. This is the cheapest source of variety in the genre.

## 6. Money: the counter, the coins, the floating numbers

- **`Wallet` autoload** (`wallet.gd`): `cash`, `add(amount, world_position)`, `try_spend(amount)`, signals `changed`, `earned`, `spent`, `rejected`. Everything listens to this one place.
- **`MoneyCounter`** (`money_counter.gd`, a `Label`): the number never jumps. It rolls toward the real value (`roll_speed` 10, exponential), punches to 1.25 scale with back ease on a gain, flashes green on gain and red on a loss, shakes on `rejected`. Compact format from `EconomyCurves.format_compact` (950, 1.2K, 3.4M, 1.2B). Make it the biggest thing in the HUD: it is the number the whole genre watches.
- **`HudCoinFlight`** (`hud_coin_flight.gd`): `collect(world_position, amount)` projects the world position to the screen (`unproject_position`), splits the amount into up to 8 coins, flies each along a screen space arc to the counter, 45 ms apart, and **calls `Wallet.add(share)` as each coin lands**, with a chime that climbs 6 percent per coin. The counter therefore ticks up in step with the chimes. ⛔ Never add the cash first and play the coins as decoration.
- **`PopNumber`** (`pop_number.gd`, a `Label3D` in `pop_number.tscn`): a "+12" at the spot where the money was made, pops to 1.3 with a back ease, rises 1.3 m, fades out in the last 40 percent of its 0.85 s life. Gold for cash, other colours for other currencies. Billboard, no depth test, outline on.
- **Big moments:** a rare fish, a milestone (every 10 levels), a first-ever unlock. Slow the time scale to 0.5 for 0.4 s, `fov_kick`, a confetti burst, a bigger number. Rare beats must feel rare: reserve them.

## 7. Unlock pads: pay by standing

`scripts/unlock_pad.gd`. The mechanic that carries the whole expansion loop.

- The pad is an `Area3D` with a glowing floor plate, a **big** price (a `Label3D`, readable at phone scale) and a fill ring. The player steps on it.
- Money drains from the wallet at `pay_rate_start` (30 per second) and **accelerates up to 8x over 1.4 seconds** of standing there, with an ease in. Short waits for small prices, still a satisfying slow drain for big ones. The price label counts down with every payment (`progress_changed`), coins fly from the player's head to the pad (one every 0.05 s, `ItemFlight.fly`), and a ticking sound climbs in pitch with progress.
- ⛔ **Drains exactly the price, never over.** The chunk is clamped to the remaining price and to the cash in hand. Verified: a 60 price pad drained exactly 60 from 100.
- **Not enough money:** the pad is dim, shows the remaining price, and if the player stands on it with zero cash it fires `rejected_poor` (a "need money" shake and thud). It never silently does nothing.
- **Completion (keep, in order):** `unlocked` fires; `reveal_targets` pop into the world with `pop_in` (back ease, overshoot 1.15), 80 ms apart; a dust ring and confetti at each; camera `focus_beat` toward the new thing (0.55 s travel, 0.9 s hold, 0.7 s back) when it is off screen; trauma 0.3 and a short FOV kick; a fanfare; the pad shrinks away. Targets are authored hidden in the level, never spawned by code from nothing.
- **Pad flavours (same script):** unlock an area, hire a worker, upgrade (capacity, speed, income, rod count). An upgrade pad stays after use and rebinds to the next level price (`EconomyCurves.level_cost`).
- **The next target is always pointed at.** `ObjectiveArrow` (`objective_arrow.gd`): a chunky bouncing arrow over the next pad or station that vanishes when the player is within 3.5 m. A tycoon has no menu to tell you what to do next, so the world does.

## 8. Economy and pacing

`scripts/economy_curves.gd`: `level_cost`, `bulk_cost`, `max_affordable` (for a Buy MAX pad), `seconds_to_afford`, `offline_earnings`, `format_compact`.

- **Costs grow geometrically, income grows about linearly:** `cost(level) = base x growth^level` with growth 1.07 to 1.15 per level (dial). The widening gap is what the player feels as "it takes longer now", and each unlock resets the feeling with a jump in income.
- **Bottleneck first.** Model the line as catch rate, stack capacity, chop time, customer rate, and let `income = min(links)`. Tune so each link is the bottleneck in turn. If one upgrade never matters, it is mispriced.
- ⛔ **The first minute is the video (game-dev rule, "WOW in the first minute").** Start the player with enough cash for the first two or three pads and the first purchase in under 15 seconds. First 3 minutes target: about one meaningful purchase every 15 to 25 seconds (second spot, bigger stack, cutting table, first customer), the first worker before minute 3. Slow ramps kill the clip.
- **Debug panel (F1) is mandatory** as in the skill: +100, +1000, +100K cash, unlock next pad, spawn a rare customer, 2x/4x time, erase save. Each must show its normal feedback, never a silent jump.
- **Offline earnings** (if the game is idle-flavoured): capped at 8 hours, 50 percent efficiency, shown as a claim popup the player taps for a satisfying burst, never added silently.
- **Prestige** (long runs only): reset for a permanent multiplier, a separate currency, never in a first video build.

## 9. Camera, character and feel

- **Camera (`tycoon_camera.gd`):** perspective always, FOV 35 to 40, pitch about 50 degrees, fixed angle authored in the scene (the rig only translates). Soft follow `follow_k` 5. `focus_beat(point)` after unlocks, `add_trauma()` for chops and purchases, `fov_kick()` for speed upgrades and big reveals. Perceptual shake minimum: 0.12 trauma on a chop must still be visible after video compression, check the pixels.
- **Controls:** floating virtual joystick on mobile (appears where the thumb lands), WASD on desktop. Movement is fast and snappy with a short acceleration ramp (0.08 s) and no inertia slide. Stack size does not slow the player (a slowdown reads as punishment in this genre).
- **Character:** run, idle, carry (arms forward) with the 0.75 s blend rule. A tiny forward lean while moving. A happy hop at a purchase.
- **Water and the dock (fishing):** water is the first thing that betrays a cheap build: a real shader with colour depth, foam at the dock and a ripple layer (`references/water-foam-2d/` has the 2D one surface rule: water and foam are one surface, never two layers). Each catch spawns a **splash**: a ring ripple, 8 to 12 droplets and a sound, at the spot where the fish leaves the water.

## 10. Fishing specifics

- **Catch cadence:** a spot yields a fish every 1.2 s base (upgradable by rod count). Show the line, a bobber dip and a tug before the fish jumps, so the catch has an anticipation beat.
- **The jump:** the fish is spawned underwater at the spot, launched with `ItemFlight.fly` apex 1.2 m, 0.35 s, 1.5 turns of spin, to the stack. Splash on exit.
- **Rarity tiers:** common, rare, epic, mythic. Tier sets colour outline or glow, size multiplier (1.0, 1.15, 1.35, 1.6), price multiplier (1, 3, 10, 40) and the fanfare. A mythic gets the big-moment treatment of section 6. Show the tier colour on the pop number as well.
- **In the stack:** fish lie flat, alternating yaw, and flop (the wobble). Fish are thicker than crates: set `item_height` from the mesh AABB.
- **Cutting:** section 4. Fish becomes 2 fillets; a bones piece is an optional second output (feeds a cat, a bait or fertiliser station) that creates a second chain without a new system.
- **Selling:** fillets on an ice tray display (`ItemTray`) for the customers, price shown on the display.
- **Upgrades that pay off visibly:** stack capacity (the tower grows taller, a new tint on the backpack), rod count (a new rod appears on the dock), boat (a new spot out on the water), worker (an NPC with its own stack).

## 11. UI

- **Minimal HUD:** cash counter (huge, top centre), a pause button, nothing else by default. If the world already shows it, the HUD does not repeat it. Capacity is shown on the character ("MAX" pop), not in a bar.
- ⛔ **Large and legible (Marco's eyesight):** counter font at least 56 px at the design resolution, pad prices at least 48 px equivalent, every tappable thing at least 88 px. One downloaded font for the whole game, as the skill requires. Number outlines thick enough to read over water.
- **World space UI is the main UI:** prices over pads, order bubbles over customers, progress rings over stations, "MAX" over the head. All are `Label3D`/quads authored in their scenes.
- **Tutorial:** the objective arrow plus a pulsing hand on the first two actions only, then silence. Never a text wall.

## 12. Performance

- **Pool** everything that spawns often: fish, fillets, bills, coins, pop numbers, splash bursts. Pools instantiate saved scenes and reset state, they do not build nodes.
- **Cash piles and decorative stacks with many identical items:** a `MultiMeshInstance3D` for the resting items, individual nodes only for items in flight. A pile of 100 bills must not be 100 nodes.
- **Cap flights per frame:** at most about 30 items in the air; beyond that, land them instantly with only the squash.
- **Stack size cost:** each stacked item runs a tiny per frame loop; 30 items is fine, hundreds of workers each with a 30 item stack is not. Give far away workers a cheap non-trailing representation.
- **Mobile target:** keep draw calls low, one directional light, baked-looking environment. Particles use GPU particles with small counts (8 to 12 per burst).

## 13. Scene breakdown (Rule 1c, authored with the editor tools)

Every element is its own saved scene with named nodes. Behavior is the script above; structure is authored.

| Scene | Key nodes | Script |
| :-- | :-- | :-- |
| `player.tscn` | `CharacterBody3D`, model, `BackStack` (+ `PickupSound`), `MaxLabel`, group `player`, exports `carry_stack` | `carry_stack.gd` on `BackStack`, the player controller |
| `item_fish.tscn` (one per tier or one with a mesh swap) | `Node3D`, mesh, outline | none (tag `kind` meta from the producer) |
| `item_fillet.tscn`, `item_bill.tscn`, `item_coin.tscn` | `Node3D`, mesh | none |
| `fishing_spot.tscn` | spot zone `Area3D`, rod, line, bobber, `SplashBurst`, spawn `Marker3D` | the spot's own small producer script |
| `station_cutting.tscn` | table mesh, `InputZone`, `OutputZone`, `InputPoint`, `OutputPoint`, `ItemTray`, knife, `ProgressRing`, particles, audio | `station_processor.gd` |
| `item_tray.tscn` (output, cash, display) | grid root, optional mesh tray | `item_tray.gd` |
| `counter.tscn` / `shop.tscn` | counter zone, queue `Marker3D`s, `CashTray`, display | the shop's own script (reuse the station feed cadence) |
| `customer.tscn` | character, order bubble | the customer's own state script |
| `unlock_pad.tscn` | `Area3D`, plate, `PriceLabel`, `Ring`, `CoinFx` | `unlock_pad.gd` |
| `pop_number.tscn` | `Label3D` (billboard, fixed size off) | `pop_number.gd` |
| `hud.tscn` | `CanvasLayer`, `MoneyCounter`, `HudCoinFlight`, `hud_coin.tscn` | `money_counter.gd`, `hud_coin_flight.gd` |
| `tycoon_camera.tscn` | rig `Node3D`, `Camera3D` at the authored offset | `tycoon_camera.gd` |
| `objective_arrow.tscn` | arrow mesh | `objective_arrow.gd` |
| `fx_*.tscn` | splash, chop shreds, dust ring, confetti, sparkle | none (GPU particles authored in the scene) |

Per Rule 1c: the level composes instances of these; reveal targets are placed hidden in the level by the editor tools, not built by the pad; pools instantiate these scenes. Copy `scripts/*.gd` to `res://scripts/tycoon/` (autoload `wallet.gd` as `Wallet`).

## 14. Verification and acceptance

**Code verified headless on 2026-10-17, Godot 4.7.2** (`scripts/tests/`, copy `project.godot.txt` to `project.godot` in an empty folder with the scripts under `res://scripts/`, then run each test with `--headless --script`):

- `smoke_test.gd`: stack capacity and reservation, rejection when full, landing, top item trails more than bottom (0.39 m vs 0.09 m at 5 m/s), `send_top` by kind and its arrive callback, tray capacity and push staggering, tray to stack transfer, pad drains exactly the price and reveals its targets, camera focus and shake run, counter rolls to `$5K`, compact formatting edge cases (999999 becomes 1M).
- `station_test.gd`: 4 fish feed a station, 4 cycles, 12 chops (3 per cycle), 8 fillets on the tray, the tray empties back onto the stack.
- `hud_test.gd`: `collect(103)` flies 8 coins and the wallet receives exactly 103 as they land.

This proves the logic, not the feel. The perceptual gate stays with the build:

**Perceptual gate for a tycoon (all must be true, judged by eye on video or a frame contact sheet):**

1. Every transfer of value (catch, feed, output, serve, cash, pay) has a visible carrier on an arc, a landing squash and a sound.
2. The stack visibly trails the runner at speed and recovers when they stop; the top moves more than the bottom.
3. The pickup sound climbs across a chain of pickups and resets after.
4. A full stack shows "MAX" and a reject cue.
5. The station chop is rhythmic: the tick, the burst and the shake land together on each of the 3 beats.
6. The money counter never jumps and the coins visibly land as it rolls.
7. A pad drains while standing, the price counts down, the unlock pops the thing in with a camera beat, and the pad disappears.
8. The player has a clear next objective at all times (arrow) and no menu is needed to grow.
9. First purchase in under 15 s; a purchase every 15 to 25 s for the first 3 minutes.
10. Zero placeholders: real font, real art, themed everything (skill's placeholder audit).

Save a contact sheet of one full loop (catch, stack, cut, serve, cash, pad) in `docs/evidence/` and note the tuned dials in `docs/BUILD_NOTES.md`. After the first real build, write the tuned numbers back into this doc.

## 15. GDD drop-in block

The ready made GDD block is `Letta/Skills/Skill 5 - Proposal Writer/1 - Build GDD/patterns/tycoon-juice.md` (paste it into every tycoon GDD). Its core sentence: "Tycoon feel is specified by `references/tycoon-juice/`: every transfer of value is a visible object on an arc with squash, ripple, pitched sound and a number; the player carries goods in a trailing back stack; stations process on an accelerating feed cadence with a chop tick per beat; money is physical (cash tray, coins landing on the counter); progression is by standing on unlock pads that drain money and pop the purchase into the world with a camera beat; workers reuse the player's stack and stations; the first purchase lands within 15 seconds."
