# QuestItemButton

**WoW Classic Anniversary (Progression / TBC 2.5.6)** addon. Shows a Retail-style extra action button when you carry a *usable quest item* in your bags **and** you're in the zone where it's meant to be used.

*Example:* quest "Conjurer Luminrath" in your log + "Luminrath's Mantle" in your bags + you're in Netherstorm → the Mantle appears as a clickable extra button.

## Features

- Auto-detects usable quest items in your bags, zone-gated so the button only shows where the item works.
- Catches conditional-use items the game never flags (e.g. Apex's Crystal Focus in Netherstorm).
- Auto-hides once the quest's objectives are all complete — the item disappears when you no longer need it.
- Appear alert: the button briefly glows (optional sound) when a new quest item becomes usable.
- Bindable trigger key to fire the item, same as clicking the button.
- Optional map waypoint to the objective (TomTom if installed, else the native waypoint; needs Questie for coordinates).
- Right-click pick menu: pin an item so it beats all pickers while carried ("Auto" clears the pin).
- Optional proximity gate — show the button only within X yards of the objective (needs Questie).
- Per-character profiles — switch, copy, delete, and reset in the options panel.
- Auto-learn: records where you actually use quest items and suggests zone overrides (`/qib learned`); bundled dataset can be toggled off.
- Retail-style minimap button + full options panel with inline help.
- Questie integration for super-track / nearest-item tiebreaks.

## Problems? Found a bug?

**Please open an issue on GitHub:** https://github.com/fabio-mancin/quest-item-button/issues

Include your client version, the quest, and the item — it helps a lot.

## Changelog

### 0.12.0
- **Fixed:** Right-click pick menu now opens (it relied on `EasyMenu`, absent in this client, and failed silently).
- **Added:** The menu now also lists usable quest items the game never flags — any bag item tied to a quest in your log — so they're selectable and pinnable without a manual data entry.

### 0.11.0
- **Added:** Per-character configuration profiles — switch, create, copy, delete, and reset in the new Profiles tab. A `/reload` fully applies a switch.

### 0.10.0
- **Added:** Optional waypoint to the objective while the button shows (TomTom if installed, else the native waypoint; needs Questie for coordinates).

### 0.9.0
- **Added:** Optional trigger keybind to fire the quest item.

### 0.8.0
- **Added:** Appear alert — the button briefly glows (optional sound) when a new quest item becomes usable.

### 0.7.0
- **Added:** Auto-learn — records where you use quest items and prints paste-ready zone overrides (`/qib learned`).

### 0.6.0
- **Added:** Auto-hide once all of a quest's objectives are complete.

### 0.5.0
- **Added:** Toggle for the bundled quest dataset (off = only your own learned/manual overrides).

### 0.4.2
- **Fixed:** Skettis fire quest (11008) now gated on the whole Terokkar Forest zone so it stays available as the subzone flips while you fly.

### 0.4.1
- **Fixed:** Quests logged under a subzone header (Skettis, Ogri'la, Netherwing Ledge, ...) now show their item — the zone gate matches on subzone or real zone.

### 0.4.0
- **Added:** Optional proximity gate — show the button only within X yards of the quest objective (off by default, 10-300 yard slider, needs Questie).

### 0.3.1
- **Changed:** Options panel shows inline help — each toggle's description renders under its label instead of hover-only tooltips.

### 0.3.0
- **Added:** Retail-style minimap button (opens options on left-click, hides on right-click).

### 0.2.0
- **Added:** Right-click pick menu to pin an item; Questie-integration toggle.
- **Fixed:** Conditional-use quest items the game never flags now detected; right-click menu no longer double-fires.

### 0.1.0
- **Added:** Initial release — Retail-style extra action button for usable quest items, zone-gated.