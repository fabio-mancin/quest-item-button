# Contributing

## Layout

Lua modules load directly — no build step. Each file states its contents
(`Scanner.lua`, `Match.lua`, …); keep them small and single-purpose. Match
logic stays free of WoW globals so it's testable outside the client.

## Tests

Matching is pure data logic. Run the spec with [busted](https://lunarmodules.github.io/busted/):

```bash
busted spec/
```

## Local dev setup (optional)

Only needed if you want `make install` to copy the addon into your WoW
install. Everyone's path differs, so it's kept out of git.

```bash
make dev       # prompts for your WoW AddOns dir, saves it to .env (gitignored)
make install   # rsync the addon there (--delete, dev files excluded)
make clean      # remove the installed copy + build artifacts
```

`.env` holds only your local `DEST` path and is never committed. If you edit
Lua while the game runs, `/reload` in-game to pick up changes. Enable Lua
errors with `/console scriptErrors 1` while developing.

You can also skip the Makefile entirely and symlink or copy the folder
yourself — whatever fits your workflow.

## Packaging

```bash
make dist       # builds QuestItemButton-<version>.zip for CurseForge upload
```

No `.env` required — `dist` only reads the repo.

## Releasing (CI)

Pushing a `v*` tag triggers [`.github/workflows/release.yml`](.github/workflows/release.yml),
which runs [BigWigsMods/packager](https://github.com/BigWigsMods/packager) to
package the addon (per [`.pkgmeta`](.pkgmeta)) and upload it to CurseForge.

```bash
git tag v0.1.0
git push --tags
```

One-time setup:
- Create the CurseForge project, then put its ID in `## X-Curse-Project-ID` in
  [QuestItemButton.toc](QuestItemButton.toc) (placeholder `0000000` right now).
- Add repo secret `CF_API_KEY` (CurseForge → API token).

The packager sets the release version from the tag, so no manual `## Version`
bump is needed. `make dist` is still fine for local test builds.
