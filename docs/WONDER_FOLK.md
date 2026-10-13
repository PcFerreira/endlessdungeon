# Wonder folk and creatures

The first eight original characters from the [Adventure Time character research](../lore/research/adventure-time-character-pools.md) have distinct animated voxel bodies and runtime definitions. Their names, histories and geometry belong to the Endless World.

## Wilderness residents

| Resident | Appearance | Where to look | Interaction |
| --- | --- | --- | --- |
| Clay Herbalist | Broad clay vessel, leaf apron and herb bundles | Greenwood, Sunlit Meadows and Mooncap Grove | E opens conversation. Trade opens a provisions pack that buys clean gathered materials. |
| Moss Listener | Branching woodland hood and seed satchel | Greenwood, Deepwood and Emerald Jungle | E opens conversation about work and nearby paths. |
| Lantern Peddler | Long-necked birdfolk carrying lamps | Amber Wastes, Sunwash Coast, Windscar and Amberleaf | E opens conversation. Trade opens a general market pack. |
| Scrap Fencer | Asymmetric repaired construct with a sheathed blade | Cinderwaste, Glaslight Tundra, Windscar and Frostlands | E opens conversation about old repairs and nearby paths. |

The residents walk and rest on supported open ground within their wilderness area. Eligible encounters can select a Wonder resident or retain an ordinary wanderer. The four-roamer budget stays in place. These citizens remain outside enemy targeting and combat. Dialogue pauses their movement.

Trading requires a close, grounded approach with a clear line of sight and no nearby danger. The two supported traders use the existing buy/sell buttons, inventory capacity, clean-ownership rules, finite stock and coin purse. Selling gathered materials transfers actual goods and coins. Workshop repairs, training and quests are not offered by this first batch.

## Wildlife and enemies

| Creature | Appearance | Habitat | Disposition |
| --- | --- | --- | --- |
| Dew Jiggler | Low jelly body, stalks and a dew bead | Dry meadow, fungal and greenwood habitats | Peaceful ambient wildlife. It grazes and wanders without an enemy health bar or combat reward. |
| Rime Rooker | Squat walking bird with a stepped ice crest | Dry Frostlands and Glaslight habitats | Peaceful ambient wildlife. It uses supported ground movement. |
| Bog Mossback | Broad mossy shoulders, reed beard and heavy feet | Reedfen, Deepwood and Greenwood creature grounds | Neutral until attacked, then retaliates and returns within its encounter grounds. |
| Choir Husk | Narrow skeletal body and visible bell chamber | Hallowwood grounds, Ashen Crypt and Verdant Tomb dungeons | Hostile. A slow windup precedes its ordinary ranged attack. |

Peaceful wildlife uses WorldLife rather than the enemy list. The Mossback and Husk use ordinary targeting, combat, loot and defeated-encounter persistence. Autonomous companions ignore unselected neutral creatures; explicitly attacking a selected neutral can start combat. No special possession, transformation or choir-buff mechanic is implied by the new bodies.

Expanded-biome surface enemy selection uses the actual ground-cell ecology in editions 6 and later. Older edition4/5 surface selection retains its original pools. Saved enemy species and body descriptors retain their selected identity. Existing dungeon families can select the Husk through their ordinary content pools.

## Art and persistence

All eight bodies have grounded Idle, Walk, Wave and Attack clips, with deterministic appearance variants. Block biomes use cubical geometry; faceted biomes use actual chamfered faces. Animation, appearance and population selection preserve combat randomness. The bounded model cache holds at most64 compiled variants.

Wilderness saves retain each resident's Wonder identity, physical point and existing route state. Legacy records without a Wonder identity remain ordinary residents. Wildlife retains its species and model source across disk and home trips. Enemy descriptors retain the body variant and visual family; accepted defeats stay defeated. Portable trader stock and purses are saved under stable encounter-specific IDs.

This batch populates the native procedural wilderness, including the lands reached through Lanternwake's Worldgate on a fresh journey. The four residents and their portable shops stay outside the reserved hub island. Authored Morrowmere residents, schedules and encounters continue through its separate population controller. The first batch does not replace that world's existing people or inject procedural wildlife into its authored provider.

## Authoring and checks

[config/wonder_folk.json](../config/wonder_folk.json) defines the four NPC occupations and four creatures. [scripts/wonder_catalog.gd](../scripts/wonder_catalog.gd) validates references and creates combat/ambient definitions. [scripts/wonder_models.gd](../scripts/wonder_models.gd) builds the eight original rigs. A new ID requires an actual supported body recipe before catalogue validation accepts it.

NPCs enter through WildernessRoamers, ActorModels, WorldLifeView and the existing Expansion conversation UI. Traders use `Stores.open_wonder` and the ordinary transaction pipeline. Wildlife uses the existing habitat slots and saved animal records. EnemyCatalog appends the two combat definitions after existing source kinds, and MonsterAreas supplies the actual ecology to the surface selector. Generated bodies can still be replaced through the content editor's imported visual mode.

Focused checks:

```sh
./godot.sh --headless --script tests/test_wonder_models.gd --quit-after 600
./godot.sh --headless --script tests/test_wonder_npcs.gd --quit-after 600
./godot.sh --headless --script tests/test_wonder_creatures.gd --quit-after 1200
./godot.sh --headless --script tests/test_wonder_hub_game.gd --quit-after 600
```

The comprehensive fixture writes natural encounter examples into an isolated `artifacts/wonder-folk/check-*` folder. Use its `examples.json` with `tools/capture_wonder_folk.gd --fixtures=<path>` for the native gallery. Capture saves and settings are isolated from the player's files.

Focused headless checks pass for all eight bodies, natural encounters, dialogue, both traders' material sales, peaceful targeting exclusion, neutral retaliation, hostile combat and disk/Sanctum persistence. The NPC fixture also checks actual populations in editions 4, 6 and 7, and restores both visual families and unmarked ordinary residents in edition 7. Fresh journey checks use physical Worldgate departure while retaining HubWorld, then test resident allocation, both traders and reserved-island exclusion. Existing disk-save, dungeon-generation, enemy-descriptor, merchant and creature-style regressions pass. These results cover the focused checks rather than the full repository suite.

The local [native contact sheet](../artifacts/wonder-folk/capture-1351813/contact-sheet.png) contains 27 reviewed views at 1280 × 800: both geometry families from opposing angles and in motion, all four residents and dialogues, both merchant sales, peaceful wildlife, neutral retaliation, hostile attacks and an actual crypt encounter. Its manifest records 18 unchanged source inputs and verifies renderer readiness and loading-overlay removal before each world image. Ordinary vegetation obscures parts of two views; opposing views and the standalone gallery show the bodies. The crypt image caught a fractional-health label mismatch, subsequently corrected and checked on the actual selected-target control. The earlier capture with a loading overlay is superseded.
