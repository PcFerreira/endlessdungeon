# Wilderness roads and bridge banks

Current edition6 wilderness routes follow terrain between real settlement and landmark entrances. Town streets retain their planned layout. The wilderness planner replaces random orthogonal doglegs with diagonal segments and rounded land turns, favors dry ground and lower earthwork costs, and keeps a three-cell walking corridor clear of other landmark footprints. Every route has canonical destination IDs and complete endpoints. Edition4/5 routes use their original planner.

Routing uses a bounded12-cell coarse grid,48-cell search margin and weighted [Godot AStarGrid2D](https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html). The cost model follows the distinction between distance and terrain costs described in [Red Blob Games' pathfinding implementation](https://www.redblobgames.com/pathfinding/a-star/implementation.html). Obstacle checks include shoulder clearance. Rounding preserves endpoints, checks its new segments and leaves wet turns unrounded. Diagonal water edges are excluded. If coarse routing cannot reach both endpoints, the complete legacy obstacle-bypass route remains available.

## Bridges

Crossings use whole road sections instead of deciding separately for each deck tile. Nearby wet sections form one continuous span, with a short deck extension onto the bank and a named landing at each end. All three road columns share the crossing classification. Protected building approach foundations remain solid landings. Bridge records include stable IDs, endpoints, full span paths, axis, length, `landing_from` and `landing_to`.

The existing renderer supplies planks, outer rails, periodic supports and the surface below the deck. Land turns, crossings and joins remain reserved before vegetation. Heights retain the deterministic travel surface and half-unit walkable grades. Roads cross water above it; navigation below a bridge is outside this system.

## Saved travelers

The optional `progress.life.context.roads` field distinguishes original route1 from route2. Missing metadata means the original routes. Validation reconstructs the matching planner and rejects unsupported revisions. When an old edition6 journey opens on the revised roads, a saved road traveler's progress is projected onto the new route by distance along its canonical path. Direction, pause schedule and identity carry through. New snapshots use route2. Hero world edition, destination IDs and save envelope remain unchanged.

## Checks and previews

`tests/test_road_polish.gd` checks real destination connections, rounded/diagonal segments, unrelated footprint clearance, continuous spans and banks, actual hero-footprint movement and grades, positive/negative region coverage, stream-order replay, bounded caches and an old traveler record upgrading to a valid new snapshot. Existing planner/edition5, edition6 life, new-journey disk and surface-travel checks cover compatibility. `tests/test_streaming.gd` checks worker-produced regions/cells against the live provider, incremental navigation, prepared geometry and RNG-free enemy activation.

Run `./godot.sh --script tools/capture_roads.gd --resolution 1280x800` for six silent native World/View captures at `artifacts/road-polish/`, with opposing cameras and `gallery.json`. The helper creates no account request or player-save update. Routing caches hold at most128 paths,32 materialized deck plans and65,536 entries in each terrain/water sample cache. Road heights are evaluated only for the owning region. Cold route creation adds work; existing background preparation can warm routes before travel, and a native gallery does not certify frame pacing.
