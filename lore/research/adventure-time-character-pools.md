# Adventure Time character and creature pools

Author: Aster. Research date: 2026-10-13. Status: expansion research. This author-facing page contains spoilers. The proposed names, populations and encounters below are original Endless World content. The first eight entries are now built; their runtime scope is documented in [Wonder folk](../../docs/WONDER_FOLK.md). The remaining roster and special mechanics are proposals.

Expand the population by adding different bodies, occupations and dispositions. Give strange residents practical concerns, peaceful creatures recognizable habits, and threats a readable reason to occupy their habitat. Keep exceptional characters tied to particular places and histories.

## Reference findings

The table separates sourced character descriptions from our design inferences. The sources are rights-holder character profiles and licensed episode descriptions, with two explicitly marked secondary references. This pass checked published descriptions, not full episode footage. Episode titles identify the examples because storefront numbering, dates and runtimes can be inconsistent. Detailed transformations, quest outcomes and cosmological rules require further episode-level review.

| Reference | Supported observation | Original design inference |
| --- | --- | --- |
| [Jake](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A capable dog with special powers. | Make an unusual traveler helpful and conversational. |
| [BMO](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A friendly living game console. | A small enchanted household caretaker can be a person. |
| [Princess Bubblegum](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A scientist ruling the Candy Kingdom. | Connect civic magic with maintenance and responsibility. |
| [Marceline](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | An ancient, widely traveled vampire. | Give an apparently frightening resident a personal history. |
| [Ice King / Simon](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A lonely ruler using a magical crown. | Reserve relic-altered identities for individual stories. |
| [Lady Rainicorn](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A musical companion associated with royalty. | An unusual creature can have social ties. |
| [Lumpy Space Princess](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A princess whose assumptions cause trouble. | Let personality drive minor conflict among magical residents. |
| [Gunter](https://www.discoveryjapan.jp/cartoonnetwork/adventuretime/) | A penguin living with Ice King. | Populate magical homes with ordinary animal companions. |
| [Peppermint Butler](https://press.wbd.com/us/media-release/hbo-max-orders-four-adventure-time-distant-lands-specials-cartoon-network-studios) | Wizard City follows magical study and a suspect past. | Write a courteous institution keeper with an uncomfortable history. |
| [Huntress Wizard](https://tv.apple.com/us/episode/the-crocodile-who-bit-a-log/umc.cmc.43kiv2xq7gi355apinjiqxm4f) | Visits the Heart of the Forest and encounters a wizard order. | Make woodland magic a local vocation with institutions. |
| [Tree Trunks](https://tv.apple.com/us/episode/apple-thief--beautopia/umc.cmc.wgr67dbn84kpcjurwhsmrho2) | Her apple pie motivates a visit. | Food, hospitality and household needs can anchor encounters. |
| [Root Beer Guy](https://tv.apple.com/us/episode/root-beer-guy/umc.cmc.4zlwzvjcyqrqu82cwja1dfu0n) | Has an ordinary job and writes mysteries. | Give a fantastic-looking worker interests beyond their job. |
| [Rattleballs](https://tv.apple.com/us/episode/rattleballs/umc.cmc.421wolasfj4l7rved2vr3m5w6) | An old gumball robot encountered during sword practice. | Place retired constructs around repair yards and old defenses. |
| [Slime Princess](https://tv.apple.com/us/episode/love-games-box-prince/umc.cmc.27q7clkzi4vyw2ta3o1dabmf8) | Faces a succession dispute in the Slime Kingdom. | Slime people can have civic disagreements. |
| [Lemonhope](https://tv.apple.com/us/episode/lemonhope-pt-1/umc.cmc.4462me1ysvhkt29ssxg6vxk03) | Chooses freedom over expected responsibility. | A resident's wishes can conflict with their community's needs. |
| [Banana Guards](https://tv.apple.com/us/episode/flute-spell--the-thin-yellow-line/umc.cmc.6lkxbauagzhn8x5z8o81ljxmi) | Finn and Jake infiltrate their ranks. | Give a nonhuman watch an actual civic role. |
| [The Lich](https://tv.apple.com/us/episode/i-remember-you--the-lich/umc.cmc.43budz5av6oxlp1538tqnfvnk) | Its appearance reveals larger secrets of Ooo. | Keep major threats rare and connected to history. |
| [Prismo](https://tv.apple.com/us/episode/finn-the-human/umc.cmc.1fae10z2fv21evvis5bi4t0zr) | A wishmaster met after portal travel. | A singular host can give another dimension a social identity. |
| [The Jiggler](https://tv.apple.com/ca/show/adventure-time/umc.cmc.379m2it2q2g5zi6dwqi84cwpw) | A strange creature follows Finn and Jake home. | Add curious wildlife that approaches without attacking. |
| [Donny](https://tv.apple.com/fr/episode/donny/umc.cmc.6g5n16utx716yyw6s32s59xjc) | An aggressive ogre Finn tries to change. | Distinguish a territorial creature from an indiscriminate attacker. |
| [Hug Wolf](https://tv.apple.com/us/episode/in-your-footsteps--hug-wolf/umc.cmc.3cwrqcxz1shl1kyek17bruy3x) | An encounter changes Finn into a hug-wolf. | A gentle-looking silhouette can conceal danger. |
| [Flame Princess](https://tv.apple.com/us/episode/incendium/umc.cmc.2wi21aspw22n6d1l3ryrh8vct) | A personal meeting has fiery consequences. | Elemental residents need personalities and ordinary relationships. |
| [Choose Goose](https://adventuretime.fandom.com/wiki/Choose_Goose) | A merchant trading varied goods. Secondary character reference. | Give a traveling trader a memorable voice and believable stock. |
| [Magic Man](https://en.wikipedia.org/wiki/List_of_Adventure_Time_characters#Magic_Man) | Uses magic to impose bizarre transformations. Secondary character reference. | Put disruptive magic in a bounded encounter with consequences. |

Our inference is that appearance, personhood and hostility should be separate decisions. A slime scholar and a hungry wild slime need different identities even if they share a material. An undead resident should have a life and occupation. A hostile remnant can remain frightening without every line becoming a joke.

## Current project fit

The checked source catalogues contain ten authored enemy definitions and eighty bundled enemy definitions, before content-editor overrides. The original voxel generator has twenty-eight templates spanning biped, quadruped, crawler, flying, floating, slime and stationary movement. The NPC appearance catalogue has six imported visual families. Ambient life currently names nine species: cat, chicken, chick, dog, horse, pig, raccoon, sheep and wolf. These are source-catalogue counts, not counts of distinct behaviors or proposed new art.

Relevant entry points are [EnemyCatalog](../../scripts/enemy_catalog.gd), [voxel monster recipes](../../config/voxel_monsters.json), [NPC visual families](../../config/npc_styles.json) and [ambient life](../../config/world_life.json). `EnemyCatalog.should_engage` and `after_hit` already distinguish aggressive, retaliating and fully passive definitions. Passive enemy flags alone do not provide conversation, trading, a resident schedule or a wildlife controller.

Procedural enemy selection currently takes a legacy biome integer and optional habitat facet. Fourteen display biomes do not automatically provide fourteen independently selectable enemy pools. An expansion needs an explicit ecology-to-pool mapping or a compatible selector extension. Preserve legacy save identities and existing definitions while adding that mapping.

The largest useful additions are nonhuman residents, curious magical wildlife, neutral territorial creatures and site-specific enemies. Recoloring an existing wolf or adding a new imported profile name does not satisfy a new-body goal.

## Twelve proposed NPC roles

These are repeatable occupations. Each instance gets an original name, one practical task, one personal concern and knowledge of actual nearby places. The physical features are art briefs, not claims that complete NPC bodies already exist.

| Proposed ID / role | Body and voice | Habitat and practical purpose |
| --- | --- | --- |
| `clay_herbalist` / Clay Herbalist | Potfolk with a broad vessel body and leaf apron. Precise about smells and texture. | Greenwood and meadows. Sort local gathered herbs at an existing provisions counter. |
| `moss_listener` / Moss Listener | Woodland resident with a branching hood and seed satchel. Listens before answering. | Deepwood and jungle. Maintain trail markers and discuss actual nearby ruins. |
| `reliquary_steward` / Reliquary Steward | Small masked caretaker with keys and a neat robe. Courteous, uneasy about old work. | Mage towns, temples and old studies. Catalogue objects and provide readable local history. |
| `kiln_tender` / Kiln Tender | Ceramic figure with a protected ember chamber. Direct and particular about fuel. | Cinderwaste and Amber Wastes. Maintain ovens and explain local construction materials. |
| `orchard_host` / Orchard Host | Round animal-like resident with a basket and oversized coat. Warm, stubborn, remembers travel. | Amberleaf and meadow homes. Offer conversation about harvests and local journeys. |
| `ledger_scribe` / Ledger Scribe | Glass vessel or ordinary clerk carrying an ink roll. Curious about everyday mysteries. | Town offices and markets. Record delivered goods and compare accounts of nearby sites. |
| `lantern_peddler` / Lantern Peddler | Long-necked birdfolk with a shoulder frame of lamps. Short memorable sales phrases. | Established traveling-merchant routes. Buy eligible finds through the existing finite shop economy. |
| `reed_mender` / Reed Mender | Marsh resident with translucent sleeves and a reed tool belt. Practical about water damage. | Reedfen homes and workshops. Maintain raised foundations and discuss silver reed. |
| `weather_gossip` / Weather Gossip | Soft cloud-like silhouette with a scarf and tiny boots. Dramatic about small inconveniences. | Windscar and Lanternwake. React to present weather without controlling it. |
| `scrap_fencer` / Scrap Fencer | Retired construct with an asymmetric repaired body and sheathed blade. Dry, patient humor. | Castles, workshops and quiet repair yards. Talk about upkeep and past service. |
| `hearth_attendant` / Hearth Attendant | A compact enchanted cabinet with hinged feet and a warm face-light. Earnestly domestic. | A settled home or Sanctum. Notice furnishings and household routines. |
| `return_guide` / Return Guide | A capable unusual traveler with a weathered pack. Advice based on experience. | Roadside shelters and guild courts. Refer to places the player really visited. |

Human-compatible roles can first use existing biome-compatible complete bodies. Potfolk, birdfolk, cloudfolk, glassfolk and cabinet bodies need original recipes plus a resident renderer adapter. Reusing a monster mesh is an art starting point; the NPC still needs grounded idle/walk/greeting presentation and its own identity.

Trade should use existing source counters, stock, purse and ownership rules. Training, repairs, gifts, household assistance and new material-demand prices are future services until their callbacks exist. A conversation can describe the character's occupation without offering a functional service.

## Twelve proposed creature and monster families

Disposition is the initial encounter behavior. It is authored separately from the mesh. Existing-template references identify useful construction bases; they do not assert that the proposed bodies or special abilities are implemented.

| Proposed ID / family | Disposition and habitat | Distinct silhouette | First supported combat or ambient behavior |
| --- | --- | --- | --- |
| `dew_jiggler` / Dew Jiggler | Peaceful; meadows and fungal clearings. | Low jelly body, two stalks and a hanging dew bead. `slime` base. | Curious ambient approach or wandering. Following a player requires an explicit ambient handler. |
| `bog_mossback` / Bog Mossback | Neutral, retaliates; Reedfen and deep forest. | Broad shoulder shelf, reed beard and visibly heavy feet. `golem` base. | Slow melee, local territory and return to its own anchor. |
| `stitch_wolf` / Stitch Wolf | Hostile; Hallowwood and old forest margins. | Soft stitched bulk, long forelimbs and a small masked face. `wolf` base. | Clearly telegraphed melee. Grappling and transformation are later mechanics. |
| `lantern_snatcher` / Lantern Snatcher | Hostile; coastal cliffs and exposed ruins. | Hooked feet, broad short wings and one carried lamp. `bird` base. | Existing bounded attack and return behavior. Its name does not authorize inventory theft. |
| `choir_husk` / Choir Husk | Hostile; crypts and abandoned shrines. | Open rib chamber holding a bell, narrow head and long hands. `skeleton` base. | A slow ranged attack using supported projectile contact. Group buffs need a new handler. |
| `glass_sentinel` / Glass Sentinel | Neutral, retaliates; crystal ruins. | Tall angular torso, framed face and unequal repaired arms. `golem` base. | Melee defense inside a fixed encounter area. Reflection is future work. |
| `ink_scamp` / Ink Scamp | Hostile; abandoned studies and magical ruins. | Stubby robe, oversized quill and a hinged ink-mask. `caster` base. | Existing ranged spell behavior. Temporary curses are future work. |
| `potbound_briar` / Potbound Briar | Hostile; dry gardens and temple outskirts. | Cracked planter, thick rooted stem and folding thorn jaws. `plant` base. | Stationary ranged pressure with readable windup and clear projectile paths. |
| `reed_glider` / Reed Glider | Peaceful; marsh banks and sheltered coast. | Flat seed-shaped body with reed wings and a forked tail. `bird` base. | Ambient movement near dry bank anchors. Keep it out of the combat pool. |
| `burrow_lantern` / Burrow Lantern | Neutral, retaliates; dunes, highlands and cave mouths. | Segmented shell, short legs and a recessed belly-light. `beetle` base. | Surface walking and melee. Underground movement requires new navigation support. |
| `thorn_patchling` / Thorn Patchling | Hostile; fungal groves and jungle ruins. | Wide cap, root sleeves and a conspicuous closed bud. `mushroom` base. | Slow melee, retreat and existing spacing. Poison clouds are future work. |
| `rime_rooker` / Rime Rooker | Peaceful; frost clearings and cold settlements. | Squat bird body, stepped ice crest and wide grounded feet. `bird` recipe adapted for walking. | Ambient ground movement; no airborne collision assumption. |

Suggested baseline engagement flags are hostile `aggressive=true, retaliates=true`, neutral `aggressive=false, retaliates=true`, and peaceful `aggressive=false, retaliates=false`. Those existing enemy flags can represent disposition when using the enemy controller. Peaceful ambient species should use the life controller instead, with no combat rewards or enemy health bars by default.

Keep friendly and hostile versions in separate stable definitions. A resident and a wild specimen may share a visual lineage, but dialogue eligibility, defeat rewards, targeting and persistence must remain explicit. An animated object belongs at a believable worksite or ecological anchor; do not make every crate, plant or lantern alive.

## Biome placement shortlist

This is a proposed mapping to the fourteen current profile IDs. Entries are candidates, not a requirement to spawn every listed role in every chunk. Match an existing settlement, clear bank, clearing, repair yard, study or ruin before allocating an actor.

| Profile ID | Resident candidates | Wilderness candidates |
| --- | --- | --- |
| `greenwood` | Clay Herbalist, Return Guide | Dew Jiggler, Bog Mossback |
| `meadows` | Clay Herbalist, Orchard Host | Dew Jiggler |
| `desert` | Kiln Tender, Lantern Peddler | Burrow Lantern, Potbound Briar at old gardens |
| `frostlands` | Return Guide, Weather Gossip | Rime Rooker |
| `dense_forest` | Moss Listener | Bog Mossback, Stitch Wolf at remote old paths |
| `haunted_hollows` | Reliquary Steward | Stitch Wolf, Choir Husk at graveyards |
| `marsh` | Reed Mender | Reed Glider, Bog Mossback |
| `jungle` | Moss Listener | Thorn Patchling, Dew Jiggler |
| `autumn_woodland` | Orchard Host, Ledger Scribe | Dew Jiggler, Burrow Lantern |
| `fungal_grove` | Clay Herbalist | Dew Jiggler, Thorn Patchling |
| `volcanic_wastes` | Kiln Tender, Scrap Fencer | Ink Scamp at old studies, Potbound Briar at abandoned gardens |
| `highlands` | Weather Gossip, Lantern Peddler | Burrow Lantern, Lantern Snatcher at ruins |
| `coast` | Reed Mender, Lantern Peddler | Reed Glider, Lantern Snatcher at cliffs |
| `crystal_tundra` | Ledger Scribe, Scrap Fencer | Rime Rooker, Glass Sentinel at ruins |

Site and faction restrictions refine the ecology. An ink creature belongs at a ruined study, not on every volcanic slope. An orchard host needs an orchard or home. Keep portals, city courts, ordinary roads, rest anchors and doorway approaches peaceful and traversable.

## Four rare character briefs

Each of these uses one authored identity and an individual history. They are separate from repeatable population pools.

| Original brief | Reference pattern | Placement and story boundary |
| --- | --- | --- |
| The Snow Archivist | Ice King / Simon | A secluded winter archive; a caretaker misremembers the purpose of a relic. Any identity change needs authored continuity. |
| The Last Usher | The Lich's larger mystery | Develop the [existing Last Usher proposal](../monsters.md#the-last-usher) at one Unclosed Office ruin. It has its own history and reserved seats; no copied apocalypse motive. |
| The Lantern Host | Prismo | A single optional pocket-dimension host who remembers visitors. Portal access can be bounded; unrestricted wishes are not a supported mechanic. |
| The Uninvited Examiner | Magic Man | An isolated magic-study encounter with a recurring interruption. Begin with dialogue and supported attacks; never rewrite a player's body, inventory or save without an implemented reversible mechanic. |

## First implementation batch and handoff

Start with four residents: Clay Herbalist, Moss Listener, Lantern Peddler and Scrap Fencer. Together they cover trade, local knowledge, road encounters and older history. Use existing supported dialogue and counters while their distinctive bodies are built. Add Dew Jiggler and Rime Rooker as peaceful wildlife, Bog Mossback as neutral wildlife, and Choir Husk as a site-specific hostile creature. This eight-entry batch tests different dispositions and actor services before expanding the entire roster.

Give each new body a distinct silhouette from both isometric sides. Test model width, ground contact, head/hand facing, idle, walking and attack or greeting before assigning it to a pool. Support block and faceted biome families explicitly. Color variants do not increase the count of distinct bodies.

Authored Morrowmere inhabitants belong to Rowan-Folk's population service and the realm definition. Use fixed IDs namespaced by dimension/site/spawn; preserve accepted defeats, current hero progress and original return threads. The procedural overworld uses its existing enemy grounds and WorldLife services. Share catalogue identities and art without injecting procedural residents or encounters into the authored provider.

The runtime work should verify ecological selection, neutral/passive engagement, actual talk/trade callbacks, geometry and animation, bounded actor counts, spacing and safe approaches, combat rewards, and disk/home/realm return persistence. Keep the existing combat random stream independent of appearance and idle scheduling. Source art, preparation caches, content-editor overrides and authority manifests retain their current workflows.

The first implementation includes Clay Herbalist, Moss Listener, Lantern Peddler, Scrap Fencer, Dew Jiggler, Rime Rooker, Bog Mossback and Choir Husk. Their [implementation guide](../../docs/WONDER_FOLK.md) records actual services, habitats and persistence. The remaining characters and special mechanics await their own art, runtime support and acceptance. For general setting principles and creator interviews, see [the earlier Adventure Time research](adventure-time.md).
