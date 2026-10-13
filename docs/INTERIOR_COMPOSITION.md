# Interior style and composition

Town interiors inherit the real owning city's biome. `Interiors.describe` supplies it on entry and exact house reconstruction. Empty town records return no target or resolved interior. The existing five interior types, ten layouts, original fixture indices, doors, reader/rest points and business approaches remain authoritative.

`InteriorArea` filters actual model candidates through `EnvironmentStyles` before selecting a variant. Compatible saved variants retain their IDs. A saved model from another biome family or an incompatible object role is replaced by a matching choice. Missing compatible sources use the same-role native model. Original fixture source keys and positions remain stable; this changes presentation without deleting held items or removed-source masks.

`config/interior_dressing.json` adds materials to authored tables and workbenches and defines household, inn, shop, workshop and shrine ensembles. Use-specific contents support scribes, apothecaries, smiths, bakers and charmwrights. Materials sit on their actual table or plate with named support links. No restoration effect, stock or drop eligibility is inferred from decorative shape.

New data-defined room types can choose an existing `dressing_type`. The catalogue rejects unknown explicit profiles. Types without a matching profile use the configured `default_type`, currently `records`: reference shelves and a study desk serve their fixed reader. The fallback retains authored furniture and reader access, and follows the same density, support and biome-family rules.

Additional groups append after the original fixtures. They include refreshment/work/offering centers with nearby seats and supplies, plus wall-side stores and records. Work centers are capped; room density targets one solid fixture per ten floor cells, up to twenty-four. Supported contents add detail within those footprints. This is a physical generation rule, rather than an immersion score.

The planner rejects overlaps, unsupported companions and any added group that disconnects the remaining floor. It protects the real exit, reader approach, rest point and configured trade counter. Original layout furniture stays in place. Family-aware floor/wall geometry retains the interior's original colors; fixed books, lamps and exit mats use the same family.

`WorldItems` publishes actual model/family identity and stable source/support keys. A support cannot be taken while its materials remain. Individual goods keep town ownership, theft, removed-source masks, disk restoration and restitution. Existing stock specialties and transactions remain under the store controller.

## Evidence

The focused regression covers 160 interiors: every layout, all four biomes and four identities. It checks replay, original source indices/positions, density, actual selected and rendered family, support containment/contact, model bounds and physical exit/reader/rest/trade access. It rejects invalid supports, off-surface supplies and incompatible saved object purposes.

The integrated `test_world_content.gd` extension fixture also creates a future archive through data, verifies reader-bound dressing and density, and rejects an unknown explicit profile. Its original missing profile caused a dictionary-key error despite printing PASS; the corrected focused log `/tmp/endless-surveyor-integration-future-room-final.log` is clean. Whole-checker acceptance remains separate.

The actual business fixture runs in all four climates and checks real door entry, protected trading, support-first pickup refusal, individual theft, fresh-scene masks/ownership/RNG, restitution, Sanctum carry and exact outside return. Original interior, portable/base, finite-store, contextual-placement and dungeon-style groups are separate integration evidence.

`tools/capture_interior_styles.gd` renders all ten layouts in both biome families from opposing cameras at actual per-room gameplay zoom: forty images in `artifacts/interior-style-*.png`. Representatives of every interior type were reviewed. The first edge-only composition left large centers sparse; final captures supersede it with coherent floor groups and stronger density. Logs use `/tmp/endless-surveyor-interior-*`.

Creature, reward/placed-item and town-decoration family evidence is recorded in [Creature families](CREATURE_FAMILIES.md), [Item families](ITEM_FAMILIES.md) and [Local decorative families](LOCAL_DECOR_FAMILIES.md). The full world-building goal remains active: independent-place final acceptance, sparse lore binding and ordinary discovery journeys still require review. Interior checks cover their own generation and interaction contracts.
