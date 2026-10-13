# Lives, wildlife and town episodes

Owner: Wren. This implements the first stage of the [coordinated roadmap](ENDLESS_WORLD_ROADMAP.md), building on the [living-world research](LIVING_WORLD_RESEARCH.md). Validation results are recorded below and in `chat.md`.

Residents walk between a few nearby activity spots, pause when approached, and turn toward the player. Their E prompt follows the actual model. The fountain keeper stays within the accessible town square. Residents and animals are peaceful, nonblocking actors; they do not participate in enemy targeting, dungeon gate counts, combat drops or rewards.

Town animals rest, forage and move within a small home range. Sparse wilderness groups occupy suitable walkable land away from towns. The initial data defines cats, chickens, chicks, dogs, horses, pigs, raccoons, sheep and wolves. Habitat/biome eligibility and weights determine which appear. Wolves in this system are observational wildlife; hostile creature behavior belongs to the separate enemy catalogue.

Fountain suppers and local deliveries follow an in-game calendar. Towns can finish them while the player explores a dungeon. Supper cups or received crates remain briefly afterward. Residents offer a local-activity topic while an episode or its aftermath exists. The same calendar facts control the props and replies. Observing an episode grants no timed reward or compulsory errand.

The living clock pauses in modal screens, the Sanctum and enterable interiors. It stops when the application closes. A suspended destination retains its clock, actor positions, routes, activities, and selected animal definition/model IDs through saving and returning.

## Editable content

`config/world_life.json` defines species, registry model queries, habitat/biome weights, sizes, animation names, movement speeds, resident dwell settings and episode schedules. Generic scheduling, movement and presentation handlers live in GDScript. New species and additional instances of supported episode recipes can be added through data; a new behavior or visual recipe needs an explicit handler.

For example, a species entry uses this format:

```json
{
  "id": "woodland_neighbor",
  "habitats": ["wild"],
  "biomes": [0],
  "weight": 2,
  "height": 0.4,
  "speed": 0.65,
  "idle": "Idle_Eating",
  "walk": "Walk",
  "models": {
    "pack": "quaternius_cube_world",
    "tags": ["animal", "voxel"],
    "patterns": ["*/Raccoon.gltf"]
  }
}
```

Biome IDs follow `World.BIOMES`. Weights are positive integers. Model queries select already adopted registry records, with a wildcard matching the stable asset ID. Missing art makes a definition ineligible. The selected animal definition and asset IDs survive a save rather than being rerolled when unrelated models are added. If an optional ambient definition/model is removed, restoration uses a current compatible baseline animal.

The supported episode visuals are `meal` and `crates`. Each episode has a unique `id`, readable `label`, and ordered start/finish/end times inside `cycle_seconds`. Windows cannot overlap. `active` lasts until finish; `aftermath` lasts until end. Timings are measured in unpaused gameplay seconds, with a half-second logical tick. The starting town uses the supplied schedule directly; other towns have seeded offsets and occasional empty cycles.

Author new replies under `lore/content/` through the existing importer. Existing local-life replies support the four supper/delivery conditions. New supported calendar IDs can use `condition: "Local activity"` with matching `life_kind` and `life_phase` metadata and `event: "topic_local_life"`. Unsupported conditions remain ineligible. Extra prose alone does not create an episode or implement a player action.

Use the [asset pipeline](ASSET_PIPELINE.md) to adopt new art/text, then run a single editor import. The animal rule selects the staged Cube World animal folder using `animal`, `peaceful` and `voxel` tags. Publisher files and licenses remain preserved. The original source models were not edited.

## Runtime boundaries

`WorldLife` is a journey-owned in-process coordinator. It updates a capped nearby set and derives distant episode phases analytically. It allocates no global population, replays no missed movement history, creates no background thread and performs no network requests.

The current hard limits are twelve individual peaceful actors, three nearby town plans, two wilderness habitat groups, one added path request per simulation call, and 169 searched cells per local route. Residents and town animals have priority over optional wilderness groups. Routines change intention every few seconds rather than every frame. Movement uses the existing footprint and terrain-step checks; animations follow movement separately.

Residents live under `WorldLifeView`, independently of terrain chunks. Chunk removal cannot delete a nearby moving resident or leave a second decorative copy. Shared `WorldView.npc_models` references are retained for greeting presentation. Existing static WorldView consumers can still render fixed residents when its living-residents mode is disabled.

Placement uses the current stable city centers and ordinary walkability. Wilderness habitats are chosen deterministically from nearby loaded chunks, with explicit ordering at equal distances. No new terrain collision or obstruction is created. New episode visuals are deferred during active combat; already presented scenes can finish and clear normally.

Mutable actor records are capped and saved only for the current nearby set. Unloaded routine positions are reconstructed from their baseline and current clock when the place becomes relevant again. Unique books, discovered places and personal story progress continue to belong to their owning systems. This pilot does not retain an unlimited permanent history for every ambient animal.

## Shared interfaces and saves

| Interface | Contract |
| --- | --- |
| `game.life.event_at(city_id)` | Empty dictionary or `kind`, `phase`, `instance_id`, `home_city_id`, start/finish ticks, label and supported visual recipe. Available without loading a distant scene. |
| `game.life.residents()` | Live NPC records with stable generated IDs, explicit home `city_id`, and current `point`. |
| `game.life.actors` | Capped current peaceful actor records; `kind` distinguishes `npc` and `animal`. Animal records contain stable `species` and `asset_id`. |
| `game.life.sync(world, point)` | Refresh bounded nearby plans/actors after streaming or surface entry. |
| `game.life.advance(delta)` | Advance the logical clock. Game calls this only for unpaused overworld/dungeon play. |
| `game.life.step(world, player, delta)` | Decide and move nearby actors within local work limits. |
| `game.life.snapshot()` / `restore(data, seed)` | Versioned, bounded JSON-compatible progress; invalid restoration leaves existing life state intact. |
| `game.life_view.sync(game)` | Position/animate independent actor models and present at most one nearby episode. |

Journey capture stores optional `progress.life`. Its validator checks time ranges, actor count, canonical IDs, local positions, routes and activity/asset fields. Saves without this field get deterministic defaults. The living feature itself adds no generation reset; Lorekeeper separately owns the current geography version/reset policy. Tests and native helpers use isolated save directories.

Rowan owns discovery records and journal collections, Ember owns enemy/interior behavior, Lorekeeper owns geography/town plans, and Aster owns sound/cosmetic ambience. Their content can bind to living event facts without creating another actor scheduler. Shared integration changes and asset builds are coordinated in `chat.md`.

## Verification

```sh
./godot.sh --headless --script tests/test_world_life_catalog.gd --quit-after 600
./godot.sh --headless --script tests/test_world_life.gd --quit-after 600
./godot.sh --script tools/capture_world_life.gd --resolution 1280x800
./check.sh
```

The catalogue check covers actual adopted geometry/animation for nine species, weighted habitat eligibility, new data identities, duplicate IDs and overlapping episode rejection. The gameplay check covers bounded physical movement, immutable generated plans, offscreen episodes, current E positions, combat RNG isolation, validated saves, frozen menus/Sanctum, prior-save defaults and New Game.

The native helper captures routines, a supper, local dialogue, delivery/aftermath, a naturally streamed wildlife group and a species gallery. It checks modal animation freeze and reports a short coordinator-only CPU sample. That sample excludes rendering, streaming and other systems. It does not establish whole-game frame-time performance, a release-build budget or long-session stability.

Final Wren handoff: both focused checks pass, and `./check.sh` exited 0 with four Ruby tests / 36 assertions, catalogue freshness, editor import and all 23 Godot groups registered when the run began. That run includes enemy/interior, geography, saves/Sanctum, character, lore and ambience integration. The newer exploration lane retains its own pending handoff and final combined verification. Log: `/tmp/endless-wren-combined-check.log`.

The native helper exited 0 without engine errors or warnings. I reviewed seven 1280x800 captures, including actual moving-resident E dialogue, a streamed wildlife group, episode traces and the nine-species gallery. Modal animation freeze passed. Latest 600-sample coordinator-only timing was median 22 microseconds, p95 97 microseconds and maximum 143 microseconds on the Apple M2 in the native editor/debug runtime. This is a small local sample; rendering, streaming, the rest of gameplay and release-build performance are outside that measurement. Log: `/tmp/endless-wren-life-native.log`. Captures: `artifacts/life-*.png`.

The focused gameplay check also verifies that active combat defers a new episode and clears stale presentation. The final frame-placement refinement was reviewed natively; its scene-only change leaves the coordinator/save logic unchanged. Owned-file whitespace, local document links and shared `git diff --check` pass. Balance, repetition, distant travel, hardware variation and sustained performance remain playtesting work.

## Road activity expansion

The road/trade/patrol extension is described in [World activity](WORLD_ACTIVITY.md). It adds eight bounded road actors alongside the original twelve local residents/animals, named monster grounds, guards, barter and varied town episodes. The total live actor cap is now twenty; the original local route-search budget and fauna medium rules remain in use.
