# World expansion assets

Fourteen more packs are staged for regions, settlements and encounters. This batch contains the five suggested packs: Nature Kit, Modular Cave Kit, Survival Kit, Furniture Bits and the complete 50-model Ultimate Monsters glTF subset. It also adds fantasy town modules, workshop props, modular outfits, arcane effects and environmental recordings.

Twelve additions use CC0. The two Blender Foundation ambience collections use CC BY 3.0 and require credits. Their originals, publisher pages and license records are preserved. Required credits, including the audio conversion note, are in [ATTRIBUTION.md](ATTRIBUTION.md).

| Purpose | Downloaded pack | Staged contents | Publisher |
| --- | --- | --- | --- |
| Regional scenery | [Kenney Nature Kit](kenney_nature_kit/Models/GLTF%20format/) | 329 GLB models of vegetation, trees and rock formations. Preview renders and alternative formats are retained. | [Source](https://kenney.nl/assets/nature-kit) |
| Underground environments | [Kenney Modular Cave Kit](kenney_modular_cave_kit/Models/GLB%20format/) | 40 cave modules with texture variants. | [Source](https://kenney.nl/assets/modular-cave-kit) |
| Roadside camps and work sites | [Kenney Survival Kit](kenney_survival_kit/Models/GLB%20format/) | 80 models, including tents, bedrolls, campfires, fishing stands, tools, resources, signposts and workbenches. Modern metal structures are also included. | [Source](https://kenney.nl/assets/survival-kit) |
| Towns and markets | [Kenney Fantasy Town Kit](kenney_fantasy_town_kit/Models/GLB%20format/) | 167 modular building pieces and props, including market stalls, walls, roofs, fences, doors, windmills and watermills. | [Source](https://kenney.nl/assets/fantasy-town-kit) |
| Furnished interiors | [KayKit Furniture Bits](kaykit_furniture/content/addons/kaykit_furniture_bits/Assets/gltf/) | 53 glTF furniture models, with OBJ alternatives. | [Source](https://github.com/KayKit-Game-Assets/KayKit-Furniture-Bits-1.0) |
| Professions, workshops and magical rooms | [Quaternius Fantasy Props: Standard](quaternius_fantasy_props/Exports/glTF/) | 94 glTF props, including anvils, workbenches, cauldron, books, scrolls, potion bottles, stalls, banners and lanterns. | [Source](https://quaternius.com/packs/fantasypropsmegakit.html) |
| NPC and faction appearance | [Quaternius Fantasy Outfits: Standard](quaternius_fantasy_outfits/Exports/glTF%20%28Godot-Unreal%29/) | Four peasant/ranger outfit assemblies and 20 modular parts, with male/female options and texture variants. Compatible heads and animation integration are required. | [Source](https://quaternius.com/packs/modularcharacteroutfitsfantasy.html) |
| Regional enemies and boss candidates | [Quaternius Ultimate Monsters](quaternius_ultimate_monsters/glTF/) | All 50 glTF models from the pack, with embedded images and animation data. | [Source](https://quaternius.com/packs/ultimatemonsters.html) |
| Magical landmark effects | [Arcane Magic Effect](arcane_magic_effect/content/Arcane_Effect/) | 42 PNG frames in six effect sequences. These are animated visual effects, not landmark models. | [Source](https://opengameart.org/content/arcane-magic-effect) |
| Rain | [Rain: Loopable](rain_ambience/content/) | Four rain recordings, each in MP3 and OGG. These are alternate encodings of the same four recordings. | [Source](https://opengameart.org/content/rain-loopable) |
| Wind | [Synthesized Wind Ambience](wind_ambience/) | Five alternative one-minute WAV recordings. | [Source](https://opengameart.org/content/wind1) |
| Caves and dungeons | [Loopable Dungeon Ambience](dungeon_ambience/) | One OGG ambience recording with low wind and water drips. | [Source](https://opengameart.org/content/loopable-dungeon-ambience) |
| Wildlife ambience | [Bird, Cricket and Frog](wildlife_ambience/godot_wav/) | Four FLAC recordings, preserved alongside four PCM-equivalent WAV copies for Godot. CC BY 3.0. | [Source](https://opengameart.org/content/ambient-bird-cricket-and-frog) |
| Rivers and forests | [Mountain, River, Wind, Forest and Waterfall](river_forest_ambience/godot_wav/) | Six FLAC recordings, preserved alongside six PCM-equivalent WAV copies for Godot. CC BY 3.0. | [Source](https://opengameart.org/content/ambient-mountain-river-wind-and-forest-and-waterfall) |

## Places to assemble

These combinations are suggested uses of downloaded assets. They do not add encounters, shops, quests or simulation rules to the game.

| Place or activity | Files to start with |
| --- | --- |
| Blacksmith workshop | Fantasy Props `Anvil.gltf`, `Anvil_Log.gltf`, `Workbench.gltf`, plus Survival Kit tools and `workbench-anvil.glb` |
| Herbalist or alchemist | Fantasy Props `Cauldron.gltf`, `Potion_1.gltf` through available potion variants, `Shelf_Small_Bottles.gltf`, plus existing potion icons |
| Library or mage study | Fantasy Props `BookStand.gltf`, `Bookcase_2.gltf`, book groups, scrolls, candles and arcane effect frames |
| Merchant market | Fantasy Town stall variants, Fantasy Props `Stall_Empty.gltf` and `Stall_Cart_Empty.gltf`, and previously downloaded food/item models |
| Campsite or ranger outpost | Survival Kit `tent.glb`, bedroll variants, campfires, signposts and tools; ranger outfits for future inhabitants |
| Fishing site | Survival Kit `campfire-fishing-stand.glb`, `fish.glb`, `fish-large.glb`, plus river/stream recordings |
| Rural settlement | Fantasy Town windmills/watermills and modular buildings, furnished with KayKit or Quaternius interiors |
| Magical ruin or shrine | Existing staged stone arches and ruins, Fantasy Props banners/candles/scrolls, and Arcane Magic Effect sequences |
| Regional dungeon | Cave modules, a selected monster family, dungeon ambience and regional loot from [ITEM_VARIETY.md](ITEM_VARIETY.md) |

Select a coherent style for each location. Nature and Survival both contain overlapping scenery types. Their file totals include variants and should not be counted as unique regional themes. The outfits use Quaternius's Universal Base Character system; the supplied README says to use a compatible head and avoid an additional full body underneath the clothing. They are not interchangeable costume attachments for the current procedural voxel character without adaptation.

The free Standard subsets are deliberately separated from their publishers' complete paid offerings. Fantasy Props contains 94 model files here, not all 211 advertised across tiers. Fantasy Outfits contains four outfit assemblies and 20 parts here, not all 12 outfits advertised across tiers. Custom collision packages, paid engine scenes and additional paid models were not downloaded.

## Source records and conversions

The three Quaternius additions came from public CC0 mirrors at pinned revisions. Every downloaded file was checked against its Git blob hash and recorded with SHA-256. Fantasy Props and Fantasy Outfits retain the original `License_Standard.txt` files. Ultimate Monsters retains the supplied `License.txt`, whose heading says “Ultimate Platformer Pack”; the license text and the actual Ultimate Monsters publisher page both state CC0. This mismatch is recorded rather than edited away. The author's Google Drive returned a quota error, and the complete 50-model glTF set was obtained from the public mirror.

The two ambience collections retain all ten original FLAC files. Their `godot_wav/` copies were decoded without gain, trimming or resampling. Decoded PCM equality was checked for every FLAC/WAV pair. Original and derived hashes and the conversion record are in each pack's `SOURCE.json`. Copies shipped in the game need the same CC BY 3.0 attribution as the original recordings.

The GPL-licensed “Thunder, rain and wind” candidate was inspected but not downloaded. The rain and wind additions above use CC0. Thunder recordings, dedicated snow effects, bespoke faction heraldry and role-specific blacksmith/merchant character models remain useful future searches; the generic props and outfit bases can support prototypes now.

## Validation and adoption

Godot 4.7.2 instantiated all 837 new models and loaded 2086 textures and 24 playable audio files in an isolated project, with no reported errors or warnings. Results are saved in [world_expansion_validation.json](world_expansion_validation.json) and logs under `validation/`. All 34 original/derived audio files passed codec/duration checks, and the ten FLAC/WAV pairs had identical decoded PCM. Original FBX/OBJ/DAE/STL alternatives and FLAC editing sources are retained but are outside the Godot import check. [world_audio_inventory.json](world_audio_inventory.json) records codecs and durations, and [world_model_inventory.json](world_model_inventory.json) lists the new model meshes, skins and animation names.

Asset loading does not test a generated town, cave traversal, enemy combat, skeleton retargeting, NPC behavior, weather simulation, audio mixing or loop seams. Those need checks when the selected assets are adopted. The staging folder's `.gdignore` remains in place.
