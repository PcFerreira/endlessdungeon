# Gameplay copy

Players should encounter places and objects through names they could use in the Endless World. A cottage is a Cottage, a guild hall is an Expedition Hall, and an unidentifiable atlas weapon is a Weapon. Export numbers, mesh suffixes, coordinates, asset-pack eras and construction recipes belong in source records.

All thirty architecture templates now carry readable names. `WorldView` reads the built civic model's `construction_name`, so its sign receives the same name as the template. “Medieval Expedition Hall” becomes “Expedition Hall”; “Snow roof linked log wings” becomes “Log Hall”. Architecture, placement and source selection are unchanged.

`config/player_text.json` provides 5,231 explicit item/object names, ninety native-role names and nine category fallbacks. `PlayerText` applies these names to `ItemCatalog`, which already supplies inventory details/tooltips, trade rows/receipts, placement lists/status, and pickup/placement notices. New items without an authored name receive a readable category name. Add an explicit name keyed by the unchanged item ID before publishing distinctive new content. Avoid inventing materials, powers or histories from an ambiguous icon.

Original item names remain in `classification_name`. Loot eligibility and rarity read that field because existing rules match original names. The overlay runs after rarity initialization. IDs, prices, stats, classes, geometry, stack limits, source tags and stored item identities retain their existing values. This lets a name change without changing a reward or invalidating a backpack.

The audit also covered town/place labels, interaction hints, notices, inventory controls, traders, dialogue, books and journal/quest readers. Functional instructions such as “Buy”, “Rotate” and “Vitality” remain direct. The retired materials item's compatibility explanation now reads “A mixed collection of materials recovered along the road.” The shared-world missing-content status now asks the player to try a newer release. In-world records may still sound bureaucratic when that is the speaker's voice. Official asset-pack names and source filenames remain in credits, licenses and metadata.

## Translation and validation

`tools/build_lore.rb` exports gameplay name keys alongside lore messages, with exact source context and English hashes. Item definitions expose `name_key`; construction keys use template IDs. The game still displays English. Menus, HUD, item descriptions and runtime locale selection remain future work, as described in [Lore translations](../lore/locales/README.md).

Run the focused checks:

```sh
ruby tests/test_lore_export.rb
ruby tools/build_lore.rb --check
./godot.sh --headless --script tests/test_player_text.gd --quit-after 600
```

The gameplay regression checks every runtime name/key, all non-name source fields, every loot pool for all three classes, 300 seeded reward comparisons, and original source identities. It is registered in `check.sh`.

For native review, run `./godot.sh --script tools/capture_player_text.gd --quit-after 900`. The helper uses an isolated save directory and captures a corrected civic sign from actual WorldView, a formerly numbered atlas weapon in the backpack, and that weapon's real workshop stock row and purchase receipt. Images and extracted text are written under `artifacts/player-text/`; the temporary saves are removed. Review the images as well as the script's assertions. These focused checks do not certify unrelated concurrent gameplay or browser/server changes.
