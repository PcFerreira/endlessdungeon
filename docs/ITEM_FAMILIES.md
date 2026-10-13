# Item and reward families

World rewards, placement ghosts, placed inventory objects and home furnishings use their destination's visual family. Item IDs, quantities, stats, prices, ownership, source masks and saved placement records remain unchanged.

`ItemModels` keeps compatible volumetric source models direct and converts incompatible models through the tested mesh-local style renderer. Native cultural objects retain their role when rebuilt for another family. Icon-only items use their actual cropped icon's visible pixels to build a three-dimensional relief: exposed voxel faces or a smoothed faceted surface. Original image bytes and atlas regions remain intact. These reliefs are approximate physical representations of the catalogue artwork, rather than new authored weapon/armor meshes.

`config/item_styles.json` declares reviewed model cohorts, original native icon paths, legacy scenery keys, procedural furnishings and semantic reward icons. Shared classification accepts exact `native_item:<family>:<known-source>` and `native_reward:<family>:<role>` identities. Unknown sources and roles remain unclassified. Runtime `source_asset` preserves original provenance; `render_asset`, `asset_id`, `visual_family` and `representation` describe the actual displayed body. An inventory item ID is never replaced with its rendered derivative ID.

Gold currency has an explicit coin body in both families and a distinct coin SVG icon. Its original imported model reference remains in the definition/provenance. Immediate vitality/aether rewards have identifiable bottle bodies, while the existing ember shard has its own native form. Effects, quantities and collection rules stay unchanged. Core sword/staff now bind existing physical models; their item IDs, effects, classes and UI source images remain. The retired legacy material-sheet item keeps its complete sheet and ID, with the display name Recovered Materials matching its existing mixed-material description. Current cropped material IDs are unaffected.

Game uses the resolved surface-cell biome, including town/site footprint overrides, or the owning dungeon/interior biome. The same resolved-cell correction applies to enemy presentation. The biome-free Sanctum retains its existing block-built family. World placement ghosts use their destination point, including cross-biome placement.

Fitting occurs after representation conversion and uses the authoritative footprint, height and rotation. Planar or nearly planar mesh sources receive finite thickness before fitting; this avoids collapsed faceted surfaces and unstable large scale/translation cancellation. The optional padding/alpha-mask path leaves ordinary creature and architecture conversion unchanged. Source skins, node hierarchy and local animation bindings survive conversion.

## Acceptance

`tests/test_icon_item_geometry.gd` checks sparse transparent silhouettes, sampled colors, original image bytes, actual depth, visible winding, distinct geometric families and planar-source thickness.

`tests/test_item_styles.gd` covers all 3,120 nonportable item definitions in both families, with real geometry, finite bounds, rendered/source identities and unchanged definitions during rendering. The final fixture contains 5,002 icon reliefs, eight semantic reward bodies, 564 voxel conversions, 588 direct bodies and 78 faceted conversions. These counts describe catalogue coverage and overlap with furnishing coverage; they do not describe encounter frequencies.

`tests/test_placed_item_styles.gd` covers 2,438 portable/furnishing sources in both families, with rotated authoritative footprints, height, ground contact, real family identity and preserved original item definitions. The broad fixture exposed thin terrain models and a cave-floor alias that narrower room checks had missed; the corrected repeat passes without warnings.

`tests/test_item_styles_game.gd` checks actual four-climate reward collection, preserved combat RNG, cross-family source-item placement/pickup, exact bounds, fresh-scene disk identities, styled home furniture and owning-dungeon rewards/save reconstruction. JSON values are compared after normalizing both snapshots through serialization; integer-to-float envelope representation is not a changed item state.

Original actual drops/collection/consumables/equipment/aquatic, world theft/base/rest/respawn, surface sources/restitution, four-layer placement, furnished-home/indoor, dungeon-family save, creature save, staged edition-5 Game, environment, skinned animation and architecture conversion checks pass. Loot selector acceptance still reports the same independent deterministic probabilities and contextual/class eligibility. Chance and weights were not changed by this presentation work.

`tools/capture_item_families.gd` renders 53 source-pack/kind representatives plus core rewards/furniture in both families from opposing views: 20 native galleries. Representative core/model/icon pages were inspected. Final captures use `artifacts/items-family-*.png`; logs use `/tmp/endless-surveyor-item-*`, `/tmp/endless-surveyor-items-*`, `/tmp/endless-surveyor-placed-items-tagged.log` and `/tmp/endless-surveyor-icon-items-final.log`. Early parser, thin-surface and JSON fixture failures are superseded.

Missing-source outer-town fallback, independent geography activation, integrated all-lane checks and ordinary expedition/camera/pacing review remain separate requirements. Ordinary item chance does not include the legacy deterministic shard/resource cadence; a full reward-pacing audit must account for those separately.
