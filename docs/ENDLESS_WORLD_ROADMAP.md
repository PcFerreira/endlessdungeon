# Endless-world roadmap

Coordinator: Rowan. Started: 2026-10-13. This is an implementation roadmap. A stage becomes complete only after its stated checks and a recorded agent handoff. Ownership follows `chat.md`; changes in shared files must preserve the other lanes.

## Current foundations

The prototype has streaming terrain, roads and sanctuary towns, six dungeon families, three combat classes, character customization and imported premades, a backpack, a pocket home, authored dialogue/books and a saved journal. The dynamic asset/lore pipeline discovers content through metadata, preserves licenses and supports runtime queries. The first coordinated expansion passed the 24-group combined check on 2026-10-13. Later follow-ups listed below need their own handoffs and checks.

The [exploration research](ENDLESS_EXPLORATION_RESEARCH.md) supplies discovery and reward ideas. [Wren's research](LIVING_WORLD_RESEARCH.md) supplies bounded activity and event continuity. The goal is for repeated journeys to differ in places, decisions and remembered outcomes while keeping movement, safety and interaction readable.

## Adopted setting and the next player experience

The player lives in the Endless World, a single infinite world formed when the multiverse collapsed, and belongs to the Milewardens, a traveling guild that maps places and catalogues mysteries. This is adopted setting direction. [World lore](../lore/world.md) states the premise; [Guilds and expeditions](../lore/guilds-and-expeditions.md) and [Politics and town compacts](../lore/politics-and-town-compacts.md) develop proposals. New world/guild topics use existing resident dialogue; guild bases, ranks, report services, diplomacy, and wars are not implemented by adding prose.

The next experience should let a player leave a recognizable home settlement with a question, find a destination through an approach cue, learn something particular about it, and return to someone who cares. Former worlds explain different local materials and traditions. Preserve coherent biome/town art families and make the meeting of traditions deliberate.

Develop the four existing organizations before adding more joinable guilds. Milewardens seek useful accounts; Hearthkeepers protect hospitality; the Small Repairs care about repair and object autonomy; the Unclosed Office disputes what the old atlas meant to preserve. Their disagreements should involve actual neighbors, resources, and places. The player remains a Milewarden while personal views and local relationships can vary.

The lore authoring layer has 420 complete dialogue variants. The translation index now has 5,868 stable message keys, including item/object names and all thirty construction names, with English references, translator context, locale templates, exact placeholder checks, and source-change review. [Lore translations](../lore/locales/README.md) records that contract; [Gameplay copy](PLAYER_TEXT.md) records the name audit. Runtime language selection remains a future milestone: resolve keys with English fallback, translate before binding real names, preserve dialogue/edition IDs and gameplay state, then review expanded strings and non-Latin fonts in actual readers. Menus, HUD, item descriptions, other town configuration prose, plural forms, and direction of text need separate extraction and presentation work before claiming whole-game localization.

## Stage 1: Connected, inhabited and discoverable journeys

| Lane | Owner and status | First deliverable | Completion evidence |
| --- | --- | --- | --- |
| Geography and towns | Lorekeeper; checks/previews and fresh save verified, final crossing handoff pending | Broader continuous biome areas, 128-cell town grid, connected bridges/roads and houses facing usable streets. | Physical routes/crossings and deterministic generation passed; native landscape review reported. Generation 4 and save/reset contracts posted. See [Landscape](LANDSCAPE.md). |
| Lives and wildlife | Wren; first slice complete and released | Resident routines, peaceful animals, delivery/supper episodes, local facts and saved activity state. | Bounded updates, live interaction positions, pause/Sanctum, save/load, sanctuary and native review passed. See [Living world](LIVING_WORLD.md). |
| Enemies and interiors | Ember; first slice complete and released | Additional enemy identities and enterable rooms with stable entrances and safe returns. | Catalogue, combat, doorway, interior/save/return and native checks passed. See [Enemies and interiors](ENEMIES_INTERIORS.md). |
| Enchanted ambience and NPC presentation | Aster; first slice complete and released | Data-defined regional sound beds, spatial chimes, book/footstep cues and cosmetic resident variation. | Bounded voices/visuals, independent volume, pause, deterministic presentation and native mixer/render checks passed. See [World ambience](WORLD_AMBIENCE.md). |
| Roadside discoveries | Rowan; first milestone complete and released | Four metadata-defined landmark families, authored clues to actual nearby ruins, map markers and persistent journal entries. | Real walking routes, quiet regions, E priority/safety, collection, disk saves/Sanctum and four-family native review passed. See [Roadside discoveries](EXPLORATION.md). |

Existing creator/HUD work from Aster and Ember is preserved. The four released lanes have recorded handoffs in `chat.md`. The combined check includes geography, living activity, enemies/interiors, ambience and discoveries together. Stage 1 remains open for Lorekeeper's final release and the new follow-ups below; long-session playtesting remains separate from these automated/native checks.

### Active follow-ups before Stage 2

| Work | Owner | Integration boundary |
| --- | --- | --- |
| Full available creature/item coverage and gameplay bundles | Ember | Separate generated catalogues; stable source/license records; preserve actor caps and save IDs. Include safe loot-drop placement. |
| Complete NPC appearance expansion | Rowan; complete and released, with Surveyor's local-biome gate | 32 new complete animated appearances, 41 total. Four new metadata-defined source families; preserved licenses/credits, actual clips, reachable seeded variants, coherent biome-compatible residents/watch and wider road visitors. Actual body/animation, 128-town and opposing native galleries pass. See [NPC appearances](NPC_STYLES.md). |
| Stores and markets | Rowan-Market; complete and released | Five data-defined specialties at real shop/workshop counters and market lots. Finite saved stock/purses, owned coin buy/sell, atomic rollback and preserved source/specialty identities. Actual transactions/layouts, stock exhaustion, provenance, disk/Sanctum/legacy/remapped-specialty and native UI checks pass. See [Stores and markets](STORES_MARKETS.md). |
| Coherent environment construction and location-specific sound | Aster | Contextual recipes with support/clearance; preserve roads, doors and discovery approaches. Coordinate narrow WorldView presentation with Lorekeeper. |
| Furniture/wall support and dungeon dressing corrections | Flint; complete and released | Focused real-geometry, room/route, save/return and native checks passed. Repeat placement checks after the pending broader asset pools. |
| Visible-area enemy rendering and display options | Wren; complete and released | Focused visibility/settings, save/camera and actual native window/fullscreen checks passed; preserve combat activation and terrain occlusion. |
| Travelers, guards, local episodes and monster grounds | Wayfarer; active | Preserve regional-history hooks, real event-instance fields, local actor budgets and the other lanes' spawn/render/loot boundaries. |
| Additional town identities | Townwright; active additive type and themed-presentation implementation | Common and themed identities alongside legacy archetypes, with sixteen additional cultural/style traditions under active checks. Preserve city/building/lot IDs, supported trades/interiors, primary layout/RNG, save edition and local visual families. Lore customs and field notes remain separate from new government or service behavior. |
| Irregular independent-site geography | Lorekeeper assignment approved by Compass; runtime claim/handoff pending | Town-free regions, irregular settlement spacing, independent ruins/castles/churches/temples, a safe start, and reachable recovery. Publish actual site-ID/lookup/nearest-town/route contracts and a save decision before consumers change. No new journey deletion is authorized. |
| Progressive site knowledge | Compass; complete and released with focused save/native handoff | Saved rumor/seen/visited states; clues and quests report real targets; bounded clear-approach sightings; hidden unknown markers/clicks. `Exploration.known_sites()` consumes actual nearby IDs/type/cell and `note_site` reports actual bound targets. Independent-site geography remains separate. |
| Contextual reward eligibility and ordinary expedition review | Ember/Wayfarer; approved follow-up pending acceptance | Enemy/habitat/family/class/rarity eligibility precedes configurable item chance; reliable coins and working purchases stay intact. Measure useful drops, backpack interruptions, and affordability during ordinary travel. |

Ember's creature/item build precedes Aster's environment/audio build. Do not run concurrent catalogue builds or imports. Each owner must post a final handoff before the next combined check; Rowan's completed run does not certify edits made afterward.

### Rowan's first milestone

Completed: a small discovery catalogue with a survey marker, a roadside refuge, an old root register and a watchpost notice. Source passages and placement metadata live under `lore/content/discoveries/`, so future entries can use the importer without filename lists in GDScript.

Plan at most one landmark per eligible region for this first slice, with deterministic quiet regions. Read real region/city/ruin IDs from the current world. Reserve an ordinary reachable approach on an existing road and a clear adjacent spot for the visual marker. Leave the road and underlying collision intact. Skip unsuitable placements rather than changing terrain or promising an absent target.

Reading records the resolved passage, owning place, template edition and linked ruin in a discovery collection. Repeated visits keep the same history and do not duplicate rewards. Journal records carry through saves and the Sanctum without requiring backpack slots. Existing fountains, doors, residents/books, stairs/gates/chests and combat safety retain priority. No new permanent HUD panel is required.

The first slice does not add crafting, trading, skill-point awards or a mandatory quest. Its useful outcome is a visible, readable and remembered discovery during ordinary travel.

## Stage 2: Local identity and remembered consequences

Rowan completed the first slice under the user's follow-up authorization: three metadata-defined regional accounts shared by landmark, town-book and resident sources, attainable journal collections and observed event aftermath. See [Regional histories](REGIONAL_HISTORY.md). Source-backed and shipped-registry gameplay, save/load and native checks pass on the current imported snapshot. Ember's later shared import includes both histories and quests. A final all-lane suite remains pending concurrent runner/runtime edits; the milestone log records the exact boundary. The current geography uses a 128-cell town grid and generator edition 4. Independent-site geography is approved with its runtime claim/handoff pending; Compass has claimed progressive site knowledge independently of that topology change.

The next authorized slice is implemented as [Local history quests](LOCAL_QUESTS.md): three optional resident requests compare a real local ledger with the linked ruin's archive, then return a finding to the same speaker. The journal records stages and real routes; correct reporting changes dialogue and grants a supported one-time furnishing. Full backpacks retain a pending reward. Source-backed, actual gameplay/disk/home and native reward-placement checks pass. Unsupported townless records skip cleanly; wider independent-site binding needs the future geography resolver.

Extend this slice with district motifs, more compatible site-history bundles and richer event consequences after the active Stage 1 follow-ups have a stable combined build. Let later visits show aftermath without rerolling unique discoveries. Resolve every reliable clue to an actual target before publishing it.

Suggested ownership: Rowan for discovery definitions and collection progression; Wren for event facts/aftermath lifecycle; Lorekeeper for district planning; Ember for compatible interior anchors. These are proposed assignments until each agent claims the work.

Completion requires stable IDs across unload/reload, text/fact agreement, reachable targets, no duplicate unique reward, bounded planning and save round-trips. Compare journeys using fixed seeds and record which places players remember. The amount of content and presentation frequency should follow those playtests.

### Proposed next slice: a chapter and a reason to return

The user requested guild/faction and political expansion. The following milestones are proposed implementations, with no new runtime owner claim. Begin after the geography/discovery contracts are stable; local writing can proceed independently.

| Milestone | Concrete first deliverable | Dependencies and acceptance |
| --- | --- | --- |
| A Milewarden welcome | A charter, one recognizable custodian, and a map shelf in an existing settlement interior | Reachable real room, ordinary book/dialogue interactions, local identity, no implied unimplemented service, readable native presentation |
| One answered mystery | A collapse-related question with evidence and a resident's response; begin with the bridge's conflicting builder accounts | Reuse the comparison handler where sufficient; real target/source bindings and preserved editions; reward once, delayed safely when inventory is full |
| A visible homecoming | Return an account to that chapter and display its copy on the expedition shelf | A supported report handler, unique report/site identity, saved outcome and no duplicate reward; do not imply the player visited an unseen site |
| Local political voice | A town's government/watch tradition and one shared obligation with a neighbor | Initially additive names, customs, and dialogue; retain current law/provenance/safety. Two towns must refer to the same relation and physical dependency |
| A political comparison | One bridge or water agreement whose old records disagree | Evidence yields a truthful finding separately from the player's political preference; no unsupported toll, embargo, or diplomatic result |

The chapter is a public social base; the Sanctum remains private. Optional chapter storage, rest/respawn, fast travel, training, and paid services each need explicit handlers and their own interface. Do not attach these benefits to a room label. A first chapter can occupy an inn or archive instead of requiring new large-building generation.

For acceptance, record one ordinary expedition: notice the chapter, choose a question, leave town, encounter a physical cue before opening the atlas, investigate a memorable site, and return. Observe whether the player understands their next action, can distinguish rumor from a visit, recalls the finding and its recipient, and still has a usable way home. Focused connectivity/save tests do not establish those experience outcomes.

## Stage 3: Different expeditions and lasting rewards

Add optional side rooms and alternate dungeon objectives, clearly described expedition commitment, bounded equipment traits and regional appearance rewards. Sanctum furnishing placement and portable cleared-site bases already have focused handoffs in `chat.md`; wider integrations still need their current combined acceptance. Build on those features for expedition souvenirs and displays. Preserve finite dungeon endings and the one-time skill-point claim while evaluating side content.

Assign a dungeon/objective owner and a home-placement owner before implementation. Each new behavior needs a supported runtime handler, saved progress and an exit/recovery path. Data entries can then multiply that supported behavior. Imported metadata alone does not implement a puzzle or quest.

Completion requires objective connectivity, clear telegraphing, fair combat/reward balance, item/slot compatibility, collision-safe home placement and native UI checks. Finished skill trees should still leave worthwhile discovery and identity goals, without endless automatic stat inflation.

### Proposed guild and faction progression

After one chapter works, add regional chapters with different people and concerns. A winter chapter can survey shelter; a market chapter can investigate a working threatened by salvage. Add one new objective type at a time: route survey, then limited relic investigation. Each needs evidence, a completion handler, saved state, and an exit/recovery path before metadata expands its variations.

Use local relationships and report outcomes rather than one global faction score. A chapter can trust an account while a particular keeper objects to publishing a refuge. Make those consequences legible before the choice, with a way to reconsider where appropriate. Reports can earn recognition, new supported opportunities, display copies, or ordinary rewards. Repeated copies of a finding cannot grant infinite rewards. Leave requests optional and without real-world expiry.

Suggested future ownership is Lorekeeper for voices and mystery design, Rowan for report/discovery identity and editions, Wayfarer for the law/relationship boundary, Wren for remembered local aftermath, and the interior owner for chapter geometry. These are suggestions until claimed in `chat.md`.

## Stage 4: Regional trades and wider contrasts

Basic shop/workshop and market trading is implemented under the user's earlier stores authorization. Existing trader stock and purse persist; timed restocking, specialist town-theme wares, crafting and economic balance remain separate follow-ups. New eligible imported items enter the data-defined stock pools without runtime pack lists.

Evaluate regional shops, craft traditions, fishing/gathering, cosmetic seasonal customs, rare large landmarks and sparser wilderness districts. Select the most useful features from Stage 1–3 playtesting rather than implementing every research idea at once.

Keep collections optional and avoid expiring real-world deadlines. New shops/recipes need working transactions; new gathering needs a clear use for resources; larger landmarks need footprints, approach routes and camera checks. Changing region/site density requires an explicit generation/save decision.

### Proposed politics and selective conflict

Towns need governments and defense traditions, but a single world government is unnecessary. Current towns supply two local watch actors and property enforcement. Future councils, stewards, trade charters, keeper compacts, and road leagues can first appear as consistent local records and voices. A communal watch and a paid watch can look and speak differently while retaining tested law behavior. Removing guards requires a replacement safety/restitution design.

Begin relations with shared crossings, supply agreements, trade rivalry, and unresolved historical claims. Then evaluate mediation with actual local consequences. Wars and ceasefires belong to particular regions and stories; there is no current town-war simulation. Most towns should retain ordinary trade, hospitality, and disagreements that do not become combat. Infinity does not remove the value of reachable water, shelter, and safe roads.

Before embargos, hostile checkpoints, or war progression, implement a bounded relation record, real route dependencies, visible warnings, saved outcomes, and a usable refuge/return path. The two sides share one underlying agreement while their accounts can differ. Do not destroy the player's home or close their only recovery route through an unseen offscreen event. Preserve city-specific theft debts independently of political allegiance.

Evaluate one two-town compact before adding a wider conflict system. Its acceptance must cover both perspectives, evidence versus choice, save/revisit continuity, law separation, sanctuary recovery, and normal-gameplay clarity. A political outcome should change a supported interaction or an observed local condition; adding a faction name alone does not implement politics.

## Persistent browser world

The authorized multiplayer work begins with shared surface exploration: account registration/resume, server-owned character records and movement, SQLite-backed map chunks, bounded nearby streaming and visible peers. The browser starts at the online lobby and receives terrain without procedural generation. Native offline journeys remain separate. Architecture, local startup and the next authority milestones are in [Persistent browser world](BROWSER_MULTIPLAYER.md).

The shared-exploration slice is accepted on revision0fd56611: two actual Chrome accounts on LAN HTTP/WS and public HTTPS/WSS received 25 server chunks with zero local generation, saw each other move, and preserved account/position through token resume. Queue/boundary failures are corrected. The LAN launcher uses silent audio without changing browser security settings. Four actual backend groups and isolated Web-package/resource/license checks pass. The running authority is pinned to an assembled release and the world database is durable. The temporary HTTPS tunnel provides Internet testing; stable production hosting, physical second-device acceptance, sustained player capacity and Docker execution remain separate.

Next implement server-owned enemy/combat state and shared rewards, then inventory/shop transactions and room/party instances. The current offline mutation handlers stay gated in online sessions until their server equivalents exist. Existing world editions and account identities require explicit migration decisions.

## Shared contracts

- Use stable region, city, building, ruin, actor and discovery IDs. Keep immutable plans separate from mutable progress.
- Preserve public `region.city`, `region.dungeons`, `region.coordinate` and surface-query contracts, or post an adapter before changing them.
- Use separate deterministic streams for discovery/history/rewards; do not consume combat RNG or depend on chunk-render order.
- New additive progress fields need validated defaults in existing saves. Rowan's discovery work does not request a reset; Lorekeeper owns the separately requested generation change and its reset policy.
- Use one interaction key and explicit priority. Pause exploration/living activity during modal screens as the owning systems require. Safe towns remain safe.
- Keep runtime plans, actors and visuals bounded by nearby regions/chunks. Do not enumerate the endless world.
- Serialize asset builds and editor imports. Preserve source notices and required credits, and rerun the real-rebuild regression when changing the pipeline.
- Append claims, interface changes, test results and releases in `chat.md`, signed with the agent's nickname.

## Integration and verification order

Each lane first runs its focused tests against real source data. Merge narrow lifecycle/input/save hooks after reviewing the latest shared files. Rebuild content once the authored entries and asset rules are ready, then complete a single editor import before native or gameplay checks.

Run the combined `check.sh` after the last integration handoff. Use isolated test saves and capture helpers; do not replace the user's live journey during verification. Review exploration, combat, interiors, resident interaction, journal and Sanctum return at the normal desktop viewport. Record which checks actually ran and which playtesting remains.

## Milestone log

- 2026-10-13: Rowan reviewed active lane claims, posted discovery interfaces, created this roadmap and began the independent discovery catalogue/planner/collection slice. Stage 1 remains in progress.
- 2026-10-13: Rowan completed the discovery slice and recorded the released Wren, Ember and Aster first-stage handoffs. `./check.sh` exited 0 with four Ruby tests / 36 assertions, catalogue freshness, editor import and all 24 Godot groups; no engine errors/warnings in `/tmp/endless-rowan-roadmap-combined.log`. The focused exploration check and native four-family/journal capture also passed; marker, reader and journal images were reviewed at 1280x800 using isolated saves. Active later agent edits need subsequent verification.
- 2026-10-13: Rowan began Stage 2 regional history under explicit user authorization, coordinated narrow Expansion/event APIs with Wayfarer and requested inclusion in Ember's serialized lore build. Source-backed regional checks pass in `/tmp/endless-rowan-history-catalog.log`; integration verification remains in progress.
- 2026-10-13: Rowan's first Stage 2 slice passed full registry-backed history, original exploration/lore and disk-save checks. Seven native screens were captured and reviewed at 1280x800 with isolated saves. Real E testing also corrected bookstand sight checks to use authored approaches; legacy scenery profiles with missing paths now resolve their existing stable registry IDs. The combined attempt passed four Ruby tests / 36 assertions, then stopped at stale catalogue output during Ember/Aster's active bundle refresh (`/tmp/endless-rowan-history-combined.log`); no complete combined pass is claimed for this snapshot.
- 2026-10-13: Rowan completed three local-history comparison requests with saved evidence, return reporting, changed conversation and one-time furnishing rewards. Focused quests, history, discoveries, lore and disk saves passed cleanly; nine native quest/home captures were reviewed. The combined run passed six Ruby tests / 47 assertions, freshness/editor and all 37 runtime groups it executed, then exited 1 after concurrent checker edits caused a trailing shell parse error (`/tmp/endless-rowan-quests-combined.log`). An immutable runner repeat reached a new in-flight WorldItems compile declaration (`/tmp/endless-rowan-quests-combined-stable.log`); the owning lane corrected it. These are focused/partial integration results, not a certified complete all-lane run. Later source changes require verification after their handoffs.
- 2026-10-13: Lorekeeper adopted the Endless World/collapsed-multiverse premise and Milewarden player membership, revised player-facing discovery/history/quest voice, and added proposed guild chapters, faction disagreements and local politics. All 67 prior dialogue IDs/texts/eligibility now have six complete variants, plus eighteen neutral replies: 420 lines across nine per-speaker files. The English/export layer supplies 508 stable message keys, context/source hashes, templates, exact placeholder validation and translation-source review. Exporter tests pass four/15; dynamic and locale freshness, clean editor scan, grouped-memory/legacy-ID regression, actual expansion/history/quest/registry/save flows and isolated four-role native dialogue review pass. No language selector, guild services, diplomacy or war simulation is claimed. Full all-lane acceptance remains separate from these focused checks.
