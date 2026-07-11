# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**QuestItemButton** — WoW Classic Anniversary (Progression) addon. Shows a Retail-style extra action button when the player carries a *usable quest item* in bags AND is in the zone where it's meant to be used.

Example: quest "Conjurer Luminrath" in log + "Luminrath's Mantle" in bags + player in Netherstorm → Mantle appears as a clickable extra button.

Target client: **2.5.6** (TBC Classic), Interface `20506`. See [QuestItemButton.toc](QuestItemButton.toc).

## Commands

```bash
make dev       # prompt for WoW AddOns dir, save to .env (gitignored, per-machine)
make install   # rsync addon to that dir (--delete, excludes dev files); needs .env
make clean     # remove installed copy, build/, and dist zips
make dist      # build CurseForge upload zip (QuestItemButton-<version>.zip); no .env needed
```

The install path is **not** hardcoded — `make dev` writes it to `.env`, which is gitignored so no local filesystem paths get committed. See [CONTRIBUTING.md](CONTRIBUTING.md).

No build step — Lua is loaded directly by the client. Reload in-game with `/reload` after `make install`. Enable Lua errors in-game (`/console scriptErrors 1`) while developing.

Game API source for reference: a local clone of the [wow-ui-source](https://github.com/Gethe/wow-ui-source) repo.

## Conventions

- **Small, self-explaining files** — filename states the contents. No god-files.
- **DRY** — no copy-paste; factor shared logic.
- **Libraries encouraged** — prefer established Ace3/LibStub-style libs over reinventing (config UI, event handling, etc.). Embed under a libs/ dir and list in `.toc`.
- **Tests** — quest→item→zone matching logic is pure data logic; keep it isolated from WoW globals so it's unit-testable outside the client (e.g. busted, with WoW API stubs).
- **Highly configurable** — user-facing options for which items/zones trigger, button position, etc. Persist via `SavedVariables: QuestItemButtonDB` (already declared in `.toc`).

## Architecture (intended)

Core data flow: **bag scan + quest log** → **match against item↔zone table** → **show/hide secure action button** bound to the item.

- Combat lock: the button must be a *secure* frame (`SecureActionButtonTemplate`, `type="item"`). Attributes can't change mid-combat — resolve visibility/binding out of combat, defer with `PLAYER_REGEN_ENABLED` if needed.
- Keep the trigger data (which item goes with which quest/zone) as **plain data**, separate from the display/secure-button code, so the matching is testable and the data set is easy to extend.
- Relevant events: `BAG_UPDATE_DELAYED`, `QUEST_LOG_UPDATE`, `ZONE_CHANGED*` / `PLAYER_ENTERING_WORLD` drive re-evaluation.

Load entry: [QuestItemButton.lua](QuestItemButton.lua) — registers the re-eval events, coalesces them into one delayed tick, and drives scan → match → button. `/qib` opens options.
