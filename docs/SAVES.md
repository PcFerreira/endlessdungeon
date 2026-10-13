# Saves and menus

The main menu offers Continue, New Game, Load Game, Options, Credits, and Quit. Continue resumes the current in-memory journey or loads the newest valid save after a launch. New Game opens class selection. Beginning a new journey replaces the autosave; manual slots stay available.

Esc pauses after clearing a selected target. The pause menu offers resume, manual save, load, grimoire, options, return to the sanctuary, main menu, and save-and-quit. Inside a dungeon it also offers return to the surface. Return to sanctuary preserves progression and provides a recovery route if the character gets trapped.

## Slots and autosaving

Three manual slots are available in the Save Game menu. The Load Game menu also includes the autosave. F5 writes manual slot 1. F9 loads the newest valid save. Slot cards show the class, location, and save time in UTC. Empty and unreadable slots cannot be loaded.

Autosaving happens every 30 seconds of gameplay, when beginning a journey, resting, entering or leaving a dungeon, descending, claiming a chest, learning a skill, assigning an ability, returning to sanctuary, and respawning. Main Menu, Save and Quit, and closing the game window also autosave. If saving fails during an exit, the game stays open and offers a return to play or an explicit exit without saving.

Opening the Sanctum Sigil, returning from the pocket home, and resting at its hearth also autosave. You can save and quit from home, then load into the home with your return destination intact. See [SANCTUM.md](SANCTUM.md).

## Saved state

Saves include the world seed; character class, skill ranks, unspent points, and action bar; vitality, class resource, cooldowns, guard, and invulnerability; position, jump height and velocity, facing, and movement heading; camera angle and zoom; sanctuary and route marker; current dungeon and floor; defeated and surviving enemies; live enemy health and attack timers; chest claims, visited cities, and discovered dungeon cells; active projectiles and pickups; and the random-number generator state.

Terrain and dungeon geometry regenerate from the seed. Live actors and progression are then restored. If the saved position overlaps an obstacle, loading chooses a nearby open position. Transient cosmetic particles and camera shake are not stored. Audio and fullscreen preferences are separate from journey slots.

Home saves contain the current sanctum state and a suspended outside journey. The character's build, health/resource, cooldowns, and elapsed play time carry back when leaving home. Existing version-1 saves without the optional home field remain compatible. A return destination cannot itself be another home.

## Storage and recovery

Files live in Godot's application data directory, under `user://saves/slot-0.json` through `slot-3.json`. Slot 0 is the autosave. `user://settings.cfg` stores audio and fullscreen preferences. `user://records.cfg` keeps the deepest-floor record separately.

Each save has a format version, generator version, and checksum. The writer creates and validates a temporary file before replacing a slot. It retains the preceding valid file as a `.bak` backup. If the primary file is damaged, loading can recover the backup and reports this in the menu. Unsupported or invalid files do not replace the current journey.

`scripts/save_store.gd` handles validation and disk writes. `scripts/journey.gd` captures and restores the game state. A future terrain generator change must update `World.GENERATOR_VERSION` and provide a migration if existing saves are to remain compatible.

## Checks

`tests/test_save_game.gd` writes real files in a temporary test directory, creates a fresh game scene, and reloads the journey. It covers dungeon and surface locations, build and slot assignments, reward claims, live combat state, a jump, camera settings, random state, damaged primary recovery, invalid data, safe relocation, and autosaving on return to menu. `tests/test_save_exit.gd` checks that the window-close signal commits the autosave and settings before the engine exits. Test directories are removed after successful checks.
