# Mossmail versions

Times come from file modification timestamps on the iPad (GMT-3). Time spent
diagnosing crashes or waiting for Xogot to restart leaves no files behind, so
it is not counted.

| Version | What | First change | Last change | Build time from files |
|---|---|---|---|---|
| v1 | Running courier: endless forest, deliveries, gather, sky mail, full UI | 12:53 (assets in) / 13:02 (first script) | ~13:38 (final tests) | ~45 min |
| v2 | Hang glider flight, rolling hills with flat zones, 5×5 forest, mountain ring hiding the world edge, CC-BY credit | 17:35 (first v2 script) | 17:57 (docs) | ~25 min of building, plus earlier time on the glider crash (mesh without normals) and editor restarts |
| v3 | Flower collecting with real contact, glowing flowers, golden speed clovers, altitude lever and tilt, glider colours, title, selection screen and HUD redesign, centred flight camera, landscape lock, no LOD pop in | 19:21:35 (restart after the recording break) | 19:44:20 (completion pass) | **about 33 min**: 22 min 45 s measured (19:21:35 to 19:44:20), plus about 10 min estimated for the first part (glider controller, palette and pickup scripts) written before the recording break. Later polish rounds: forest and editor preview 20:09:59 to 20:14:38 |

Snapshots: `versions/v2/` and `versions/v3/` hold each version's scenes, scripts, shaders, materials, UI, docs, tests and
project.godot. `versions/` has a `.gdignore` so Godot never imports it, and
`assets/` is not copied because it is unchanged since download. There is no v1 snapshot: v1 was
overwritten in place before versioning started, and the project is not a Git repository.
