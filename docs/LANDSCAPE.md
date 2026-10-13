# Larger areas, crossings and town streets

Generator edition 4 creates broader climate and terrain fields, continuous crossings, and connected house approaches. Voxel terrain remains the foundation. Chunks remain 16 cells. Town centers are now 128 cells apart, with one town and two independently seeded ruins per region.

## Continuous landscapes

Temperature frequency is 0.0013 and moisture frequency is 0.0018, each with two fractal octaves. Continental, erosion, ridge and detail fields also use broader scales. River frequency is 0.0038 with two octaves. High local terrain no longer switches individual cells to Frostlands; climate determines the biome. Towns retain their owning biome within the plateau. Bounded fantasy facets remain local wonders with seeded margins.

Across eight seeds and 67,600 adjacent sample pairs at eight-cell spacing, the proportion of climate boundaries fell from 0.2950 to 0.0415. This measures neighboring samples with different biome IDs, rather than an average area size. All four climate classes still appear across seeded worlds. The native helper writes before/after climate maps over the same 2,048-cell square; forest is dark green, meadows light green, wastes tan and Frostlands pale blue. These maps show climate, not water or structure locations.

## Bridges and shared routes

City links use one canonical route plan for each pair of endpoints. Neighboring regions query the same plan, including three-cell width, heights, orientation and bridge spans. Dungeon approaches use the same planning method and meet the main road's actual height. Plans stay deterministic across region/chunk boundaries, negative coordinates and cache eviction; the route cache is capped at 128 entries.

Water channels and low gaps become connected bridge spans along the reserved route. Decks sit at least half a unit above water and retain traversable half-unit grades toward the banks. Rails mark the outer edges and leave openings where side roads join. Periodic piers support the span, and the renderer shows water or lower ground beneath the deck. The crossing creates one walkable surface; this revision does not add navigation underneath bridges. Roads and crossings are reserved before wilderness props.

`region.roads` maps cells to planned height and crossing metadata. `region.bridges` contains stable span IDs, endpoints, axis and length. Neighboring plans may refer to the same span; streamed cells render it once. `cell_info()` retains its previous fields and adds bridge orientation, edge, pier and base-surface data.

## Connected towns

`geography.town_spacing` in the area JSON sets the region width and minimum cardinal distance between town centers. The current 128-cell grid leaves 102 cells between the radius-13 plateaus. Negative coordinates follow the same grid. The starting town center and player position derive from the spacing, and the world atlas shows three region widths with bounded sampling. The region cache and 25 loaded chunks retain their existing limits.

The town plateau and sanctuary use the same square boundary with radius 13. Wilderness encounters stay outside radius 16. The central plaza and main streets are reserved before houses and props. Each house faces toward a reachable approach; a bounded breadth-first search connects the door to the existing street network while avoiding houses, the fountain, book stand and tower. Decorations stay off those paths. Books and residents retain reachable approach cells.

Town definitions have three selectable layout recipes in this revision. Architecture supports stepped gable, hip and flat roofs, authored wall/roof colors, height ranges and prop pools. Houses expose stable `id`, `door` and `approach` Vector2 coordinates, cardinal `facing`, footprint and architecture data. Existing city/resident IDs and region coordinates remain intact. Living residents retain independent actor roots.

Every current recipe includes a home, a store, an inn, a workshop and a shrine, then chooses additional homes, farmhouses, bakeries, outfitters or general stores from its themed pool. Buildings expose `use_id`, `use_name` and explicit `interior_type`, so exterior use agrees with the enterable room handler. Use-specific architecture changes height, roof, walls and awnings. Business signs face the actual front door. Shop types currently share the existing shop interior; this geography work adds no independent shop transaction system.

Each town also reserves a named 3x3 market and a 3x3 crop garden. Mushroom commons grow spore gardens, woodland towns have herb beds, caravan towns have irrigated seed beds and winter towns have winterroot beds. These are small farm plots. Outdoor records in `city.outdoor_lots` expose stable lot ID, kind, footprint, authored recipe, solid cells and connected facing/door/approach. Market counter goods have a supporting surface; low crops remain walkable. Lots are reserved before path planning, stay on the plateau, and do not overlap house footprints or interaction anchors. These semantic anchors are available for the separate contextual asset construction work.

## Editable definitions

The additive [town density and magic pass](TOWNS_MAGIC.md) adds small lane buildings, magical trades and civic charms around these primary foundations. It retains existing streets/doors/ruin positions and the 128-cell town spacing, so generator edition remains 4.

Edit `config/world_areas.json` to adjust town spacing, building uses, required/extra building pools, outdoor lots, layouts, town weights, architecture, props, biome vegetation, facets, transitions and supported family metadata. Spacing must be a multiple of 32 within 128 to 512. The loader rejects unknown interior handlers, incomplete building pools, invalid lots, and layouts that overlap lots, main streets, reserved interactions, tower or other maximum-size plots. New props can use asset-registry aliases; defined scale profiles remain available. Geometry patterns and supported gameplay handlers remain code, while their specific recipes and selections are data.

The four broad climate classes remain the supported foundation. A new dungeon family also needs its layout/encounter handlers. Catalogue changes affect seeded choices; validate the new data and consider a generator edition change when altering existing geography. Optional life/exploration records alone do not require resetting worlds.

Current edition6 wilderness roads use terrain-aware diagonal routing, rounded land turns and continuous bridge spans with explicit bank landings. Old traveler snapshots migrate their route progress without changing hero saves. See [ROAD_PATHS.md](ROAD_PATHS.md) for the current planner, compatibility rules and native gallery.

## Verification

`tests/test_landscape.gd` measures climate boundaries, checks minimum town spacing and mixed building uses, rejects invalid layouts, checks front-door/NPC/book/lot reachability, bounds wilderness encounters, and physically walks streamed town links across region boundaries. Existing world checks cover four biomes, vertical variation, finite ruins, collision, deterministic reload and bounded streaming. The physical entrance-route regression covers 128 positive/negative regions. Interior tests verify all five handlers and exact outside return points.

Run `./check.sh` for the coordinated game checks. Run `./godot.sh --script tools/capture_landscape.gd` to write the climate comparison and native town/bridge captures under `artifacts/`. Review crossing banks, stairs, oriented house footprints and opposing camera views. `tools/capture_town_shapes.gd` also renders a standalone gallery of building uses and crop forms without loading Game or imported model pools. Long-distance travel pacing and long-session performance still need playtesting.

Save envelope format remains 2; generator edition is 4. Following the user's fresh-world instruction, the edition-specific reset removes old journey slots once while preserving settings and the deepest-floor record. Subsequent launches preserve new worlds.
