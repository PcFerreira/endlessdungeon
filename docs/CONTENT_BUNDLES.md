# Creature and item bundles

Dungeon enemy rendering now uses [generated voxel monsters](VOXEL_MONSTERS.md). Existing enemy profiles, species IDs, eligibility and loot continue to come from these catalogues. The imported creature visuals described below remain the surface-hostile and peaceful-fauna pipeline and retained source inventory.

Ember added a source-driven catalogue for staged animal, enemy and item assets. `config/content_bundles.json` defines pack selectors, semantic roles, habitat/stat defaults, item effects and source-conversion jobs. The builder emits runtime definitions and exact importer selectors; runtime scripts contain no growing list of asset filenames. Existing content identities and save fields are preserved. This expansion does not change the world generator.

The current catalogue adds 80 enemy profiles and 3,107 collectible item definitions. Its 37 animal records include the nine existing cube-world animals; the living catalogue retains their existing species identities instead of adding duplicate models. Enemy profiles preserve the original ten entries before merging generated profiles. All creatures and items are reachable through their respective habitat, encounter or loot pools.

## Runtime coverage

Enemy sources include all 50 Ultimate Monsters, all nine Cube World enemies, four complete animated KayKit skeletons, twelve converted voxel creatures, four graveyard characters and the rendered skeleton sprite sheet. Skeleton weapon/quiver/arrow/shield pieces are items rather than detached enemy bodies. Existing authored enemy profiles remain available alongside the generated profiles.

Peaceful fauna include Cube World animals, suitable Monster Pack animals, converted voxel animals, both supplied brontosaurus resolutions, the holiday reindeer and all ten supplied FBX animal samples. Fish, dolphin and shark definitions use water habitat cells and water-only routes. Birds use safe local routes above the ground. Animal visuals fit bounded height and width. Local life budgets, NPC activity, offscreen reconstruction and existing saved species/model IDs remain in use.

Items cover weapon models, furniture, food, farm models and matched farm icons, original dungeon/ruins furnishings, survival tools, seasonal props, isometric furniture sprites, individually authored RPG icons and nonempty cells from the six assorted icon sheets and the sixteen-cell crafting-material sheet. Alternate export formats, views and resolutions share logical identities where configured. Atlas cells use stable pixel-coordinate identities and `AtlasTexture` regions, avoiding blank sheet cells as loot.

Equipment uses the existing weapon/armor/charm slots, class restrictions and power/vitality/resource bonuses. Food and potions use data-defined restoration effects and are consumed only when they restore a resource. Materials can be collected and retained; their art does not define crafting recipes. Furnishings use the existing placement support where their item definitions allow it. A 3D item appears as its actual model in world pickups and backpack thumbnails. Icon items use their supplied icon in both places.

Ordinary creature kills always drop one stable gold coin. A JSON policy gives ordinary bag items a 20-percent opportunity and merchant shards an independent 8-percent opportunity. Shards replace the old guaranteed every-second-kill reward. Both rolls reconstruct from the run seed and kill ordinal without consuming combat RNG. Actual enemy identities, biome/facet and dungeon families select explicit source pools for remains, forage, ore, relics, potions, provisions, compatible equipment and arcane gear. Equipment rolls filter the current class. Available common/uncommon/rare tiers use relative weights 82/16/2; missing tiers are renormalized. Uncommon gear uses 12-percent power, 18 vitality or 15 resource bonuses; rare gear uses 18-percent power, 28 vitality or 22 resource bonuses, according to its existing slot/stat. These are initial tuning choices, not a validated long-session balance result.

The complete production kill audit measures coins, shards, ordinary inventory items and instant health/mana orbs separately. Across 36,000 calls spanning three classes, six dungeon families and four seeds, the old cadence produced only 40.5 percent coin-only inventory rewards and 0.6955 noncoin inventory items per kill. The revised policy produces 74.35 percent coin-only inventory rewards and 0.2755 noncoin items per kill. Coins remain guaranteed; all eighteen class/family rows retain their ordinary-item, equipment/material/consumable and resource-orb counts. Coin-only inventory rewards can still emit instant resource orbs; this change does not tune resource recovery, combat difficulty or collection pacing.

Generated furnishings come from cleared final chests, with two additional catalogue furnishings alongside the existing one-time skill point, furnishing, armor/charm and class weapon. Chest selection cycles source bundles and their members. Every ordinary bundled item has an eligible enemy source, and every furnishing is reachable through the chest cycle. Reward choice and chance reconstruct from run seed, kills and actual encounter context without consuming combat RNG or adding a save field. Drops relocate to nearby walkable points when their requested location is obstructed.

## Build and extend

```sh
ruby tools/build_content_bundles.rb
ruby tools/import_assets.rb --build
./godot.sh --headless --editor --quit
./check.sh
```

Register a pack with an honest `SOURCE.json` and retain its supplied license notices. Add JSON rules for its semantic roles. Existing selectors discover additional matching assets automatically; stable IDs derive from pack, logical source identity and atlas cell coordinates, so adding another file does not renumber older content. Use profiles to override habitat, dimensions, combat stats, equipment slot/classes or consumable effects. A malformed or empty selector fails the build rather than silently losing its content.

`config/items.json` holds the eleven original items and their unchanged IDs/effects, plus the stable gold-coin item and retired mixed-material ID for save compatibility. The generated `assets/bundles/catalog.json` adds enemy, fauna and item records. `config/generated_content_imports.json` is included through the main importer's `rule_files`; the environment lane can maintain a separate rule fragment. Both fragments select shared resources once, and the importer follows model buffers, textures and source notices.

Native voxel and Blender/FBX sources are converted to portable GLB files under `import_assets/bundled`. Slab6 indexed voxel files and MagicaVoxel XYZI/RGBA files preserve source color with culled internal faces. The eight objects inside the Voxel Loot Blender file are exported separately, including initially hidden source objects. FBX scenes retain available materials and authored animation. Rigged samples without animation clips export their evaluated bind poses as static meshes so rendered geometry matches placement bounds. Every converted record carries its source path, SHA-256, object name and output hash; each derived pack's `CONVERSIONS.json` is included with runtime source notices.

When a Blender/FBX source changes or a new one matches a conversion selector, provide a Blender executable:

```sh
ruby tools/build_content_bundles.rb --blender /path/to/Blender
```

Blender is only needed during source conversion. Cached conversions and all runtime resources work without Blender installed. Original source bytes are preserved. The official [Blender command-line documentation](https://docs.blender.org/manual/en/4.2/advanced/command_line/arguments.html) describes background execution; the [MagicaVoxel specification](https://github.com/ephtracy/voxel-model/blob/master/MagicaVoxel-file-format-vox.txt) describes its native chunk format.

## Inventory and provenance

`assets/bundles/source_inventory.json` inventories every recognized staged model, image, audio, scene, mesh and model-dependency representation, including sources without registration. It records source path, bytes and SHA-256 plus gameplay, item-icon, converted, alternate, support or outside-creature/item status. Converted records link original source identities to their runtime models. Unrelated terrain, architecture, UI, music and effects remain represented in the inventory without being treated as collectible gear or animals. Missing publisher uploads are not counted as locally available assets.

The supplied animal-sample folder has no publisher identity or license notice. Its provenance record explicitly preserves that absence; it does not invent attribution or licensing terms. Farm assets retain their supplied commercial-use license. All other adopted pack metadata and required credits remain in `assets/imported/CREDITS.md` and each imported pack's source notices.

## Validation

```sh
ruby tests/test_content_bundles.rb
ruby tools/build_content_bundles.rb --check
./godot.sh --headless --script tests/test_content_bundles.gd --quit-after 600
./godot.sh --headless --script tests/test_bundle_gameplay.gd --quit-after 600
./godot.sh --script tools/capture_content_bundles.gd --quit-after 1200
```

Builder tests cover future matching assets, stable IDs, stale-output rejection and voxel face/color data. Runtime coverage checks instantiate every creature/item model, load every item icon/atlas region, verify all fauna eligibility and all generated enemy pools, and traverse the complete item-loot cycle. Gameplay checks exercise collection, consumption, equipment, save/load, enemy rewards, accessible drops and aquatic movement/restoration. The native helper renders every creature and a representative item from every source bundle, then verifies actual backpack model thumbnails. Captures are saved under `artifacts/bundle-*.png`.

Enemy/family pools and rarity live in `config/loot_pools.json`; chance/chest counts live in `config/loot.json`. `tests/test_enemy_loot.gd` checks every ordinary item's source, class filtering, context differences and deterministic rarity selection. The controlled measurement helper is `tools/measure_loot_expedition.gd`, writing `artifacts/loot-expeditions.json`. It uses real default combat and collision from a real dungeon entrance and stops at completion/death or 900 active seconds. Its results measure automated behavior; ordinary human expedition pacing, item usefulness and long-session balance require a separate review.

`tools/measure_kill_rewards.gd` writes `artifacts/kill-rewards.json` using production `Game._hit_enemy`, replacing only rendered rewards/effects with a ledger. `tests/test_kill_rewards.gd` also checks guaranteed coins, majority coin-only inventory rewards in every class/family, bounded total item frequency, unchanged combat RNG, valid shard odds and the absence of an alternating shard cadence. Clean logs are `/tmp/endless-surveyor-kill-rewards-baseline-clean.log` and `/tmp/endless-surveyor-kill-rewards-tuned-final.log`; `artifacts/kill-rewards-baseline.json` preserves the comparison. These controlled kills do not simulate fighting, collection or human exploration.

The updated ordinary-combat pilot collects 104 coins, four shards and thirteen other items for both mage and spellsword over 900 active seconds. Their earlier pilots collected 52 shards over the same kill count. Sword collects 116 coins, five shards and sixteen other items before defeat at 419.43 seconds; its earlier run ended at 413.88 seconds with 113 kills. No pickup is blocked, and the pilots equip one to three upgrades. None reaches the final chest. These are one-seed automated observations, rather than completed expeditions or human balance acceptance. The clean current log is `/tmp/endless-surveyor-loot-expedition-tuned-final.log`; the earlier report is retained in `artifacts/loot-expeditions-before-shard-tuning.json`.

The initial seed-42 population check produced 2,029 ordinary item opportunities out of 10,000. Four independent 500-opportunity contexts each produced 105 items, with different mixes: wolf 68 materials/34 consumables/3 gear; skeleton 70/28/7; violet wizard 45/26/34; quarry golem 66/17/22. Only one rare item appeared across these small context cases. That sample is insufficient to validate rare-drop balance.

The current controlled seed-12345 office expeditions used actual movement, default abilities, healing consumption, equipment upgrades and projectile damage. Starting at the real entrance limits the measurement to dungeon activity. Mage and Spellsword reached the 900-active-second cap on floor 8; Sword died on floor 9 after 413.88 seconds. None claimed the final chest, so this run does not assess final-chest rewards or outdoor travel. The pilot does not use defensive/movement abilities optimally; its death and stalled progress are measurement limits, not a class-balance conclusion.

| Class | Kills | Collected ordinary items | Gear upgrades | Used consumables | Highest backpack slots | Blocked pickups | Coins | Potential 4-coin potions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Mage | 104 | 13 | 2 | 5 | 14/24 | 0 | 104 | 26 |
| Sword | 113 | 15 | 2 | 6 | 16/24 | 0 | 113 | 28 |
| Spellsword | 104 | 13 | 3 | 2 | 17/24 | 0 | 104 | 26 |

Materials are reported as collected, without claiming that every material has a crafting use. Gear upgrades compare the candidate's actual supported bonuses against the equipped slot. Currency purchase capacity is a projection from collected clean coins; the separate merchant tests verify actual payment and rollback. Human pacing, meaningful material uses and ordinary outdoor/final-chest interruptions remain part of the later expedition review.
