# The Inner Sanctum

Every new character owns a bound Sanctum Sigil. It occupies an item button beside the action bar and uses H. The sigil opens a pocket dimension containing a floating stone island, a study, a hearth, and a return portal. The home has no hostile spawns or damage. Its music uses Spells a-Brewin, with a star field and magic motes around the island.

## Travel and rest

Entry requires an active journey and stable footing. An enemy within 8.5 cells with clear line of sight blocks recall. A live hostile projectile also blocks it. This keeps the home from serving as an immediate combat escape. Opening the sigil preserves the outside area and moves the player to the home entrance.

Press E within two cells of the hearth to restore vitality and the class resource. Press E near the return portal, or H anywhere in the home, to resume the journey at the location you left. The pause menu has a return button as well. The world seed, dungeon floor, live enemies, pickups, projectiles, discovery, route marker, camera view, and random state resume from the outside snapshot. A short protection period covers the return.

Learning skills and changing the action bar at home carry back into the journey. Health, resource, cooldowns, and elapsed play time also carry back. The city sanctuary remains the respawn destination. Return to sanctuary / Unstuck in the pause menu leaves the home and discards its current return thread.

## Saving

Save slots and autosaves support the home as a third location layer. The save includes both the current home state and the suspended outside journey. Loading into a fresh game scene restores the home and its portal destination. Entry, return, and hearth rest autosave, alongside the normal periodic and exit saves.

The optional `home` field contains the sigil item ID and `return_journey`. The return journey must be an overworld or dungeon location in the same seeded world. Nested home destinations are rejected. Existing version-1 saves without the field still load and receive the starting sigil. The terrain generator version remains unchanged.

## Furnishings later

Two outlined spaces reserve room for future furnishings. `scripts/sanctum.gd` owns the floor plan, fixed collision, hearth, portal, and `furnishing_plots`. `scripts/sanctum_view.gd` renders them separately. Collecting and placing items is deferred. The next step is a furnishing inventory and saved placement records, followed by grid placement, rotation, obstacle validation, and removal.

The home retains a fixed layout in this MVP. A new journey starts with the same starter home and a fresh character. Homes are attached to journey saves rather than shared across separate characters.

## Checks

`tests/test_sanctum.gd` exercises real game scenes and disk saves in a temporary directory. It checks footing/enemy restrictions, damage immunity, hearth rest, exact surface and dungeon return, retained pickups and random state, learned skills, home loading across fresh scenes, legacy saves, invalid recursive destinations, and the sanctuary recovery route. Native previews cover the new HUD, home entrance, hearth, rotation, pause menu, and return.
