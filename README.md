# Mossmail

A cozy, endless forest flying game for iPad, built in Godot 4.7 with Xogot.
You fly the forest post's hang glider over rolling wooded hills and collect glowing flowers floating at different heights. Golden four leaf clovers give a burst of super speed. Giant mountain ranges always close the horizon.

## Run it

1. Open the project folder in Xogot (iPad) or Godot 4.7.
2. Press Play. The main scene is `scenes/main.tscn`.

Keep the project on Godot 4.7, the version Xogot ships. Opening it in a newer desktop Godot upgrades the version stamp and it may stop opening in Xogot.

## Controls

| Input | Action |
|---|---|
| Hold the left half of the screen | Steer left |
| Hold the right half of the screen | Steer right |
| Tilt the iPad left or right | Steer |
| Altitude lever (bottom right) | Set the flying height |
| Tilt the iPad top edge toward you or away | Climb or dive |
| W / S or Up / Down arrows | Climb or dive (keyboard) |
| A / D or Left / Right arrows | Steer (keyboard) |

## Versions

Every version is a commit, an annotated tag `vN` and a branch `vN`.

| Version | What it is |
|---|---|
| v2 | Hang glider flight, rolling hills, 5×5 streamed forest, mountain ring that hides the world edge |
| v3 | Collect glowing flowers at different heights with real contact, golden speed clovers, altitude lever and tilt, glider colour selection, simpler title and HUD, landscape lock |

v1 (a running courier on flat ground) was replaced in place before the repository existed, so it has no tag.
The design history of every version is in `docs/GDD.md` and `docs/VERSIONS.md`.

## How the GDD was created

1. Five game ideas were pitched first as a visual board, and Mossmail was picked.
2. The asset packs were downloaded and imported before building, and the AI agent inventoried them, so every object in the design is a real file.
3. The design describes behaviour with numbers (speeds, heights, timers, rewards), not code.
4. Every mechanic was checked by a test script run inside the game (`tests/game/`) and by screenshots taken by the agent.
5. Each version adds a new section to `docs/GDD.md` instead of rewriting the old one, so the design history stays readable.
6. Every round of feedback was played, screenshotted and fixed, and the notes and measured values live in `docs/BUILD_NOTES.md`.

## Project layout

| Folder | Contents |
|---|---|
| `scenes/` | One saved scene per game element: actors, gameplay, world chunks, props, UI |
| `scripts/` | GDScript, mirrored by domain |
| `shaders/` | Terrain, water, particles, screen mood pass |
| `materials/`, `ui/` | Materials, environment, theme and font variations |
| `assets/` | Third-party packs exactly as downloaded |
| `docs/` | GDD, build notes, asset manifest, version log |
| `tests/game/` | In-game acceptance test for the current version (run with game eval) |
| `game-dev/` | The Godot game development skill (agent instructions) used to build the game, included on purpose so you can use it in your own projects |
| `xogot/` | Xogot Modeler data |
| `pitch_*`, `game_pitches.html`, `primate_test.tscn` | The five game ideas the agent pitched first, and the first editor test, kept as they were |

## License and credits

Code and original content: MIT (see `LICENSE`). The packs in `assets/` keep their own licenses (see `THIRD_PARTY_NOTICES.md`).

Hang glider by Poly by Google (CC-BY 3.0). Nature models and animations by Quaternius (CC0). KayKit Forest Nature Pack by Kay Lousberg (CC0). Textures by ambientCG (CC0). Font Fredoka (SIL OFL 1.1).
Built in Xogot (Godot 4.7.2) with an AI agent.
