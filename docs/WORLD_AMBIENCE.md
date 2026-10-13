# World ambience

Exploration now mixes the existing music with a quieter environmental layer. Greenwood has forest air and distant birds; meadows have open wind; wastes have a drier wind; Frostlands have mountain air. Nearby water replaces the wilderness bed with flowing water. Towns use their fountain, dungeons use a subterranean loop, interiors use quiet room air and occasional creaks, and the Sanctum has an original harmonic hum.

Small voxel wisps drift above reachable ground. Their colors follow the biome, and spellcasting briefly brightens them with an original three-note chime. They are friendly scenery: they have no collisions, target markers, rewards or interaction prompts. The direction takes Adventure Time's playful, everyday magic as a reference while using original creatures and charms.

Residents, watch and travelers now use [generated voxel characters](VOXEL_CHARACTERS.md) with seeded faces, hair, clothing and role accessories. The living-world coordinator still owns their positions, routines and animation changes. Cosmetic choices do not consume combat randomness.

Footsteps follow distance actually traveled on the ground, with different recordings for wilderness and hard floors. Landing adds a heavier step. Opening and closing authored books uses the staged RPG recordings. Ambient voices fade in menus and readers, and quiet down near active combat. UI book sounds can finish while the world is paused.

Options has separate Music, Effects and Ambience sliders. Ambience defaults to 65%; the value persists in the existing settings file. Master mute still controls all audio. This addition does not require a save migration or world reset.

## Content

[`config/world_ambience.json`](../config/world_ambience.json) contains surface/location beds, cue aliases and wisp counts/colors. Its former resident model queries and accessory recipes are retained as legacy data; current NPC appearance recipes live in [`voxel_characters.json`](../config/voxel_characters.json).

[`world_ambience.gd`](../scripts/world_ambience.gd) handles environmental effects, while [`actor_models.gd`](../scripts/actor_models.gd) creates generated NPCs. [`ambience_catalog.gd`](../scripts/ambience_catalog.gd) validates ambience data; [`voxel_character_catalog.gd`](../scripts/voxel_character_catalog.gd) validates current character recipes. The visual cap is six wisps; audio uses two environment beds, four spatial cues and two effect voices. A dedicated listener follows the player instead of the distant isometric camera.

Audio aliases resolve through the asset registry. Add selections/aliases in [`asset_imports.json`](../config/asset_imports.json), run the normal importer build, then let Godot import the result. Coordinate shared catalogue rebuilds in `chat.md`. Pack metadata and notices accompany the generated audio; Blender Foundation ambience requires attribution and is included in both [Credits](../CREDITS.md) and the game screen. Original recording bytes are preserved; Godot changes playback looping, volume and, for footsteps, pitch.

The [world construction catalogue](WORLD_CONSTRUCTION.md) supplies broad semantic audio/effect pools. Regional wind and wildlife, several footsteps/door/book recordings, eight CC0 music additions and contextual portal particles reuse those registered sources. Rare seeded woodland/meadow showers have visible rain and matching sound; dry/frozen climates retain their normal atmosphere. Nearby stationary relic menders can supply page sounds at their actual position. Weather is cosmetic, bounded and paused by menus.

## Checks

Run `./check.sh` for the headless regression, including catalogue rejection, actual audio resource resolution, stable role/model variants, noncolliding bounded visuals, pause behavior, independent randomness and isolated settings persistence.

Run `./godot.sh --script tools/check_ambience.gd` for native WAV/Ogg looping, environment crossfades, footsteps/book cues, spatial chimes, pause/resume and independent mute. It records non-silent mixer output to `artifacts/ambience-mix.wav` and `artifacts/ambience-footsteps.wav`, and renders `artifacts/ambience-npc-gallery.png`. Mixer checks establish playback and routing; sound balance still benefits from headphone and speaker playtesting.

Run `./godot.sh --script tools/capture_ambience.gd` to capture the actual town, four biome palettes, Sanctum, dungeon, Options and Credits at 1280x800. Both native helpers use fixtures or isolated preview saves; they do not update the player's journey or preferences.
