# World objects and dungeon bases

Take movable world objects into the backpack, then place them elsewhere. Ordinary items, equipment, materials and furnishings can be placed. City property retains its owner when carried or placed. Required walls, terrain, entrances, gates, quest books and their fixed supports remain in the world.

## Controls

- **T** takes the closest movable object within reach. Objects on a table or shelf must be taken before their support.
- **V** or the HUD's **Objects** button opens nearby objects, backpack placement and dungeon-base controls. **B** opens the same panel outside the Sanctum and the existing furniture editor inside it.
- Choose **Place in world** in the backpack or select an item in the objects panel. Hover to position the preview or move it with the arrow keys. **R** rotates it; **Enter** or a world click places it. **Esc** cancels and closes the panel.
- Invalid placement leaves the backpack unchanged. Solid furniture must fit on level ground and preserve walking routes. Entrances, readables and rest points stay accessible. Display objects need a table or shelf; wall fixtures need an actual wall.
- Place another item over an existing item to stack it. The new item's footprint must fit fully on its support. Stacks hold up to four items, including their bottom support; take the top item first. Rugs and wall fixtures retain their own support rules.

The panel pauses movement, combat and the living-world clock. Placement checks run when the preview target changes and again when confirming. Placed objects and previews rest on the actual terrain height. Each stacked object rests on the top of the object below, and clicking that top preserves the stack's floor location. World items use the existing model catalogue; no separate process or background service runs for this mechanic.

## Claiming a base

Clear the dungeon's floors and claim its final reward chest. Open **V**, choose **Claim cleared dungeon as base**, then choose **Set rest point here** on clear floor away from the stairs and chest. A visible marker identifies the checkpoint. **E** near it restores health and the class resource. Death returns the character to the saved base checkpoint; entering the claimed dungeon also uses that floor and point.

The base panel lets the player revisit cleared floors to decorate them. Furniture and stored items remain where placed through surface trips, Sanctum visits, floor changes and disk saves. Each location scope supports up to 128 placed objects, with a journey-wide limit of 4,096 placement records. The backpack still has its existing capacity. Picking up an object with a full backpack leaves it in place.

## City ownership

Taking a city-owned object marks that copy as stolen. The backpack shows the stolen quantity. Placing it in a dungeon or the Sanctum retains its original city and source identity. Owned identical copies remain separate from the stolen quantity.

Guards from the affected city demand restitution before using force. Returning the property restores the original objects and ends that city's dispute. Refusing makes its watch hostile within its jurisdiction. Guard interactions remain available for restitution after refusal. Other cities retain their own claims. Watch attacks do not grant enemy kills, drops or dungeon-gate credit. See [CITY_LAW.md](CITY_LAW.md) for enforcement details.

Ordinary use, sale and discard cannot consume stolen copies. The general placement transaction explicitly transfers ownership. Restitution can reclaim the stolen copy from the backpack or from another stored location and removes that copy before restoring the original. Take clean or another city's objects off a stolen support before returning it; otherwise restitution leaves all custody unchanged. Same-city stolen layers can be returned together. A missing or inconsistent source record rejects restitution or loading rather than clearing the claim.

## State and validation

`progress.world_items` is optional and stores removed source instances, placed instances, city refusal state, claimed bases and the active checkpoint. Inventory snapshots contain optional source-instance provenance in `stolen`. Older journeys default to empty object/base state and clean inventory. The save validator cross-checks each stolen source against the removed-object ledger and rejects duplicate backpack/placed custody. Base claims must refer to already claimed dungeon chests. The additive mechanic does not change the generator version or reset journeys.

`world_items.gd` controls registration, rendering, placement and base actions. `world_item_state.gd` handles atomic inventory transactions and saved ownership. Renderer callbacks expose stable source IDs and individual nodes. Source removals must also release their authored collision, and restoration must restore it. Required quest anchors are excluded at registration.

## Verification

`tests/test_world_items.gd` checks provenance, refusal persistence, restitution after placement, capacity rollback, base eligibility and malformed records. `tests/test_world_items_game.gd` checks actual interior source props, disk reload, invalid custody rejection, Sanctum carry, all-floor dungeon clearing, placed furniture collision, rest/respawn checkpoints, floor revisits and older optional fields. The city-law groups cover guard demands, refusal damage, jurisdiction separation and remote stored-property restitution.

`tests/test_surface_items.gd` takes goods from a generated market while preserving its stall, takes an independent cart and releases its authored blocked cell, repeats chunk streaming and disk saves, then restores the original city's geometry and collision through restitution. It rejects free healing from stolen consumables and checks placed/preview height on raised terrain. `tools/capture_surface_items.gd` captures the natural market transaction and stolen-backpack state with isolated settings/saves.

`tools/capture_world_items.gd` uses isolated save/settings paths and real generated geometry to capture preview, placed furniture, rest markers, base controls and disk restoration. Native screenshots live under `artifacts/base-*.png`. These checks cover the prototype's transactions and rendering; long-session decoration limits and player preferences still need playtesting.

`tests/test_item_stacks.gd` checks raised-ground rendering, four-layer support, fifth-item rollback, top-first pickup, cyclic/cross-location/floating saved stacks, and atomic restitution with clean or other-city children. `tests/test_item_stacks_game.gd` checks actual raised world terrain, mouse placement, touching model bounds and fresh disk restoration. Run `./godot.sh --script tools/capture_item_stacks.gd` for the same Game checks with native images at `artifacts/stacks-*.png`.
