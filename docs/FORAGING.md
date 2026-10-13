# Foraging

Walk up to a wild herb, berry bush, mushroom, crystal cluster or shell patch and press E when the Gather prompt appears. Each patch gives one to three materials. The backpack Materials category shows their names, original icons and descriptions. A full backpack leaves the patch available.

Gathering is available during offline exploration of the procedural overworld and Morrowmere. Town footprints, doorway approaches, dungeon entrances, authored sites and Lanternwake are excluded. The small plants and deposits have no collision. Existing doors, books, rest spots and portals retain interaction priority.

## Biome materials

Each biome has two materials. The first has an 80-percent selection weight and the second has a 20-percent weight. Patches use the biome at their actual ground cell.

| Biome | Commonly found | Less often found |
| --- | --- | --- |
| Greenwood | Bramble Berries | Ironbark Curl |
| Meadows | Wayside Sage | Starlight Petals |
| Desert | Cactus Fiber | Sunstone Chip |
| Frostlands | Winter Mint | Ice Resin |
| Dense forest | Fern Curl | Moth Moss |
| Haunted hollows | Ghost Petals | Wisp Glass |
| Marsh | Silver Reed | Bog Pearl |
| Jungle | Lantern Fruit | Red Ginger |
| Autumn woodland | Russet Nuts | Amber Drips |
| Fungal grove | Mooncap | Dreaming Spores |
| Volcanic wastes | Obsidian Flakes | Cinder Crystal |
| Highlands | Wind Thyme | Sky Flint |
| Coast | Tide Kelp | Whisper Shell |
| Crystal tundra | Glass Lichen | Prism Heart |

## Selling

Open a general market, provisions shop or smithy with E, select Your goods, choose a gathered material and press Sell. Shops pay two to eleven gold coins per unit, depending on the material. Selling transfers one unit into the merchant's stock and reduces its finite purse. The displayed sale price is authoritative. Other shop types accept goods according to their existing trade profile.

Collected resources are clean owned goods. They stack up to 99 per backpack slot and use the existing inventory capacity and trade rollback checks. Merchants initially stock their usual wares. They can resell forage that players bring them.

## Persistence and expansion

Harvested patches remain depleted across chunk streaming, saving, loading and trips through the Sanctum and Lanternwake. This MVP has no regrowth timer. Starting a new journey resets the gathering ledger. Old saves without a ledger load normally.

[config/foraging.json](../config/foraging.json) defines the 28 materials, individual values, yield ranges, colors, geometry families and biome pools. Authored display names are registered in [config/player_text.json](../config/player_text.json); regenerate their locale keys with `ruby tools/build_lore.rb` after changes. [scripts/forage_catalog.gd](../scripts/forage_catalog.gd) generates sparse deterministic candidates with a separate random stream. Gathering does not alter terrain, encounters or combat randomness. World seeds and generator editions scope procedural patches; dimension identity and map revision scope authored-world patches. Explicitly compatible dimension revisions remain valid in saved ledgers.

[scripts/foraging.gd](../scripts/foraging.gd) limits active patch models to 96, reuses mesh templates and saves only harvested IDs. The bounded ledger holds 16,384 patches. A full ledger refuses gathering without consuming the patch. [scripts/forage_visual.gd](../scripts/forage_visual.gd) supplies original block and faceted models. The 28 original SVG icons in `assets/foraging` load at runtime without a separate editor import.

Run `./godot.sh --headless --script tests/test_foraging.gd --quit-after 600` for the focused checks. `./godot.sh --script tools/capture_foraging.gd --quit-after 600` captures actual gathering, backpack and shop views with isolated preview saves.
