# Changelog

All notable changes to QuestItemButton are documented here.

Format based on [Keep a Changelog](https://keepachangelog.com/); this project
adheres to [Semantic Versioning](https://semver.org/).

## [0.9.0] - 2026-07-12

### Added
- Optional trigger keybind: bind a key (under Display → "Trigger key") to fire
  the quest item, same as clicking the button. Uses an override binding, applied
  out of combat (combat-time changes reapply on `PLAYER_REGEN_ENABLED`). Clear
  the binding to unbind.
- New `Keybind.lua`; its pure `normalize` is unit-tested (`spec/keybind_spec.lua`),
  the secure binding is verified in-game.

## [0.8.0] - 2026-07-12

### Added
- Appear alert: the button briefly glows (and optionally plays a sound) when a
  new quest item becomes usable. Toggles `alertGlow` (default on) and
  `alertSound` (default off) under Display. Re-showing the same item does not
  re-alert; hiding never alerts.
- New WoW-free `Alert.lua` (`Alert.shouldAlert`) with `spec/alert_spec.lua`.

## [0.7.0] - 2026-07-12

### Added
- Auto-learn: when you use a usable quest item, the addon notes the current zone
  and prints a paste-ready `[questID] = { zone = "..." }` line for zones it
  doesn't already ship. Toggle `learn` (default on) under Behavior; `/qib learned`
  dumps everything gathered so far. Suggestions persist in SavedVariables.
- New WoW-free `Learn.lua` (`Learn.note`, dedupes + skips shipped quests) with
  `spec/learn_spec.lua`.

## [0.6.0] - 2026-07-12

### Added
- Auto-hide when the quest is complete: once every objective of a quest is
  finished, its item button is hidden (you no longer need it). Toggle
  `hideComplete` (default on) under Behavior. Quests with no trackable
  objectives are never auto-hidden.
- New WoW-free `Complete.lua` (`Complete.isComplete`) with `spec/complete_spec.lua`.

### Changed
- The distance gate and the new completion gate now compose: a candidate must
  pass every enabled gate to show. No behavior change when only one is on.

## [0.5.0] - 2026-07-12

### Added
- Bundled quest dataset is now toggleable: `bundledData` option (default on)
  under Behavior. Off = only your own learned/manual overrides are used; the
  shipped `Data.overrides`/`byItem` and its `byItem` bag scan are skipped.
- `spec/data_spec.lua`: structural validator for the shipped dataset (key types,
  no unknown override keys, no disabled-yet-zoned contradictions, byItem points
  at non-disabled quests). Guards the table against malformed edits.

### Changed
- `Data.lua` is now `require()`-able (guards `addon`, returns the table) like
  `Match.lua`/`Proximity.lua`, so the dataset is unit-testable outside the client.

## [0.4.2] - 2026-07-12

### Fixed
- Skettis fire quest (11008) is logged under the "Skettis" subzone but the item
  is used while flying all over Terokkar (Skettis / Blackwind Lake / Veil
  Ar'ak). Gated it on the whole real zone ("Terokkar Forest") so it stays
  available as the subzone flips underneath you.

## [0.4.1] - 2026-07-12

### Fixed
- Quests logged under a subzone header (e.g. "Skettis") never showed their item
  because the zone gate only compared against `GetRealZoneText()` ("Terokkar
  Forest"). The subzone is now passed through and the gate passes on either
  match, fixing the whole subzone-header class (Skettis, Ogri'la, Netherwing
  Ledge, ...) with no per-quest data. Additive — cannot hide anything already
  shown.

## [0.4.0] - 2026-07-12

### Added
- Optional proximity gate: show the button only when within X yards of the
  quest objective. Off by default, with a yards slider (default 100, range
  10-300). Distance comes from Questie; the option greys out unless Questie is
  loaded and enabled.

### Changed
- `Match.resolve` gains an injected `gateFn` (pure, WoW-free) and returns the
  pre-gate in-zone count so the live ticker keeps polling as you approach.

## [0.3.1] - 2026-07-12

### Changed
- Options panel shows inline help for each config option: descriptions now
  render as a dimmed subline under each label (previously hover-only tooltips),
  each group has a one-line intro blurb, and the header notes that hovering
  reveals more detail.

## [0.3.0] - 2026-07-12

### Added
- Retail-style minimap button (LibDataBroker-1.1 + LibDBIcon-1.0) that opens
  the options panel. Left-click opens options, right-click hides the button.
  "Show minimap button" toggle in the Display group; position/hide state
  persisted via `QuestItemButtonDB`.

## [0.2.0] - 2026-07-11

### Added
- Right-click pick menu on the button: pin an item so it beats all pickers
  while carried ("Auto" clears the pin).
- Questie-integration toggle and proximity/super-track tiebreak wiring.

### Fixed
- Detect conditional-use quest items the game never flags via
  `GetQuestLogSpecialItemInfo`. Scanner now emits carried mapped items whose
  quest is in the log, zone-gated off the quest header. Button icon falls back
  to `GetItemIcon` when no special-item texture exists. Maps Apex's Crystal
  Focus (28786 → quest 10256, Netherstorm).
- Right-click menu no longer double-fires (it opened on press then toggled shut
  on release); the `PostClick` handler is now gated to the up edge.

## [0.1.0] - 2026-07-11

### Added
- Initial release: Retail-style extra action button that appears when the
  player carries a usable quest item in bags and is in the zone where it is
  meant to be used.
