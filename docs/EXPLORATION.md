# Roadside discoveries

The first exploration milestone adds small nonblocking landmarks beside existing roads. Press E near a safe landmark to read its passage. The text names the actual owning town and a real ruin from that region. Choose **Mark the linked ruin** to set the ordinary atlas route marker.

Reading adds one place-bound record to the field journal. Press J and use the Roadside discoveries section to reread it. Repeated visits do not duplicate a record, spend backpack slots or grant extra skill points. Discovery records survive disk saves, loading into a fresh scene and Sanctum return.

## Atlas knowledge

The atlas marks places you have learned about. A reported destination has an outlined marker; a location seen on a clear nearby approach has a filled marker. A marked center confirms a visit. The starting settlement is known, and a new journey has no automatically selected dungeon route. Terrain and actual roads remain charted for navigation.

Reading a real roadside clue, a local account, or accepting a comparison request can report its bound target. Choose the reader's route button or click a known marker to set a route. Unknown destinations have no named or clickable marker. Reaching a loaded entrance within ten cells with a clear approach records a sighting; entering its dungeon confirms the visit. Town visits follow their actual sanctuary footprint.

[site_knowledge.gd](../scripts/site_knowledge.gd) keeps monotone `rumor`, `seen` and `visited` stages under optional `progress.exploration.knowledge`. Its versioned snapshot binds records to the journey seed and stores actual ID, type, cell, name and stage. Invalid stages, coordinates or foreign seeds are rejected before restore. Older current-generation saves recover real remembered directions, recorded nearby visits and their active destination. Knowledge persists across disk reload, interiors and Sanctum return, and resets with a new journey.

`Exploration.known_sites()` filters the actual bounded `World.nearby_sites()` result and supplies each marker's `knowledge` stage. `note_site(id, cell)` reports only an actual matching target. Nearby observation runs at most four times per second during surface gameplay and requires the site's chunk to be loaded. Opening an atlas does not publish every nearby destination. Independent irregular-site geography remains a separate generator change; this component adds no reset or imaginary settlements.

## Current content

Four metadata-defined families are available: a survey stone, a traveler's cart, a woodland root register and an old watch marker. Their short passages are original setting content. The root register is eligible in Greenwood and Sunlit Meadows; other families are eligible across the four base biomes. Model variants are selected from the imported registry through `pack`, `tags` and `patterns` queries.

The starter region attempts a landmark. Other regions have a deterministic one-in-four quiet selection before placement checks. The planner tries at most one landmark per region. It reserves a clear adjacent ground cell and a walkable approach on an existing road, checks a maximum half-cell height difference, and stays clear of ruin entrances. If art or a suitable anchor is unavailable, the region stays quiet. It does not flatten terrain, add blocking collision or move existing routes.

Fountains, interior entrances, residents/books, stairs, gates and chests retain interaction priority. Reading new discoveries requires grounded safe conditions. The reader pauses ordinary gameplay and living activity, hides competing HUD/menu overlays and closes with Escape or its button. Collected passages can be reopened through the journal at home or during an expedition.

## Data and runtime ownership

Definitions live under `lore/content/discoveries/`. They use the existing lore importer with authored kind `discovery`; the runtime catalogue exposes them as text records tagged `discovery`. Add more JSON records and run `ruby tools/import_assets.rb --build`, then complete the Godot editor import. No discovery filename list exists in GDScript.

Required definition fields are `id`, `version`, `family`, `title`, `author`, `text`, `marker_label`, `biomes`, `requires`, `model_query`, `marker_width` and `marker_height`. The only implemented capability in this slice is `read_discovery`. Unsupported/invalid definitions are excluded and surfaced by the catalogue regression check. Model-query fields follow the shared `pack`/`tags`/`patterns` contract. Patterns match stable registry asset IDs.

`{city_name}` and `{dungeon_name}` are bound to committed region/site facts before publishing a passage. Other unresolved placeholders prevent placement. New text alone does not add a puzzle, transaction, quest or event handler.

| Module | Responsibility |
| --- | --- |
| [discovery_catalog.gd](../scripts/discovery_catalog.gd) | Discover and validate definitions; filter biomes/capabilities and actual model availability. |
| [discovery_sites.gd](../scripts/discovery_sites.gd) | Plan deterministic clear roadside anchors and bind actual place/history/model IDs. |
| [discovery_view.gd](../scripts/discovery_view.gd) | Render nearby markers and short-range labels without collision. |
| [exploration.gd](../scripts/exploration.gd) | Bounded nearby plans, safe interaction, reader, collection, atlas markers and journal rows. |

The planner uses independent hashes rather than combat RNG. Plans and visuals follow nearby streamed regions/chunks; they do not enumerate the endless world. Collected records retain their resolved text and chosen model/definition edition so a content-bank expansion does not rewrite a discovered passage.

Optional `progress.exploration` contains a version and records keyed by stable instance ID. Its default is an empty collection in existing saves of the current generator. Numeric JSON fields are validated and normalized before restore. A discovery ID includes the journey/generator/region identity and template edition. The separately owned geography change controls generation-4/reset policy; this additive component does not introduce a reset. [Regional histories](REGIONAL_HISTORY.md) add shared local accounts, source collections and observed aftermath through an optional nested field.

## Verification

```sh
./godot.sh --headless --script tests/test_exploration.gd --quit-after 90
./godot.sh --headless --script tests/test_site_knowledge.gd --quit-after 600
./godot.sh --script tools/capture_discoveries.gd --resolution 1280x800
./godot.sh --script tools/capture_site_knowledge.gd --resolution 1280x800
./check.sh
```

The focused check uses real world plans and imported content. It samples multiple seeds and positive/negative/distant regions, checks deterministic quiet/eligible placements, walks the actual collision graph from a sanctuary to the approach, and validates real ruin bindings. A Game-backed check exercises actual E, marker presence, combat RNG/backpack preservation, duplicate handling, journal reopening, disk JSON round-trip, old optional-field defaults, Sanctum carry, airborne safety and fountain priority.

The native discovery helper uses isolated preview saves under `artifacts/discovery-preview-saves`. It captures all four marker/reader families and journal/rereading screens at 1280x800. It verifies the selected ruin marker and normal E interaction. Captures are `artifacts/discovery-*.png`; they do not overwrite the player's journey or settings.

The knowledge regression checks reports, sightings and visits, hidden map clicks, actual clue routing, independent combat RNG/inventory, disk/home/legacy carry and invalid-save rejection. Its native helper uses `artifacts/site-knowledge-preview-saves` and renders the unknown, reported, seen and visited atlas, the actual clue and entrance, E entry and disk-restored visit. Captures are `artifacts/knowledge-*.png`.

Focused and native checks do not establish long-session performance, perfect coverage of all generated road/biome combinations or the discovery cadence players prefer. The next roadmap stage adds richer local history, collection progression and event-fact bindings after those playtests.
