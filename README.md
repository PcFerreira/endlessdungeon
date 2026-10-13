# Endless World: The Wandering Lands

A playable Godot prototype of an isometric fantasy world with magic and sword combat. Travel through generated biomes, follow roads into cities, and explore dungeons beneath old ruins. The overworld generates new chunks as you move. Each dungeon has a seeded length of 1 through 20 floors. Its final chest awards one skill point.

The art uses 3D voxel forms and an orthographic camera, with imported fantasy props dressing buildings and ruins. Forgotten Realms and tabletop adventures are aesthetic references. Terrain, buildings, characters, and location names are original; adopted props and music are listed in [CREDITS.md](CREDITS.md).

## Play

Double-click `Play.command` on this Mac. Double-click `Edit.command` to open the editor, or open `project.godot` in Godot and press F5.

```sh
./godot.sh
./godot.sh --editor
```

The launcher finds the local engine in `.tools/Godot.app`, an installation in `/Applications`, or `godot` / `godot4` on your PATH. The local engine came from the [official Godot website](https://godotengine.org/download/macos/). This prototype was tested with Godot 4.7.2 on an Apple M2 using the Compatibility renderer.

| Control | Action |
| --- | --- |
| WASD or arrow keys | Move relative to the screen |
| Left-click an enemy | Select it |
| Left-click empty ground | Clear the target |
| 1 through 0 | Cast the ability assigned to that slot |
| Space | Jump and clear larger terrain ledges |
| Q / R | Rotate the camera left / right by 45 degrees |
| Middle-mouse drag | Orbit the camera freely |
| Mouse wheel | Zoom the camera |
| G | Open or close the grimoire |
| H or click the Sanctum Sigil | Enter your pocket home or return to the place you left |
| Click a filled action-bar slot | Cast its ability |
| E near a city fountain | Rest and set your sanctuary |
| E near a ruin | Enter its dungeon |
| E at the dungeon stairs | Return to the world |
| E at an unlocked underground gate | Descend to the next floor |
| E at the final chest | Claim one skill point after defeating the wardens |
| F inside a dungeon | Return to its surface entrance |
| Tab on the surface | Open or close the regional atlas |
| Click a city or dungeon on the atlas | Set a route marker |
| Esc | Close the atlas, clear the target, or pause/resume |
| F5 | Save to manual slot 1 |
| F9 | Load the newest valid save |
| F11 | Toggle fullscreen |
| M | Toggle sound |
| R or Enter after death | Respawn at your sanctuary |

Start in a generated city. Its fountain restores vitality and your class resource and sets your respawn point. Cities protect the character from hostile damage. Citizens are decorative in this MVP. Follow the paved streets and dirt roads into the wilderness; the atlas marks nearby cities and dungeon entrances.

Inside a dungeon, defeat its wardens to unlock the descent gate. The final floor contains a chest that awards one skill point. Claim it once per dungeon, then spend the point in the grimoire. Intermediate floors restore resources when you descend. Returning to the surface keeps the dungeon's current depth and defeated enemies. Each entrance has a different layout seed. Defeated wilderness enemies also stay defeated when their chunks reload.

Death returns you to the last city sanctuary when you press R or Enter. You keep learned skills, action-bar assignments, unspent points, chest claims, and world progress. The main menu offers Continue, New Game, Load Game, Options, Credits, and Quit. New Game opens class selection and starts a fresh journey. Three manual save slots and an autosave preserve your expedition between launches, including live combat, dungeon discovery, and camera settings. See [docs/SAVES.md](docs/SAVES.md) for storage and recovery details.

Esc opens the pause menu after clearing a selected target. Save, load, change options, or return to your sanctuary if trapped. Returning to the main menu, quitting, and closing the window save the journey. Movement remains relative to the screen as you rotate the camera.

## Your sanctum

Every character starts with a bound Sanctum Sigil, shown beside the action bar. Press H or click it while grounded and away from enemies to enter the Inner Sanctum. This floating island is your home in a pocket dimension. E at the hearth restores vitality and your class resource. E at the portal, or H anywhere inside, returns to your previous world or dungeon position. The outside area waits while you are home, keeping its enemies, loot, discovery, and dungeon progress.

You can save, load, change your action bar, and learn skills at home. Home saves retain the return destination across launches. The island has a study and two marked spaces for future furnishings. Collecting and placing furniture will come in a later round. See [docs/SANCTUM.md](docs/SANCTUM.md) for the mechanic and expansion points.

The HUD uses the supplied Kenney RPG UI Pack and Fantasy UI Borders. It has compact framed vitality/resource bars, class identity, a minimap with book/menu buttons, ten ability slots with costs and cooldowns, and the sigil item. The target panel appears when an enemy is selected. Sword uses a green stamina bar; Mage and Spellsword use blue aether bars.

## Classes and grimoire

Choose a class before beginning a journey:

| Class | Starting abilities | Resource |
| --- | --- | --- |
| Mage | Arcane Bolt, Ember Orb, Frost Nova, Blink | Aether |
| Sword | Sword Strike, Cleave, Iron Guard, Battle Step | Stamina |
| Spellsword | Sword Strike, Arcane Bolt, Ember Orb, Blink | Aether |

Press G to open the grimoire. Its skill tree has damage, resource, and vitality branches, with prerequisites for three further abilities per class. Each rank costs one point. Claim points from final dungeon chests; an opened chest cannot award another point after leaving, returning, or respawning. Select the Abilities and action bar tab to assign learned abilities to any of the ten slots. Moving an ability removes it from its old slot.

## Combat

The action bar is ordered `1 2 3 4 5 6 7 8 9 0`. Four abilities are equipped initially. Click an enemy to select it. Targeted magic and sword strikes require a clear line of sight and range, including vertical distance. Melee reach is about 1.7 cells; ranged spells reach 7.5 cells. Failed casts spend no resource and start no cooldown.

Projectiles follow the cast-time target. Cleave hits an arc ahead of the character, Whirlwind hits all nearby enemies, and Iron Guard reduces incoming damage for three seconds. Healing, area spells, movement abilities, and guard work without a target. Resources regenerate. Defeated enemies drop vitality or resource pickups.

## Current world MVP

- Four noise-driven biomes: Greenwood, Sunlit Meadows, Amber Wastes, and Frostlands.
- Biome vegetation, rocks, water, roads, bridges, terraced terrain, and jumping. Terrain generation follows a noise-first sequence adapted from the Minecraft research in [docs/TERRAIN.md](docs/TERRAIN.md).
- Generated compact cities with six to eight houses, varied roofs and heights, a tower, a fountain, and decorative citizens.
- One city and two independently seeded dungeon entrances per 64 by 64 region.
- Finite dungeons with 1-20 floors, discovery fog, one-time reward chests, and surface return.
- A scrolling minimap and a regional atlas with route selection.
- Mage, Sword, and Spellsword classes; targeted magic and melee combat; fifteen abilities; a grimoire and ten-slot action bar.
- Chunk loading with 25 active chunks of 16 by 16 cells each.
- Deterministic regeneration and disk saves for character builds, defeated enemies, dungeon progress, and live actors.
- An orbiting orthographic camera, view-relative movement, outdoor cutaways, and dungeon walls that adjust with the view.
- Banners, barrels, crates, pots, and statues in cities; imported stone arches at dungeon entrances.
- Tiled dungeon floors, wall torches, flame particles, fountain mist, and magic motes.
- Nine area-based music tracks with loops, two-second crossfades, and a delay that prevents rapid changes at biome boundaries.
- Main and pause menus, three manual saves, autosaving, backup recovery, fullscreen, audio options, and in-game credits.
- A persistent pocket home with safe recall, hearth rest, an exact journey return, its own chart and ambience, and space for future furnishings.

The world has no fixed map boundary. Terrain has half-unit terraces, hills, peaks, valleys, rivers, and water. Characters can jump up larger ledges. Landing checks the whole footprint and allows movement away from a ledge after a fall. Cities use level plateaus, dungeon roads have bounded grades, and wilderness props have spacing to leave room for passage. Cities use modular layout templates with seeded variation; their interiors, shops, and quests are not implemented.

## Project structure

| File | Responsibility |
| --- | --- |
| `scripts/grid_area.gd` | Height-aware movement, collision, and line of sight |
| `scripts/character_build.gd` | Classes, abilities, skill trees, unlocks, and action-bar assignments |
| `scripts/save_store.gd` | Save validation, atomic file replacement, and backup recovery |
| `scripts/journey.gd` | Capture and restore character, world, combat, and camera state |
| `scripts/sanctum.gd` | Home floor plan, obstacles, hearth, portal, and furnishing spaces |
| `scripts/sanctum_view.gd` | Floating island, study, lights, portal, and star motes |
| `scripts/ui_skin.gd` | Imported UI frames and composed resource bars |
| `scripts/world.gd` | Biomes, regions, city layouts, roads, dungeon sites, and chunk data |
| `scripts/world_view.gd` | Chunk rendering, instancing, and outdoor structures |
| `scripts/world_voxels.gd` | Outdoor terrain, vegetation, buildings, and props |
| `scripts/scenery.gd` | Imported models, normalized grid dimensions, and shared materials |
| `scripts/ambience.gd` | Flame, mist, and magic particles |
| `assets/world_cutaway.gdshader` | Outdoor obstruction cutaway |
| `scripts/dungeon.gd` | Seeded underground generation |
| `scripts/dungeon_view.gd` | Underground rendering, discovery, and stairs/gate |
| `scripts/voxel_kit.gd` | Shared mesh construction and combat models |
| `scripts/game.gd` | Travel, actor state, combat, progression, and respawn |
| `scripts/interface.gd` | HUD, action bar, menus, and atlas overlay |
| `scripts/minimap.gd` | Surface maps, route selection, and underground discovery map |
| `scripts/soundscape.gd` | Area music, loops, crossfades, volume controls, and synthesized effects |
| `docs/MVP.md` | Current design and next development steps |
| `docs/TERRAIN.md` | Minecraft research, generation passes, terrain and jump rules |
| `docs/SAVES.md` | Menus, save slots, autosaving, stored state, and recovery |
| `docs/SANCTUM.md` | Sigil, home travel, persistence, and future furnishings |

Gameplay uses `Vector2(x, z)`; rendering uses `Vector3(x, height, z)`. One world unit is one terrain cell. Character models face positive Z and have their origin at the feet. Terrain and props use shared meshes and MultiMesh batches. The generator and visual models are separate so imported assets can replace the procedural kit.

To repeat a world:

```sh
./godot.sh -- --play --seed=12345 --class=spellsword
```

## Checks and previews

```sh
./check.sh
./godot.sh --script tools/capture_preview.gd --resolution 1440x900
./godot.sh --script tools/check_audio.gd --resolution 480x270
```

`check.sh` imports the project and runs the asset, progression, traversal, world, generation-route, dungeon, gameplay, camera, save/load, sanctum, and window-close checks. It requires ripgrep and fails on engine errors, warnings, or missing PASS markers. Asset checks load imported geometry and materials, verify grid scale, decode all nine tracks, and check music context changes. Solid city props have generated blocked cells outside the house footprints.

Progression checks cover prerequisites, rank limits, skill costs, unlocks, and unique slot assignment for all three classes. Traversal checks cover walking, footprint landing, ledge retreat, solid obstacles, and terrain occlusion. The world check covers 12 seeds, all four biomes, city buildings and their collision, bounded chunk loading, negative/distant coordinates, and identical data after reload. Route checks use physical movement to reach both dungeon entrances in 128 seeded regions. The dungeon check covers 200 seeded floors. Live-scene checks cover combat, progression, travel, jumps, respawn, reset, and pause. Camera checks cover keyboard and mouse orbit, view-relative movement, zoom, and menu isolation. Save checks use temporary directories and fresh game scenes to verify disk round-trips, backup recovery, invalid-file rejection, safe relocation, and saving before window-close exit. Automated checks keep real journey files and settings untouched.

Sanctum checks cover recall restrictions, hearth rest, world/dungeon return with retained drops and random state, skills learned at home, a home save loaded into a fresh scene, prior saves without a home field, invalid recursive destinations, and sanctuary escape.

Rendered captures cover the new HUD, sanctum/hearth/return, main and pause menus, save/load slots, options, rotated outdoor and dungeon views, starting city, credits, atlas, four biomes, dungeon entrance, underground combat, final chests, all three classes, grimoire/tree/action-bar assignment, jumps, surface return, and death. They are written to `artifacts/`. The native audio check records the music mixer and checks playback, Ogg/MP3 end looping, crossfades, and music mute. Visual inspection and native audio checks are separate from headless checks. Long journeys, combat balance, and other hardware still need work.

## Assets

Voxel models, the icon, spell icons, sanctum sigil, shader, and synthesized combat sounds were created for this project. Cinzel is distributed under the SIL Open Font License included in `assets/fonts/OFL.txt`. KayKit, Quaternius, and Kenney runtime assets include their CC0 licenses. UI graphics from Kenney's RPG UI Pack and Fantasy UI Borders live under `assets/ui/`. Music by Eric Matyas uses the Soundimage International Public License, with attribution in the main-menu Credits screen and [CREDITS.md](CREDITS.md).

`import_assets/` is a staging directory for supplied source packs. Its `.gdignore` keeps raw collections out of Godot's import scan. A selected subset and all nine music recordings are copied to `assets/`, with source paths and hashes in `assets/source_manifest.json`. Run `ruby tools/adopt_assets.rb` to repeat the selection. The original staging files are preserved.
