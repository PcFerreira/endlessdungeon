# Procedural dialogue and placement

Status: writing specification and draft content. This is a handoff for the coding agent, not an implemented dialogue system.

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
| `met_speaker` | Future per-player, per-speaker conversation history |
| `returned_from_ruin` | Future recorded surface-return event linked to this visit |
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

A seeded speaker and book should be reproducible given the same content version. Dialogue history needs its own retained state. Cross-launch continuity requires future save support; the current world is not fully saved between launches.

Choose a town's optional local custom or wonder once. NPCs and books that discuss it must use the same local record. A rumor is phrased as testimony. It must not place a nonexistent landmark, promise a reward, or silently become confirmed history.

## City line bank

Events here are proposed dialogue events. `greeting` opens an interaction, `farewell` closes one, and `ambient` is an optional proximity bark. `topic_*` events require explicit dialogue choices. All these events need future NPC interaction support.

| ID | Speaker | Event | Conditions | Text |
| --- | --- | --- | --- | --- |
| `keeper_hello_01` | `fountain_keeper` | `greeting` | First meeting | Welcome to {city_name}. Take a breath. The road can wait. |
| `keeper_hello_02` | `fountain_keeper` | `greeting` | Any | Rest first. You can tell me what happened afterward. |
| `keeper_return_01` | `fountain_keeper` | `greeting` | Met speaker; returned from a linked ruin | Back from {dungeon_name}? Sit down before you tell me about it. |
| `keeper_fountain_01` | `fountain_keeper` | `topic_fountain` | Any | The fountain offers rest. Keeping the steps clean is my contribution. |
| `keeper_dawn_01` | `fountain_keeper` | `topic_dawn` | Any | My grandmother said the Dawn lasted three days. Her sister said four. They argued until sunset. |
| `keeper_meadow_01` | `fountain_keeper` | `ambient` | Sunlit Meadows | We set a place for whoever the road brings next. |
| `keeper_frost_01` | `fountain_keeper` | `ambient` | Frostlands | Some bells are waiting for people, too. |
| `keeper_bye_01` | `fountain_keeper` | `farewell` | Any | Come back when you need somewhere to sit. |
| `warden_hello_01` | `milewarden` | `greeting` | City name available | {city_name}. Spelled it correctly this time. |
| `warden_hello_02` | `milewarden` | `greeting` | Any | I measure the road. Whether it has an end is above my wages. |
| `warden_ruin_01` | `milewarden` | `topic_ruins` | Linked actual ruin | There is a ruin called {dungeon_name} in the country near {city_name}. |
| `warden_dawn_01` | `milewarden` | `topic_dawn` | Any | The Office promised a complete map. We are still correcting their work. |
| `warden_green_01` | `milewarden` | `ambient` | Greenwood | The oldest oaks still wear the surveyors' nails. |
| `warden_amber_01` | `milewarden` | `ambient` | Amber Wastes | A full cup deserves a steady hand. |
| `warden_bye_01` | `milewarden` | `farewell` | Any | If you find more country, write down how you reached it. |
| `mender_hello_01` | `relic_mender` | `greeting` | Any | Let me finish this seam. It has strong opinions. |
| `mender_magic_01` | `relic_mender` | `topic_magic` | Any | An old enchantment can keep doing its job after everyone forgets what the job was. |
| `mender_bye_01` | `relic_mender` | `farewell` | Any | Mind the corners on your way out. |
| `delver_hello_01` | `retired_delver` | `greeting` | Any | Sit if you're staying. My neck has retired, too. |
| `delver_ruin_01` | `retired_delver` | `topic_ruins` | Any | A gate opening is a chance to leave as well as a chance to go deeper. |
| `delver_mage_01` | `retired_delver` | `topic_training` | Mage or Spellsword | Blink still needs somewhere clear to put you. Remember that when you're frightened. |
| `delver_sword_01` | `retired_delver` | `topic_training` | Sword | A sword arm needs rest. Pride can wait beside it. |
| `delver_memory_01` | `retired_delver` | `topic_companions` | Once per speaker | My old crew argued over every meal. I miss the noise. |
| `delver_bye_01` | `retired_delver` | `farewell` | Any | Leave yourself a way back. |
| `potfolk_hello_01` | `potfolk_neighbor` | `greeting` | Future Potfolk character support | I'm the courier. The soup is a separate arrangement. |
| `potfolk_handle_01` | `potfolk_neighbor` | `topic_self` | Future support; this individual has chosen their current handle | I chose this handle. The first one was somebody else's idea. |
| `potfolk_bye_01` | `potfolk_neighbor` | `farewell` | Future Potfolk character support | Safe roads. Soft landings. |

For this first bank, the generic Potfolk role describes a courier. Expand occupation-specific pools before assigning these lines to other Potfolk professions.

## Monster bark bank

Use the existing enemy kind to select a voice. The events correspond to future hooks into actual combat transitions. Text belongs in a subtitle or bark presentation system, not in the target's name.

| ID | Speaker | Event | Text |
| --- | --- | --- | --- |
| `skeleton_aggro_01` | `crypt_skeleton` | `aggro` | Visitors must wait outside. |
| `skeleton_attack_01` | `crypt_skeleton` | `attack` | Inventory discrepancy. |
| `skeleton_hurt_01` | `crypt_skeleton` | `hurt` | That was accounted for. |
| `skeleton_memory_01` | `crypt_skeleton` | `hurt` | There were beds here. I counted them. |
| `invoker_aggro_01` | `sanctum_invoker` | `aggro` | Identify your instructor. |
| `invoker_attack_01` | `sanctum_invoker` | `attack` | Demonstration follows. |
| `invoker_hurt_01` | `sanctum_invoker` | `hurt` | The exercise is incomplete. |
| `invoker_memory_01` | `sanctum_invoker` | `hurt` | Please. I practiced. |
| `shade_aggro_01` | `tomb_shade` | `aggro` | You came back. |
| `shade_attack_01` | `tomb_shade` | `attack` | Stay where I can remember you. |
| `shade_hurt_01` | `tomb_shade` | `hurt` | I had a name. |
| `shade_memory_01` | `tomb_shade` | `hurt` | Was it warm outside? |

Treat the three `*_memory_01` lines as rare and once per enemy instance. "You came back" is the shade's mistaken recognition, not a condition that the player visited previously.

Proposed pacing: choose an aggro bark at most once per encounter, with a chance of silence. Attack and hurt barks should be infrequent. Give the presentation system a shared cooldown so groups do not speak over one another. Do not require speech to communicate combat information.

## Neutral fallback text

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
