# Larger biomes

New offline characters use edition 7. Temperature and moisture retain the one-fifth sampling frequency introduced in edition 6, giving the same climate fields five times their earlier width. Named ecology regions use seeded centers spaced on a 2,560-cell grid, so individual patches have irregular widths. Their 160-cell transition setting measures the difference in distance to neighboring centers; the physical width varies with the boundary geometry. Town planning stays at 128 cells; roads, settlements and independent places retain their separate placement rules. Existing edition-4, edition-5 and edition-6 journeys restore their own physical generation rules.

The fourteen profiles have different ground, soil and rock palettes, vegetation and atmosphere. Edition 7 adds correlated groves, open patches and clearings, with an eight-cell fade from clearing to stand. Seeded focal groups interrupt the vegetation: five-grave memorials with an open approach, cactus groups, mushroom colonies, basalt beside continuous fissures and crystal clusters with smaller nearby shards. Flowers form short ribbons; pumpkins gather at harvest and memorial edges. Wet-edge reeds follow actual water, while coast planting leaves open shoreline patches. Natural dressing avoids actual roads, town plots, independent structures and dungeon entrances.

Dense forest and jungle use distinct original broad crowns with layered foliage. Their trunks occupy one blocked cell; overhang starts at least 2.6 cells above ground in the full-sized bodies. Hallowwood is a persistent haunted region whose pumpkins, bare trees and graves do not depend on the calendar. Coast follows actual water margins, so its shoreline band remains local rather than filling an inland ecology zone. Its palette and vegetation mixture fades toward the inland ecology using the existing continuous terrain height field, before terrain is rounded into steps. Water and general terrain heights retain their existing rules. Edition 7 changes wilderness prop collision and levels accepted small construction plots by at most half a cell; older editions keep their original occupied cells and heights.

The larger regions contain 28 [micro-biome pockets](MICRO_BIOMES.md) with persistent material caches and eight [wild construction types](BIOME_LANDMARKS.md) with stories, supplies and safe wells. Their approaches avoid roads and existing sites. Fungal nurseries and fairy rings use small colored mushroom caps around an open cache core; larger caps remain at the edges.

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

`config/biome_composition.json` controls patch size, clearing radius, occupied versus open densities, understory and focal arrangements for all fourteen profiles. `BiomeComposition` computes plain data from seed and global coordinates without changing gameplay RNG or retaining unbounded patch caches. Grove density blends across the same ecology mixture as terrain. Clearings and arrangements cross streamed chunk boundaries without restarting at chunk edges.

`config/biome_atmosphere.json` gives every named ecology its own restrained ambient and sunlight tint, existing licensed sound pools and bounded motes. Light and energy blend over time and across biome mixtures. Water and town audio, dungeon/interior lighting, authored realms, mute settings and weather keep their existing authority. The runtime retains two bed voices, four cue voices and at most six motes; it adds no fog shader or extra render pass.

`config/biomes.json` controls size, transition width, profile weights, palettes, density and details. `BiomeCatalog` selects coherent seeded ecology regions, blends palettes and vegetation at boundaries, and validates the transported profile identities. Smooth proximity weights also handle corners where several regions meet. Mixtures use sixteen weight units for stable palette caching; density, detail frequency and plant selection follow the same mixture. Numeric climate IDs 0 through 3 remain the inputs to existing species, loot, building families and character palettes. The named ecology is an additive `biome_id`, accompanied by transition data. NPCs and dungeon monsters keep their separately requested generated voxel renderers.

`config/biome_art.json` defines twenty nature roles and their actual source choices or native geometry. `BiomeModels` preserves imported source identities and records the rendered family and representation. Giant mushrooms, reeds, fern-like growth, basalt and fissures have explicit native bodies. Trees, pumpkins, graves, palms, bamboo and crystals use actual registered sources where suitable. Native giant mushrooms replaced initial imported derivatives whose enlarged shapes did not read clearly as mushrooms. One white autumn derivative was replaced with a gold source variant. Source files remain intact.

The dedicated biome cutaway material preserves source color, metallic, specular, roughness and UV settings. It keeps the player visible behind tall foliage. Emissive fissures retain their material. Terrain cache keys include the ecology palette; live terrain meshes and biome template references remain bounded while streamed chunks keep their own resources.

Existing saved worlds keep their edition. New-character creation explicitly selects `World.NEW_JOURNEY_EDITION`; the low-level `World.generate` and debug `Game.start_run` defaults remain edition 4 for existing callers. The first Begin Journey flow enters Lanternwake, and its Worldgate leads to the same edition-7 natural world. Shared clients receive server-owned terrain records. Existing persistent server worlds remain pinned to their stored edition; a fresh shared world can explicitly select edition 7 after its coordinated manifest build.

## Acceptance

Focused checks cover fivefold climate-coordinate scaling, all fourteen generated profiles, clear actual connected roads, exact site ecology, transition sampling, eighteen role bodies in both geometry families, seed-bound clue and traveler compatibility, and old-save byte preservation. The coastal correction has its own actual dry-shore regression: 28,363 neighboring naturally dry land pairs, scalar coastal mixtures, cold coastal prop selection and legacy terrain/water/ecology checks including actual cell records. Cold shoreline plants use conifers even where the coastal mixture is secondary to an inland profile. Its largest measured ground-color distance is 0.07349, compared with 0.44091 before the correction. These are sampled limits, not a proof over every seed. Actual Game checks from the original expansion stream every profile, inspect rendered family identities and bounded caches, and restore edition-6 terrain through fresh disk and Sanctum return. The new-character check follows actual first hub arrival, fresh hub reload, physical Worldgate departure and an unchanged legacy slot reload.

`tools/capture_biomes.gd` records the earlier fourteen generated locations from opposing cameras in `artifacts/biomes`. Its `points.json` stores the real player cells and ecology records. `tools/capture_biome_bodies.gd` compares mushroom and autumn bodies directly with production batching. Those 28 reviewed views predate the coastal correction. The junction fixture covers 400 adjacent samples and limits its largest measured ground-color jump to 0.027. The current body matrix covers 240 cases and 79 role, family and source selections, including the new broad crowns.

The edition-7 composition review in `artifacts/biome-composition` records all fourteen ecologies from opposing cameras: 28 actual Game views with identical before/after hashes for 45 source inputs, completed render warmup and visible gameplay UI. Both directions were reviewed. Dense forest and jungle have open centers enclosed by broader crowns; haunted, fungal and crystal regions show coherent groups. Coast uses an actual Tide Garden beside existing water. Frostlands lighting was reduced after a rejected diagnostic: its floor remains bright, but terrain edges and shadows are readable in the final views. The separate `artifacts/biome-coast-gradient-review` shows the actual dry-shore palette fading across nine weights from inland ground to sand.

Focused edition checks replay 300 complete pre-composition edition-6 cell records exactly, retain edition-4 and edition-5 loading, and exercise edition-7 transport through the actual server worker. Actual Game checks stream all fourteen themes, inspect renderer families and cache bounds, and carry exploration through fresh disk loading and Sanctum return. These checks and selected native views do not establish ordinary expedition pacing, stutter-free rendering or full combined browser/server acceptance.
