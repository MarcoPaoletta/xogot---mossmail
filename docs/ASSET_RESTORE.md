# Asset restoration

**WORK IN PROGRESS. DO NOT DELETE THIS PROJECT.**

This game or its production copy is protected because its video is unpublished, it is reused by pending production, or it is an unfinished direction. This documentation does not change that protection. No code, scene, asset, cache or file location was changed to prepare it.

Recorded on 2026-10-27.

Repository: https://github.com/MarcoPaoletta/xogot---mossmail.git

Local branch: `main`. Metadata baseline commit: `2276f5143961e265eeb9b21e784921204ffe011c`.

## Restore workflow

1. When restoration is actually needed, clone the matching code revision. Restore Git-managed files first and use `git lfs pull` if the repository uses LFS.
2. Consult the source manifests below for the exact models, packs, relative destinations, versions and import settings. Keep downloaded models and their textures together.
3. For generated assets, use the original provider account and original model/export name or persistent ID. Marco confirmed on 2026-10-27 that his generated originals remain in those accounts. Missing direct URLs or IDs are not a reason to generate a replacement. No current API download test is claimed here.
4. Retrieve the same rigged/animated and texture variant, preserve filenames, and reapply the recorded scale, orientation, animation mapping and postprocess scripts.
5. SDKs, editor integration and the private development skill are installed separately. Do not commit account credentials or the private skill copy. Godot/Unity imports and other generated caches can rebuild when the project is reopened.

## Current authoritative model and source records

* `assets/SOURCES.txt`
* `docs/ASSET_MANIFEST.md`
* `docs/GDD.md`
* `README.md`

## Pack/provider notes already recorded in the project

These are excerpts of existing project metadata, not a new assertion that a binary is currently present on a remote server.

* nature/    Quaternius, Stylized Nature MegaKit [Standard], CC0. https://quaternius.com/packs/stylizednaturemegakit.html (glTF only kept)
* courier/   Quaternius, Universal Animation Library [Standard], CC0. https://quaternius.com/packs/universalanimationlibrary.html
* props/     KayKit (Kay Lousberg), Forest Nature Pack 1.0 FREE, CC0. https://kaylousberg.itch.io/kaykit-forest (glTF only kept)
* | `assets/nature/` | Stylized Nature MegaKit (Standard) | Quaternius | CC0 1.0 | Forest, giant trees, mushroom homes, collectible flowers (Petal_3 + Petal_1), golden speed clovers (Clover_1), flower counter icon, mountain ring (Rock_Medium scaled up) |
* | `assets/courier/` | Universal Animation Library | Quaternius | CC0 1.0 | **Not used** since the switch to the glider |
* | `assets/props/` | Forest Nature Pack 1.0 FREE | KayKit | CC0 1.0 | **Not used** (style clash) |
* No Kenney assets.
* - **Speed boost:** golden four-leaf clovers (Quaternius Clover_1) hover 10–40 m over clearings in the pines and meadow chunks. Touching one gives 4 s of super speed (×1.75), with a golden trail, speed lines and a FOV kick. Updrafts and sky rings are removed.
* Hang glider by Poly by Google (CC-BY 3.0). Nature models and animations by Quaternius (CC0). KayKit Forest Nature Pack by Kay Lousberg (CC0). Textures by ambientCG (CC0). Font Fredoka (SIL OFL 1.1).

## Stable source/reference URLs already recorded

No signed download URL or credential is stored here.

* https://ambientcg.com
* https://kaylousberg.itch.io/kaykit-forest
* https://quaternius.com/packs/stylizednaturemegakit.html
* https://quaternius.com/packs/universalanimationlibrary.html

## Cleanup status

**Protected and not ready for deletion.** Keep this project local. Update this file as new models are imported, but do not archive the game merely because this file exists.
