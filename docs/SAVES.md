# Saves and menus

The main menu offers Continue, New Game, Load Game, Options, Credits, and Quit. Continue resumes the current in-memory journey or loads the newest valid save after a launch. New Game opens class selection. Beginning a new journey replaces the autosave; manual slots stay available.

Esc pauses after clearing a selected target. The pause menu offers resume, manual save, load, grimoire, options, return to the sanctuary, main menu, and save-and-quit. Inside a dungeon it also offers return to the surface. Return to sanctuary preserves progression and provides a recovery route if the character gets trapped.

## Slots and autosaving

Three manual slots are available in the Save Game menu. The Load Game menu also includes the autosave. F5 writes manual slot 1. F9 loads the newest valid save. Slot cards show the class, location, and save time in UTC. Empty and unreadable slots cannot be loaded.

Autosaving happens every 30 seconds of gameplay, when beginning a journey, resting, entering or leaving a dungeon, descending, claiming a chest, learning a skill, assigning an ability, returning to sanctuary, and respawning. Main Menu, Save and Quit, and closing the game window also autosave. If saving fails during an exit, the game stays open and offers a return to play or an explicit exit without saving.

Opening the Sanctum Sigil, returning from the pocket home, and resting at its hearth also autosave. You can save and quit from home, then load into the home with your return destination intact. See [SANCTUM.md](SANCTUM.md).

## Saved state

Saves include the world seed; character class, skill ranks, unspent points, and action bar; vitality, class resource, cooldowns, guard, and invulnerability; position, jump height and velocity, facing, and movement heading; camera angle and zoom; sanctuary and route marker; current dungeon and floor; defeated and surviving enemies; live enemy health and attack timers; chest claims, visited cities, and discovered dungeon cells; active projectiles and pickups; and the random-number generator state.

Terrain and dungeon geometry regenerate from the seed. Live actors and progression are then restored. If the saved position overlaps an obstacle, loading chooses a nearby open position. Transient cosmetic particles and camera shake are not stored. Audio, fullscreen and window-resolution preferences are separate from journey slots.

Home saves contain the current sanctum state and a suspended outside journey. The character's build, appearance, inventory, health/resource, cooldowns, elapsed play time, lore and placed furnishings carry back when leaving home. Kills, deepest floor, floor progress, chest claims, visited cities and discovered dungeon cells also carry back after a detour through Lanternwake's Worldgate. The original return thread still restores its location, random state and loose pickups. A return destination cannot itself be another home. Optional `progress.furnishings` holds the home arrangement in every location layer; missing data defaults to an empty home, and invalid item/support/collision records are rejected before replacing live state. Furniture previews are transient, while completed placement, movement and pickup request autosaves. See [SANCTUM.md](SANCTUM.md) for controls and the placement contract.

`progress.lore` stores discovered book IDs, met speaker IDs, heard dialogue lines, and the last actual ruin visited from each town. Dialogue and reader panels pause simulation. Their display state is transient; loading resumes gameplay. A new character starts with an empty journal and fresh conversation history.

Optional `progress.world_items` stores removed source objects, placed items, city claims/refusals, dungeon bases and rest/respawn checkpoints. Optional inventory `stolen` records preserve each city's source ownership through placement and restitution. Loading cross-checks backpack and placed custody against the source ledger before replacing live state. Older journeys default to empty portable/base state and clean inventory. Completed pickup, placement, restitution and base/rest changes request autosaves; placement previews stay transient. These additive fields preserve the generator edition. See [WORLD_ITEMS_BASES.md](WORLD_ITEMS_BASES.md).

## Storage and recovery

Files live in Godot's application data directory, under `user://saves/slot-0.json` through `slot-3.json`. Slot 0 is the autosave. `user://settings.cfg` stores audio, fullscreen and window-resolution preferences. `user://records.cfg` keeps the deepest-floor record separately. See [DISPLAY_VISIBILITY.md](DISPLAY_VISIBILITY.md) for resolution choices and native checks.

Each save has a format version, generator version, and checksum. The writer creates and validates a temporary file before replacing a slot. It retains the preceding valid file as a `.bak` backup. If the primary file is damaged, loading can recover the backup and reports this in the menu. Unsupported or invalid files do not replace the current journey.

`scripts/save_store.gd` handles validation and disk writes. `scripts/journey.gd` captures and restores the game state. The save envelope remains format 2. New offline characters use generator edition 7; editions 4, 5 and 6 remain supported, and restoration requests the edition stored in the journey. Home and indoor return journeys must use the same seed and edition as their enclosing save. Edition initialization records the existing `generation-4.reset` marker but preserves all slot, backup and temporary files, including damaged files that may have recoverable backups. Optional component fields do not trigger a reset. Settings and the deepest-floor record are preserved.

## Checks

`tests/test_save_game.gd` writes real files in a temporary test directory, creates a fresh game scene, and reloads the journey. It covers dungeon and surface locations, build and slot assignments, reward claims, live combat state, a jump, camera settings, random state, damaged primary recovery, invalid data, safe relocation, and autosaving on return to menu. `tests/test_save_exit.gd` checks that the window-close signal commits the autosave and settings before the engine exits. Test directories are removed after successful checks.

`tests/test_worldgate_progress.gd` follows the actual Sanctum study, Lanternwake Worldgate, generated dungeon combat, collected rewards and historical original return. It checks retained progression alongside exact original location, random state and loose pickups, with private disk saves and cleanup.
