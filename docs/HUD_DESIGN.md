# Play interface

Ember refactored the play interface on 2026-10-13. The bottom dock keeps the ten-slot MMORPG action bar, places vitality and class resources beside it, and provides a separate row for character, backpack, grimoire, journal, atlas and menu actions.

## Research and decisions

| Source | Relevant guidance | Application here |
| --- | --- | --- |
| [Guild Wars 2 new-player guide](https://www.guildwars2.com/en/new-player-guide/?modal=weapon-skills) | Skills occupy a bottom bar. Key cues, recharge countdowns and hover descriptions explain their use. Selected enemies show information near the top of the screen. | Keep ten stable slots, small keys on equipped abilities, a recharge shade and countdown, detailed tooltips, and a target frame that appears after selection. |
| [Nielsen Norman Group: progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/?lm=listbox-dropdown&pt=article) | Move advanced or infrequent information to a secondary view so the main interface is easier to understand. | Remove the permanent shortcut legend and repeated skill names, costs and ready-state labels. Keep details in tooltips, the grimoire and Options. |
| [Microsoft XAG 102: contrast](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/102) | HUD text, meters and map information need contrast against their backgrounds. | Use dark panel surfaces with light text, quiet warm borders and explicit health/resource numbers. Cooldowns include numeric countdowns; blocked/resource warnings include a symbol and a tooltip. |
| [Microsoft XAG 101: text display](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101) | Readability depends on text size, spacing and the player's display. Important text should remain readable in HUDs, menus and notifications. | Keep action details in larger tooltips and menu screens. Wrap long location names and prompts, and truncate long player names inside the fixed dock. |

These are design references. The current compact desktop layout has not undergone an accessibility conformance audit and does not implement adjustable text or HUD scaling.

## Layout and feedback

The upper-left panel shows the current place and a short objective or route. The upper-right chart keeps its legend in a tooltip. Clicking the chart opens the atlas on the surface; the atlas action is disabled underground and at home, where the existing local chart remains visible.

The bottom dock contains character identity, vitality, the class resource, ten fixed ability slots and the Sanctum Sigil. Empty slots retain their positions but have no shortcut or placeholder text. Equipped slots show a small key. During recharge, a dark shade drains from the icon, a countdown appears, and a thin meter fills. A warning mark identifies insufficient resources or a selected target outside an ability's usable range/sight; the tooltip gives the reason. Buttons still call the existing gameplay methods, which decide whether the action can occur.

The utility row uses names without shortcut suffixes. Hovering reveals the key and purpose. The same caption treatment applies to shared menu buttons. Options contains the full controls reference, including the journal key.

A contextual prompt appears above the dock when there is a nearby interaction. It contains one relevant key and action. Notifications use a separate panel above that prompt, so an interaction cannot overwrite loot or journey feedback. Both panels disappear when unused. The HUD hides while a modal screen is open.

## Implementation and review

`scripts/interface.gd` owns the layout and presentation. `scripts/hud_skin.gd` provides shared surfaces, button states, meters, dropdowns, tabs, name fields and tooltips. Existing spell/sigil artwork and the Cinzel typeface remain in use. Character, inventory, lore, saves and gameplay retain their existing APIs.

Run `./godot.sh --script tools/capture_hud.gd` for native captures and interaction checks. The helper uses isolated saves under `artifacts/hud-preview-saves`; it does not use the player's save directory. It exercises pointer-driven utilities, atlas, sigil and an ability; the atlas keyboard shortcut after pointer interaction; target selection and recharge; resource warnings; simultaneous prompts and notifications; class changes; a long name; and windows at 1280x800, 1024x768 and 1600x900. The existing stretch mode retains a 1440x900 logical canvas and letterboxes other aspect ratios. Captured game canvases are 1280x800, 1024x640 and 1440x900, excluding the letterbox bars. Screens are written to `artifacts/hud-*.png`. Headless project checks remain separate from visual review.

The native helper passed on Godot 4.7.2 with Apple M2 graphics. Exploration, combat, backpack, grimoire, pause, options, simultaneous prompt/notification, resized canvas and ability-tooltip captures were visually reviewed. The combined `check.sh` passed four Ruby tests with 36 assertions, catalog freshness, editor import and all 16 Godot check groups. Both final logs contained no engine errors or warnings: `/tmp/endless-ember-capture.log` and `/tmp/endless-ember-check.log`. Other display hardware and a full accessibility review remain untested.
