# Town types

The world now selects thirty-four town identities: six baseline settlement templates, twelve trade/civic themes and sixteen [cultural, festival and fantastic themes](TOWN_THEME_EXPANSION.md). Each addition supplies distinctive quarter names, a signature infill business, trade pools, local appearance metadata, market/garden names, a crop recipe and an original floating civic form. The sixteen newest themes also supply exterior accents. The town label shows the selected identity; a real resident's Town charm topic explains its account and custom.

These identities share the existing three layouts of their parent template. They are implemented town themes and do not supply thirty-four different street plans or settlement sizes. Current towns retain the same safety radius and density ranges. Aster's architecture and Compass's staged independent-site geography are separate integrations; this identity layer does not certify their complete visual/topology acceptance.

## Added identities

| Identity | Parent template | Climate | Signature business | Local custom reviewed by Lorekeeper |
| --- | --- | --- | --- | --- |
| Grain Commons | Crossroads | Greenwood, Meadows | Bakery | Keep an arrival cup ready |
| Quarry Borough | Crossroads | Meadows, Wastes, Frostlands | Smithy | Name repaired stones |
| Lantern Court | Market | Greenwood, Meadows, Frostlands | Charmwright | Lend lamps to arriving guests |
| Archive Steps | Market | Any | Letter and spellbook shop | Preserve disagreeing accounts |
| Rootbound Ward | Woodland | Greenwood | Charmwright | Ask before pruning shared roots |
| Herbkeepers Common | Woodland | Greenwood | Apothecary | Share labeled cuttings |
| Glasswater | Caravan | Wastes | Charmwright | Shade water vessels and offer guests water |
| Clockwork Ward | Caravan | Wastes | Smithy | Let a human caller announce meetings when clocks disagree |
| Pilgrim Court | Mushroom | Greenwood | Shrine | Welcome different remembered faiths |
| Orchard Commons | Mushroom | Greenwood | Bakery | Leave harvest for late arrivals |
| Aurora Watch | Winter Hearth | Frostlands | Outfitter | Wrap bells for overdue travelers |
| Bellkeepers Hearth | Winter Hearth | Frostlands | Smithy | Unwrap bells on their return |

The sixteen further additions are Rainwood Street, Reedpaper Court, Jadebeam Court, Porcelain Exchange, Warmstone Village, Moonjar Commons, Harvestmask Hollow, Candlewake Borough, Evergreen Hearth, Giftmakers Square, Neon Relay, Chrome Bazaar, Spellbinders Ward, Observatory Court, Dewbell Commons and Petalweave Court. The [theme guide](TOWN_THEME_EXPANSION.md) maps all sixteen IDs to their separate inspirations and supported exterior details.

Crossroads Town, Market Town, Woodland Commons, Caravan Town, Mushroom Common and Winter Hearth remain selectable. The safe starting settlement retains its existing Crossroads identity. The additional themes express communities with traditions from former worlds, following the Endless World's collapsed-multiverse setting and the Milewardens' practice of recording local accounts.

## Generation contract

`config/town_types.json` holds versioned definitions. `scripts/town_types.gd` validates base/climate eligibility, whole positive selection weights, supported business IDs, four quarter pools, colors, permitted appearance overrides, crop shapes, bounded civic geometry and the eight supported theme/exterior-style IDs. Each parent gets two baseline tickets plus the weights of its eligible themes. Grain Commons has two tickets; the other added themes have one. Local climate narrows the pool. No theme requires a bridge, coast, mountain pass or other unverified geographical feature.

Selection uses an independent seed derived from the actual city ID after primary town, ruin and road generation. The plan exposes:

| Field | Meaning |
| --- | --- |
| `city.id`, `city.name`, `city.cell` | Existing actual instance identity, name and location |
| `city.archetype_id` | Existing parent template; current facet, construction and asset eligibility selector |
| `city.settlement_type_id` | Selected stable authored identity, including the six baseline IDs |
| `city.settlement_type_name` | Display name used on the town label |
| `city.local_trade` | Added theme's descriptive trade; specialist stock follows the actual store rules |
| `city.theme_id`, `city.exterior_profile` | Optional cultural/festival/fantastic category and decorative style/colors |
| `city.quarters` | Actually occupied infill neighborhoods with theme names |
| `city.magic.profile_id` | Existing baseline charm ID or `<settlement_type_id>:charm` |

Theme application retains primary foundation IDs, footprints, heights, doors, supported interior types, residents, book IDs, streets, tower, well, lot IDs/positions and ruin identity/placement. Primary roof and wall appearance can change. Additional infill uses the existing independently seeded, connected placement planner, with a charmwright and the theme's signature business required. Trades use the existing home/shop/inn/workshop/shrine handlers; bespoke stock, prices, farming, machines, performances, religious mechanics and new quest handlers are not supplied by these labels.

Generator edition remains 4, save envelope remains 2, and no save root, migration, importer pass or world deletion is added. New infill and appearance are regenerated from the seed. Existing accepted quest/history records and ownership remain bound to actual instance IDs. The existing safe-footing recovery still applies when additive infill occupies previously open ground.

## Coordinated ownership

Townwright owns the definition/selection layer, narrow World attachment, town-label fallback and focused tests. Lorekeeper reviewed the identities and supplied all twelve ordinary customs; Lorekeeper owns player-facing lore/index/politics expansion. Local stories remain separate from future politics and war mechanics.

Aster and Surveyor retain coherent environment/NPC family selection and construction recipes. Current architecture can consume the theme fields; its actual rendered bounds supply the height/footprint context for trim and roof lights. Local decorative meshes follow the owning block/faceted family through [DecorGeometry](LOCAL_DECOR_FAMILIES.md). Crop shape/color remains available to the native fallback; imported farm ensembles follow their actual selected recipe. Distinct crop data does not certify twenty-eight new farm arrangements. Transparent glass walls, great roots, full heritage streets, mechanical systems and speaking lamps remain later art/gameplay work.

Wren retains source-object registration/provenance; market/farm IDs, kinds, footprints, solid cells and construction part selectors stay stable. Wayfarer's watch/law/trade contracts retain actual city IDs. Compass and Rowan retain discovery/quest/history ownership. Flint retains furnishings and stacking. The future independent-site planner can reuse this identity layer after constructing a supported actual town plan; it must provide truthful climate/feature eligibility for any later bridge/coastal/castle themes.

## Checks and previews

`tests/test_town_types.gd` samples 484 town plans, requires reachability of all thirty-four identities, rejects malformed definitions, checks eligible climate/signature trades/lot IDs, regenerates one instance per identity and checks physical access to doors, lots, books and residents. It also builds every civic form and exterior style, checking their bounds and node budget. `tests/test_town_magic.gd` retains the pre-density primary-foundation/door/street/ruin fixtures.

`tests/test_town_types_game.gd` uses Rainwood's real resident and scribe entrance, reads its actual custom, checks streamed exterior meshes and disk-restores its identity/profile through an isolated journey. `tools/capture_town_types.gd` renders all twenty-eight additions from opposing views, sixteen exterior detail views and a real themed charm reader. Preview saves live under `artifacts/town-types-preview-saves`; player settings and records use isolated paths.

Run the two new tests with `./godot.sh --headless --script tests/test_town_types.gd --quit-after 600` and the corresponding `tests/test_town_types_game.gd` path. Run the capture helper without `--headless`. These checks cover the authored identity layer; the shared full checker and longer player visits remain separate evidence.

The first eighteen-identity snapshot passed the two new tests, primary-anchor/density/magic test and interior, NPC-family, landscape and 128-region physical-route regressions. The thirty-four-identity expansion passes the expanded plan/access/bounds test and actual themed Game/disk test; native output covers all twenty-eight additions and sixteen exterior details at 1280x800. Surveyor's later family/actual-support acceptance is recorded in the local decoration guide. No complete shared-suite run is certified by this lane while other agents continue their separate runtime/authoring changes.
