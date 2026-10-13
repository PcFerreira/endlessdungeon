# Contextual world construction

The environment catalogue accounts for the staged collection and makes portable resources available to the asset registry. Scene recipes decide where those resources belong. A seed selects variations within a suitable regional palette; it does not scatter unrelated objects.

Markets have a floor treatment, a covered counter, supported displays and stock crates. Farms have soil rows, recognizable growth bands and watering supplies. Workshop benches carry tools or repair materials. Standing braziers and animated arcane flares mark ruin entrances; archives and sanctums can use a supported column-and-lintel frame. Roads, doors, resident/book approaches and discovery anchors keep their existing positions and collision rules.

Wilderness foliage replaces existing generated prop anchors. Each region uses a small palette for a given role, so neighboring trees and rocks share a visual language. Climate eligibility separates deciduous woodland, evergreens and desert plants. Imported parts use the existing terrain cutaway shader, with embedded textures kept distinct. MultiMesh batches reuse geometry, and construction/scenery template caches have a 96-entry limit.

All source files retain their bytes and notices. The catalogue currently contains 2,709 canonical model, audio and effect resources across 29 source packs, with 70 semantic pools and 36 construction recipes. The source inventory also accounts for alternate exports, dependencies, other agents' creature/item/UI resources, legacy runtime bindings and the license-review collection. Those status counts are generated, not hand-maintained.

Architecture parts without a supported assembly remain an explicit library. Modern food, modular walls, puzzle components and other unmatched resources do not appear as arbitrary terrain clutter. Generator-owned house plots, doors, facing and collision remain authoritative. [Town architecture](TOWN_ARCHITECTURE.md) now fits themed imported buildings and supported modular assemblies to those real plots, with source and voxel representations selected by biome.

## Authoring

[`world_asset_sources.json`](../config/world_asset_sources.json) selects canonical pack representations and classifies them into semantic pools and component libraries. [`build_world_assets.rb`](../tools/build_world_assets.rb) writes [`catalog.json`](../assets/world_construction/catalog.json), [`source_inventory.json`](../assets/world_construction/source_inventory.json) and the independently owned [`generated_world_imports.json`](../config/generated_world_imports.json) fragment. The main importer includes this fragment alongside Ember's creature/item fragment, so shared models have one stable registry identity.

[`world_dressing.json`](../config/world_dressing.json) defines anchor names, climate/town/family eligibility, priority, footprint and ordered parts. A part names a semantic model pool or a supported primitive, its local footprint/height/point and its support. Tabletop goods reference an earlier declared surface. A spanning canopy or lintel names distinct supporting posts with equal cumulative top elevations, including its primary support. Farm crops reference their soil rows. Parts must fit the reserved assembly footprint; unknown supports, overhanging goods and empty pools are rejected.

`WorldDressingCatalog.recipe_for(anchor, context)` selects a suitable recipe, and `plan` chooses its stable asset variations. `WorldConstruction.build` normalizes actual geometry in both collision axes, derives support heights from rendered bounds and exposes `recipe_id` plus per-part asset/support/bounds metadata. WorldView substitutes an assembly only after it builds successfully; otherwise it uses the existing native fallback. It never draws both versions at the same anchor.

Portable interactions must preserve this dependency graph. Removing a counter cannot leave supported goods floating. Take a complete assembly or remove its dependents first. Walkable farm context stays low, while the market's tall framework remains within its existing central solid cell. The scene recipes do not add new obstacles or competing interaction prompts.

## Sound and atmosphere

The [ambience controller](WORLD_AMBIENCE.md) resolves whole audio pools for wind, wildlife, footsteps, doors, books and indoor creaks. A stationary nearby relic mender can supply the physical source for a quiet page sound. Eight additional CC0 songs have regional purposes alongside the original Soundimage recordings. Music and environment transitions retain their debounce/crossfade and independent volume controls.

Rare regional showers have both visible rain and a rain bed, restricted to woodland/meadow climates. They are seeded cosmetic weather and do not alter movement, combat, farming or save format. The render limit is 72 rain particles. Menus pause/hide the shower and fade its ambience.

The original `impactGlass_light_002.ogg` contains a legacy Sony comment that Godot diagnoses during first import. Its audio decodes and passes a separate native non-silent mixer check. Classic OBJ ambient coefficients also produce first-import notices because Godot uses PBR lighting. Original coefficients/recordings remain intact; these messages are distinct from runtime model, texture or playback failures.

## Build and review

Coordinate shared builds in `chat.md`. Prepare independent data first, then serialize one importer/editor pass:

```sh
ruby tools/build_content_bundles.rb
ruby tools/build_world_assets.rb
ruby tools/import_assets.rb --build
./godot.sh --headless --editor --quit
./check.sh
```

The world builder's Ruby test checks canonical/alternate/support classification, unassigned-asset retention, source preservation and stale-output detection. The GDScript construction check uses real resources to verify determinism, support/footprint rejection, embedded-texture separation, actual ground/support heights and reserved lot approaches.

`./godot.sh --script tools/capture_world_construction.gd` captures actual town, market, farm and ruin presentation, a reverse entrance view and every construction recipe at 1280x800. `./godot.sh --script tools/check_ambience.gd` checks real looping/crossfades, registered music, footsteps/book sounds and non-silent mixer recordings. Review the `artifacts/construction-*.png` screens at the normal gameplay scale as well as closeups. Headphone/speaker balance and long-session rendering remain playtesting work.
