# Creature biome families

Generated enemies and wildlife use the owning biome's visual family. Logical species, habitat weights, stats and saved source IDs remain separate from rendered geometry.

`config/creature_styles.json` classifies reviewed model cohorts. Cube World animals/enemies, voxel creature packs, Padadu creatures and all ten supplied animal samples are block-built. Ultimate Monsters, KayKit skeleton bodies and Kenney creature models are faceted. The supplied animal samples were initially misclassified; the native gallery and an actual mesh face-area inspection exposed their block-built geometry. Pack names and broad fantasy tags do not establish compatibility.

`CreatureModels.choose` prefers compatible source models before deterministic selection. If a species has no compatible source, it retains that species and renders a geometric derivative. A valid saved source takes priority, preserving existing encounters and wildlife identities. `CreatureModels.instantiate` accepts only classified creature sources. The single adopted pixel skeleton has an explicit presentation mapping to a Cube World skeleton or KayKit skeleton warrior. Its logical species and original PNG source identity remain unchanged.

Direct compatible bodies retain their imported meshes, rigs and clips. Incompatible bodies are converted per mesh in local coordinates, preserving the original node hierarchy, skin resource, skeleton path and animation players. Block derivatives contain actual exposed voxel faces. Faceted derivatives smooth the connected voxel surface, refit the original bounds and generate flat triangle normals. Sampled colors remain visible in the project's Compatibility renderer. These are approximate visual representations; original asset and animation resources are unchanged.

The optional skin path in `TownModelVoxelizer` interpolates source bone influences, retains the strongest four and normalizes them. Collapsed projected triangles use finite nearest-corner weights instead of dividing by zero. The four-lane attributes follow [Godot's SurfaceTool API](https://docs.godotengine.org/en/4.7/classes/class_surfacetool.html). Default architecture conversion remains unchanged apart from the finite projected-triangle guard.

`source_asset` and the enemy's saved `variant` retain original provenance. `render_source`, `render_asset`, `representation` and `visual_family` describe the actual body. Converted identities use `native_creature:<family>:<classified-source>`. Unknown sources, unrelated scenery and unknown biomes cannot become creature derivatives merely by adding that prefix. Missing enemy resources use a declared native shape in the required family while retaining the original saved source ID.

Game passes the actual surface-cell biome or owning dungeon biome. Wildlife records retain their generated habitat biome while moving; reconstruction derives it from the same source location, so no new saved field or migration is required. Resident/watch and road-visitor policies remain separate.

## Acceptance

`tests/test_animated_style_conversion.gd` checks synthetic two-bone geometry, bounds, winding, finite attributes, source immutability and three actual rigged sources in both families. Twenty-two skinned meshes retain their bindings; every tested rig actually changes bone poses through its imported clip.

`tests/test_creature_styles.gd` checks 102 source IDs, all 90 enemy types in four climates, all 37 wildlife types in both families, deterministic compatible preferences, preserved incompatible saved sources, explicit skeleton presentation and unavailable-resource fallback. Enemy coverage contains 182 direct presentations and 178 derivatives. This count describes the four-climate fixture, not gameplay encounter frequency.

`tests/test_creature_styles_game.gd` checks actual four-climate streaming with 20 generated animals, dungeon entry, source/species preservation, fresh-scene disk reconstruction, combat RNG and Sanctum return. Original enemy, wildlife catalogue/routine/Game, content-bundle, dungeon save and staged edition-5 Game regressions pass. The bundle gameplay regression now computes its expected reward with the actual owning dungeon biome, matching the existing production context; drop chance and weights are unchanged.

`tools/capture_creature_families.gd` renders 48 opposing galleries containing every enemy and wildlife type in both families. Representative enemy and wildlife pages were inspected, including the corrected sample-animal derivatives. `tools/capture_animated_styles.gd` also renders three rigged source/derivative comparisons in two moving poses. Final logs use `/tmp/endless-surveyor-creature-*` and `/tmp/endless-surveyor-animated-style-final.log`; gallery images use `artifacts/creatures-*.png` and `artifacts/animated-styles-*.png`. Earlier parser, classification and fallback-fixture failures are superseded.

These focused checks do not establish ordinary expedition pacing or complete all local-asset integration. Reward visuals, town accents/magic, carried-object presentation and independent-location integration still require their own acceptance.
