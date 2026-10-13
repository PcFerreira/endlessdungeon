# More reasons to keep exploring

Author: Rowan. Date: 2026-10-13. Status: research and proposed design. No mechanics, placements or new assets are implemented by this document.

Start with small discoverable places, linked local stories, and collections that record where an expedition went. Then vary dungeon objectives and reward the player with things worth bringing home. These additions could make familiar terrain support different journeys. Their effect on the game's endless feel remains a playtest hypothesis.

The current world already streams beyond fixed boundaries. Its repeated structure is more limiting than its map size: the updated 128-cell town grid gives regions one sanctuary town and two ruins, with more wilderness between towns. Six town archetypes, six dungeon families and two surface facets provide variety. Roadside discoveries are implemented; regional history and source collections are the next slice. Shops, crafting and alternate dungeon objectives remain opportunities. The saved journal and dynamic asset/lore registry provide useful foundations.

I reviewed [the current MVP](MVP.md), [the implemented expansion](WORLD_EXPANSION.md), [the 72-area draft catalogue](../lore/areas-guide.md), [the existing exploration proposal](../lore/world-generation.md), and the current region, inventory and lore code. The 72 area entries are proposals, not 72 implemented destinations. Collected furnishings exist; placing them in the Sanctum remains future work.

Wren's [living-world research](LIVING_WORLD_RESEARCH.md) covers residents, animals, event episodes and simulation budgets. This proposal supplies places, discoveries and reasons to revisit that can connect to that coordinator. It does not propose a competing scheduler.

## What the research suggests

| Reviewed source | Supported observation | Proposed use here |
| --- | --- | --- |
| [Dormans and Bakkes: Generating missions and spaces](https://research-portal.uu.nl/en/publications/generating-missions-and-spaces-for-adaptable-play-experiences/) | The 2011 paper's abstract separates the sequence of tasks from the space supporting them. I reviewed the abstract, not the full experimental results. | Choose an encounter's purpose and dependencies before arranging its rooms or props. A changed floor outline should not be the only source of variety. |
| [Unexplored 2 developer: Level Generation](https://www.ludomotion.com/blogs/level-generation/) | Joris Dormans describes a staged process from a high-level plan to graphs, gates, goals and populated terrain. | Give optional sites a recognizable approach, a decision and an outcome. Validate the route before dressing it. |
| [No Man's Sky: Desolation](https://www.nomanssky.com/desolation-update/) | Derelict interiors combine generated layouts with logs and personal objects revealing the crew's fate. | Link room condition, a recovered object and a short passage to one stored local history. |
| [Minecraft: Trail ruins](https://www.minecraft.net/en-us/article/trail-ruins) | Buried roads and structures contain evidence of earlier inhabitants, including pottery fragments and decorative rewards. | Make ruins readable through materials and artifacts. A fragment can identify a local culture and suggest another site. Full terrain excavation is unnecessary for an initial inspect interaction. |
| [No Man's Sky: Worlds Part II](https://www.nomanssky.com/worlds-part-ii-update/) | Relic worlds offer architectural discoveries and construction blueprints; unusual environments have distinct resources. | Tie selected exploration rewards to their place of origin and future home decoration. |
| [No Man's Sky: Expeditions](https://www.nomanssky.com/expeditions-update/) | Milestones group exploration activities and provide rewards; the actual expeditions are time limited. | Offer optional personal expedition themes. Our adaptation would have no real-world expiration and would retain progress. |
| [No Man's Sky: Aquarius](https://www.nomanssky.com/2024/09/aquarius-update/) | Fish discovery varies by location, depth, time and weather, and catch history is recorded. | Later, build regional fishing or naturalist collections with readable habitats. Use an in-game clock and avoid forcing players to wait for a real-world date. |
| [Unexplored 2 developer: Never Enough Space!](https://www.ludomotion.com/blogs/inventory/) | The developer reports that forced inventory decisions interrupted rewarding exploration moments. | Record stamps, observations and copied texts in a journal collection instead of filling the existing 24-slot backpack with mandatory fragments. |

These sources offer design precedents. The adaptations, priorities and examples below are original proposals for the Endless Realm, and their effect on this prototype remains untested.

## Elements worth adding

Priority describes a suggested sequence, not an approved implementation schedule. Scope is relative to the current prototype; no development-time estimates have been measured.

| Element | What changes for the player | Original examples | Priority and dependencies |
| --- | --- | --- | --- |
| Small wilderness landmarks | Ordinary travel offers brief, optional discoveries between major sites. | Ruined watchtower, wrapped bell, abandoned mill, stone-circle clearing, roadside shrine. | First. Reachable placement and one inspect/read interaction; reuse staged art. |
| Regional signatures | Nearby towns and ruins belong to a recognizable local district. | Slate roofs and survey marks; mushroom gardens and repaired cisterns; wool banners around frost shelters. | First. Shared district facts and a few compatible motifs; preserve existing base biomes. |
| Linked discovery clues | A passage or object points toward an actual destination. | A mender's letter names the existing quarry ruin; a chipped marker matches a symbol at its entrance. | First. Resolve actual site IDs and bind text to committed facts. |
| Field-journal collections | Exploration leaves a record beyond cleared combat encounters. | Survey seals, copied inscriptions, local recipes, architectural sketches, observed species. | First. Saved discovery records and duplicate handling; observation rewards need not occupy backpack slots. |
| Site histories | Similar rooms tell different small stories. | A cistern was repaired, sealed or used as a refuge; objects and notes agree with that choice. | First. Finite authored history templates and compatible prop bundles. |
| Short side chambers | A player can complete a small discovery without committing to a long dungeon. | One-room reliquary, cellar archive, two-room abandoned workshop. | Next. Separate optional sites or branches; retain current dungeon length/reward rules. |
| Dungeon purpose variants | Returning to a familiar family can involve a different decision. | Recover a ledger, restore a light, choose a quiet detour, locate a guardian's sealed chamber. | Next. Explicit behavior handlers, exit validation and readable objectives. Start with optional branches rather than replacing warden gates. |
| Named relics and bounded item traits | Rewards have provenance and sometimes a distinct use. | A repairer's lantern, a surveyor's boots, a blade from a frost forge. | Next. An item-definition catalogue, fixed trait budgets, compatible equipment rules and balance tests. |
| Sanctum displays and furnishings | Repeated journeys visibly change the player's home. | Place a recovered chair, display a copied map, hang a district banner. | Next. Placement, rotation, saved transforms, collision and removal; collection alone is not placement support. |
| Archaeological finds | Old places offer discoveries without requiring combat. | Inspect a collapsed pillar to sketch its crest or record a broken pottery pattern. | Next. Inspect anchors and site-specific artifact pools. Terrain digging can wait. |
| Optional local errands | A short task connects people to nearby places. | Return an already spawned tool from a nearby workshop or compare two existing route markers. | Next. A saved quest state machine and real reachable targets. Avoid unsupported promises in dialogue. |
| Regional shops and craft traditions | Travel creates reasons to seek particular towns. | A frost tailor, a mushroom dyer, a caravan cook with a local specialty. | Later. Trading and crafting systems, recipes and local stock. Props and icons are already available. |
| Personal expedition themes | Players can choose their own direction. | Find three different building traditions; document a river district; read accounts from two conflicting witnesses. | Next. Small optional journal goals using discovered facts; no urgent timers. |
| Rare landmark silhouettes | Occasionally the destination itself changes the journey's character. | Broken observatory, hill fortress, sandstone palace court, root-covered temple. | Later. Footprint/camera/route checks and art adoption. Protect the sanctuary function of existing towns. |
| Bestiary and regional fauna | Seeing a familiar creature in a different habitat carries information. | Cave-roosting bats, meadow chickens, a rare frost visitor. | Connect to Wren. Observation records and habitat definitions; creature simulation stays with the living-world proposal. |
| Fishing and gathering | Quiet locations become optional destinations. | River catches, mushrooms near old logs, mineral seams around a quarry. | Later. Supported interactions, resource rules and useful rewards. Avoid mandatory hunger, wear or repetitive collection quotas. |
| Local seasonal traditions | Familiar towns gain occasional atmosphere and collectible memories. | Lantern supper, first-snow decorations, harvest stall, remembrance candles. | Connect to Wren. Cosmetic first pass; use saved in-game phases and reusable holiday art. No exclusive real-date rewards. |
| Persistent aftermath | Returning lets players recognize what happened. | A copied survey mark is completed, a repaired shrine keeps its light, a local event leaves an empty supper table. | Connect to Wren. Small saved changes attached to actual site/event IDs; do not regenerate player progress. |
| Sparse wilderness districts | Some journeys have room for anticipation and quiet. | A long woodland approach with one distant landmark and few nearby distractions. | Later structural change. Review sanctuary distances, road guarantees and generator/save policy before changing fixed site density. |

## Give completed builds reasons to travel

The existing skill trees have finite rank caps. Additional skill points alone cannot sustain exploration after a player finishes a build. Keep the current dungeon skill-point reward, but add parallel rewards with lasting identity: discovered histories, regional appearance options, furnishing designs, collection records and personally chosen expedition goals.

Bound equipment traits and avoid an automatic power increase for every distant coordinate. A rare lantern can reveal a readable local clue once that behavior exists; a regional coat can offer a deliberate tradeoff rather than another unconditional damage increase. Reward variants need compatible class/slot definitions and clear descriptions. Never replace a promised unique discovery with a random duplicate because the backpack is full.

Allow players to recognize expedition commitment before entering. The existing site already records its finite floor count; a light-touch entrance description could distinguish a short ruin from a deep expedition. Optional branches can offer a quick discovery without requiring every session to finish twenty floors. Challenge diversity, fair telegraphing and reward value still need playtesting.

## A first content batch using existing art

Build a modest set of readable discoveries before adding another biome catalogue. The following cards are proposed compositions, not downloaded packs or implemented sites.

| Discovery card | Visible scene and small decision | Reward or continuation | Existing staged art |
| --- | --- | --- | --- |
| The Unrung Bell | A bell has been wrapped in cloth beside a ruined tower. Read why, then decide whether to leave a journal mark. | A district custom entry; a truthful reference to a nearby sanctuary. | Castle Kit tower pieces, banners, Fantasy Props scrolls. A bell model is a possible art gap. |
| The Finished Crossing | A new repair mark appears beside an old bridge. A short note records two conflicting dates. | A survey stamp and a clue about the district's actual old ruin. | Castle Kit bridges, Cube World cart, Fantasy Props book/scroll. |
| The Borrowed Workshop | An abandoned workbench contains a labeled borrowed tool. Inspect it without spawning an errand before quests exist. | A mender's sketch; later a local return task if the recipient and handler exist. | Fantasy Props workbench/anvil, Survival Kit tools. |
| The Moss Archive | A sheltered shelf holds a readable page among tree roots. The route remains open. | A copied page and an optional related inscription in an existing tomb. | Nature Kit plants, Cube World trees, Fantasy Props bookcase/books. |
| Three Cups at the Hearth | A small camp has three cups and a repaired stool. Its note explains a local hospitality custom. | A furnishing sketch; eventual home recipe after placement/crafting support. | Survival Kit camp and Food Kit containers; Furniture Bits. |
| The Cistern Register | A shallow ruin court has water stains, sealed niches and a maintenance record. | A site-history entry and a real fungal-cistern reference if one is linked. | Modular Temple walls/pillars, Cave Kit, existing arcane frames. |
| The Windward Marker | A cairn and banner stand on a reachable rise. The player can pause to record a viewpoint. | A regional atlas observation, without an equipment requirement. | Nature Kit rocks, Castle Kit flags, existing terraced terrain. |
| The Misfiled Memorial | A small temple notice gives an administrative name to an ordinary household. Objects clarify who lived there. | A recovered local name and a related Office text. | Modular Temple, Fantasy Props books and candles. |
| The Empty Stall | A roadside stall displays an old maker's mark and one short recipe description. | A regional food note; no trading promise until a shop exists. | Fantasy Town stalls, Food Kit, existing item icons. |
| The Winter Shelter | A sheltered bench, lantern and folded blanket suggest previous travelers. | A copied letter; later a decorative lantern reward. | Furniture Bits, Survival Kit bedroll, Fantasy Props lanterns, Holiday Kit decorations. |

Most of this art is staged rather than enabled in the runtime selection. Selection rules, materials, collision footprints and placement still need adoption through [the asset pipeline](ASSET_PIPELINE.md). Full licenses and original creator records must accompany any adopted files.

## Make combinations coherent

Choose a district identity, then compatible history, landmark, interaction and reward entries. A desert maintenance office can use sandstone, survey records and a preserved cistern. Snow decorations would need an explicit explanation or should be filtered out. Variants should change a route choice, an observation, a supported interaction or a reward's provenance. Counting all theoretical combinations would exaggerate meaningful variety.

Give each family a signature containing its recognizable layout, interaction and story roles. Limit repeated signatures near one another through deterministic planning; rendering order and player approach direction must not alter placement. Reserve quiet areas. A rare family should have a legible clue or silhouette so rarity does not mean invisible content.

Commit truth before writing rumors. Store the actual place ID, its relevant history and any linked destination. Reliable text names those facts. A mistaken witness needs explicit unreliable authorship and contradictory evidence. No passage should send the player to an absent shop, unreachable ruin or unimplemented action.

Example: a Crossroads resident describes a collapsed survey station beside the region's existing quarry. A matching marker appears on its actual approach. The quarry contains the same station's repair record. Reading it adds a sketch to the journal. Returning to the resident acknowledges that place, without creating a second station or claiming the player completed an unimplemented repair.

## Data and implementation handoff

The current importer handles assets and text. It does not execute a landmark template, create a quest, apply an item affix or interpret a new journal condition. Add each behavior once as a supported capability, then express additional entries as versioned data. Structured gameplay definitions need an explicit catalogue/parser extension; putting a proposed landmark JSON record in the existing text folder does not implement it.

| Proposed definition field | Purpose |
| --- | --- |
| `id`, `version` | Stable template identity and authored content edition. |
| `biomes`, `facets`, `archetypes` | Eligibility within the actual region plan. |
| `required_capabilities` | Only select interactions the runtime implements. |
| `required_asset_tags`, `asset_choices` | Match real registry art; commit the chosen IDs. |
| `anchor_tags`, `footprint`, `approach` | Reserve a visible, reachable site without blocking roads. |
| `history_choices`, `clue_roles` | Authored compatible facts and related text roles. |
| `reward_pool`, `discovery_family` | Supported rewards, duplicate policy and collection identity. |
| `rarity_band`, `exclusion_tags` | Control placement and incompatible neighboring compositions. |

An instance should record `instance_id`, owning `region_id`/`site_id`, template/content version, resolved asset/text IDs, actual linked destinations, committed facts and a novelty signature. Mutable progress belongs in separate discovery/reward records. Use independent deterministic streams for placement, story, reward and decoration rather than consuming combat RNG.

Use Wren's proposed actor/event IDs and committed episode facts for living connections. A clue should bind to a specific event phase or aftermath rather than to an independently rolled description. Prefer local links in the first milestone; cross-region chains require valid destinations and a bounded planning range.

Preserve the existing 25-chunk stream and bounded region cache. Derive distant immutable plans on demand; do not instantiate every landmark or simulate the entire world. Save actual discoveries, one-time reward claims and persistent changes. New optional progress fields should default safely for current generation-2 saves. This research does not authorize another reset or world migration. Layout-changing work requires a separate generator/save decision.

## Suggested development order

1. Add a reachable discovery-site planner, using existing regions and short read/inspect interactions. Try several cards above with real approach paths and normal camera zoom.
2. Bind each selected site to a local history and related journal entry. Add a small collection view or extend the saved journal; avoid filling the backpack with administrative tokens.
3. Add optional side-room objectives and meaningful district rewards. Preserve mandatory routes, warden gates and one-time skill-point chests while evaluating the new branches.
4. Connect discoveries to Wren's local episodes and aftermath. Introduce home displays when furnishing placement is supported.
5. Evaluate crafting traditions, shops, fishing, rare large landmarks and broader district density changes after the small journey loop proves useful.

## How to tell whether it works

Record meaningful discovery families rather than generated names or recolor counts. Compare journeys using the same test seeds before and after the addition. Ask players which places they remember, why they changed direction, and whether returning felt different. Measure travel between memorable discoveries, repetition of recent signatures, optional branch use and inventory interruptions. No target values have been validated yet.

Check determinism when entering from different directions; negative coordinates and region boundaries; reachable approaches; camera legibility; safe combat/interaction priority; reward deduplication; save/load; Sanctum return; and stable text references after content updates. Re-entering a cleared site must not reroll its history or reward. Expired local activities must not erase unique discoveries.

This pass reviewed sources, code and existing asset records and checked the document's local links. It did not download new packs, modify runtime behavior, benchmark performance or conduct a gameplay playtest.
