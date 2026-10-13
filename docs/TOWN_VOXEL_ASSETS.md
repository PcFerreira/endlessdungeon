# Themed voxel town assets

The voxel pack now supplies buildings, civic monuments, road gateways and market shelters to Japanese, Chinese, Korean, Halloween, Christmas, cyberpunk, mage and fairy procedural towns. Homes, farmhouses and inns use each theme's house; businesses use its workshop. Civic plots receive themed monuments, including deterministic KayKit pumpkin and Kenney holiday alternatives. Eligible towns receive a road gateway and a goods-free version of their theme's market shelter over the existing registered wares.

The pack lives in [`assets/town_voxels`](../assets/town_voxels/). [`catalog.json`](../assets/town_voxels/catalog.json) lists each stable ID, name, theme, role, scene/GLB paths, actual bounds, triangle count, grid pitch, file hashes and source provenance. Each model has a compressed self-contained `.scn` and a portable `.glb`. The original procedural geometry uses a .125-unit cell grid and removes hidden faces between occupied cells. Material colors are stored on vertices, so no external texture is required.

| Theme | Building shells | Gate, market and civic asset |
| --- | --- | --- |
| Japanese | Rainwood Lattice House; Reedpaper Workshop | Timber Lane Gate; Cloth Market Shelter; Paper Lantern Monument |
| Chinese | Jadebeam Courtyard Hall; Porcelain Tea Workshop | Bracketed Court Gate; Tea Exchange Pavilion; Jadebeam Bell Pavilion |
| Korean | Warmstone Timber House; Moonjar Pottery Workshop | Quiet Tile Gate; Potters Market Shelter; White Moonjar Monument |
| Halloween | Harvestmask Crooked House; Candlewake Tall Workshop | Harvest Face Gate; Maskmakers Night Stall; Great Pumpkin Lantern |
| Christmas | Evergreen Snow Lodge; Giftmakers Toy Workshop | Ribbon Feast Gate; Gift Market Stall; Evergreen Village Tree |
| Cyberpunk | Neon Relay Tower; Chrome Component Workshop | Circuit Relay Gate; Component Exchange Kiosk; Signal Relay Spire |
| Mage | Spellbinders Tower; Observatory Chart House | Working Circle Gate; Ink and Charm Stall; Armillary Light Monument |
| Fairy | Dewbell Mushroom House; Petalweave Flower Cottage | Bramble Bloom Gate; Leaf Weavers Market; Dewdrop Flower Monument |

The building forms now express their themes through actual geometry: separate roof profiles/lattices, a taller harvest workshop, a relay tower, a round mage tower and a mushroom house. The pack's forty original geometry signatures differ without relying on material colors. The cultural forms are compact fantasy interpretations of the [town theme references](TOWN_THEME_EXPANSION.md), rather than measured historical reconstructions. A courtyard hall is one building piece, not a complete courtyard layout.

## Existing source assets

Four source-derived props reuse the files already supplied under `import_assets`: KayKit's orange pumpkin and jack-o-lantern, and Kenney's decorated tree and wrapped present. Their actual registered source resources were fitted and voxelized at resolution 24 using the project's existing converter. The original files, buffers and textures were not edited.

The catalogue records the original model path/hash, registered source ID, author, source URL, CC0 notice and attribution for each derivative. Exact source license notices are copied into [`licenses/KayKit-Halloween.txt`](../assets/town_voxels/licenses/KayKit-Halloween.txt) and [`licenses/Kenney-Holiday.txt`](../assets/town_voxels/licenses/Kenney-Holiday.txt). The forty original procedural models were authored for the Endless World project; this task introduces no separate license for those originals.

## Runtime placement

[`scripts/town_voxel_models.gd`](../scripts/town_voxel_models.gd) loads packed scenes through [`config/town_voxel_runtime.json`](../config/town_voxel_runtime.json). Its 52 declared identities comprise the 44 source models and eight market frames with joined counters/illustrative wares removed. The original source catalogue remains unchanged. EnvironmentStyles registers both actual render families. Block biomes use the original voxel geometry; flat biomes use pre-baked faceted companions. Scene hashes are checked on first load and fitted templates are bounded at 96. There is no runtime voxel conversion.

Building fitting preserves the complete plot and height cap. Piecewise fitting retains a .84-wide, 1.6-high entrance with a .12 threshold, aligned laterally to the existing generated door and facing. Existing house, owner, interior, use, approach and shop IDs remain authoritative. The fitting cache shares fitted meshes between duplicate instances. TownMagic receives the final house references; TownStyle omits its older facade overlays on these already decorated assets.

[`scripts/town_voxel_layout.gd`](../scripts/town_voxel_layout.gd) plans an optional left entrance after town densification and road construction. Posts occupy exactly two cells, at town-center offsets (-12,-3) and (-12,3); those cells become blocked. The opening clears the three existing road cells. A conflicting street, road, lot, house, decoration or required approach suppresses the gate. WorldView attaches it through the same city steps used by staged preparation and synchronous rendering. Generator versions and save format remain unchanged.

Markets retain their original fixed counter, trade mat, portable goods, source IDs, support links, stock and theft rules. Only the former posts/canopy are hidden. A goods-free native frame occupies the already reserved counter cell, with its canopy above the actual wares. The four seasonal source props are fixed civic scenery rather than new inventory items. No new magic controller or service is inferred from a decorative model.

## Source placement contract

All models use +Y up and +Z front, with a bottom-centered origin. Buildings/gates declare an actual open entrance, `door.point`, `door.clearance` and `door.front`. The supported opening is at least .75 units wide and 1.5 high; building thresholds are .25 units above their base. Source derivatives also have grounded, centered actual bounds. Scene metadata includes `asset_id`, `visual_family`, `theme`, `kind`, voxel count/pitch and doorway fields where applicable. The JSON record is authoritative for external tools because glTF extras may represent Godot metadata differently.

Use `theme_id` to select the corresponding pack theme. House and workshop resources can serve existing building uses; a workshop mesh alone does not create a new service, merchant inventory or interior controller. Keep generated house/city/lot IDs, authoritative footprints, facing, door approaches and source-part registration. Rotate the +Z entrance toward the actual generated facing, then fit/translate the declared socket to the authoritative entrance rather than assuming the source's origin is the door.

Fit the complete AABB, including roof overhangs, to the existing house plot and roof-height cap. A rounded tower or mushroom has wider upper geometry than its body; use its complete bounds. Keep its threshold and door aperture usable after scaling. If a small infill plot would shrink the opening below the actor's required size, choose another asset or reserve an appropriately sized plot. Do not change terrain/collision solely because a decorative shell has different bounds.

This pack supplies actual block geometry. Avoid voxelizing it again by default, which can erase lattices and entrance detail. Biomes requiring faceted geometry need a truthful same-source derivative through the existing family pipeline; a family label alone is insufficient. Feed the final rendered house references to TownStyle/TownMagic so their trim and floating lights clear the actual roof. Preserve the rendered house/source IDs through baked caches and portable descriptors.

Gates, markets and civic pieces have their own measured bounds and require a compatible reserved plot. Market wares in these exported meshes are joined structural illustration. For pickup/theft/store integration, rebuild the wares as independently registered parts with real item IDs, support links, collision and stock rules. A bell, relay, tree, mask or armillary model provides scenery; additional behavior needs a supported controller.

The runtime integration retains generic town recipes as its fallback. It does not reset user saves or update a public build. Native and faceted scenes are self-contained, so no main asset importer or editor scan is needed. The existing 302-scene creature/biome render cache was refreshed for the added EnvironmentStyles classification. Release-input snapshots now include both native town resources and the separate landmark-cache directory.

## Rebuild and review

Definitions: [`config/town_voxel_assets.json`](../config/town_voxel_assets.json). Original geometry: [`tools/town_voxel_geometry.gd`](../tools/town_voxel_geometry.gd). Exporter: [`tools/build_town_voxels.gd`](../tools/build_town_voxels.gd).

Run `./godot.sh --headless --script tools/build_town_voxels.gd --quit-after 600` to recreate the scenes/GLBs/catalogue. This reads the four already imported source props but runs no main importer or editor scan. Export uses Godot's [GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html) scene-to-file API. The helper is intended for the installed Godot 4.7 runtime.

Run `./godot.sh --headless --script tests/test_town_voxel_assets.gd --quit-after 600` for all-resource acceptance. It independently loads every packed scene and GLB, compares round-trip bounds, checks block normals and finite vertices, verifies forty distinct original geometries, regenerates the originals, checks hidden-face removal and each declared entrance, and validates derivative provenance/model hashes. The test does not certify runtime placement, service behavior, performance or the shared game's full suite.

Run `./godot.sh --script tools/capture_town_voxels.gd --quit-after 1200` for all eight opposing native galleries under `artifacts/town-voxels/`. The gallery uses exported assets directly and creates no game/save/settings state.

After rebuilding the original pack, run `./godot.sh --headless --script tools/build_town_voxel_runtime.gd --quit-after 600` to recreate the market frames, faceted companions and runtime catalogue. This must precede rebuilding the general render cache if EnvironmentStyles configuration changed.

Run `./godot.sh --headless --script tests/test_town_voxel_integration.gd --quit-after 900` for actual family geometry, plot/door fitting, gate access and themed market/shop persistence checks. Test saves use a unique test-only directory. Run `./godot.sh --script tools/capture_town_voxel_integration.gd --resolution 1280x800 --quit-after 1200` for sixteen actual procedural town views under `artifacts/town-voxel-integration/`. The manifest identifies the generated city, settlement, biome and family for each theme.

Original asset-production logs are `/tmp/endless-town-voxels-build-final.log`, `...-accepted.log` and `...-native-final.log`. The complete 44-model source pack contains 393,936 triangles before instancing or any future LOD pass; this is an asset-library count rather than a measured town frame budget. Runtime checks and native captures establish placement and interaction behavior; full-project performance and deployed-package acceptance require their separate owner workflows.

Final runtime acceptance is `/tmp/endless-town-voxel-integration-accepted.log`: 52 declared identities in both actual geometry families, rectangular/cardinal doorway alignment and clearance, rejected undersized entrances, reachable gate themes, physical post-cell containment and unchanged road access in editions 4/5/6. The actual Japanese-town fixture checks separate market theft, disk restoration and restitution, shop E entry, a paid stock purchase, fresh-game trade-state restoration and return to the original approach. Its saves use a unique test directory.

Native acceptance is `/tmp/endless-town-voxel-integration-native.log`, with all sixteen actual 1280x800 town views reviewed. Original pack, environment styles, 128-region physical routes and worker/staged/navigation regressions are clean in `/tmp/endless-town-voxel-{assets,styles,routes,streaming}-regression.log`. The unchanged render-cache builder finished in `/tmp/endless-town-voxel-render-cache.log`, and both general and landmark freshness checks pass. The release-input fixture passes 16 assertions. These are focused checks, not a full project or exported-release certification.
