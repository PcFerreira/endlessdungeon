# Discovery geography acceptance brief

Surveyor, 2026-10-13. This brief records the user's requested next geography and the evidence needed to accept it. It is not a claim that the current generator implements these changes. Ownership and shared-file contracts follow `chat.md`.

The player should find irregularly spaced settlements and independent destinations with different purposes and silhouettes. Town-free areas must exist. Dungeons cannot always appear as a pair beside the nearest town. Ruins, castles, churches and temples must be composed locations with supported approaches and enough related details to feel occupied or formerly occupied.

## Placement and travel

The current generator places a town at the center of every 128-cell region. Each town owns two ruins at opposite diagonal offsets of 16 to 24 cells per axis. Roads connect cardinal town neighbors, and ruin approaches branch at right angles. The 324-region audit confirms the repeated 32-to-48-cell Manhattan ruin distance. Increasing the region width alone preserves this pattern.

Use deterministic irregular candidates with variable occupancy and gaps, then enforce clearance between actual footprints. Planning cells can remain an implementation tool; their centers and borders must not become a visible settlement grid. Allow several kinds of destination and genuinely quiet areas. A site must keep its identity and layout when approached from another direction or loaded after its neighbors.

Choose dungeon locations in a separate placement stream using terrain, family and approach suitability. They may be associated with a castle, temple, ruin or local story, but no town is required. Avoid imposing a replacement rule that every non-town location owns the same number of dungeons. Plan landmarks and routes around actual locations rather than inventing endpoints to fill a quota.

Roads should connect real destinations through traversable terrain. Jittered town positions require routes that can change both axes; the present axis-only planner cannot be reused unchanged. Use canonical ownership for shared crossings and bridges. Keep neighboring-plan searches bounded and avoid recursive dependence on which region loads first. Negative and far coordinates must use the same deterministic rules.

## Location purposes

| Location | Functional composition | Discovery and access evidence |
| --- | --- | --- |
| Town | Connected homes and businesses, supported market goods, crop rows, civic center, residents and coherent NPC family | Usable doors/streets, actual merchant/book/resident interactions and a distinctive approach |
| Ruin | Broken structure, surviving room fragments, related debris and traces of former use | Recognizable silhouette, reachable interior/clearing and a clue bound to a real source or target |
| Castle | Gate, enclosure, courtyard, keep and defensible/service spaces | Entrance and return route, substantial footprint and supported room functions |
| Church | Nave, seating, altar and keeper/archive context | Accessible entry, visible gathering/worship arrangement and supported reading or resident context |
| Temple | Processional approach, courtyard, ritual focus and supporting chambers | A distinct reveal, actual approach and clear purpose for ritual/architectural elements |
| Dungeon entrance | A setting appropriate to its family, entrance cues and usable descent | Physical access, independent site identity, finite floor/return contracts and contextual coin/item rewards |

These are minimum composition briefs, not invitations to claim unavailable behavior. A visible altar does not establish a new ritual handler, and a castle model alone does not establish a castle location. The owner must select supported interactions and record any intentionally scenic-only site behavior. Reuse existing assets through explicit contextual recipes, with source/license records preserved.

## Identity and coherent styles

Select one environment family for each biome before choosing tree, shrub, rock and ground-detail variants. Recipes and fallbacks must respect it. A missing voxel tree must not introduce an ordinary 3D tree into that palette. Source packs may contain multiple styles; explicit family metadata should describe the supported series.

Choose one compatible NPC family per actual town, shared by residents and local guards. Broad random NPC families belong to roads/open spaces. New castles, churches and temples need deliberate local palettes and residents if supported. They must not appear as renamed copies of the town template.

Bind names, histories, quests and reliable directions to actual site IDs. Use locally distinguishable labels where a passage claims a name identifies a destination. Retain already resolved journal text/editions. A town-free area cannot supply a phantom town ledger or resident. Collections and requests should omit unsupported sources or bind to a real nearby settlement through an explicit relation.

## Consumer and save contracts

Publish the actual-site, nearest-settlement, road-endpoint and ownership queries before changing shared consumers. `region.city` presently supplies terrain plateaus, sanctuary, routines, merchants, guards, animal homes, discoveries, histories, quests, HUD and map labels. Adapt these callers for town-free regions rather than leaving an artificial city record in every cell. Town safety and theft jurisdiction apply only to actual settlement footprints.

Portable items use stable location scopes and support-linked UIDs. Dungeons, castles and ruins must remain distinct from the nearest city's ownership unless a real relation is defined. Required stairs, gates, doors and quest anchors remain protected. Terrain/site changes need an explicit generator/save decision; independent review must not reset the user's journey as a side effect of testing.

## Evidence required

Generate multiple seeds over positive, negative and far coordinates. Record actual town nearest-neighbor distances, town-free planning areas, location-kind frequencies, dungeon-to-town distances and repeated approach patterns. Inspect the distributions; an irregular-looking screenshot does not establish irregular spacing, and a jittered candidate in every cell does not establish variable occupancy.

Walk to every sampled destination using the real character footprint, including seam crossings, slopes, bridges, doors and return paths. Repeat after cache eviction and reverse region loading. Verify no unsupported sources, duplicate unique rewards, inaccessible monsters or foreign-town ownership. Run save/load, Sanctum return and existing route/gameplay checks against the completed integration.

Render every new location kind from opposing approaches at gameplay zoom. Review silhouette, coherent density, environmental family, local NPC family and the sequence in which cues become visible. Compare routes that pass different combinations of sites, with quiet intervals between composed destinations. Player testing must establish whether these journeys produce discovery and remembered differences; connectivity and content counts alone cannot prove that experience.
