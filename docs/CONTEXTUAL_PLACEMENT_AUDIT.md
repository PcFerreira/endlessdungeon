# Contextual item and asset placement

The indoor and underground placement corrections keep furniture attached to suitable room features. Furniture variants come from category queries within authored layouts. Wilderness vegetation remains restricted to biome/facet pools; town prop anchors already avoid streets, house footprints and door approaches.

## Corrected findings

| Finding | Current behavior |
| --- | --- |
| Indoor storage at `[2,2]` was detached from the wall. | Floor cabinets/bookcases use explicit wall support and face into the room. |
| The original bookcase query included KayKit wall-mounted shelf boards, stretched into tall floor furniture. | Cabinets/bookcases and elevated wall shelves use separate queries and recipes. Shelf elevation is 1.0, height is .55, and the supporting wall is 1.6 high. |
| Width-only model normalization could render tables outside their collision depth. | `Scenery.fitted_model` fits both horizontal axes to the declared footprint. Collision and rendered bounds agree. |
| Chairs used the same orientation regardless of their table. | `face` identifies the table position; the generated chair yaw points toward it. |
| Beds, workshop benches and storage had arbitrary wall gaps. | Their recipes specify a wall and inward facing. Long counters query long tables. |
| Indoor books used a fixed display height; lanterns floated without support. | Books use the supporting furniture height; the small freestanding lanterns stand on the floor. |
| Dungeon bookcases and torches assumed room corners were walls. | The planner selects exposed wall segments after corridors exist, checks the whole footprint and reserves clear approaches. |
| Dungeon collision used a fixed .7-square box for differently sized props. | Each decoration carries its own footprint; the view uses the same footprint and orientation. |

## Authoring rules

Interior recipes are in `config/world_content.json`. A furniture record has `fallback`, `point`, `footprint`, `height` and an optional registry `query`. Use a category-specific query; importing an asset does not establish its purpose or its authored front.

- `wall` is `north`, `south`, `east` or `west`. The footprint must sit .07 through .16 units from that wall plane and face inward. Bookcases and mounted shelves require this field.
- `facing` is a unit direction in gameplay X/Z coordinates; the default is `[0,1]`. `face` instead names a table/workbench position and determines the facing direction.
- `elevation` sets the model base above the floor. Positive elevation requires wall support. A `wall_shelf` must be elevated at least .5 units, and wall furniture must fit below the 1.6-unit wall height.
- Keep at least .05 units between furniture footprints. Preserve walking access to the start, exit, readable approach and optional rest position.
- A readable needs a book stand, table or workbench at its book point. Its model height follows that support.

`WorldContent.valid` rejects invalid geometry, support, overlap and access before accepting a replacement catalogue. `reload` retains the previous valid data when validation fails. Mounted shelves conservatively reserve their floor projection in the current collision model.

`ContextualPlacement.wall_slots(area, room, local_size)` returns deterministic `{cell, point, wall, yaw, footprint}` candidates. It checks floor support and wall continuity across the full footprint, existing obstacles, a walkable approach and separation from the start/exit. The generated dungeon wall gap is .16 units, with .14 units of corner clearance to accommodate the actual wall mesh caps. Dungeon placement chooses among these supported candidates with a separate hash, leaving combat RNG independent.

`Scenery.fitted_model(key, footprint, height, yaw)` centers the model, grounds its base and bakes rotation into the mesh transforms before fitting the X/Z dimensions. The returned root needs only its world position. This helper preserves the older `model` and `profiled` contracts. Horizontal fitting can change an asset's proportions; select a suitable native model category and a sensible recipe footprint. Authored-front adapters remain the asset recipe author's responsibility.

Existing interior layout IDs and furniture variant indices are retained. Mounted shelves are appended to the layout records. Older saved floor-storage selections that do not belong to the corrected cabinet/bookcase pool are replaced deterministically with an eligible model. No world reset or save-format change is added by this work.

## Verification

Run `./godot.sh --headless --script tests/test_contextual_placement.gd` and `./godot.sh --headless --script tests/test_wall_support.gd`. Both are registered in `check.sh`.

The focused check covers all ten current interior layouts and 271 model/layout combinations, including valid existing fallbacks when a registry query is empty. It loads every current item icon, verifies actual model bounds/materials, wall gaps, overlaps, deterministic saved variants, exits/books/rest access and invalid-data rejection. It checks dressing, actual walls, torch support, facing, walking routes and deterministic replay across 216 seeded floors from all six dungeon families. It also checks street/house/door clearance and biome/facet prop eligibility in 36 region plans.

The existing interior, content and expansion integration checks passed after the placement changes, including disk saves, exact outside returns, Sanctum travel, dungeon connectivity and book interaction. Native helpers are `tools/capture_contextual_placement.gd` for six dungeon families in both orientations and all ten interior layouts, and `tools/inspect_furniture_facing.gd` for authored furniture fronts. Captures are in `artifacts/placement-*.png` and `artifacts/facing-*.png`; logs are `/tmp/endless-flint-placement-green.log`, `/tmp/endless-flint-native-context.log` and `/tmp/endless-flint-facing.log`.

The initial regression run demonstrated wall-detached storage, geometry exceeding collision bounds, invalid-layout acceptance and dungeon shelves without actual wall support. A separate native inspection exposed the mounted-shelf/floor-bookcase asset mismatch.

## Coordinated follow-ups

Aster owns broader environment construction and exterior presentation. The audit requested that directional frontage models follow `house.facing`, with roads, doors and resident/book/discovery approaches preserved. Ember owns the broader creature/item bundle and loot changes; the audit requested local walkable selection for offset loot drop positions. These active lanes coordinate through `chat.md` and must rerun placement checks after expanding their asset pools.

The combined checker attempt passed four Ruby tests / 36 assertions, then stopped at catalogue freshness because Ember's in-flight main config references the not-yet-generated `config/generated_content_imports.json`. A direct runtime loop passed eleven groups through the original world check before encountering Lorekeeper's then-red town-spacing assertion. A later loop passed world-content before the in-flight geography catalogue prevented the next interior check. Those runs do not establish a full integrated pass for the broader changes.

After Lorekeeper's 128-cell town-use schema handoff, the final focused placement check passed again without errors/warnings (`/tmp/endless-flint-placement-final.log`), including the 36 updated region plans. The earlier clean native and interior/expansion tests remain snapshot evidence. Subsequent asset imports, regional-history, world activities and exterior construction remain separate integration validation work.

The wall-support regression compares wide fixtures against actual `VoxelKit.wall` mesh projections, including cap width, perpendicular corners and a corridor opening. It found 51 intersections before the clearance correction and passes afterward (`/tmp/endless-flint-wall-green.log`).

After the first creature/item bundle import and WorldLife compile corrections, the latest full placement check, interior save/return integration check and native 22-scene capture each passed without errors/warnings. Logs are `/tmp/endless-flint-placement-latest.log`, `/tmp/endless-flint-interiors-latest.log` and `/tmp/endless-flint-native-context-latest.log`. Item-icon loading includes the newly generated item definitions. Rendered views were inspected for supported furniture, inward-facing storage, elevated shelves, table seating and clear room/dungeon approaches. The broader bundle lane still has source-conversion repairs and the environment lane has a pending build; these focused passes do not certify every newly adopted asset or the entire changing project.
