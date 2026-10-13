# The Endless World

The multiverse collapsed into the Endless World, a single infinite world. Peoples who once lived beneath different skies now share roads, markets, and mysteries. A village might employ a dwarf bridgewright, an elf beekeeper, and a clay pot who insists that being waterproof is a professional qualification.

The player belongs to the Milewardens, a traveling guild that maps the world and catalogues its mysteries. These setting pillars are adopted. Further characters, customs, and magical explanations remain proposals unless a page records their adoption. D&D, Forgotten Realms, and Adventure Time supply broad inspirations; their setting histories are separate.

## Reading order

| File | Contents |
| --- | --- |
| [Adventure Time research](research/adventure-time.md) | Sourced observations about the inspiration and original design applications |
| [Adventure Time character pools](research/adventure-time-character-pools.md) | 24 character references, original NPC and creature proposals, biome mapping and implementation handoff |
| [Breath of the Wild research](research/breath-of-the-wild.md) | Terrain, route choices, visual reveals, and exploration principles |
| [World generation](world-generation.md) | Proposed generation passes, connected places, and a coding handoff |
| [Area guide](areas-guide.md) | 72 surface, city, dungeon, and transition archetypes with implementation stages |
| [Implemented expansion](../docs/WORLD_EXPANSION.md) | Current six towns, six dungeon families, facets, dialogue, readers, and saved journal |
| [World](world.md) | Premise, history, peoples, factions, and unresolved questions |
| [Guilds and expeditions](guilds-and-expeditions.md) | Milewarden chapters, faction disagreements, collapse mysteries, and proposed homecoming loops |
| [Politics and town compacts](politics-and-town-compacts.md) | Local government, watches, trade dependencies, disputed borders, and proposed political stories |
| [Magic](magic.md) | Everyday wonders, adventuring magic, and dangerous old workings |
| [Town life and magic](town-life-and-magic.md) | Dense neighborhoods, six civic charms, local customs and their implemented placement |
| [Towns from other skies](town-themes.md) | Townwright's Milewarden field notes about sixteen themed communities; readable-item publication remains separate |
| [Regions](regions.md) | Lore for the four existing biomes and underground themes |
| [NPCs](npcs.md) | Reusable character roles, voice, motives, and placement |
| [Monsters](monsters.md) | Existing enemy lore and proposed future creatures |
| [Books](books.md) | Readable passages and rules for generating related texts |
| [Procedural dialogue](procedural-dialogue.md) | Line banks, context rules, examples, and coding handoff |
| [Lore translations](locales/README.md) | Stable message keys, English context, locale templates, placeholders, and translation validation |

## Writing direction

Speak from inside the world. Let a reader notice a chipped inscription, hear a neighbor's account, or find a tired surveyor's note. Keep code terms, placement instructions, content IDs, asset explanations, and editorial reliability labels in author notes. Clear controls and quest instructions can stay direct; characters should sound like people with something to say.

Use the established world origin consistently. Former worlds explain different local building traditions and materials. Preserve a coherent visual family within each place. The guild's work gives the player a reason to notice, copy, compare, and return without promising unimplemented guild ranks or services.

Keep swords, spellbooks, old towers, dangerous expeditions, and local politics as the fantasy foundation. Give unusual people ordinary concerns. Let humor come from their priorities. Leave room for affection, regret, frightening discoveries, and quiet moments.

Every recurring oddity should affect life somewhere. If a bell eats sound, explain who feeds it, who benefits, and who cannot sleep. Give a monster an appetite or purpose before giving it a punchline.

Reveal history through conflicting accounts and physical traces. A character can be mistaken. The writer still needs to know which claims are reliable within the draft.

## Scope and handoff

The original writing pass stays inside `lore/`. These files supply authored content and placement instructions. The user subsequently approved implementation of the focused expansion described in [the implementation guide](../docs/WORLD_EXPANSION.md). That guide distinguishes playable features from the larger proposed area catalogue.

The current game contains four biomes, six sanctuary town archetypes, six independently seeded dungeon families, two surface facets, three enemy kinds, and Mage, Sword, and Spellsword classes. Four resident roles offer authored procedural conversations, six books can be read, and the field journal saves discovered texts. Faction encounters, creature negotiation, Potfolk presentation, combat barks, and new creatures remain proposals.

Each content entry states its intended location. Existing world features can carry the new prose later; a placement instruction does not mean that interaction already exists. Use the game's generated city and dungeon names. The setting name does not require renaming the application in this pass.

Start implementation with short sanctuary conversations, then enemy barks and short books. Add quest promises only when the relevant quest and outcome exist. Detailed selection rules and proposed source touchpoints are in [Procedural dialogue](procedural-dialogue.md#handoff-to-the-coding-agent).
