# Character and inventory

Choose Mage, Sword, or Spellsword on the new-journey screen, then select Customize your character or press C. Choose a name of 1-24 characters, Human/Elf/Dwarf ancestry, six skin palettes, six hair colors, six clothing colors, and a hood, short hair, long hair, shaved head, or beard. The live voxel preview has turn controls. C also opens appearance changes during a journey; the menu pauses play. Appearance and ancestry are cosmetic. Class determines abilities, resource, and the weapon silhouette.

The Style selector changes the custom character's clothing geometry. Mage has Apprentice robes, Scholar vestments, and Battlemage mantle. Sword has Vanguard armor, Duelist coat, and Sentinel plate. Spellsword has Runewarden coat, Spellblade armor, and Arcane cloak. Color is separate from style. Changing class during creation replaces an incompatible clothing style while keeping name and colors.

The Character selector also offers nine imported premades: KayKit Mage, Knight, Barbarian, Rogue, and Hooded Rogue, plus four Cube World characters. Premades retain their complete authored appearance; custom ancestry, hair, skin, style, and color controls are disabled until switching back to a custom character. Name and combat class still apply. Imported models use idle, walking, and jump animations and are normalized to stand on the ground at player scale.

The character name appears on the HUD and backpack. Appearance is stored with the journey and survives travel, death, loading, and return from the sanctum. A new journey resets to Wanderer and the default appearance.

The saved appearance contains optional `costume` and `model` fields. Older six-field appearances receive class-default clothing and a custom model. Premades save their stable asset ID instead of a menu index. New registry models tagged `player` become selectable after adding them through [the asset pipeline](ASSET_PIPELINE.md); existing Cube World character records also remain available. Model paths supplied directly in a save are rejected.

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

`scripts/character_profile.gd` owns appearance validation and registry-backed premade choices. `scripts/voxel_kit.gd` renders custom clothing. `scripts/character_visual.gd` handles custom/imported models, scale, floor origin, and animation states. `scripts/inventory.gd` owns item metadata, capacity, quantities, equipment, and snapshots. The character and backpack screens live in `scripts/character_menu.gd` and `scripts/inventory_menu.gd`. The new item icons are original SVGs in `assets/items/`.

`tests/test_character_inventory.gd` checks atomic capacity rejection, bound/equipped-item removal, class restrictions, equipment stats, potion consumption, appearance validation, loot collection, real disk saves across fresh scenes, sanctum carry, and default fields. `tests/test_character_styles.gd` loads every selectable premade and checks scale, floor origin, actual animation clips, class clothing, safe model IDs, save/load, and sanctum return. `tools/capture_character_inventory.gd` checks that the native preview renders geometry and captures all nine clothing styles, all premades, Human/Elf/Dwarf, backpack, equipment, furnishing filter, home inventory, and pause menu. Run it with `./godot.sh --script tools/capture_character_inventory.gd --resolution 1280x800`.
