# Xogot project repo: what every game built for Xogot ships with

**Rule of Marco, 2026-09-15.** Every game project built for a Xogot video (Joseph Hill, Xibbon) is born as a GitHub repo that Joseph can fork and publish under `github.com/Xogot-Projects` without asking us for anything. That is part of the deliverable, not an extra. He asked for it explicitly on 2026-09-15 for the Sushi Restaurant repo ("Can you add an MIT license... commit the GDD.md... share how the gdd was created... fork this to github.com/Xogot-Projects"), and the answer is always yes. The point of the rule is that the next repo already has all of it on day one, so the question never comes back.

**Addendum, Marco 2026-09-17: the repo is PUBLIC from the first commit.** Joseph forked the private Sushi Restaurant repo and could not make the fork public (GitHub: a fork of a private repo stays private), so he copied the contents into a new repo and lost the whole commit history, "especially for the design docs", which is the part he values. He asked us to make the repo public so he can fork and publish that version, Marco said yes and made it the rule: nothing built for Xogot is private, ever, because the fork with history is the deliverable and a private repo cannot be forked into a public one. The reader invite still goes out (it is the notification), but it is no longer what gives him access.

## The checklist (all of it, before the repo invite goes out)

| Item | What exactly | Why |
|---|---|---|
| Visibility | **Public from the first commit** (`gh repo create ... --public`). Never private, not even while the game is being built or before the video is out. | A fork of a private repo cannot be made public on GitHub. Joseph hit that on 2026-09-17, copied the files by hand and lost the commit history he wanted. Public from day one means he forks with the full history whenever he wants, no round trip. |
| `LICENSE` | MIT, `Copyright (c) <year> Letta Corporation (Marco Paoletta)`, plus a short note at the end saying that `assets/` includes third-party assets under their own licenses and pointing at `THIRD_PARTY_NOTICES.md`. | Joseph's ask, word for word: the license file itself must point out the assets. ⚠️ The note makes GitHub's detector return `NOASSERTION` (it needs the MIT text verbatim). That is accepted: his ask wins over the badge, and he can move the note if he prefers the badge on the fork. |
| `THIRD_PARTY_NOTICES.md` | A table: path, author, license, link, and the name of the license file inside the pack folder. Quaternius packs are CC0 1.0, Kenney is CC0, Lilita One is SIL OFL 1.1. Generated audio (`tools/gen_audio.py`) and our own shaders are ours, say so. | So the split is explicit and each pack keeps its license file in its folder (add a `LICENSE.txt` note when a download ships without one, as the sushi kit did). |
| `docs/GDD.md` (+ `docs/GDD.pdf`) | The build GDD, committed from the FIRST commit ("Initial state: empty project, packs imported, GDD"), and versioned in place: each round of play adds a section that supersedes the earlier ones (1.0 spec, 1.1 implementation notes, 2.0, 3.0, ...). Never rewritten, never a clean summary written afterwards. | Joseph wants people to see "what a good design specification looks like" and the history is the teaching material. GDD rules: Skill 5 `1 - Build GDD` (English, behaviour not code, acceptance test per mechanic, cut list, build order). |
| `README.md` | What the game is, how to run it (Xogot for Mac link, controls verified against `project.godot`), **how the GDD was created** (the six points below), repo layout, license section, credits (asset authors with links, editor, models used, Letta). No dashes as punctuation. | The "share a bit more about how the gdd was created" part of his ask. |
| Commit history | One commit per step of the GDD's build order, message says what the step was. | `git log` is the build diary; Joseph reads it. |
| Invite | Joseph as `JosephHill`, read access, in the delivery email of the video, with the repo link and the line that he can fork it or do whatever he wants with it. On a public repo the invite is the notification, not the access. | He forks to `Xogot-Projects` and renames it `Xogot-<Game-Name>`. Always yes. |
| Versions | Every version of the game (V1 to Vn) is a commit plus an annotated tag `vN` plus a branch `vN`, all pushed. Full rule and push recipe: `SKILL.md`, "Repo rules for every Letta game". | Joseph forks with history and the videos show every version; a branch lets anyone return to a version and continue from it. |
| Godot version stamp | The project stays on the Godot version Xogot ships (`config/features` in `project.godot`). Never opened in a newer desktop Godot: one save upgrades the stamp and the project stops opening on the iPad or in Xogot. | Measured on the shaders video (4.6 vs 4.7). |
| Engine and packs untouched | Vendor packs go in `assets/<Pack name - date>/` with their own folder structure, `.gdignore` in every `Blends/` folder, `* -text` in `.gitattributes`. | The "before" state is part of the video and of the fork. |
| Private authoring skill | `game-dev` is installed locally, ignored by Git and excluded from exports/source packages. No current or historical copy is published. The public game runs without it. | Marco may monetize the skill; public game source does not authorize distributing his private methodology (2026-10-07). |

## The six points of "how the GDD was created" (reuse them in every README)

1. Start from what exists: the packs are imported first and the model inventories them, so every object named in the GDD is a real file path.
2. Behaviour with numbers, never code.
3. An acceptance test per pillar and per non-trivial mechanic.
4. Scope written down: explicit cut list, numbered build order (each step ends with a run, a screenshot check and a commit), a table of missing assets with the fallback for each.
5. Versioned after each round of play by adding a superseding section, first build is one prompt (`create the game, follow @GDD.md`).
6. Iterate with screenshots, and the agent takes its own through `xo` before reporting back.

Gold standard: `MarcoPaoletta/xogot---sushi-restaurant` (public since 2026-09-17; README, LICENSE, THIRD_PARTY_NOTICES.md, docs/GDD.md), local clone at `D:\_Programming\Game Development\Games - Letta Collaborations\Xogot\xogot---sushi-restaurant\`.

## Naming

Our repo: `xogot---<game-name>`, **public from the first commit** (rule of 2026-09-17, see the addendum above), Joseph invited as reader so he gets the notification. His fork: `Xogot-Projects/Xogot-<Game-Name>`. When a repo built earlier is missing any item of the checklist, add it the day it is asked, in the same turn, and push.


## Xogot projects use `game-dev` LOCALLY, never publish it (Marco, 2026-10-07)

Each local Xogot project uses the WHOLE `game-dev` skill in `skills/game-dev/` (not only the Xogot folders: it holds general Godot rules the agent needs), and the GDD is written with it. The October 5 requirement to use it still applies, but the October 7 privacy rule supersedes publishing or committing it. Xogot's own publicly distributed tooling remains separate; do not remove it when excluding Marco's skill.

On the Mac the canonical checkout lives in `~/Skills/game-dev` (a clone of the private mirror `MarcoPaoletta/game-dev-skill`, ONLY this skill). For a new build: `git -C ~/Skills/game-dev pull`, then `python3 ~/Skills/game-dev/install_to_project.py "<project root>"`. Commit the resulting `.gitignore` and project docs, **never the skill snapshot or its local README**. The installer refuses already tracked copies, which need a separate history cleanup. Lessons go to the Hub, never the mirror or game copy. The Hub post-commit hook refreshes the private mirror.

Do not update existing game copies just because the canonical skill changed. In particular, leave the current twin-stick shooter improving an existing game untouched while Marco has unpublished changes; its audit/cleanup is deferred explicitly (2026-10-07).
