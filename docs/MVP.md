# MVP 0.7

The player chooses Mage, Sword, or Spellsword and travels through an isometric voxel world. Cities provide sanctuary, roads connect destinations, and ruins lead into finite dungeons. Completing a dungeon earns one skill point from its final chest.

## Classes and combat

Keep Godot, an orbiting orthographic camera, click-to-select targeting, and the ten-slot `1 2 3 4 5 6 7 8 9 0` action bar. Q/R rotates by 45 degrees, middle-mouse drag orbits freely, and the wheel zooms. Movement stays relative to the screen. Outdoor cutaways and dungeon wall heights respond to the camera direction. Forgotten Realms remains an aesthetic reference. Voxel terrain, characters, buildings, names, and abilities are original; adopted environment props and music retain their licenses and credits.

Mage starts with Bolt, Ember Orb, Frost Nova, and Blink. Its unlocks are Storm Lance, Mending Light, and Meteor. Sword starts with Sword Strike, Cleave, Iron Guard, and Battle Step. Its unlocks are Whirlwind, Second Wind, and Execution. Spellsword starts with Sword Strike, Bolt, Ember Orb, and Blink. Its unlocks are Runeblade, Frost Nova, and Mending Light.

Sword uses stamina and has 140 base vitality. Mage uses aether and has 100 vitality. Spellsword uses aether and has 120 vitality. Targeted attacks check range, vertical distance, visibility, resource, and cooldown before spending anything. Sword strikes deal immediate damage. Projectiles follow their selected enemy. Guard reduces incoming damage by 65% for three seconds. Execution doubles its damage against targets below half vitality.

## Grimoire and skill tree

G opens the grimoire and pauses simulation. Each class has six skill nodes. Power has three ranks and adds 15% ability damage per rank. Reserves and vitality have two ranks, adding resource capacity/regeneration or maximum vitality. Specialty requires power, utility requires reserves, and the advanced ability requires specialty. Every rank costs one skill point.

The grimoire lists learned abilities, descriptions, costs, cooldowns, and target ranges. Assign abilities to any action-bar slot, including 0. An ability occupies at most one slot. Skill ranks and assignments survive dungeon transitions, death, and saving/loading.

## Finite dungeons

Each entrance's seed selects a fixed length of 1 through 20 floors. Floor generation uses the entrance seed and current depth. Defeating a floor's wardens unseals its exit. Intermediate exits descend directly and restore resources. The final exit is a chest, with no further descent.

The chest grants one skill point once per dungeon. The chest remains open after leaving and re-entering. Defeated wardens, their recorded health, the dungeon's current floor, and reward claims persist and are included in saves. F or E at the starting stairs returns to the surface. Death returns the character to the city sanctuary and preserves the build and dungeon progress. A new journey resets the build, points, reward claims, and world session.

## Menus and saves

The main menu provides Continue, New Game, Load Game, Options, Credits, and Quit. Esc opens a pause menu with saving/loading, options, grimoire, return to sanctuary, main menu, and save-and-quit. Three manual slots and an autosave preserve the character, world seed, progression, discovery, live combat, jump state, and camera view. F5 saves slot 1; F9 loads the newest valid save. Autosaves run during gameplay and at progression events, menu return, quit, and window close. Validated temporary writes and a previous-valid-file backup protect slots. See [SAVES.md](SAVES.md).

## Terrain and jumping

The world streams 25 chunks of 16 by 16 cells. Regions are 64 by 64 cells, with one compact city and two dungeon sites. Separate seeded noise fields define broad landforms, erosion, ridges, local detail, rivers, and climate. Heights range from 0 to 8 world units in half-unit terraces. Climate and altitude determine biome palettes and vegetation. Cities have level plateaus, entrance platforms are level, and roads interpolate heights to remain traversable.

Space jumps with real vertical velocity, gravity, clearance checks, and landing. Walking climbs half-unit steps; jumping clears larger ledges. Large downward steps cause a fall. Landing uses the whole footprint, and horizontal movement allows retreat from a higher ledge. Wilderness props are spaced and entrance roads use bounded grades. Invalid loaded positions move to an open spot; the pause menu provides a sanctuary return if trapped. Trees, walls, buildings, and water stay impassable. Use bridges to cross water. Enemy path connections respect height differences and line of sight includes terrain occlusion. See [TERRAIN.md](TERRAIN.md) for the Minecraft research and detailed rules.

## Pocket home

Every character starts with a bound Sanctum Sigil beside the action bar. H opens the Inner Sanctum while grounded and away from enemies. The floating island has a safe hearth, study, return portal, and two spaces for future furnishings. E at the hearth restores vitality and the class resource. H or E at the portal returns to the suspended world or dungeon location, retaining progress, enemies, loot, and discovery. Home saves preserve the return destination across launches. See [SANCTUM.md](SANCTUM.md).

## Environment and audio

The HUD uses Kenney's RPG UI Pack for panels, buttons, and resource bars, with Fantasy UI Borders for frames and dividers. The class panel and action tray are compact; a target panel appears only for selected enemies. The minimap has book/menu controls and changes to a home chart inside the sanctum. A Sanctum Sigil item sits beside the ten ability slots.

Keep the voxel structures and characters. KayKit props dress cities and dungeon rooms, Quaternius arches mark entrances, and Kenney textures add flame, mist, and magic particles. A cutaway shader preserves the character silhouette behind foreground buildings, vegetation, and terrain.

Eric Matyas's nine music tracks follow cities, biomes, shores, and dungeon themes. Track changes crossfade over two seconds; biome changes wait briefly to avoid repeated restarts near a border. Options controls music and effects separately, mute, and fullscreen. Credits are available from the main menu.

## Validation and next work

Checks cover imported assets/music, skill prerequisites and slot assignment, height-aware collision and jumping, terrain occlusion, seeded finite dungeon lengths, physical routes through 128 seeded regions, bounded streaming, deterministic regeneration, one-time rewards, class combat, resource gates, travel, death, reset, camera controls, save/load round-trips, backup recovery, and save-before-window-close. Sanctum checks cover safe recall, rest, exact return, progression learned at home, fresh-scene saves, and legacy compatibility. Native captures cover the HUD, sanctum, menus, camera rotation, three classes, the grimoire, final chests, jumping, and terraced terrain. Native audio has a separate playback/crossfade check.

Playtest terrain readability, jump feel, melee reach, enemy pursuit, ability balance, and the time needed to finish a 20-floor dungeon. Next work includes collectible furnishings and placement in the sanctum, inventory, boss encounters and distinct dungeon identities, city shops/quests/interiors, more biome vocabulary, and background generation. Mining, volumetric caves, overhangs, long-session performance, and other platforms are outside the current validation.
