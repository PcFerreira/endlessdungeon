# Denser towns and civic magic

Towns now add small homes and trades along clear lanes, while retaining their primary buildings and public routes. Every current town has an original civic charm, roof lights and road inlays. A resident's Town charm topic explains the local account and custom.

## Density and access

`config/world_areas.json` defines `density.additional_buildings`, required infill uses and four neighborhood use pools. Most towns request six to nine extra buildings; market towns request eight to ten. The existing six to eight primary buildings still use their original generation sequence. Additional foundations have 2x2 footprints and use a separate seeded stream after the primary town and ruin plan is complete.

Layout `infill_plots` reserve candidates around the maximum primary footprints, public square, street cross, tower and outdoor lots. Runtime placement excludes existing streets and props, then plans a physical door connection around all structures. A new door must stay at least 2.4 cells from resident/book points and approaches. The planner tries another facing when needed and skips candidates without a connected door. It preserves all existing streets and primary doors.

The town plan exposes `density` with primary, accepted and requested infill counts. Infill houses add `infill`, `floors` and `quarter_id`; they retain the common house/interior contract. `quarters` lists only neighborhoods containing generated infill. Small two-level exteriors have an extra window row, while entering uses the existing home/shop/workshop room handler. Charmwrights, apothecaries and letter/spellbook shops are additional supported exterior uses.

Town centers remain 128 cells apart. Plateaus and safety boundaries stay at radius 13, and the public three-cell street cross stays clear. The broader biome fields, shared crossings and ruin roads are unchanged.

## Magic tied to actual places

Each base town definition selects a `magic_profile`. Profiles supply a name, account, custom, colors, bounded pieces, roof-light cap and road-mark distances. The six base forms are the return lantern, floating measure, root crown, travelers star, spore chorus and borrowed ember. Twenty-eight additional [town identities](TOWN_TYPES.md) select their own civic shapes and Lorekeeper-reviewed customs through the additive town-type layer. Their stories are local tradition; their silhouettes and repeated lights are visible features.

`city.magic` exposes the bound profile ID/data, deterministic seed, public-well support, actual roof-house IDs/positions and reserved street cells. `scripts/town_magic.gd` renders one hovering civic form, a small orbiting ring, at most eight household lights and eight inlaid road marks for the current profiles. These are noncolliding visual cues. They consume no inventory, combat randomness or progression resource.

The native component mounts beside the existing WorldView city construction and streams with its owning town. It now builds block or faceted forms according to the actual city biome. Roof lights and the hovering core use actual rendered house/fountain bounds for clearance through their animated range; source plans remain unchanged. No new imported source asset is required. Aster's construction recipes remain responsible for other exterior props and supported market/farm ensembles. The component uses no additional particle emitters, ambient audio players or light sources. See [local decorative acceptance](LOCAL_DECOR_FAMILIES.md) for the current 34-profile, four-climate checks.

Residents offer an additive Town charm topic. It reads the actual generated city's account/custom and leaves regional history, books, traveling roles, barter and their state intact. The player can return to the conversation or close it through the existing lore controls.

## Existing journeys

Generator edition remains 4 and save envelope remains 2. This is additive infill around retained foundations, doors, streets, well/books/residents and ruins. The original region-generation random sequence is preserved. It introduces no world reset, migration or new save field. Existing saved positions still use the standard safe-footing validation if a new small building occupies their previous open ground.

## Verification

`tests/test_town_magic.gd` rejects bad lane/profile/use definitions, checks physical door/NPC/book/lot access in actual streamed towns, and verifies the primary foundation/door/street/ruin compatibility fixtures captured before this change. It also builds and animates all six bounded native charm forms. The sampled footprint comparison reports occupied building cells, not population or a player-experience score.

The current 32-town sample has at least twelve buildings per town and 1.69 times the primary buildings' occupied footprint. The ten related world/interior/life/activity/lore/history/save regression groups passed on the integrated snapshot. All six real town types, opposing camera views, detail views and the actual resident account were rendered and reviewed. The complete shared checker remains a separate result: its latest stable attempt stopped on catalogue freshness after another lane's content update.

`tests/test_town_magic_game.gd` uses actual E and the Town charm button, checks the displayed account/custom, verifies unchanged inventory/combat RNG, reloads a generator-4 disk save and enters/exits an infill interior at its real approach.

Run `./check.sh` for integration checks. `./godot.sh --script tools/capture_town_magic.gd` writes native captures of all six real town types from both sides, detail views and a resident account under `artifacts/`. It uses isolated preview journeys and leaves actual player settings/records intact. Longer visits, social pacing and business balance need playtesting.
