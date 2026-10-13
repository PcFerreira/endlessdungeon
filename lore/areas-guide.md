# Area guide for the Endless Realm

Status: draft content and implementation brief. Scope: documentation in `lore/` only. The coding agent owns game changes. None of the new area types below are implemented by this guide.

The Endless Realm contains ordinary farms, trade towns, old crypts, and places whose inhabitants live by stranger customs. A road can lead from a grain market into a district of living pottery, then past a pale grove toward an abandoned star observatory. Travelers remain in the same continuous world.

## Catalogue

| Catalogue | Area types | Contents |
| --- | --- | --- |
| [Surface areas](areas/surface.md) | 16 | Four existing biomes and twelve distinctive districts |
| [Generic cities](areas/cities-generic.md) | 8 | Reusable settlements built around ordinary work and travel |
| [Themed cities](areas/cities-themed.md) | 16 | Communities with distinct materials, customs, and local wonders |
| [Dungeons](areas/dungeons.md) | 24 | Three existing themes and twenty-one additional dungeon families |
| [Transitions](areas/transitions.md) | 8 | Physical approaches between neighboring area identities |

There are 72 archetypes in this catalogue. An archetype can have many separately named instances. A unique historical person or event needs its own stored identity; selecting the same archetype does not duplicate that person or event.

## One realm with many facets

People call a place with an unusual local character a facet. A facet has geography, residents, resources, and routes to its neighbors. Its size can range from a clearing to a district spanning several regions.

The Unfinished Dawn is one proposed explanation for some facets. Other places developed through natural history, long habitation, old enchantments, or deliberate construction. Their inhabitants disagree about origins. This catalogue does not establish a literal former multiverse, prove that the Dawn created infinity, or require portals between towns.

The common foundations are stable geography, shared roads, sanctuary hospitality, and the practical limits of adventuring magic. Local variations should be visible and discoverable. A facet's broad theme does not silently alter movement, combat, time, death, or resource costs.

Give unusual communities everyday needs. A glassworker buys grain. Potfolk commission repairs. An observatory town needs somebody to clear snow from its steps. Their exchanges with ordinary towns make the wider world feel inhabited.

## Current source baseline

Guide edition: 2026-10-13. The project source inspected during this pass contains:

- Greenwood, Sunlit Meadows, Amber Wastes, and Frostlands, plus layered height generation.
- 16-cell chunks and 64-cell regions, with one compact sanctuary city and two independently seeded ruin entrances per region.
- City houses, fountain, tower, banners, containers, decorative citizens, roads, bridges, and ruin arches.
- Finite dungeons of 1 to 20 floors, generated rooms and corridors, discovery fog, wardens, descent gates, and a final reward chest.
- Crypt Skeleton, Sanctum Invoker, and Tomb Shade enemy kinds; Mage, Sword, and Spellsword classes.
- A rotatable orthographic camera, jumping, journey capture/restore, save slots, and autosave code.

These are source observations. This lore pass did not run the game or validate the other agent's changes. Older research notes may describe earlier camera or save limitations; use this snapshot and the current checkout when planning implementation. Dialogue, readable books, new creatures, and area-specific mechanics still require their own support.

The three underground themes currently follow floor depth. They are not persistent dungeon-family assignments. Most cities share one modular arrangement. Adding an archetype therefore means more than assigning a new display name.

## Reading each area entry

Every entry provides an `Area ID`, placement, visual and spatial instructions, local life or encounters, a discovery to place, and a staged implementation note.

The frequency bands are design defaults, not tested balance:

| Band | Selection role |
| --- | --- |
| Common | Everyday geography and settlements that establish a familiar baseline |
| Distinctive | Strong local identity used repeatedly without dominating every region |
| Exceptional | A rare district or major theme that deserves a deliberate approach |

The build classes identify the first substantial dependency. All classes need coding work.

| Build class | First implementation requirement |
| --- | --- |
| Layout | New composition, placement, palette, or content data using mainly existing forms |
| Art | New environmental or character assets to make the proposed identity legible |
| Systems | New behavior, traversal, hazard, or world-state support for the full version |

An entry's first version can use a simpler representation. Label that representation honestly in development. A recolored grove is not a completed cloud district. Keep future behavior out of dialogue until implemented.

## Proposed area record

| Field | Purpose |
| --- | --- |
| `archetype_id` | One catalogue ID, such as `city_crossroads` |
| `instance_id` | Stable identity of this actual place |
| `area_content_version` | Version of the area definition used for this instance |
| `owner_plan_id` | District, region, or site plan responsible for placement |
| `base_biome` | One of the four existing biome IDs, retained separately from theme |
| `facet_id` | Optional shared district identity, distinct from its archetype |
| `layout_variant` | Selected topology, footprints, and route connections |
| `material_profile` | Actual rendered materials and visual motifs |
| `local_history` | Stored facts linking architecture, NPCs, monsters, and books |
| `available_features` | Interactions and mechanics that this instance actually supports |
| `dungeon_family` | Persistent dungeon identity, independent of display name |
| `floor_sequence` | Stored or reproducible variation within a dungeon family |

These are proposed fields, not a required storage format. Keep mutable progress separate from the place definition. Integrate new state with the existing journey/save design and generator version policy. Do not assume old saves can adopt a changed layout without migration.

## Surface, city, and dungeon are separate choices

A surface district controls the surrounding geography. A city archetype controls settlement identity. A dungeon family controls an actual ruin's underground composition. They can reinforce each other without always matching.

A Glass Heath might contain a common caravan city whose residents avoid the reflective ground. A plain meadow could hold a strange bakery community beside a frightening crypt. A mushroom town can have ordinary foundations beneath it.

For the first implementation, retain one sanctuary city and two ruins per existing region. Apply themed identity to those sites. Do not add extra city or dungeon instances merely because a surface entry mentions a settlement or ruin.

Prefer compact city blocks that fit within the current settlement footprint. Towers, workshops, markets, and civic halls can represent a larger city's ward. Large capitals, continuous megacities, and inhabited interiors are future expansion.

All city archetypes in this catalogue are sanctuary settlements. Keep their fountains and access routes reliable. Invasion, hostile city factions, and removing sanctuary protection are separate game design decisions.

## Selection and adjacency

First filter candidates by base biome, geography, footprint, available art, supported mechanics, and district history. Then choose by frequency band using separate deterministic streams for identity, layout, and decoration.

Suggested initial mix among eligible city and dungeon families: 60 percent Common, 30 percent Distinctive, and 10 percent Exceptional. Surface facets use a different rule: ordinary biome geography remains the default, with optional bounded distinctive patches. Limit each initial district plan to one dominant Exceptional facet. These are starting values for playtests.

If a band has no eligible candidate, redistribute its share to the remaining bands. Unsupported content never becomes eligible because it received a high weight. Reserve a biome-appropriate generic city and an existing dungeon theme as deterministic fallbacks.

Choose coherent clusters. A cloud district can sit on reachable high ground. A glass district fits dry ground or a deliberately recorded magical origin. A mushroom district needs damp terrain. A rare mismatch requires an explicit cause and a transition that communicates it.

| Surface group | Natural city partners | Natural dungeon partners |
| --- | --- | --- |
| Greenwood and damp facets | Woodland Commons, Mushroom Common, Rootbound Ward | Verdant Tomb, Root Chapel, Fungal Cistern |
| Meadows and cultivated facets | Grain Town, Market Town, Breadhearth | Orchard Vault, Banquet Cellars, Abandoned Observatory |
| Wastes and reflective facets | Caravan Town, Glasswater, Amber Garden | Sand Archive, Glass Labyrinth, Amber Reliquary |
| Frostlands and high facets | Passwatch, Winter Hearth, Starfall Watch | Frost Bell Crypt, Storm Conductor, Abandoned Observatory |
| Saltwind Shore in any biome | Bridge Town, Market Town, Caravan Town | Waterworks, Sand Archive, Survey Cellars |
| Any biome with a recorded local cause | Archive Steps, Maskmakers Square, Potters Borough | Unclosed Office, Mask Theatre, Potter's Underworks |

The names in this table are archetype labels. Use generated display names for their instances. Cross-reference the stable IDs in the catalogue, never match behavior by a display-name substring.

## Entry, reveal, and exit

Give every place a readable approach, one distinctive landmark, and a useful relationship with the surrounding routes. Apply the composition rules in [World generation](world-generation.md).

```mermaid
flowchart LR
    Ordinary[Ordinary biome] --> Clue[Small material or cultural clue]
    Clue --> Edge[Readable district edge]
    Edge --> Choice[Choose an approach]
    Choice --> Centre[Distinctive settlement or ruin]
    Centre --> Road[Shared road continues]
```

A transition changes materials, density, architecture, or sound while preserving actual movement rules. A new biome color alone is insufficient. Reserve a normal route through any unusual terrain.

Check landmarks from supported camera rotations and zoom levels. A cinematic approach can favor one direction, but access and interactable recognition must work from other approaches. Consider cutaway behavior, foreground walls, and terrain height separately from combat line of sight.

## Dungeon implementation rules

Choose and retain a dungeon's family at its entrance. Preserve its site seed, finite floor count, defeated enemies, discovery state, and claimed reward identity. The current display names can be reused as flavor; they do not select the family.

Give a family a room vocabulary and spatial pattern. Begin with the existing floor/wall palettes, room roles, and props; later add assets. A long family can alternate subthemes, but its history and architectural motifs should remain recognizable. A short dungeon still needs its entrance, traversal, and final room to communicate the family.

All first versions retain the existing warden-clear progression and final chest rules. New puzzles, peaceful completion, bosses, special loot, moving rooms, and environmental hazards require explicit support. Theme alone never introduces an additional skill-point reward.

The existing enemy kinds are temporary encounter choices where listed. Preserve their real names and behaviors. Do not relabel a skeleton as a new animal and claim that creature is implemented. Reserve entry, return stairs, gates, chests, and spawn clearance before dressing rooms.

## Implementation waves

| Wave | Proposed content | Completion evidence |
| --- | --- | --- |
| 1 | Four base surfaces, eight generic cities, the three existing dungeon families, Survey Road and Boundary Common | Different readable layouts; existing access and progression preserved |
| 2 | Moss Fen, Orchard Belt, Cinder Verge, Pale Grove; Lantern Court, Archive Steps, Winter Hearth; Survey Cellars, Root Chapel, Abandoned Observatory, Waterworks | Shared local facts, room/settlement composition, and appropriate transitions |
| 3 | Remaining distinctive materials, city art, new creatures, and richer themed dungeon kits | Actual identity assets, collision, camera review, and supported interactions |
| 4 | Floating terrain, dream behavior, sound effects with gameplay meaning, moving mechanisms, and exceptional landmarks | Implemented mechanics, save continuity, and deliberate encounter validation |

The whole catalogue remains available for planning. These waves allow broad variety without requiring every proposed mechanic at once.

## Acceptance for the coding handoff

Verify unique archetype and instance IDs, eligibility filtering, deterministic placement independent of load order, connected approaches, boundary ownership, sanctuary access, and dungeon completion on short and long floor counts.

Review material boundaries, city silhouettes, room composition, and clue placement in rendered scenes. Verify that new text references actual placed objects. Integrate new identity and progress fields with save migration before changing existing saved areas.

The guide has document validation only. Asset availability, rendered identity, encounter balance, and enjoyable exploration remain implementation checks.
