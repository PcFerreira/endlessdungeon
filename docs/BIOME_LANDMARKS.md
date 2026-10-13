# Wild constructions

Edition 7 adds eight kinds of small construction to natural wilderness clearings. The fourteen biomes choose from weighted pools: haunted ground favors tombs, highlands favor watchtowers, and fungal or crystal regions favor mage towers. Every kind has original block and faceted geometry, biome colors and an open approach.

| Construction | Exploration use |
| --- | --- |
| Weathered Monolith | Read an inscription and retain its story in the field journal |
| Wayside Well | Rest at an open stone basin with a windlass; restore health and mana on safe ground, including with a full backpack |
| Abandoned Watchtower | Search an old supply cache |
| Secluded Mage Tower | Search a former study cache beneath a roof with colored windows |
| Wayside Tomb | Search an offering cache through a clear alcove |
| Ruined Cottage | Search household supplies inside broken walls |
| Forgotten Shrine | Read the site's story |
| Ruined Arch | Record the remains of an old passage |

Press E at the doorway or reading point. Supply caches give two to four existing biome materials and twelve to twenty-four owned gold coins once. A failed backpack insertion rolls back both rewards and keeps the cache unclaimed. Stories and well visits record no currency or skill rewards. Well recovery is repeatable while the existing safe-ground rule permits rest. Discoveries and visits persist through the existing Exploration snapshot, disk loading, Sanctum visits and Worldgate returns.

Plots occupy five or seven cells on each side. Every plot cell must be naturally dry, outside roads, towns, independent structures and entrance margins, and within half a cell of the highest plot floor. Generation levels only the accepted plot to that height, removes vegetation from its footprint and entrance, and blocks the exact cells occupied by walls or plinths. The door and two approach steps remain clear. Foundations extend below the ground; roofs and arches keep standing clearance over open cells. These are surface landmarks; towers and tombs do not add separate interiors or climbable floors.

Landmarks use a quarter of eligible active composition features after excluding micro-biome candidates. They preserve the natural pockets' identities and layout opportunities. The authored Lanternwake island, finite realms, shared clients and editions 4 through 6 keep their existing physical rules. Edition-7 wilderness outside Lanternwake remains eligible after actual Worldgate departure.

`config/biome_landmarks.json` contains the eight physical blueprints, parent-biome weights, descriptions and reward pools. `BiomeLandmarkCatalog` computes supported plans using plain terrain data. `BiomeLandmarkModels` builds the matching geometry, and `BiomeLandmarkExploration` handles discovery, interaction and the journal. Runtime limits are six visible construction models, thirty-two model templates, thirty-two cached world plans and 4,096 recorded identities. The journal displays the latest 64 discoveries while retaining every visit.

Catalogue checks pass 5,028 assertions, all eight actual generated kinds and matching plans from separate worker instances. Physical checks pass 2,262 assertions, including actual wall rejection, reachable doors, negative chunk boundaries, inherited HubWorld wilderness and bounded plan retention. Original geometry checks pass 7,792 assertions for both families, exact solid masks, door clearance, opposing cache states and retained live meshes through template eviction. The well's water bowl has an unobstructed opening, tested with actual mesh rays after replacing its broad canopy with a slender windlass.

The final actual Game fixture has a clean exit and 37 unchanged source hashes. It covers every kind, all four cache rewards, backpack rollback, story panels and reopened journal entries, safe full-backpack wells and refusal near an actual enemy. Claims survive fresh disk loading and actual Sanctum/Worldgate travel, and saves without the optional landmark ledger still restore. The 300 pre-composition edition-6 reference cell records remain exact. These results are focused checks rather than a full combined acceptance run.

An actual journal-layout regression checks all eight generated names and complete descriptions after container layout at 1,440 by 900. Plain full-width rows and wrapped descriptions eliminate horizontal overflow; the final scroll range equals its visible page width. Landmark labels remain visible through construction walls only within their normal nine-cell display range.

`artifacts/biome-landmarks/native-seed91` contains 32 reviewed current native Game views: production hub start and actual Worldgate departure, opposing cameras for every kind, actual story panels, cache receipts, well recovery and both ends of the field journal. The capture has 53 identical before/after source hashes, completed warmup, clear gameplay UI and exact actual E results. Water and windlass are visible from both well angles, tower names remain readable through walls, and journal stories wrap without horizontal clipping. An earlier source-stable gallery exposed those presentation defects and is archived separately in `native-before-readability-fixes-seed91`; the current gallery includes their corrections. These are selected views, not a performance benchmark or a Windows export validation.
