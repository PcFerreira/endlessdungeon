# Terrain generation

The Minecraft research source is Microsoft's [World Generation Overview](https://learn.microsoft.com/en-us/minecraft/creator/documents/world-generation?view=minecraft-bedrock-stable). It describes seeded gradient noise for continuous landforms, followed by biome, structure, feature, sky, and spawning passes. Biome inputs include height, temperature, humidity, erosion, and variation noise.

This prototype adapts that sequence to an isometric game. It uses a height field with one surface per column. Overhangs, digging, and natural cave networks are outside this version. Underground destinations still use the room-and-corridor dungeon generator.

## Landforms

`scripts/world.gd` seeds separate FastNoiseLite fields for continents, erosion, ridges, local elevation, rivers, temperature, and moisture. Broad continental noise sets the low-frequency height. Ridged noise adds peaks, erosion reduces their strength, and local elevation adds smaller variations. Heights are clamped to 0 through 8 world units and rounded into half-unit terraces.

The climate pass chooses Greenwood, Sunlit Meadows, Amber Wastes, or Frostlands. High wilderness terrain uses the frost palette. Low land, local lake noise, and narrow river channels create water. Roads crossing water become bridges. The surface remains deterministic at chunk boundaries and negative coordinates.

## Roads and structures

Cities occupy level plateaus. The surrounding terrain blends toward each plateau. The main roads interpolate between neighboring cities' plateau heights. Dungeon spurs interpolate from the highway to a level entrance platform. Entrance heights are limited by the spur length so the grade stays within a walking step. Entrance blending affects adjacent terrain without changing road heights. Trees, rocks, city buildings, facade props, and entrance pillars retain their blocked footprints. Wilderness props require a lower placement roll than all eight neighboring cells, preventing adjacent blocking props.

This ordering keeps settlements usable even when their surrounding terrain is steep. Terrain and vegetation are batched with MultiMesh. Columns have stone sides, a soil cap, and a biome-colored surface. A cutaway shader follows the camera direction and covers foreground terrain and buildings to keep the character visible while orbiting.

## Traversal

Characters can walk up a half-unit step. Larger ledges require a jump. Space launches the character upward with a velocity of 7.2 units per second; gravity is 20 units per second squared. Maximum jump height is about 1.3 units. The character cannot jump again until landing. The camera follows ground height, so jumping does not bounce the view.

Horizontal movement checks the character footprint and current airborne clearance. Landing uses the highest terrain beneath the footprint, avoiding descent into a ledge while the feet still overlap it. Movement can retreat toward lower ground after a fall, even when the footprint overlaps higher terrain. A jump cannot pass through trees, buildings, walls, or water. Water crossings use bridges in this MVP. Walking down a large drop causes a fall and landing; fall damage is not implemented.

Spawn and load positions are checked for stable footing and obstacle clearance. An invalid position moves to a nearby open cell with a walkable neighbor; the surface can fall back to the sanctuary. The pause menu also offers Return to sanctuary / Unstuck, preserving health and progression.

Enemy navigation connects adjacent walkable cells only when their height difference is at most half a unit. Tall terrain blocks line of sight. Ability range includes vertical distance, and projectile collisions include terrain height.

## Checks

`tests/test_world.gd` checks varied heights, all four biomes, seeded regeneration, finite dungeon lengths, bounded chunk data, city/prop collision, and routes from cities to their entrances. `tests/test_generation_routes.gd` uses actual footprint movement to reach both entrances in 128 seeded regions at positive and negative coordinates. `tests/test_traversal.gd` checks ledges, retreat after falling, airborne clearance, solid obstacles, and terrain occlusion. The gameplay check verifies footprint landing and movement onto the supported ledge. Save checks verify relocation from a blocked position. Native previews cover the city, wilderness in four biomes, camera orbit, terrain terraces, and a jump.
