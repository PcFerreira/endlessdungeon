# Peaceful wilderness walkers

The Endless map now streams peaceful herbalists, cartographers, prospectors, storytellers, wanderers and trail couriers alongside its town residents, road travelers and animals. They explore connected open ground in woodland clearings, fields and safe settlement outskirts, rest, and stop to face the player at conversation distance. Each walker has up to six spaced destinations that cover an area, including diagonal offsets from home. They move through the existing terrain navigation, which can bend around obstacles. Press E to talk about their work or surroundings. Ordinary work descriptions are dialogue; these occupation profiles do not consume forage nodes, create deliveries or operate shops. Aster's Wonder folk use this movement system while retaining their separate body/dialogue/trade contracts.

These walkers use the existing generated voxel NPC bodies, with stable seeded appearance and the actual local biome palette. Their occupation labels identify them in the world. They are Life actors, separate from hostile enemies, combat targeting and loot. Sources avoid roads, bridges, water, town clearances, occupied creature grounds and the initial combatants' approach range. Actual movement uses the existing terrain footprint and step rules.

The six profiles are authored in `config/wilderness_roamers.json`. Each has an original display name, a supported voxel role, walking speed, greetings and work text. Profile selection and appearance use independent seeded randomness. The runtime does not spend combat RNG to plan walks or choose dialogue.

## Streaming and saves

Roamer IDs are `roamer:<chunk-x>:<chunk-y>:<slot>`, with two possible identities per chunk and at most four active walkers. New candidates come from nearby streamed chunks. Existing nearby identities have priority; distant ones leave the active set as the player explores. A first restore prioritizes saved identities while their terrain remains loaded and suitable, retaining point, heading, path and intention.

The total peaceful actor cap is 24: twelve local residents/animals, eight road travelers/guards and four wilderness walkers. All local actors share one path query per step and a 169-cell search ceiling. Each cached blueprint separately checks at most 169 loaded ground cells for connected terrain and legal steps, then chooses non-collinear destinations within six cells of home and its existing chunk envelope. Up to 32 cached blueprints avoid repeating spawn searches. Saved records reject noncanonical IDs, excessive roamer counts, escaped positions, invalid paths and malformed clocks. Existing saves without roamers remain valid and acquire walkers through subsequent exploration.

Morrowmere remains Rowan-Folk's separate authored population. Rowan has expanded its 64 stable residents onto authored two-axis courtyard, house and grave-clearing loops; Rowan-Folk owns the actual supported-motion proof for that data. Its `dimension:<id>:resident:<id>` identities and travel persistence are preserved. The procedural roamer builder rejects finite, hub and remote World subclasses. Neither this change nor the coordination adopts new public authority data or rebuilds exported releases.

## Validation

```sh
./godot.sh --headless --script tests/test_wilderness_roamers.gd --quit-after 600
./godot.sh --headless --script tests/test_wilderness_roamers_game.gd --quit-after 600
```

The world fixture checks varied peaceful profiles, non-collinear open-area destinations, physical movement along both axes at positive and negative coordinates, terrain/town/monster clearance, bounded actor and route work, conversation pauses, JSON restoration and rejected records. The actual Game fixture checks naturally streamed ordinary and Wonder body contracts, E/path/work dialogue, paused activity, exclusion from enemy targeting, separate combat RNG, disk position/body identity and Sanctum carry. Existing Life, road-travel, merchant and voxel-NPC fixtures provide compatibility checks. These are functional checks; they do not establish gameplay FPS, acceptance of Aster's complete first batch, or a refreshed native visual gallery.
