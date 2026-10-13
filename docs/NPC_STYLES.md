# NPC appearances

Runtime NPC rendering now uses the [voxel character generator](VOXEL_CHARACTERS.md). The imported appearances and source-series policy below describe the retained asset collection and the previous renderer. `npc_styles.json` remains source classification data; ActorModels no longer selects those imported bodies. The current NPC tests and gallery helper paths validate generated characters.

The catalogue includes 32 new complete animated appearances beside the nine existing Cube World and KayKit people. The expansion adds four visual families. Town residents and the town watch share one source series selected from their actual city ID, after filtering by the owning city's biome family. Road travelers select from the wider visitor cohort using their actor identity. Selection is deterministic and does not consume combat RNG.

| Family | New appearances | Sources |
| --- | ---: | --- |
| Kenney blocky people | 11 | Blocky Characters: a, b, e, f, k, l, m, n, o, p, r |
| Kenney miniature townsfolk | 11 | Mini Characters: six female models and male a, b, d, e, f |
| Quaternius rustic people | 6 | Complete Men: Adventurer, Farmer, King; complete Women: Adventurer, Medieval, Witch |
| Quaternius seafarers | 4 | Pirate Kit: Anne, Captain Barbarossa, Henry, Sharky |

These counts refer to distinct complete source bodies. Role charms, palette accents, modular limbs, standalone mobility aids, weapons and alternate file formats do not increase the count. Police uniforms, robots, business suits and the blocky game-controller shirt are outside the runtime selection. Pirate costumes and rustic clothing are curated fantasy appearances; their source names do not assign new lore, government offices or gameplay roles.

`config/npc_styles.json` defines family queries and animation aliases. `config/npc_asset_imports.json` adopts the matching character files through the existing rule-fragment importer. Runtime actors query the published registry; no pack-specific filename branch is needed in actor code. A role without a narrower pool selects another complete body from its selected family. Actor height remains 1.15 units, with the source bounds centered and feet grounded.

Each source series declares `environment_family`. Cube World and Kenney blocky people use `block_voxel`; KayKit, Kenney mini, Quaternius rustic and seafarers use `flat_lowpoly`. `EnvironmentStyles` reads these reviewed series into actual model classification. Local selectors use `family_for(city.biome)` before choosing a town series, and the regression checks `allows(actual_model, biome)`. The watch remains local despite its movement system's `traveling` flag. Existing generated resident/watch sources and WorldLifeView already preserve the actual biome. Legacy direct local callers without a biome use biome 0; generated places must supply their owning biome.

Each optional family `animations` entry maps a gameplay action to an ordered list of actual clip names. The actions currently used are `Idle`, `Walk`, `Wave` and `Attack`. Kenney supplies lowercase clips and a nod (`emote-yes`) for greetings. Quaternius supplies `Wave` and family-specific punch clips. Greetings play once and return to the idle clip. Existing families without alias metadata keep their original animation lookup.

## Sources and licenses

Research and acquisition were performed on 2026-10-13. The official pack pages identify these assets as CC0 and permit personal and commercial use:

- [Kenney Blocky Characters](https://kenney.nl/assets/blocky-characters). The previously staged original pack is now adopted through the NPC import fragment.
- [Kenney Mini Characters](https://kenney.nl/assets/mini-characters). The complete original ZIP is retained in `import_assets/archives/kenney_mini-characters.zip`; its CRC, byte count and SHA-256 are recorded.
- [Quaternius Ultimate Modular Men](https://quaternius.com/packs/ultimatemodularcharacters.html) and [Ultimate Modular Women](https://quaternius.com/packs/ultimatemodularwomen.html). Only the six selected complete `Individual Characters` glTFs are acquired, with original notices and previews.
- [Quaternius Pirate Kit](https://quaternius.com/packs/piratekit.html). Four complete character glTFs are acquired, with the pack preview and atlas.

The Quaternius files come from the public `agentkaerf/FreeModels` mirror pinned at `db3df04d1e4714298a09510b26fb6de6645138a2`. Every downloaded file was checked against its Git blob hash. `SOURCE.json` records per-file SHA-256, byte count, download URL, author, official source and license. The official HTML and CC0 legal text are retained beside the source files. Original license notices are retained where supplied. The importer copies notices and authorship into the runtime packs and `assets/imported/CREDITS.md`, which the existing credits UI reads.

[Ultimate Animated Character Pack](https://quaternius.com/packs/ultimatedanimatedcharacter.html) was also researched. Its author download returned a Google Drive quota page, so none of its advertised 52 models are counted as acquired or available. Fantasy Outfits remains a staged modular clothing source; its incomplete body parts are not counted as NPCs.

## Previous imported-pack workflow

1. Place original assets and license notices in `import_assets`, with a `SOURCE.json` record matching the existing source format.
2. Add a model rule to the NPC import fragment or another registered fragment. Restrict selection to complete bodies and retain their texture/buffer dependencies.
3. Add the coherent source series to `npc_styles.json`, declare its reviewed `environment_family`, set actual animation aliases, and list it under `town_families`, `road_families`, or both.
4. Reserve the shared publication window in `chat.md`, run `ruby tools/import_assets.rb --build`, then index resources with `./godot.sh --headless --editor --quit`.
5. Run `tests/test_npc_expansion.gd` and `tests/test_npc_families.gd`. Review actual native family/appearance galleries before releasing the window.

The previous expansion regression checked that at least 30 new complete bodies were reachable through imported-model selection, then checked source clips and ground alignment. Those imported-model checks are superseded by generated-body, recipe-reachability, limb-animation and save reconstruction checks described in [VOXEL_CHARACTERS.md](VOXEL_CHARACTERS.md). Adding a pack through the retained importer no longer makes it an NPC body.
