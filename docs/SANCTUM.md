# The Inner Sanctum

Every new character owns a bound Sanctum Sigil. It occupies an item button beside the action bar and uses H. The sigil opens a pocket dimension containing a floating stone island, a study, a hearth, and a return portal. The home has no hostile spawns or damage. Its music uses Spells a-Brewin, with a star field and magic motes around the island.

## Travel and rest

Entry requires an active journey and stable footing. An enemy within 8.5 cells with clear line of sight blocks recall. A live hostile projectile also blocks it. This keeps the home from serving as an immediate combat escape. Opening the sigil preserves the outside area and moves the player to the home entrance.

Press E within two cells of the hearth to restore vitality and the class resource. Press E near the return portal, or H anywhere in the home, to resume the journey at the location you left. The pause menu has a return button as well. The world seed, dungeon floor, live enemies, pickups, projectiles, discovery, route marker, camera view, and random state resume from the outside snapshot. A short protection period covers the return.

Learning skills, changing the action bar and arranging furnishings at home carry back into the journey. Health, resource, cooldowns, and elapsed play time also carry back. The city sanctuary remains the respawn destination. Return to sanctuary / Unstuck in the pause menu leaves the home and discards its current return thread while retaining the furnishings.

## Saving

Save slots and autosaves support the home as a third location layer. The save includes both the current home state and the suspended outside journey. Loading into a fresh game scene restores the home and its portal destination. Entry, return, and hearth rest autosave, alongside the normal periodic and exit saves.

The `home` field contains the sigil item ID and `return_journey`. The return journey can be an overworld, dungeon or interior location in the same seeded world. Nested home destinations are rejected. Furniture is stored separately in optional `progress.furnishings`, so it also survives an interior's exact outside return. Existing current-generation saves without that furniture field load an empty home. This feature changes neither the format-2 save envelope nor the generator edition and requests no world reset.

## Place and arrange furnishings

Press B in the Sanctum to open the furnishing editor. You can also select an owned furnishing in the backpack and choose Place in Sanctum. Furnish any clear floor across the island; there are no placement zones. The side walls remain available for shelves and other furnishings that need wall support. The editor keeps the world visible and pauses movement, combat and living activity.

| Control | Action |
| --- | --- |
| Select a backpack furnishing | Start a placement preview |
| Move the pointer | Position the preview on a quarter-cell grid |
| Left-click or Enter | Confirm a valid placement or move |
| R | Rotate the furnishing by 90 degrees |
| Arrow keys | Move the preview relative to the current view |
| Select a placed item in the list, or click it in the world | Preview moving it |
| Delete or Pick up to backpack | Return the selected placed item to the backpack |
| Esc or right-click | Cancel the current selection |
| B or Close | Leave the editor |
| View buttons | Orbit the camera while arranging furniture |

The preview shows a green footprint for a valid placement and red for a rejected one. Shelves, wall lights, beds and storage snap to a compatible alcove wall and face inward. Small display objects need a supported flat table, cabinet or shelf board. Decorated or unclassified tops are not assumed to be usable surfaces. Pick up displayed objects before moving or removing their support.

Placement keeps the entire model footprint on island floor, rejects solid overlap and protects walking access through the home, including the hearth, study and return portal. It also respects separately placed portable objects and retains their collision when refreshing the arrangement. Rugs can lie beneath floor furniture but must leave the portal and other access points clear. Wall fixtures stay below their supporting wall height. Outside-facing walls fade with the camera while retaining their supporting geometry. The editor supports up to 48 placed objects.

A successful placement consumes one owned inventory copy. Invalid previews and cancellations consume nothing; moving and rotation consume no additional copy. Picking up returns exactly one copy, and a full backpack leaves the placed furnishing intact. Pending previews are not saved. Completed place, move and pickup operations request an autosave.

The chair, rune lantern and woven rug rewards have immediate placement recipes. Imported furnishings use the category rules in `config/sanctum_furnishings.json`; standing frames and table utensils have distinct support rules from wall frames and tables. Unclassified finds remain in the backpack until a supported recipe is authored. Stolen-only stacks use the separate Place in world flow so their provenance remains intact.

The home retains a fixed layout in this MVP. A new journey starts with the same starter home and a fresh character. Homes are attached to journey saves rather than shared across separate characters.

## Saved placement contract

`scripts/furnishings.gd` owns inventory transactions, geometry/support checks and saved records. The optional `progress.furnishings` object contains `version`, `next_id` and `placed`. Each record has stable `uid`, inventory `item`, X/Z `point`, quarter-turn `rotation` and a supporting `parent` UID for display objects. Restoration normalizes JSON numbers and rejects invalid items, rotations, overlaps, support references, blocked paths and capacity violations before replacing the live arrangement.

`scripts/furnishing_catalog.gd` validates and resolves declarative recipes. `scripts/furnishing_editor.gd` owns the modal preview and controls. `scripts/sanctum.gd` provides fixed geometry and collision; `scripts/sanctum_view.gd` renders placed meshes and lights separately. Render caches belong to the view/editor and are released with those nodes. Preserve existing profile dimensions/support semantics when extending recipes, because saved layouts are validated against them.

## Checks

`tests/test_sanctum.gd` exercises real game scenes and disk saves in a temporary directory. It checks footing/enemy restrictions, damage immunity, hearth rest, exact surface and dungeon return, retained pickups and random state, learned skills, home loading across fresh scenes, legacy saves, invalid recursive destinations, and the sanctuary recovery route. Native previews cover the new HUD, home entrance, hearth, rotation, pause menu, and return.

`tests/test_furnishings.gd` covers placement across the island, edge and access protection, real furniture categories/models, wall and tabletop support, inventory ownership/refunds, full backpacks, floor collision, rugs, movement/rotation and invalid/legacy JSON. `tests/test_furnished_home.gd` uses actual hotkeys and fresh game scenes to cover placement outside the former zones, cancellation, home/away disk saves, exact return, interior/Sanctum carry, corrupted saves, independent new homes and unchanged combat RNG. Both are registered in `check.sh`.

Run `./godot.sh --script tools/capture_furnishings.gd` for the native editor/arrangement gallery. It checks actual ground clicks, invalid portal placement, shelf/tabletop support, move cancellation, full-backpack pickup refusal and saved rendering. Images are `artifacts/furnishings-*.png`. These fixtures use isolated saves/settings and do not overwrite the player's journey.
