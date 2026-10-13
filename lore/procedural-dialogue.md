# Procedural dialogue and placement

Status: authored content and writing specification. The four sanctuary roles, six books, and saved journal are now implemented; see [the expansion guide](../docs/WORLD_EXPANSION.md). Potfolk lines, ambient barks, and combat barks remain future presentation work. The original handoff below records the broader authoring direction.

Use complete authored lines selected for a speaker and an event. Procedural variety comes from character identity, local context, and remembered encounters. Keep fragments from incompatible personalities out of the same conversation.

## Proposed content record

Every line needs a stable `id`, `speaker`, `event`, `text`, and explicit eligibility conditions. Optional fields are `biomes`, `tone`, `weight`, and `once_per`. Values below are proposed authoring conventions. The coding agent can adapt the storage format.

Each spawned speaker needs a stable instance identity in addition to its role. A role such as `fountain_keeper` can recur across towns. Its chosen personality, personal facts, local affiliation, and names should stay consistent on revisits.

| Context value | Meaning and source |
| --- | --- |
| `city_name` | Display name of the relevant generated city |
| `dungeon_name` | Display name of an actual ruin linked to that city or encounter |
| `biome_label` | Greenwood, Sunlit Meadows, Amber Wastes, or Frostlands |
| `player_class` | Current class ID: `mage`, `sword`, or `spellsword` |
| `met_speaker` | Saved per-player, per-speaker conversation history |
| `returned_from_ruin` | Recorded surface-return event linked to this visit |
| `local_fact` | Future seeded regional detail, stored consistently across content |

Only the three name values in the first rows are text placeholders in this pass: `{city_name}`, `{dungeon_name}`, and `{biome_label}`. Other context values control selection. The class ID `sword` displays as Sword in the current game; use it for condition matching.

Missing required facts make a line ineligible. Never display unresolved braces. A neutral fallback should require no placeholder or conversation history.

## Selection and continuity

1. Establish the world seed, relevant place, speaker identity, and event.
2. Filter lines by role, event, biome, supported interaction, available bindings, and recorded conditions. Unknown conditions are false.
3. Select among eligible complete lines using a separate dialogue random stream. Do not consume the terrain or encounter generator's random stream.
4. Avoid recently displayed line IDs for that speaker. If the eligible pool is exhausted, prefer a short neutral fallback to repeating a personal revelation.
5. Bind names from actual world records. Two ruins can share a display name, so preserve their distinct site IDs internally.
6. Record encounter history after presentation. Regenerating a chunk must not make a met speaker introduce themselves again during the same retained session.

A seeded speaker and book should be reproducible given the same content version. Dialogue history and the field journal have retained save state. Existing collected editions keep their saved text; revised passages apply to future discoveries.

Choose a town's optional local custom or wonder once. NPCs and books that discuss it must use the same local record. A rumor is phrased as testimony. It must not place a nonexistent landmark, promise a reward, or silently become confirmed history.

## City line banks

Canonical English dialogue lives in `content/dialogue/`. Each original line has six complete authored variants. The first retains its old ID and text. Additional IDs end in `_v02` through `_v06`; those suffixes are stable identities, not array positions. All variants retain their group's speaker, event, eligibility, and named placeholders.

| Role | Source | Lines | Presentation |
| --- | --- | --- | --- |
| Fountain keeper | [fountain_keeper.json](content/dialogue/fountain_keeper.json) | 90 | Resident conversations; ambient lines remain future work |
| Milewarden | [milewarden.json](content/dialogue/milewarden.json) | 84 | Resident conversations; ambient lines remain future work |
| Relic mender | [relic_mender.json](content/dialogue/relic_mender.json) | 60 | Resident conversations |
| Retired delver | [retired_delver.json](content/dialogue/retired_delver.json) | 78 | Resident conversations |
| Potfolk neighbor | [potfolk_neighbor.json](content/dialogue/potfolk_neighbor.json) | 18 | Future distinct Potfolk character support |

The banks include greetings, farewells, world/guild/neighbor topics, role-specific subjects, and supper/delivery replies. `greeting` opens an interaction, `farewell` closes it, and `topic_*` events appear as choices for the four resident roles. Local-life replies keep their exact active/finished conditions. Missing facts and unsupported conditions exclude a line; more wording does not create new behavior.

The generic Potfolk role describes a courier. Its first handle was chosen by somebody else; its current handle was chosen by the individual. The future-support conditions remain in place. Do not use this bank for an ordinary decorative pot or a different occupation without a compatible character definition.

## Monster bark banks

| Enemy voice | Source | Lines | Presentation |
| --- | --- | --- | --- |
| Crypt Skeleton | [crypt_skeleton.json](content/dialogue/crypt_skeleton.json) | 24 | Future combat barks |
| Sanctum Invoker | [sanctum_invoker.json](content/dialogue/sanctum_invoker.json) | 24 | Future combat barks |
| Tomb Shade | [tomb_shade.json](content/dialogue/tomb_shade.json) | 24 | Future combat barks |

Use the existing enemy kind to select a voice. These complete barks describe aggression, attack, hurt, and rare memory. They belong in future subtitles or bark presentation, not in a target's name. The skeleton's formal duties and the invoker's lessons are in-world voices, not author instructions. The shade's recognition can be mistaken; it does not prove the player has been here before.

A `Once per speaker` condition applies to the entire `variant_group`. After hearing one memory variant, that speaker must not offer another wording of the same memory as a new revelation. Future enemy barks need the enemy instance as their speaker identity. Legacy heard IDs suppress their full group too.

Choose an aggro bark at most once per encounter, with a chance of silence. Attack and hurt barks should be infrequent. A future presentation system needs a shared cooldown so groups do not speak over each other. Speech must not carry essential combat information by itself.

## Translation-ready authoring

Every dialogue record has `source_locale: "en"`, an opaque stable `text_key`, and a `variant_group` separate from the prose. Conditions, event IDs, role IDs, groups, and place identities remain language-neutral. The full localization workflow and commands are in [locales/README.md](locales/README.md).

The generated English message index also covers readable-book titles/authors/passages, discovery labels, quest passages/choice labels, and regional-history notes. Each complete passage is a message. Translations must preserve named placeholders such as `{city_name}` and `{dungeon_name}`. Translate before binding the real names. Partial locale packs can fall back to English; they never change eligibility, rewards, or saved identities.

The locale files and keys prepare future runtime translation. There is no language selector or complete game-UI localization in this pass. Books and collected history/quest editions remain complete accounts; do not randomize their sentences independently.

## Neutral fallback text

The complete fallback bank is [citizen_fallback.json](content/dialogue/citizen_fallback.json). Its eighteen lines provide six greetings, six farewells, and six replies to an unknown topic. The selected reply carries a stable `text_key`, while its returned dialogue `id` stays empty so it cannot masquerade as an eligible authored fact or repeat a personal memory. Silence remains the monster fallback.

| Context | Text |
| --- | --- |
| Citizen greeting | Good to see a traveler. |
| Citizen farewell | Safe travels. |
| Requested topic has no eligible line | I don't know enough to tell you. |
| Monster has no eligible bark | Silence; show no subtitle |

## Authored conversation examples

These illustrate future choice flow. The choices reveal text and do not offer quests or change gameplay.

Fountain keeper in a generated town called Amberhaven:

> Keeper: Welcome to Amberhaven. Take a breath. The road can wait.
>
> Player choice: What happened during the Dawn?
>
> Keeper: My grandmother said the Dawn lasted three days. Her sister said four. They argued until sunset.
>
> Player choice: Goodbye.
>
> Keeper: Come back when you need somewhere to sit.

The town name above is an example. Substitute the real generated city name.

Retired delver:

> Delver: Sit if you're staying. My neck has retired, too.
>
> Player choice: Did you travel with anyone?
>
> Delver: My old crew argued over every meal. I miss the noise.
>
> Player choice: Goodbye.
>
> Delver: Leave yourself a way back.

Mark the personal line as heard after showing it. A later visit needs a different reply or the neutral topic fallback rather than repeating the revelation as if new.

## Handoff to the coding agent

These are suggested integration locations based on current source inspection. The coding agent owns the implementation and can choose a different architecture.

| Content | Where it should appear | Likely current source touchpoint | Dependencies |
| --- | --- | --- | --- |
| World and biome prose | NPC topics; future atlas descriptions | `scripts/world.gd`, `scripts/minimap.gd` | Stable place IDs and a flavor presentation field |
| Sanctuary conversations | Fountain-side NPC interaction | `scripts/world_view.gd`, `scripts/game.gd`, `scripts/interface.gd` | Speaker instances, proximity/interaction handling, dialogue panel |
| Combat barks | Brief subtitles during real enemy events | `scripts/game.gd`, `scripts/interface.gd` | Kind mapping, event transitions, bark pacing |
| Books and documents | Future readable props in homes, roadside stops, or ruin rooms | `scripts/world_view.gd`, `scripts/dungeon_view.gd`, `scripts/interface.gd` | Prop placement, book identity, read interaction and panel |
| Magic flavor | Grimoire or tutor topics | `scripts/character_build.gd`, `scripts/interface.gd` | Flavor fields that preserve current mechanical descriptions |
| New creatures and named stories | Future explicitly designed encounters | Implementation location to be chosen | Models, behavior, encounter identity, persistence, and any quest outcomes |

Authoritative content remains in `lore/` during development. Agree on a runtime export format before copying prose into scripts. Keep research and placement instructions out of player-facing text.

First implementation candidate: one fountain keeper role with greetings, a Dawn topic, and farewell; no quest, item, or faction effects. Follow with bark pools for the three existing enemies and the six authored books. New people, animals, relic effects, and unique encounters are later work.

Validate name bindings, missing-condition fallbacks, distinct ruin IDs with identical names, speaker identity after chunk reload, non-repeating personal lines, and bark pacing when several enemies become active. A fresh world should reset dialogue history along with world state. Review the rendered text separately for clipping and readability.
