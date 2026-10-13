# Offline streaming performance

The [current Windows package](WINDOWS_RELEASE.md) was rebuilt on 2026-10-13 with the latest source and biome/landmark additions. The measurements below remain scoped to their recorded host/source snapshots; the refreshed EXE has not been timed on Windows.

The Windows release ran successfully for the user, who reported stuttering while exploring after leaving the hub. Profiling found synchronous chunk generation, full navigation rebuilds and first-use model conversions on the main thread. Measurements below are from the Apple M2 host, using seed 12345 and twenty consecutive chunk crossings in an edition-6 world. They are CPU stage timings, not Windows frame-rate measurements.

| Measured work | Before | With worker preparation and baked models |
| --- | ---: | ---: |
| Median main-thread chunk generation/installation | 91.5 ms | 4.4 ms |
| Median navigation update | 25.8 ms | 13.2 ms |
| Largest creature-view update | 213.4 ms | 8.7 ms |

Matched reports are `artifacts/streaming/profile-17080195.json` and `profile-15686481.json`. They precede the additional shared-batch-mesh optimization. Later native checks cover that optimization and both rendering thread modes. A later planner-cache transfer also retains already computed immutable route records; it does not remove all local-actor planning costs.

## What changed

All four optimizations are integrated in the main project and enabled during ordinary play. On macOS, double-click `Play.command` or run `./Play.command` from this repository. The launcher runs the current main source and its current features. The baked models are already present; no conversion step is required before playing. The worker prepares procedural offline surface chunks, including the HubWorld exterior reached through the Worldgate. The reserved Lanternwake island, remote terrain and authored finite worlds keep explicit loading.

`StreamingData` prepares missing chunks on one worker using a private World or HubWorld with the same seed, edition and hub theme. It publishes owned copies of cells, spawn records and generation caches through a mutex. The worker receives no active scene nodes or gameplay dictionaries. The game requests the next area ten movement units ahead, keeps a bounded preparation buffer, and installs ready chunks before the normal crossing update. It also warms neighboring region plans used by local travel. A world/seed/edition mismatch discards stale results. During native wilderness walking, missing preparation retains the supported previous ring until the incoming data and visuals are ready. Explicit destination travel still loads synchronously behind its loading screen. The worker is joined when its Game is destroyed.

Crossings now update navigation points and edges while retaining the unchanged part of the graph. Ordinary full rebuilds remain available for area changes and placement/collision edits. A regression compares every point and height-aware connection against the full rebuild after crossings and backtracking.

## Residual crossing pass

The user still observed a brief freeze in the Endless wilderness after the Worldgate. The first worker pass left visual construction and navigation scans on the crossing frame. The main game now prepares up to nine hidden visual chunks ahead of the player, with a two-millisecond target between individual work steps. Terrain cells, batches, houses, landmark components and portal animation frames advance separately. A completed root becomes active when its data chunk loads. An unfinished root completes synchronously when needed, preserving visible terrain and interaction geometry. Individual resource or model operations can exceed the preparation target.

World installation retains unchanged cells and updates only entering/leaving chunks. Navigation retains per-chunk point lists and checks new cells/height connections, with a full rebuild when placed obstacles change. Enemy models prepare one at a time without spawning actors or consuming combat RNG; the actual spawn reuses the matching model and retains its normal combat state. Foraging keeps unchanged patch nodes and bounded plans for the overlapping grid window. Its original allocation, depletion ledger, capacity rollback, economics and save identity remain intact.

Six fixed castle/watch/church components are baked separately in `assets/landmark_cache`. This removes an observed 46 ms first-use conversion while retaining original geometry, transforms and provenance in both visual families. Freshness checks cover their source inputs and scene bytes. The existing 302 creature/vegetation bakes remain separate.

| CPU stage on the twenty-crossing edition-6 route | Initial residual measurement | Final main-project measurement |
| --- | ---: | ---: |
| Median chunk installation | 5.6 ms | 2.5 ms |
| Median visual update at crossing | 24.1 ms | 0.4 ms |
| Median navigation update | 17.0 ms | 4.3 ms |
| Largest local-life planning update | 74.1 ms | 6.8 ms |
| Largest enemy creation/update | 40.2 ms | 0.7 ms |

Reports are `artifacts/streaming/profile-20896963.json` and `profile-22573406.json`. The final report includes foraging at 2.3 ms median, compared with 7.1 ms before patch/model retention in the native report `profile-30276749.json`. Main-project content was advancing between these reports, so these are recorded route measurements rather than a frozen whole-project A/B benchmark. Before/after source hashes are identical within the final headless and native replays. Native screenshots at crossings 1, 7, 13 and 20 were inspected. Native frame-signal waits still include longer outliers; they do not establish GPU timing or stutter-free play.

Worker equality, obstacle-aware navigation, staged/synchronous geometry, inactive bounded preparation, RNG-free enemy reuse, twelve legacy worlds, gameplay, world-object theft/collision, local life, four surface-place interactions, fresh disk saves, foraging/overlapping-model retention, hub/dimension returns and town-charm callbacks passed focused checks. The town-charm fixture now selects the existing icon tile by its tooltip as well as its old button text. The streaming fixture gets a larger frame ceiling in `check.sh` to avoid prematurely terminating its worker/timer waits.

Restart the running game and open `Play.command` to use these source changes. The previously delivered Windows performance binary remains the earlier isolated build; this pass updates the main project.

The release includes 302 baked creature and vegetation source scenes. First use loads the existing converted geometry instead of voxelizing or smoothing those models during travel. Mesh arrays, transforms, skin bindings, animation keys and provenance are checked against the original generation path. The cache records source/script/config hashes and scene hashes; stale inputs reject packaging. WorldView also shares prepared batch meshes across chunks, keeping distinct material variants separate, instead of repeatedly duplicating and uploading identical geometry.

The delivered Windows performance release preserves the original generation rules, world editions, content IDs, saved journeys and pinned online authority. Its source snapshot is `.tools/windows-performance-release/`; other agents' concurrent feature changes are outside that packaged build. The main project retains the performance changes alongside its current feature work. Surface creatures retain their owning-family rules; the previously adopted dungeon-monster voxel exception remains intact.

## Rendering on another thread

Godot supports `--render-thread separate`; its current engine reports this mode as experimental. Both safe and separate modes completed the native streaming route on this host. The separate run's startup experimental warning is expected; no runtime errors were observed. `frame_post_draw` wait timing measures only the caller's wait for that signal and must not be reported as GPU time or total frame time.

The Windows ZIP includes `EndlessWorld-ThreadedRendering.bat` to try separate-thread rendering. Launch `EndlessWorld.exe` normally for the standard render mode. On macOS, use `./Play.command --render-thread separate` to try the same engine option in the main game. A normal double-click keeps the standard render mode while using all the loading optimizations. Moving rendering does not move scene-tree work or generation automatically. See [Godot's thread-safe APIs](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/thread_safe_apis.rst) and [CPU optimization guidance](https://docs.godotengine.org/en/4.2/tutorials/performance/cpu_optimization.html).

## Repeat the checks

```sh
./godot.sh --headless --script tools/build_render_cache.gd --quit-after 36000
./godot.sh --headless --script tools/build_landmark_cache.gd --quit-after 1800
ruby tools/check_render_cache.rb
./godot.sh --headless --script tests/test_streaming.gd --quit-after 3600
./godot.sh --headless --script tests/test_render_cache.gd --quit-after 36000
./godot.sh --headless --script tests/test_landmark_cache.gd --quit-after 1800
./godot.sh --headless --script tools/profile_streaming.gd --quit-after 1800 -- --baseline
./godot.sh --headless --script tools/profile_streaming.gd --quit-after 1800 -- --prefetch
./godot.sh --render-thread separate --script tools/profile_streaming.gd --quit-after 1800 -- --prefetch
```

Bake during a serialized build window, then run checks against the completed cache. Profiling uses isolated settings/saves and removes its temporary files. Timing comparisons need an otherwise idle host; do not run a conversion suite alongside them. Existing gameplay, fresh-scene disk saves, biome presentation, creature reconstruction and item-placement regressions also passed in this slice.

Main-project integration was checked on 2026-10-13 through `Play.command`: worker/navigation/mesh sharing, all 302 cached bodies, gameplay, fresh-scene disk saves, authored dimension travel, floating-city routing and mixed-size monster packs passed without engine errors or warnings. Cache freshness and launcher syntax/argument forwarding also passed. This is focused integration acceptance; the timing table above still comes from the earlier matched performance route.

These changes reduce measured loading work, but do not establish stutter-free Windows play. Cold town construction, first shader/resource use and local-actor planning remain possible sources of spikes. Windows frame timing, extended travel, shader-driver differences and separate-thread rendering on the user's hardware need a repeat there.

## Minecraft research and continuous walking

Minecraft Java separates world generation, section rebuilding and graphics uploads. The version-specific [Fabric Yarn 1.21.1 generation interface](https://maven.fabricmc.net/docs/yarn-1.21.1%2Bbuild.3/net/minecraft/world/chunk/ChunkGenerationStep.html) exposes target status, neighboring dependencies, a write radius and completion futures. Its [ChunkStatus interface](https://maven.fabricmc.net/docs/yarn-1.21.1%2Bbuild.3/net/minecraft/world/chunk/ChunkStatus.html) lists distinct biome, noise, surface, carving, feature, lighting and completion stages. These are mapped vanilla interfaces; they do not prove that every stage runs on an arbitrary worker or that Minecraft never stalls.

The vanilla [client ChunkBuilder interface](https://maven.fabricmc.net/docs/yarn-1.21.1%2Bbuild.3/net/minecraft/client/render/chunk/ChunkBuilder.html) exposes worker execution, prioritized tasks, pooled buffers and a separate upload queue. Mojang's [1.18 release notes](https://feedback.minecraft.net/hc/en-us/articles/4415128577293-Minecraft-Java-Edition-1-18) describe blocking, threaded and intermediate section-update modes: asynchronous updates reduce stutter while allowing brief visual delays. Mojang later [removed unnecessary surrounding-chunk loading for disk reads](https://feedback.minecraft.net/hc/en-us/articles/27439656840589-Minecraft-Java-Edition-Snapshot-24w19b), reducing memory and CPU overhead.

Sodium is a Minecraft rendering mod, separate from vanilla. Its [LevelSlice implementation](https://github.com/CaffeineMC/sodium/blob/dev/common/src/main/java/net/caffeinemc/mods/sodium/client/world/LevelSlice.java) copies terrain, biome and light data for isolated worker use and recommends pooling large arrays. Its [job queue](https://github.com/CaffeineMC/sodium/blob/dev/common/src/main/java/net/caffeinemc/mods/sodium/client/render/chunk/compile/executor/ChunkJobQueue.java) puts important tasks first. The [render section manager](https://github.com/CaffeineMC/sodium/blob/dev/common/src/main/java/net/caffeinemc/mods/sodium/client/render/chunk/RenderSectionManager.java) separates blocking and deferred work, estimates build effort and limits upload size and duration. Those development-branch details are design examples, not portable numeric budget recommendations.

For this game, the useful pipeline is `requested -> data ready -> visuals prepared -> active`. Native Endless walking now keeps the previously loaded terrain ring until the incoming ring has both data and hidden visuals. The player remains on supported old terrain while the outer edge catches up. WorldView prepares at most nine jobs concurrently and retains at most 25 candidate roots, with its existing soft 2 ms work target. Preparation prioritizes the player's required ring before further travel lookahead. The worker publishes completed chunks before optional neighboring-site warming, then delivers warmed metadata separately. Explicit destination loading, finite providers, Lanternwake and downloaded online terrain retain their existing paths.

The minimap also caused walking stalls. It now retains overlapping terrain colors, samples only entering cells and draws one nearest-filtered terrain texture with live markers. Its local color cache stays bounded to 48 by 48 cells; atlas sampling stays at most 80 by 80. Online revisions, provider/seed/mode changes and finite bounds invalidate the chart as appropriate. The CPU raster is retained for headless inspection because [Godot 4.7.2's dummy texture update is a no-op](https://github.com/godotengine/godot/blob/4.7.2-stable/servers/rendering/dummy/storage/texture_storage.h); a native fixture separately checks actual updated texture pixels.

The remaining architectural work is to budget graphics uploads and first material use. A hidden prepared root does not prove its shaders have compiled. Our Compatibility renderer requires drawing representative materials and particles in the view frustum during loading to warm them; Godot's Forward+/Mobile shader baker does not apply to Compatibility. [Godot's shader stutter guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html). Off-thread mesh-array construction, loading-screen shader warmup, bounded resource-upload batches and reusable section buffers are follow-up options. The subsequent rendering pass below implements terrain-array workers, bounded terrain uploads and loading-screen warmup.

`tools/profile_walking.gd` uses isolated saves/settings, supported movement and real simulation over reachable navigation paths. It records monotonic frame intervals, measured main-thread stages, render-signal intervals and before/after source hashes. `scene_process_ms` covers idle work before the draw signal; physics has its own measured interval. `render_submit_wait_ms` includes rendering submission and waiting and is not GPU time. Godot's built-in time monitors update periodically, so their sampled values are not independent per-frame measurements. The harness protects player health to complete its route and does not certify combat balance or a quiet host when other agents have readers running.

Walking reports `48728081` (baseline), `38757147` (map change), `42552382` (earlier chunk publication), and `38574154` (deferred ring) are under `artifacts/streaming/`. The map-only replay has identical before/after recorded inputs. Other replays record concurrent source changes and are not frozen-source A/B comparisons. The final route traversed six chunks over 66.7 cells: chunk-data peak 2.46 ms, visual activation peak 0.64 ms, complete refresh peak 14.3 ms and minimap-draw peak 4.5 ms. Before deferral, the first refresh spent 119–126 ms on data and 25–29 ms on visuals. Thirty deferred frames kept supported existing terrain during preparation. Render-signal waits still reached 129 ms, with 136–138 ms wall-frame outliers; shader/driver first use is a candidate, not a proven diagnosis. The native screenshot shows filled terrain and a readable updating minimap. No stutter-free or Windows timing claim is made.

```sh
./godot.sh --headless --script tests/test_minimap_cache.gd --quit-after 600
./godot.sh --script tests/test_minimap_cache.gd --quit-after 600
./godot.sh --headless --script tests/test_streaming_defer.gd --quit-after 1800
./godot.sh --script tools/profile_walking.gd --quit-after 1800
```

Final focused acceptance is recorded in `/tmp/endless-walking-streaming-accepted.log`, `endless-minimap-cache-final.log`, `endless-minimap-cache-native.log`, `endless-walking-test_streaming_defer-catchup.log` and `endless-walking-test_{dimension_map,gameplay,landmark_cache}-accepted.log`. Each accepted run ended with exit 0 and no engine diagnostics. The catch-up fixture stages ten incoming chunks, proves that pending terrain/visuals retain the supported old ring, and checks nine-job/25-root bounds before promotion. Worker metadata merges preserve incoming snapshot keys and remove older memo keys to respect the existing 32-region/128-plan capacities. Exact warmed cache comparisons remain in the worker regression.

The last native timing report predates the final bounded metadata merge, edition-aware chart key and six-scene landmark-cache refresh. Those final changes passed focused checks but were not reprofiled natively. The landmark scenes were rebuilt on Rowan's released authoring helpers; both 302-body and six-landmark freshness checks pass. The main source and `Play.command` use these changes. The previously exported Windows EXE has not been rebuilt in this pass.

## Rendering fixes and the actual Worldgate route

The earlier walking harness started a plain World directly. A fresh player journey instead starts in Lanternwake and retains HubWorld after departing through its physical Worldgate. Exact-World gates excluded that route from worker preparation and deferred ring activation. The new `test_worldgate_streaming.gd` reproduced synchronous activation before the correction, then passed through the real new-journey and portal interaction. Game now admits the genuine HubWorld exterior. Its private worker also constructs HubWorld, preserving reserved-area cells, region records and the return gate; it never substitutes plain World metadata. Edition 6 and 7 equality and island/finite/remote exclusions are checked. The walking harness now uses that departure by default; `--plain-world` retains the older diagnostic route.

Terrain preparation now copies immutable source arrays and translation placements to a worker. The worker assembles one colored terrain surface per chunk, including indexed source meshes. Scene nodes, ArrayMesh creation and installation stay on the main thread. WorldView commits at most one prepared terrain surface per frame and retains the nine-builder/25-root limits. Props keep their original material, placement and composition paths. The geometry fixture compares positions, normals, colors and triangle counts with the original terrain.

`RenderWarmup` draws ordinary, instanced and skinned material formats, portal sprites and actual scene geometry before releasing the loading overlay. It covers shadowed/unshadowed sunlight and local-light variants, then draws two wide actual-scene frames. Physics/input pause during this loading step; the helper restores camera size, current camera and sunlight settings. Headless runs bypass it. Native capture helpers must await its busy flag and the removal of the real overlay before saving images. Hidden preparation alone did not cover the repeated first-use stalls on this Compatibility renderer. This follows [Godot's requirement to render materials during loading](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html).

The biome-art selection catalogue previously invalidated all 302 baked bodies when it changed. Runtime validity now depends on actual geometry recipes and imported sources; selection changes remain part of build freshness. The baker checks its input hashes again before publishing, and both the 302-body and six-landmark freshness checks passed after the guarded rebuild.

A remaining source-stable walking diagnostic identified a Skeleton Mage scene reparse: 49.5 ms in native preparation and 62.7 ms headless. Releasing the actor had also released its PackedScene. The render cache now retains up to 32 scenes and permits two asynchronous native resource requests. Enemy preparation checks readiness before constructing nodes, leaving gameplay RNG and physics on the main thread. Headless loading remains synchronous. A failing retention regression passed after this correction. As [Godot documents](https://docs.godotengine.org/en/stable/classes/class_resourceloader.html), retrieving a threaded resource too early can block; ordinary prepared actors wait for the loaded status.

Native report `walking-45652784.json` is source-stable but uses the older plain-World route before the retained-scene correction. Its 1,200 frames cover 69.4 cells: median wall interval 20.3 ms, 95th percentile 28.3 ms and maximum 81.2 ms; the render-signal interval peaks at 56.0 ms. Earlier repeated 125–130 ms render intervals disappeared after the actual-scene warmup. These are observed route results, not a matched whole-project comparison, GPU measurements or Windows acceptance. The denser edition-7 composition also changes draw counts.

The first corrected-provider attempt, `walking-42922513.json`, is rejected: the script viewport was not producing draw signals, loading timed out and the player never moved. The profiler now explicitly sizes/shows its window, stops on incomplete loading and rejects missing movement or render samples. `walking-38394287.json` is a clean, source-stable 650-frame HubWorld diagnostic, but its setup changed destinations and snapped the camera before loading finished. That shrank the intended wide coverage and retained a 127 ms render interval. The profiler now awaits each portal destination separately. RenderWarmup also enforces wide coverage until both actual scene draws complete, then restores the player's previous zoom. A failing camera-coverage regression passes after the guard, including a native pre-draw check.

Final report `walking-38948998.json` covers a genuine new journey, the physical Worldgate departure and 650 walking frames over 35.0 cells in HubWorld exterior. No competing native capture/profile ran during this replay. Its loaded scripts, starting JSON files and profiler have identical before/after hashes; unexpected newly loaded scripts reject acceptance. Unconnected drafts are outside that guard. The saved PNG was inspected: terrain, shadows, portal, NPCs and minimap are present, with no loading overlay.

| Final actual-Worldgate measurement | Result |
| --- | ---: |
| Median wall-frame interval | 18.4 ms |
| 95th-percentile wall-frame interval | 28.6 ms |
| Maximum wall-frame interval | 51.4 ms |
| Maximum render-signal interval | 41.2 ms |
| Maximum prepared enemy-model work | 0.79 ms |
| Maximum chunk visual activation | 0.66 ms |
| Maximum complete surface refresh | 12.4 ms |

The preceding HubWorld diagnostic peaked at 138.2 ms wall time. The repeated 125–130 ms rendering stalls did not recur in the final route, and the earlier 49.5 ms scene preparation did not recur. These observations support the fixes on this host and route; they do not establish a matched whole-project comparison or stutter-free play. Smaller outliers remain, and the current Windows EXE has not been rebuilt or timed.

The accepted walking snapshot precedes other agents' subsequent rare-landmark World/controller integration. That content has separate acceptance and is outside this renderer benchmark.

Thirteen focused regressions passed: terrain arrays, headless warmup, camera coverage, cache selection/retention, worker/navigation/geometry, deferred ring, actual Worldgate streaming, gameplay, fresh disk saves, floating-city routing, finite travel and all 302 baked bodies. Native warmup coverage/restoration and asynchronous resource-retention checks also passed. Every accepted run ended with exit 0 and no engine errors or warnings. Logs are `/tmp/endless-render-final-*.log`, `/tmp/endless-worldgate-stream-final.log`, `/tmp/endless-render-camera-green.log`, `/tmp/endless-render-warmup-camera-native.log`, `/tmp/endless-render-native-final-render_cache_retention.log` and `/tmp/endless-render-worldgate-native-accepted.log`. This is focused acceptance, not a complete repository suite. Both cache freshness checks, shell syntax and whitespace checks are clean.

```sh
./godot.sh --headless --script tests/test_worldgate_streaming.gd --quit-after 3600
./godot.sh --headless --script tests/test_terrain_mesh_data.gd --quit-after 600
./godot.sh --headless --script tests/test_render_camera_warmup.gd --quit-after 600
./godot.sh --script tests/test_render_warmup.gd --quit-after 600
./godot.sh --script tests/test_render_cache_retention.gd --quit-after 600
./godot.sh --script tools/profile_walking.gd -- --frames=1200
```
