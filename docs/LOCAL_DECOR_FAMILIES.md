# Local decorative families

Town trim, civic magic, roof charms, street runes, shop signs, NPC accessories and temporary event supplies follow their owning visual family. They retain their authored theme, role, palette and animation behavior.

`DecorGeometry` builds actual block meshes or bevelled faceted meshes from the existing decorative recipes. `EnvironmentStyles` registers eight exact `native_decor:<family>:<role>` identities. Unknown decorative roles and unknown families remain unclassified. NPC accessories use the selected body's visual family, including broader road visitors; local residents/watch continue to use their shared town series.

`TownStyle.build` receives WorldView's actual house-model references. Its plans use the rendered local bounds for width, length and roof height. Model placement still uses the existing house center and facing. The renderer retains house IDs, colors and cutaway materials without modifying generated house records, doors, streets or collision.

`TownMagic.build` receives those house references and the actual central fountain. Household lights clear the rendered roof through their complete bobbing range. The civic core clears its actual fountain support by at least .30 units, including its lowest animation position. The separate civic tower is offset from that fountain and does not determine core clearance. The charm label follows the core's actual top. Profile IDs, source plan positions, seeded phase, roof-house IDs and street cells remain unchanged.

Shop boards/posts retain their original text and door-side placement but use the same family-aware mesh helper. Their positions and services do not become new obstacles or portable goods.

`WorldLifeView` renders delivery, meal, banner, books and market episodes using their real city's biome. Native crates, pot, tea cups, banner, table, books and bread replace the old mixed scenery and anonymous goods. Meal rugs touch the ground; pots/cups touch the rug; wares touch and fit inside the table. Episode IDs, clocks, modal/combat deferral and aftermath behavior remain intact. These temporary visuals do not invent inventory, stock or ownership mechanics.

## Acceptance

`tests/test_local_decor_styles.gd` covers eight exterior styles and 34 magic profiles across four climates: 168 compositions. It checks every NPC role, all five episode recipes in both phases across those climates, finite geometry, actual angled decorative meshes in the faceted family, source-bound fitting, taller roof/fountain clearance, animation movement and exact supply supports. The 40 episode fixtures exercise the production presentation builder with controlled episode descriptors; they do not claim that every descriptor occurs in every natural town.

`tests/test_local_decor_game.gd` checks actual streamed towns in all four climates, rendered roof support, sign/accessory identities, unchanged generated plans, fresh-scene disk reconstruction and combat RNG. Original town-type/magic, actual resident/custom/interior, NPC-family, living-world, ambience, activity/merchant, surface portable and staged edition-5 Game checks pass. Creature save acceptance passes after the decoration change.

The existing town-type helper renders all 28 added identities from opposing cameras, plus themed detail views and a real charm reader. Representative detail views from all eight exterior styles were inspected. The NPC helper renders all six resident/watch source series with their updated accessories. `tools/capture_local_episodes.gd` renders all five production presentation recipes in both families from opposing views. These native helpers use isolated preview journeys or controlled gallery fixtures.

Final logs use `/tmp/endless-surveyor-local-decor-*` and `/tmp/endless-surveyor-decor-*`. Captures use `artifacts/town-type-*.png`, `artifacts/npc-family-*.png` and `artifacts/local-episodes-*.png`. Earlier parser, floating-point fixture and overly broad per-leaf angle assertions are superseded. Native cultural panels may be ordinary flat box meshes; the new decorative forms themselves must contain actual faceted geometry.

This slice does not complete reward visuals, carried-object presentation, missing-source outer-town fallbacks, independent geography or ordinary expedition/camera acceptance. Their integration remains part of the full world-building review.
