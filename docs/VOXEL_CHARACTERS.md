# Generated voxel NPCs

Ember replaced runtime NPC bodies with characters generated from `config/voxel_characters.json`. Town residents, town watch, merchants and road travelers use the same generator through `ActorModels.create`. Original imported character files and their credits remain available on disk. Player, animal and enemy rendering keeps its own pipelines.

NPC identity and the existing appearance index seed a local random generator. Revisiting a resident or loading an older save reconstructs the same generated appearance without adding a save field or consuming combat randomness. The first replacement changes the old imported appearance; subsequent reconstruction uses generator version 1 and the current catalogue. Changing the available options, their order or their recipes can change appearances. Catalogue edits are authoring changes, rather than saved per-NPC customization.

The catalogue currently provides three body builds, six skin tones, eight hair colors, six hairstyles, three beard choices, five outfits, six hats, seven accessories and eleven role profiles. Role profiles restrict outfit, hat and accessory combinations. Guards wear mail and carry a blade; merchants carry stock packs or satchels; scholars carry books. Unknown future roles use the plain villager recipe while retaining their gameplay role. Skin and hair selection is independent of biome. Town residents and watch share an identity-selected palette from their actual biome's two palettes. Road travelers use the palette supplied by their current biome and home-city identity.

All body geometry consists of axis-aligned voxel cuboids, with quarter-cell details for facial features and trim. Metadata identifies it as `block_voxel`; it does not reuse the previous imported NPC rule that required flat low-poly bodies in some climates. Clothing palettes still follow actual biome context. Six separate head/torso/limb meshes support idle breathing, walking, one-shot greetings and watch attacks. Each mesh merges the colored cuboids belonging to one animated part. Characters fit the existing 1.15-unit height with grounded feet. Cosmetics add no collision and do not alter law, commerce, dialogue or world-life paths.

Generated meshes are shared by matching appearance descriptors. The cache retains at most 128 descriptors; meshes used by live actors remain referenced if their cache entry is evicted. Animation data is shared. Character creation does not require Blender, an imported skeleton or an asset publication step.

## Edit a character recipe

`builds` defines torso width and head width in whole voxel cells. `skins`, `hair_colors` and `palettes` provide source colors. Each biome lists eligible palette IDs. The `hair`, `beards`, `outfits`, `hats` and `accessories` dictionaries contain named recipes; roles refer to those names.

Each recipe piece declares an animated `bone`, local `point`, positive `size` and color token. Coordinates use quarter-cell increments. Bones are `Torso`, `Head`, `LeftArm`, `RightArm`, `LeftLeg` and `RightLeg`. Palette tokens include `cloth`, `trim`, `pants`, `leather` and `metal`; `skin`, `hair`, `paper` and `eye` are also available. Feet rest at cell zero, the torso pivot is cell 11, shoulders are cell 19 and the head pivot is cell 20. New recipe keys enter deterministic selection automatically once a role references them; hairstyles and beard recipes enter directly. Validation rejects missing references, invalid colors, excessive piece counts and invalid geometry.

Call `ActorModels.style_for(appearance_index, actor_context)` to inspect a generated descriptor, or `ActorModels.create(appearance_index, actor_context)` to create its animated node. The context uses the existing `id`, `city_id`, `biome` and `role` fields.

```sh
./godot.sh --script tools/capture_voxel_characters.gd --quit-after 1200
./godot.sh --headless --script tests/test_voxel_characters.gd --quit-after 600
./godot.sh --headless --script tests/test_voxel_characters_game.gd --quit-after 600
```

The native helper renders 48 real characters in four climate palettes, from opposing views and in animation poses. Images are written to `artifacts/voxel-npcs-*.png`. The former NPC family/expansion helper paths now run this gallery. Runtime checks cover recipe reachability, replay, bounded meshes, grounded finite geometry, limb tracks and greeting return. Actual Game checks cover resident interaction, walking and fresh-scene disk appearance reconstruction; existing law/traveler checks cover watch combat and merchant transactions.

The implementation uses Godot's [SurfaceTool mesh API](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/surfacetool.html) and [Animation property tracks](https://docs.godotengine.org/en/4.5/classes/class_animation.html). The standalone voxel rig has no imported animation dependency.
