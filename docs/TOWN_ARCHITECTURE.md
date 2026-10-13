# Town architecture

Japanese, Chinese, Korean, Halloween, Christmas, cyberpunk, mage and fairy towns now prefer the [native voxel pack](TOWN_VOXEL_ASSETS.md). It supplies authored houses/workshops, civic monuments, gateways and goods-free market shelters, with original block geometry and pre-baked faceted companions. Native door sockets are fitted to the existing generated approach axis while preserving usable openings.

The legacy catalogue remains the generic and unavailable-resource fallback. Its 30 construction templates include twelve complete imported building forms and eighteen assemblies of imported walls, roofs, doors, frames and platforms. Homes, inns, smithies and shrines keep their real building use. Keeps, watchtowers, markets, mills and colonnades occupy the existing reserved civic plot. Fourteen fallback architectural profiles cover the current town identities.

The profiles choose buildings by purpose and theme. Every profile covers all eleven existing home and business uses within its own curated list. A town keeps its selected source palette across households; roof colors do not count as new building silhouettes. The acceptance check finds thirty distinct geometry signatures before color or representation changes.

## Sources and representation

The catalogue uses the already imported CC0 KayKit Medieval Hexagon, Kenney Fantasy Town, Kenney Castle, Kenney Holiday, Kenney Survival, Kenney Graveyard and Quaternius Medieval Village packs. Source model bytes and notices are unchanged. See [project credits](../CREDITS.md) for the creators and source records.

The imported fallback buildings are medieval forms. Their modular pieces support additional timber houses, courtyard halls, stacked lodges, stone towers and metal workshops. Cultural profiles are fantasy assemblies with separately authored town details; they do not establish historical Japanese, Chinese or Korean buildings. Native fairy and cyberpunk models now provide actual mushroom/flower houses and circuit architecture; the fallback profiles retain their imported assemblies and town trim.

For imported fallback buildings, faceted biomes display source meshes and materials; block biomes display an actual voxel conversion. The converter samples triangle surfaces and source material, vertex and texture colors into a bounded cube lattice, with internal faces removed. Source identity remains separate from the rendered derivative. It preserves sampled openings; detail smaller than a cell can disappear. Native pack buildings already contain block geometry and bypass this conversion. Both paths provide visual shells while existing plots and controllers govern physics and interiors.

## Placement and gameplay

The existing generator owns house IDs, use IDs, footprints, facing, doors, clear approaches, terrain height and collision. Architecture changes the visible shell. Its complete rendered bounds fit inside the existing plot with a small margin. Grounding includes the full source bounds, including models whose original origin lies above their lowest geometry. Roof height is capped at the existing house height plus one metre, below the current roof charms.

Business signs stand on posts at the generated door approaches. E uses the same entrances and interior/store controllers as before. Several complete source meshes have no authored doorway socket, so their visible door positions are not a substitute for the authoritative approach. The gallery checks facing and silhouette separately from the actual entry and saved return checks.

The former civic tower's reserved three-by-three plot hosts the civic variants. Their sources fit inside that plot; an old overlapping statue is omitted when a replacement is present. A mill exterior is scenery. Working machines, new services and new construction plots require their own gameplay definitions. The watermill remains in the asset library because no verified waterside civic binding exists.

No generation version, save format or user journey reset is needed. Structural buildings remain fixed. Existing portable goods, store stocks, law, town charms and discovery bindings retain their source identities.

## Authoring

[`town_architecture.json`](../config/town_architecture.json) declares complete templates, ordered parts, use eligibility and theme pools. A part specifies an imported asset or a foundation primitive, bottom-centred position, local dimensions and yaw. Fit the part to its local dimensions before rotating it; a thin side wall must remain thin across the rotated axis. Pitched roofs require their matching slopes and attic-end infill. A template declares its intended front orientation. New source palettes must resolve actual registered models. New building purposes need a real building-use or site controller before they can be offered as enterable services.

[`TownArchitectureCatalog`](../scripts/town_architecture_catalog.gd) validates references, sizes and per-theme use coverage. Selection uses an independent seeded generator and retains the town's palette. [`TownArchitecture`](../scripts/town_architecture.gd) builds and fits the source assembly, verifies original source classification, converts block representations and verifies the derived identity. Its fitted template cache holds at most 48 entries. Unavailable or invalid sources use the existing safe house fallback.

Each successful model exposes `house_id`, `template_id`, `construction_name`, `source_assets`, `visual_family`, `render_asset`, `representation`, `render_height` and `theme`. WorldView exposes its actual `house_models` by ID on the city chunk. These values support height-aware trim and future construction interactions without modifying saved generator records.

## Verification

[`test_town_architecture.gd`](../tests/test_town_architecture.gd) checks every template with actual source resources and voxel geometry, every theme and business purpose, rotated fitted bounds, source immutability, materials, deterministic selection, generated clear approaches, real shop entry and disk-restored return. [`test_town_model_voxelizer.gd`](../tests/test_town_model_voxelizer.gd) checks actual block faces, colors, texture sampling, open gaps, unindexed imported surfaces, source preservation and conversion budgets.

[`capture_town_architecture.gd`](../tools/capture_town_architecture.gd) renders opposing views of each themed town and every template in both representations at 1280 by 800. It saves isolated screenshots under `artifacts/town-architecture`. Native runs require the shared imported resources and style catalogue to remain stable during capture. A PASS alongside engine errors is not a clean result.
