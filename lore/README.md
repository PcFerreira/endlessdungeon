# The Endless Realm

The Endless Realm is a fantasy world of sanctuary towns, dangerous ruins, wandering adventurers, and strange neighbors. A village might employ a dwarf bridgewright, an elf beekeeper, and a clay pot who insists that being waterproof is a professional qualification.

This folder is the writing workspace. The world name and the requested D&D, Forgotten Realms, and Adventure Time inspirations come from the project direction. All new history, characters, customs, and magic explanations below are draft proposals. Edit them freely before adopting them as canon.

## Reading order

| File | Contents |
| --- | --- |
| [Adventure Time research](research/adventure-time.md) | Sourced observations about the inspiration and original design applications |
| [Breath of the Wild research](research/breath-of-the-wild.md) | Terrain, route choices, visual reveals, and exploration principles |
| [World generation](world-generation.md) | Proposed generation passes, connected places, and a coding handoff |
| [Area guide](areas-guide.md) | 72 surface, city, dungeon, and transition archetypes with implementation stages |
| [World](world.md) | Premise, history, peoples, factions, and unresolved questions |
| [Magic](magic.md) | Everyday wonders, adventuring magic, and dangerous old workings |
| [Regions](regions.md) | Lore for the four existing biomes and underground themes |
| [NPCs](npcs.md) | Reusable character roles, voice, motives, and placement |
| [Monsters](monsters.md) | Existing enemy lore and proposed future creatures |
| [Books](books.md) | Readable passages and rules for generating related texts |
| [Procedural dialogue](procedural-dialogue.md) | Line banks, context rules, examples, and coding handoff |

## Writing direction

Keep swords, spellbooks, old towers, dangerous expeditions, and local politics as the fantasy foundation. Give unusual people ordinary concerns. Let humor come from their priorities. Leave room for affection, regret, frightening discoveries, and quiet moments.

Every recurring oddity should affect life somewhere. If a bell eats sound, explain who feeds it, who benefits, and who cannot sleep. Give a monster an appetite or purpose before giving it a punchline.

Reveal history through conflicting accounts and physical traces. A character can be mistaken. The writer still needs to know which claims are reliable within the draft.

## Scope and handoff

All work in this pass belongs inside `lore/`. These files supply content and placement instructions for the coding agent. No game scripts, scenes, assets, menus, or project settings are changed here.

The current source contains four biomes, sanctuary cities, independently seeded ruins, three enemy kinds, and Mage, Sword, and Spellsword classes. Citizens are currently decorative. Dialogue, readable books, faction encounters, creature negotiation, and the new creatures described here require future implementation.

Each content entry states its intended location. Existing world features can carry the new prose later; a placement instruction does not mean that interaction already exists. Use the game's generated city and dungeon names. The setting name does not require renaming the application in this pass.

Start implementation with short sanctuary conversations, then enemy barks and short books. Add quest promises only when the relevant quest and outcome exist. Detailed selection rules and proposed source touchpoints are in [Procedural dialogue](procedural-dialogue.md#handoff-to-the-coding-agent).
