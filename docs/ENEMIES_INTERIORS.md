# Creatures and enterable places

Enemy definitions and interior recipes live in [config/world_content.json](../config/world_content.json). Peaceful wildlife definitions live in [config/world_life.json](../config/world_life.json). The asset importer publishes staged models through [config/asset_imports.json](../config/asset_imports.json). Content changes use these JSON files; the runtime supplies combat, movement, room rendering and interaction handlers.

## Play

Wilderness encounters now select creatures by biome and surface facet. Dungeon encounters select from the current family. The catalogue starts with ten combat profiles and selects their appearances from imported Cube World and Ultimate Monsters models. A single profile can select several authored models. Health, movement speed, attack range, windup, recharge and damage come from its definition. Town sanctuaries remain protected, and a streamed chunk has at most two planned enemies. Peaceful animals remain separate from hostile enemies and dungeon gate counts.

Approach a town building's door and press E when its entry prompt appears. The initial catalogue includes homes, inns, shops, workshops and shrines. Room names, layouts and furniture vary by stable building identity and model queries. Furniture has collision, books can be read, and designated rest spots restore vitality and the class resource. Walk to the entrance mat and press E to leave; F and the pause menu also return outside. Designated shops and workshops offer finite stock through the store controller. Decorative work supplies retain their room purpose; crafting needs its own gameplay handler.

The room chart replaces the outdoor map indoors. The existing action dock remains available. Walls facing the camera lower as it rotates. Larger rooms start with wider camera framing, and the wheel adjusts indoor zoom separately from dungeon zoom. The living-world clock and peaceful outside models pause indoors. The Sanctum Sigil can leave a room and return to it.

## Add content through data

Add imported collections with pack-local source metadata and pattern-based rules in `config/asset_imports.json`. Run `ruby tools/import_assets.rb --build`, then `./godot.sh --headless --editor --quit`. Coordinate this rebuild/import window in `chat.md`; concurrent builds and runtime captures can otherwise observe incomplete import caches. The importer preserves source attribution and licenses.

`WorldContent` model queries accept `tags`, an optional `pack`, and `patterns` matched against stable asset IDs. Omitted tags/pack do not restrict the query. Patterns are case-insensitive and can include `*`. For example:

```json
{
  "tags": ["enemy"],
  "pack": "quaternius_ultimate_monsters",
  "patterns": ["*/Ghost*.gltf"]
}
```

An enemy entry contains a stable `id`, player-facing `name`, positive `hp`, `speed`, `reach`, `windup`, `period`, `damage`, `height` and integer `weight`, a `ranged` boolean, a `visual` query and a `habitat` record. Habitat fields are `biomes`, `facets` and `families`. Biome numbers follow the current world catalogue. Facet-specific pools take priority where the catalogue defines them. Family IDs match the area catalogue. Add a profile using the existing melee or projectile handler without adding a GDScript enemy case. A genuinely new attack mechanic needs a new generic handler.

`legacy_kind` reserves the original three combat indices for older records. Other definitions use their stable IDs in saves, even when catalogue insertion changes the runtime array index. `voxel_shape` selects original fallback geometry when an imported appearance is unavailable; normal matched variants use the authored imported models. Model normalization keeps their feet at ground level and bounds their size. Idle, movement and attack animations are selected from available clips.

An interior entry contains `id`, `name`, optional alternative `names`, integer `size`, a floor colour, a published `book` ID, an optional `rest` coordinate, and `layouts`. Each layout has its own stable `id` and `props`. Props specify a centre `point`, collision `footprint`, display `height`, a `query` for furniture variants and a legacy `fallback` alias. Shared bookshelf/bookstand and readable anchors are in `interior_defaults`. Add room types, layouts and matching furniture through data. Position props inside the room and keep paths from entry to exit, books and rest anchors open.

An optional `dressing_type` selects a profile from `config/interior_dressing.json`. Unknown explicit profiles reject the entry. A new room type without a matching profile uses the configured reader-bound `records` default. See [Interior style and composition](INTERIOR_COMPOSITION.md) for additional fixtures, supported supplies, density and biome-family selection.

For example, a chair slot can choose from the whole adopted furniture collection:

```json
{
  "point": [3, 7.7],
  "footprint": [0.65, 0.65],
  "height": 0.85,
  "fallback": "bench",
  "query": {
    "tags": ["furniture"],
    "patterns": ["*/chair*.gltf"]
  }
}
```

The catalogue loader rejects malformed definitions and retains its last valid data after a failed reload. Animal scheduling and its independent JSON validation belong to the living-world component; the same tag/pack/pattern query convention applies there.

## Persistence and coordination

Enemy encounter records save stable species and asset IDs alongside health and combat timers. Hostile projectiles save their configured damage. Interior saves use optional root `indoors` state with a stable building ID, definition ID, layout ID, selected furniture IDs, name, zoom and suspended outside journey. Restore resolves the building against the generated town before changing the active journey. Exit restores the outside position and encounter state while carrying current character, inventory, stats and all progress fields. Interior return snapshots must point outside, and recursive indoor returns are rejected. Existing saves without `indoors` remain supported within the current generator edition.

Lorekeeper owns the concurrent geography/generator edition and stable house door/approach fields. This creature/interior work does not request another world reset. Wren owns animal scheduling and peaceful model lifetime; Aster owns compatible appearance/ambience presentation; Rowan owns optional discoveries and their saved collection. The compact HUD and existing character/inventory/lore APIs remain in use.

## Checks and native previews

```sh
./check.sh
./godot.sh --script tools/capture_places.gd
```

The focused checks are `tests/test_world_content.gd`, `tests/test_enemies.gd` and `tests/test_interiors.gd`. They cover data-only future definitions, asset query/normalization, saved selection stability, invalid catalogue retention, habitat selection, sanctuary protection, connected rooms, indoor saves in fresh scenes, exact returns and Sanctum round-trips. The native helper writes `artifacts/entrance-*.png`, `artifacts/interior-*.png`, `artifacts/enemies-catalogue.png` and individual enemy views. Helpers and checks use isolated save folders.

An earlier creature/interior snapshot passed four Ruby tests with 36 assertions, catalogue freshness, editor import and 23 Godot groups. The native place helper passed on Godot 4.7.2 with Apple M2 graphics. Entrance, furnished-room, reverse wall cutaway and enemy-gallery captures were visually reviewed. Those snapshot logs contain no engine errors or warnings: `/tmp/endless-ember-expanded-check.log`, `/tmp/endless-ember-places-render.log`. Current biome-family and composition evidence is recorded in [Interior style and composition](INTERIOR_COMPOSITION.md) and [Creature families](CREATURE_FAMILIES.md). The earlier snapshot does not certify the expanded current checker.
