# QuestItemButton

**WoW Classic Anniversary (Progression / TBC 2.5.6)** addon. Shows a Retail-style extra action button when you carry a *usable quest item* in your bags **and** you're in the zone where it's meant to be used.

*Example:* quest "Conjurer Luminrath" in your log + "Luminrath's Mantle" in your bags + you're in Netherstorm → the Mantle appears as a clickable extra button.

## Features

- Auto-detects usable quest items in your bags, zone-gated so the button only shows where the item works.
- Catches conditional-use items the game never flags (e.g. Apex's Crystal Focus in Netherstorm).
- Right-click pick menu: pin an item so it beats all pickers while carried ("Auto" clears the pin).
- Optional proximity gate — show the button only within X yards of the objective (needs Questie).
- Retail-style minimap button + full options panel with inline help.
- Questie integration for super-track / nearest-item tiebreaks.

## Problems? Found a bug?

**Please open an issue on GitHub:** https://github.com/fabio-mancin/quest-item-button/issues

Include your client version, the quest, and the item — it helps a lot.

## Changelog

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