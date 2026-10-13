# Generated dungeon monsters

Dungeon enemies now use voxel characters generated from `config/voxel_monsters.json`. All 90 existing enemy profiles retain their species IDs, names, habitat/family eligibility, stats, AI, attack timing and loot definitions. Their dungeon bodies use 28 articulated templates. Surface hostiles and peaceful fauna still use their existing source/derivative pipeline; imported files and credits remain available.

Templates include skeletons and bone mages, casters, shades, goblins, ghouls, golems, demons, winged demons, wolves, boars, hoofed beasts, bears, lizards, dragons, brontos, rodents, birds, spiders, beetles, slimes, wisps, mushrooms, plants, fish, squids, cannons and frogs. Ordered semantic selectors match existing species IDs or display names. Every current enemy has an explicit selector. Future unmatched profiles use the configured default template, without requiring another imported model or a filename branch in runtime code.

Each monster receives a deterministic material palette, biome accent, lean/regular/heavy build, plain/scarred/crested ornament and slight color variation. Material colors preserve recognizable bone, fur, stone, scales, metal and magical bodies. Four owning-biome contexts each supply two accent/eye pairs. Geometry is honestly tagged `block_voxel`, including dungeons whose architecture uses another family, under the explicit voxel monster replacement request.

Biped and quadruped rigs swing their limbs with foot clearance. Crawlers move articulated legs; birds and dragons flap wings; floating spirits hover; slimes squash, bounce and stretch for attacks. Casters carry staves, bone mages have distinct caster gear, and cannon turrets recoil. These are cosmetic animation tracks. Actual damage, projectiles, attack windup, collision and targeting still use the existing combat rules. Resting bodies fit each profile's height and the existing 1.3-unit maximum width/depth; animation poses and hit flashes can extend those resting bounds.

## Generation and saves

`EnemyModels.create(kind, seed, saved_variant, biome, true)` creates a generated dungeon model. The final argument defaults to false for existing surface/source callers. `Game._spawn_enemy` passes true only in the dungeon layer. `VoxelMonsterGenerator.appearance` resolves the semantic template and uses a local seed derived from species identity and the existing encounter seed. Rendering does not consume combat randomness or change spawn plans.

The existing encounter `variant` string stores a validated descriptor: generator version, template, material palette, biome, accent, build, ornament and tone. Loading it restores the actual choices even if a different generation seed is supplied. An old imported variant ID, unknown descriptor version, malformed descriptor or incompatible template reconstructs a generated appearance from the existing encounter seed. Species, health, defeat state and encounter IDs remain unchanged. No new save field or save-version bump is needed.

Adding choices leaves existing supported descriptors intact. Editing a chosen recipe or color changes its appearance; removing a referenced option can cause regeneration. Animation playback phase is not stored, matching the existing enemy renderer's behavior.

Matching descriptors share generated meshes. A cache retains at most 128 descriptors; live nodes retain their mesh resources across eviction. Animation libraries are shared per template, with the catalogue limited to 64 templates. Characters require no Blender conversion, textures, imported rig or asset publication.

## Author recipes

`templates` defines the body and its articulated `parts`. Each part has a voxel-cell `pivot`, colored cuboid `pieces`, a `motion` category and a phase sign. Coordinates and dimensions use quarter-cell increments. A piece specifies local `point`, positive `size` and a material token. `body`, `dark`, `shade`, `trim`, `tooth` and `metal` come from the chosen material palette; `accent` and `eye` come from the owning biome. Parts merge into one vertex-colored mesh each.

Motion categories are `still`, `core`, `head`, `arm`, `leg`, `crawler_leg`, `wing`, `tail` and `turret`. Templates choose biped, quadruped, crawler, floating, flying, slime or stationary locomotion. Their ornament recipes attach additional pieces to existing parts. Crests use actual supporting surfaces; spiders have eight legs, while beetles have six.

Add a template or palette and reference it in an ordered `selectors` entry. Selectors use exact `ids` or case-insensitive wildcard `names`; optional palettes narrow the template's supported material choices. Specific identities precede broad groups, such as bone mages before skeletons and blobs before their base species. Restart the game after catalogue edits. Validation rejects unknown references, invalid names/colors, nonfinite or off-grid geometry, invalid phase signs and excessive recipe sizes.

```sh
./godot.sh --headless --script tests/test_voxel_monsters.gd --quit-after 600
./godot.sh --headless --script tests/test_voxel_monsters_game.gd --quit-after 600
./godot.sh --script tools/capture_voxel_monsters.gd --quit-after 1200
```

Direct checks cover all 90 profiles in four climates, every authored template, saved descriptor restoration, recipe rejection, bounded mesh ownership and real limb tracks. Actual Game checks cover fresh-scene descriptor/health saves, legacy imported variants, damage/rewards/death persistence and the surface-renderer boundary. Existing enemy, gameplay, fresh-scene save and surface/animal style tests pass. The native helper writes opposing views, movement/attack poses and an actual visible dungeon encounter under `artifacts/voxel-monsters-*.png`. These are focused replacement checks; they do not certify unrelated world-generation work or encounter balance.
