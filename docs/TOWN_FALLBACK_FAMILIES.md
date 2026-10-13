# Missing-source town forms

When a house, civic tower or outdoor-lot model is unavailable, WorldView renders a composed procedural form in the actual city biome's family. The fallback retains its role, foundation, orientation, service text and source identity. It does not relabel an unavailable imported mesh.

`TownFallback` declares four exact roles: house, civic tower, market lot and farm lot. Shared classification recognizes `native_town:<family>:<role>` only for those roles. Runtime metadata records the rendered family, source UID and measured height.

The optional family argument in `WorldVoxels.house`, `tower` and `outdoor_lot` preserves the existing block API. Block models retain their authored boxes. Faceted forms use actual bevelled surfaces; gable and hip roofs have pitched faces rather than voxel stair steps. Flat roofs retain their slab form. Every form preserves the original outer bounds, including roof/chimney clearance.

Markets retain supported counters/wares and a shelter canopy. Farms retain their planted beds and crop recipe. Existing foundations, doors, streets, collision, public approaches, house/lot IDs, services, generated plans and saves remain authoritative. Actual house bounds continue to support the family-aware trim and floating roof charms.

## Acceptance

`tests/test_town_fallback_styles.gd` forces the three unavailable-model paths in all four climates. It checks exact rendered/source identities, measured bounds, real geometric families, visible winding, pitched gable/hip surfaces, retained block/flat-roof behavior and unchanged plans. The lot fixture forces only the lot path; unrelated city decoration construction retains its own existing native fallback policy.

`tests/test_town_fallback_game.gd` checks actual streamed fallback towns across all climates, real shop entry/exit, source/height reconstruction, fresh-scene disk restoration and combat RNG. Original architecture, town identity, actual charm/service, portable/restitution, environment, local accent and staged edition-5 Game checks pass.

`tools/capture_town_fallbacks.gd` renders eight actual Game views across all climates from opposing cameras at surface zoom 19. Representatives from every climate were inspected. The first faceted capture retained stepped roofs and was rejected; the pitched-roof captures supersede it. Final logs use `/tmp/endless-surveyor-town-fallback-*`; images use `artifacts/town-fallback-*.png`.

This completes the focused missing-source house/civic/lot presentation path. Integrated checks, independent geography activation and ordinary expedition/camera/reward-pacing review remain separate work.
