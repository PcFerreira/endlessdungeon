# Character and inventory

Choose Mage, Sword, or Spellsword on the new-journey screen, then select Customize your character or press C. All player bodies are now generated voxels with animated limbs. Choose a name of 1-24 characters, Human/Elf/Dwarf/Orc/Halfling ancestry, and four body builds. C also opens appearance changes during a journey; the menu pauses play. Appearance and ancestry are cosmetic. Class determines abilities, resource, and the weapon silhouette.

The creator has Presets, Body, Face, Clothes, and Colors tabs. Twelve voxel presets provide starting looks; every preset remains editable. Face offers eleven haircuts, six beard choices, ten headwear choices, and three eye shapes. Clothes offers twelve shared outfits plus three class styles, six outer layers, four glove choices, five boot choices, four belts, and six accessories. Counts include the uncovered or empty choice where available. Turn the live preview to inspect each side, or select Stand, Walk, and Jump to inspect poses.

Colors are independent of clothing geometry. Twelve skin, hair, and cloth palettes cover skin, hair, outfit, trim, trousers, boots, outer layer, and headwear; eyes have six colors. A hood or closed helmet covers the hair beneath it. Changing class during creation replaces incompatible class clothing while keeping the remaining appearance choices. Clothing does not grant equipment bonuses.

The character name appears on the HUD and backpack. Appearance is stored with the journey and survives travel, death, loading, and return from the sanctum. A new journey resets to Wanderer and the default appearance.

Appearance saves use version 2 with explicit layer and palette fields. Older appearances retain their original six palette entries, name, ancestry, and class clothing. Legacy hood and beard choices become separate layers. Former approved imported player bodies migrate to a customizable voxel body when loaded; imported bodies are no longer selectable. Arbitrary model paths are rejected. The supplied imported assets remain available to their other existing consumers.

## Backpack

Press I, select Backpack below the minimap, or open it from the pause menu. The backpack has 24 slots. Items of the same kind stack up to their item limit; further stacks use another slot. Select an item to see its description, total quantity, and available actions. Filters show consumables, equipment, furnishings, or materials. Use a potion, equip an item, unequip it with the minus button, or discard one copy. The Sanctum Sigil is bound and cannot be discarded. The last copy of equipped gear cannot be discarded until unequipped.

Each journey starts with the sigil, three Vitality Potions, and two Recovery Potions. Vitality restores 35 health; Recovery restores 40 aether or stamina. A potion is only consumed when it can restore the relevant resource. Inventory and grimoire menus pause combat.

Defeated enemies still drop their immediate vitality/resource pickups. They also drop Ember Shards or a Vitality Potion every fourth kill. A final dungeon chest drops a furnishing and equipment in addition to its one-time skill point. The furnishing is an Oak Chair, Rune Lantern, or Woven Rug, chosen deterministically per dungeon. Gear from chests is a Traveler's Coat and Runed Staff for Mage, or a Silver Charm and Tempered Sword for the other classes. These rewards follow the existing one-time chest claim.

Walk over a golden item pickup to collect it. If the backpack is full, it stays on the ground. Uncollected items in the active area are included in journey saves and the sanctum's suspended return state. Ground drops follow the MVP's existing area-transition rules; collect valuables before leaving an area.

## Equipment

| Item | Slot | Bonus | Classes |
| --- | --- | --- | --- |
| Tempered Sword | Weapon | +10% ability damage | Sword, Spellsword |
| Runed Staff | Weapon | +10% ability damage | Mage, Spellsword |
| Traveler's Coat | Armor | +20 maximum vitality | All |
| Silver Charm | Charm | +15 maximum aether/stamina | All |

One item occupies each equipment slot. Equipment stays in the carried-item count and uses backpack space. Equipping maximum-resource gear does not refill the resource. Unequipping clamps current vitality/resource to the new maximum. Damage bonuses add to skill-tree bonuses. Gear changes stats; character clothing and the weapon silhouette remain controlled by appearance and class in this version.

## Homes and saves

Items collected, used, equipped, or discarded at home carry back to the journey. Appearance changes at home carry back too. Journey snapshots store optional root `character` and `inventory` fields. The reader validates palette IDs, names, quantities, stack capacity, bound-item count, equipment slots, and class restrictions before changing the live journey. Saves for the current generator that omit these fields receive default appearance and starter inventory. This does not migrate terrain from an older generator.

Press B in the Sanctum, or choose Place in Sanctum from the backpack, to arrange owned furnishings. The chair, rune lantern and woven rug rewards have stable inventory IDs and placement recipes. Successful placement consumes one owned copy; invalid/cancelled previews consume nothing, and pickup returns a copy only when the backpack has room. See [SANCTUM.md](SANCTUM.md) for support rules, movement, rotation and saved arrangements. Stolen-only copies use the separate Place in world action to retain provenance.

## Files and checks

`config/player_wardrobe.json` defines voxel presets, layers, and palettes. `scripts/player_wardrobe.gd` validates those recipes. `scripts/character_profile.gd` validates appearances and migrates older saves. `scripts/player_voxels.gd` compiles player geometry with a bounded mesh cache; the shared NPC generator retains its default recipes. `scripts/character_visual.gd` handles scale, floor origin, and animation states. `scripts/inventory.gd` owns item metadata, capacity, quantities, equipment, and snapshots. The screens live in `scripts/character_menu.gd` and `scripts/inventory_menu.gd`.

`tests/test_character_inventory.gd` checks inventory, equipment, potion consumption, appearance validation, loot, real disk saves, sanctum carry, and default fields. `tests/test_character_styles.gd` checks all twelve editable presets, cosmetic stat/RNG isolation, cache reuse, legacy migration, disk saves, and sanctum return. `tests/test_player_wardrobe.gd` checks actual mesh-array differences for every layer, proportions, walking-foot clearance, animation, and atomic validation. `tools/capture_player_wardrobe.gd` captures preset and Mage/shared outfit fronts/backs, all five creator tabs, real preset/layer/color callbacks, and world/home views. Run it with `./godot.sh --script tools/capture_player_wardrobe.gd --resolution 1280x800 --quit-after 1200`; images are written to `artifacts/player-wardrobe/`. Creator thumbnails render once; only the main preview animates continuously.
