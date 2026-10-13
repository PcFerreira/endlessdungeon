# Larger biomes

New offline characters use edition 6. Temperature and moisture sample at one fifth of the previous frequency, giving the same climate fields five times their previous width. Ecology zones use a 2,560-cell spacing, with 160-cell transition bands. Town planning stays at 128 cells; roads, settlements and independent places retain their separate placement rules. Existing edition-4 and edition-5 journeys restore their own generation rules.

The fourteen profiles have different ground, soil and rock palettes, vegetation density and detail pools. Dense forest and jungle have more low foliage as well as taller plants. Hallowwood is a persistent haunted region. Its pumpkins, bare trees and graves do not depend on the calendar. Coast follows actual water margins, so its shoreline band remains local rather than filling an inland ecology zone.

| Profile | Name | Visible features |
| --- | --- | --- |
| `greenwood` | Greenwood | Open woodland, broadleaf trees and scattered undergrowth |
| `meadows` | Sunlit Meadows | Open grass, flowers and occasional stone |
| `desert` | Amber Wastes | Warm sand, cacti and sparse rocks |
| `frostlands` | Frostlands | Snow tones, conifers and pale rock |
| `dense_forest` | Deepwood Forest | Dark moss ground, tall canopy and frequent fern-like undergrowth |
| `haunted_hollows` | Hallowwood | Muted violet ground, crooked bare trees, pumpkins and graves |
| `marsh` | Reedfen Marsh | Damp olive ground, reeds, sparse trees and lilies on actual water |
| `jungle` | Emerald Jungle | Dark green ground, bamboo or palms and broad understory leaves |
| `autumn_woodland` | Amberleaf Woods | Ochre ground, gold and orange trees, occasional pumpkins |
| `fungal_grove` | Mooncap Grove | Cool ground, large purple or pink caps and low woodland growth |
| `volcanic_wastes` | Cinderwaste | Ash ground, basalt columns and glowing fissure details |
| `highlands` | Windscar Highlands | Muted grass, stone clusters and sparse conifers |
| `coast` | Sunwash Coast | Sand along real water margins, reeds, grass and warm-climate palms; cold shores use conifers and the name Frostbound Coast |
| `crystal_tundra` | Glaslight Tundra | Cold blue ground, crystal outcrops and scattered conifers |

## MMO references

The research used official game descriptions to identify recurring visual themes. Blizzard's [Drustvar guide](https://news.blizzard.com/en-gb/article/21757527/battle-for-azeroth-preview-drustvar-visitors-guide) combines a haunted shoreline, mountain passes, a red forest and fungal growth. Its [Nazmir guide](https://worldofwarcraft.blizzard.com/en-gb/news/21797338/battle-for-azeroth-preview-nazmir-visitors-guide) describes swamps, tributaries, encroaching vegetation, ruins, coastline and tar pits. Those examples support keeping wetland, autumn, fungal and haunted regions visually distinct.

Blizzard's [Zuldazar guide](https://worldofwarcraft.blizzard.com/en-gb/news/21701414/battle-for-azeroth-preview-zuldazar-visitors-guide) describes jungle canopy, temples, waterfalls and coast. ArenaNet's [Heart of Maguuma overview](https://heartofthorns.guildwars2.com/game/maguuma/) distinguishes canopy, floor and roots. We used those references for a denser jungle with several plant heights; this implementation retains the game's existing terrain and movement system.

ArenaNet's [Blood and Madness release](https://www.guildwars2.com/en-gb/the-game/releases/october-15-2013/) describes haunted doors, undead, spiders and Halloween creatures. Hallowwood uses an original permanent setting with existing licensed tree, pumpkin and grave assets. Lanternwake is a separate floating arrival hub with its own seasonal decoration.

The profile names and configuration are original project work. Existing source licenses remain authoritative.

## Data and compatibility

`config/biomes.json` controls size, transition width, profile weights, palettes, density and details. `BiomeCatalog` selects coherent seeded ecology regions, blends palettes and vegetation at boundaries, and validates the transported profile identities. Smooth proximity weights also handle corners where several regions meet. Mixtures use sixteen weight units for stable palette caching; density, detail frequency and plant selection follow the same mixture. Numeric climate IDs 0 through 3 remain the inputs to existing species, loot, building families and character palettes. The named ecology is an additive `biome_id`, accompanied by transition data. NPCs and dungeon monsters keep their separately requested generated voxel renderers.

`config/biome_art.json` defines eighteen nature roles and their actual source choices or native geometry. `BiomeModels` preserves imported source identities and records the rendered family and representation. Giant mushrooms, reeds, fern-like growth, basalt and fissures have explicit native bodies. Trees, pumpkins, graves, palms, bamboo and crystals use actual registered sources where suitable. Native giant mushrooms replaced initial imported derivatives whose enlarged shapes did not read clearly as mushrooms. One white autumn derivative was replaced with a gold source variant. Source files remain intact.

The dedicated biome cutaway material preserves source color, metallic, specular, roughness and UV settings. It keeps the player visible behind tall foliage. Emissive fissures retain their material. Terrain cache keys include the ecology palette; live terrain meshes and biome template references remain bounded while streamed chunks keep their own resources.

Existing saved worlds keep their edition. New-character creation explicitly selects `World.NEW_JOURNEY_EDITION`; the low-level `World.generate` and debug `Game.start_run` defaults remain edition 4 for existing callers. The first Begin Journey flow enters Lanternwake, and its Worldgate leads to the same edition-6 natural world. Shared clients receive server-owned terrain records. Existing persistent server worlds remain pinned to their stored edition; a fresh shared world can explicitly select edition 6 after its coordinated manifest build.

## Acceptance

Focused checks cover fivefold climate-coordinate scaling, all fourteen generated profiles, clear actual connected roads, exact site ecology, transition sampling, eighteen role bodies in both geometry families, seed-bound clue and traveler compatibility, and old-save byte preservation. Actual Game checks stream every profile, inspect rendered family identities and bounded caches, and restore edition-6 terrain through fresh disk and Sanctum return. The new-character check follows actual first hub arrival, fresh hub reload, physical Worldgate departure and an unchanged legacy slot reload.

`tools/capture_biomes.gd` records fourteen actual generated locations from opposing cameras in `artifacts/biomes`. Its `points.json` stores the real player cells and ecology records. `tools/capture_biome_bodies.gd` compares mushroom and autumn bodies directly with production batching. All 28 captured views were reviewed, with enlarged checks for mushroom, autumn and volcanic presentation. The final junction fixture covers 400 adjacent samples and limits its largest measured ground-color jump to 0.027. The direct body matrix covers 216 cases and 75 actual role, family and source selections. Current focused logs have clean terminal exits, including remote JSON terrain transport and exact old-save recovery. Scripted captures verify those selected views; ordinary expedition pacing and the separate full browser/server acceptance remain broader review tasks.
