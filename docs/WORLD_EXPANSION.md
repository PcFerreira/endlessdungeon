# Endless Realm expansion

The base world remains voxel terrain with half-unit terraces, traversable roads, 16-cell chunks, and 128-cell regions. Voxel buildings, terrain, combatants, and Cube World NPCs are the first choice. Standard 3D tents, stalls, furniture, book stands, and cave floor surfaces provide additional forms. Source packs stay under `import_assets/free_packs`; adopted resources retain their dependencies and licenses.

## Places in this release

| City | Eligible climate | Second resident | Town book |
| --- | --- | --- | --- |
| Crossroads Town | All; guaranteed at the start | Milewarden | A Cup for Whoever Comes Next |
| Market Town | All | Relic mender | On the Ownership of Handles |
| Woodland Commons | Greenwood | Milewarden | A Cup for Whoever Comes Next |
| Caravan Town | Amber Wastes | Relic mender | Notes on Keeping Water |
| Mushroom Common | Greenwood | Milewarden | On the Ownership of Handles |
| Winter Hearth | Frostlands | Retired delver | A Letter Kept Warm |

Each town also has a fountain keeper. Generated names and resident IDs remain deterministic across unloading, revisiting, and loading a save. The archetypes have different plot arrangements, roof treatments, and prop pools. Each region retains one town and two ruins with independent seeds and 1–20 floors. The starting ruins are an Ashen Crypt and an Unclosed Office.

| Dungeon family | Construction | Dressing and book |
| --- | --- | --- |
| Ashen Crypt | Paired burial galleries | Beds and bookcases; The Bed Counter's Ledger |
| Violet Sanctum | Central examination chamber with branches | Book stands and workbenches; Instructions for the Final Atlas |
| Verdant Tomb | Connected garden circuit | Plants and stumps; A Letter Kept Warm |
| Quarry Depths | Work spine with extraction spurs | Rocks, anvils, cave surfaces; The Bed Counter's Ledger |
| Fungal Cistern | Broad colony chambers connected in a circuit | Mushrooms and cave surfaces; Notes on Keeping Water |
| Unclosed Office | Filing spine and annexes | Bookcases and tables; Instructions for the Final Atlas |

Room dimensions vary by seed and family. Depth increases the room and enemy count within the existing limits. Room roles are recorded for future content. A book in the entry room can be reached outside the stairs' interaction range. Props occupy small collision footprints outside the central routes and spawn positions. Dungeon props and books follow the cell fog reveal. The HUD and music use the actual family throughout the expedition. All wardens still seal the gate, and the final chest awards one skill point only once.

Mycelium Downs and Cinder Verge are bounded surface facets. Mycelium appears in Greenwood, including Mushroom Common; Cinder appears in Amber Wastes or warmer Greenwood. A seeded margin blends target growth into ordinary vegetation. Roads stay open and upland Frostlands retain their climate. Survey Road marks ruin approaches, Rootline marks fungal boundaries, and Boundary Common marks other town approaches. These are connected route compositions with ordinary movement rules.

## Talking and reading

Press E near a resident or book while grounded and away from danger. Fountain, ruin entrance, stairs, gate, and chest interactions keep priority. Dialogue and readers pause simulation; Esc closes them. Topics select complete authored lines by role, class, biome, names, and history. Personal revelations appear once per speaker. Return greetings name the actual last ruin visited from that town. Dialogue selection does not consume the combat random stream. Unknown conditions and unresolved placeholders are ineligible.

The four resident roles use the authored bank in `lore/procedural-dialogue.md`. Future Potfolk lines and combat barks remain in the catalogue for later presentation hooks. Talking offers lore rather than quests or trades. Farewell is an authored reply with a separate return button.

Reading copies each book to the field journal once. Press J or choose Field journal in the pause menu to reopen discovered books. Journal access also works in the Sanctum. Discovered books, met speakers, heard line IDs, and linked ruin returns save under `progress.lore` and carry through the Sanctum return. A new character clears that history.

## Content and assets

`config/world_areas.json` defines placement pools, layouts, architecture, climate prop palettes, facets and family metadata; `scripts/area_catalog.gd` validates and exposes those definitions. `scripts/expansion.gd` owns interaction, presentation, and narrative state. `scripts/lore_catalog.gd` reads books and dialogue from Rowan's runtime asset registry. The registry selects animated voxel NPCs while preserving their skeletons and animation players; static scenery uses a separate normalizing loader and MultiMesh batches for repeated outdoor props.

For new authored content, follow [ASSET_PIPELINE.md](ASSET_PIPELINE.md) and run `ruby tools/import_assets.rb --build`. Existing IDs remain stable. New text in the catalogue still needs an applicable placement or supported event to appear in play. Unknown scenery aliases resolve through the registry; the generator still decides which assets to place and their collision footprint. The deliberately selected expansion models retain scale profiles in `scripts/asset_profiles.gd`. `tools/build_lore.rb` remains a reference exporter of the original six-book bank; runtime lore uses the dynamic importer.

## New saves

The larger landscape revision uses generator version 4 with save envelope format 2. The user requested fresh worlds without migration. On the first launch of this generator edition, `SaveStore.reset_expansion()` removes the four journey slots and their backup/temp files, then writes `user://saves/generation-4.reset`. Subsequent launches preserve all new saves; optional life, exploration or ambience fields do not trigger another reset. Audio/display settings and the separate deepest-floor record are outside that reset. Begin a journey to create its autosave. See [LANDSCAPE.md](LANDSCAPE.md) for the broader biomes, crossings and connected town streets.

## Verification

Run `./check.sh` for importer freshness, resource instantiation, world routes, generation, combat, inventory, camera, save recovery, Sanctum return, and expansion checks. The expansion test samples 1,568 regions, checks all six families at multiple depths, verifies model geometry/materials and animation hierarchy, exercises real E interactions, validates dialogue conditions and one-time personal lines, and tests narrative persistence and the one-time reset on real files. Gameplay and camera checks use isolated save folders.

Run `./godot.sh --script tools/capture_expansion.gd` for native 1280×800 captures under `artifacts/`. It renders six towns and six families from opposing camera directions, both facets, four dialogue roles, six readers, the journal, and pause controls. Long-session performance and a full playthrough of every generated layout remain playtesting work.
