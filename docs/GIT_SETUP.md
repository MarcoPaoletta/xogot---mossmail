# Git setup for Mossmail

The iPad build environment cannot run `git`, so the repository is created with a Git client.
Everything Git needs is already in the project: `.gitignore`, `.gitattributes`, `LICENSE`, `THIRD_PARTY_NOTICES.md` and `README.md`.

**Ignored on purpose:** `.godot/`, `build/` and the local `versions/` snapshots (the `v2` and `v3` tags and branches hold every version). The `game-dev/` authoring skill and the early pitch prototypes ARE committed: this repository ships everything.

## Repository
- **Name:** `xogot---mossmail` (skill naming).
- **Visibility:** **public** from the first commit.
- **Branch:** `main`.

## Commit plan (follows the game-dev repo rules)

1. **Setup commit.** Stage only `.gitignore`, `.gitattributes`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `README.md`, `icon.svg`, `icon.svg.import` and `assets/`.
   - Message: `Initial state: packs imported`
   - Annotated tag: `setup-finished`
2. **v2 commit.** Stage everything else.
   - Message: `Mossmail V2: hang glider flight, rolling hills, mountain ring`
   - Annotated tag `v2` (message `Mossmail V2`) and branch `v2`.
3. **Push** `main`, then tag and branch `v2` with full refspecs (a tag and a branch share the name `v2`), then `setup-finished`.

## On a Mac or any machine with git (copy the project folder there first)

```
git init -b main
git add .gitignore .gitattributes LICENSE THIRD_PARTY_NOTICES.md README.md icon.svg icon.svg.import assets
git commit -m "Initial state: packs imported"
git tag -a setup-finished -m "Mossmail setup finished"
git add -A
git commit -m "Mossmail V2: hang glider flight, rolling hills, mountain ring"
git tag -a v2 -m "Mossmail V2"
git branch v2
gh repo create xogot---mossmail --public --source . --remote origin
git push -u origin main
git push origin refs/heads/v2:refs/heads/v2
git push origin refs/tags/v2
git push origin refs/tags/setup-finished
```

## On the iPad with Working Copy

1. Working Copy: **+** → *Link External Directory* (older versions: *Setup Synced Directory*). Pick *On My iPad → Xogot → AI iPad*, then choose to initialise a new repository there.
2. Open the **Changes** tab and select only the files listed in step 1 above. Commit with that message.
3. Commit menu → *Tag*: name `setup-finished`, add a message, so the tag is annotated.
4. Select all remaining changes and commit with the v2 message. Tag it `v2` (message `Mossmail V2`), then *Branch* → new branch `v2` at that commit and stay on `main`.
5. *Remotes* → add GitHub (sign in) → create the **public** repository `xogot---mossmail`. Push `main`, then push the `v2` branch and all tags.

## Every later version (v3, v4, ...)

Save the version the moment it is reached, before the next version's changes start:
`git add -A && git commit -m "Mossmail V3: <what changes>"`, `git tag -a v3 -m "Mossmail V3"`, `git branch v3`, then push `main`, `refs/heads/v3:refs/heads/v3` and `refs/tags/v3`.

## v3 (ready now)

The working tree is v3.

**If v2 was already committed and pushed:**
```
git add -A
git commit -m "Mossmail V3: collect glowing flowers, speed clovers, altitude lever, glider colours, new menus"
git tag -a v3 -m "Mossmail V3"
git branch v3
git push origin main
git push origin refs/heads/v3:refs/heads/v3
git push origin refs/tags/v3
```

**If the repository was not created yet:** v2 can no longer be committed from this tree. Its files are in `versions/v2/`, which is ignored.
1. Copy `versions/v2/` over a fresh clone and commit it as v2, with tag and branch.
2. Copy the current project over it and commit it as v3.
