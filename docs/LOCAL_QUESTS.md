# Local history quests

The first local quest behavior connects a resident, a real town ledger and an archive in that region's linked ruin. Talk to a fountain keeper and choose **Local comparison** to review an optional request. Accept it, read the town book with E, inspect the annotated archive with E inside the marked ruin, then return to the same resident and compare the copied accounts.

Three original requests follow the regional histories. The shared measure and returning-name accounts agree with their inscriptions. The borrowed-light accounts explicitly disagree about ownership. The quest reader retains both passages so the player can check their words before reporting. A wrong comparison leaves the request open and spends nothing.

The J journal records the next step and can mark its actual town or ruin. Archived pages cannot supply new evidence or report a result from afar. The archive annotation appears only for an accepted quest in its real ruin and respects dungeon discovery visibility. It adds no blocking collision and reuses the existing reserved readable approach. Any entered floor can supply that archive's inscription, including the floor where a saved expedition resumes.

Correct reporting changes the giver's conversation and grants one supported home furnishing. If the backpack is full, the completed record reserves the reward; collect it later from the quest record when there is room. Completion and reward delivery are separate saved flags, so repeated reports, loading and Sanctum return cannot duplicate the reward. The furnishing uses the existing placement system and its support, clearance and refund rules.

## Data contract

Definitions live in `lore/content/local_quests/` and use authored kind `local_quest`. The normal lore importer publishes text records tagged `local-quest`. Adding another comparison requires another metadata record and the normal serialized catalogue build/import, without a filename list in GDScript.

| Field | Use |
| --- | --- |
| `id`, `version`, `title`, `author`, `text` | Definition identity and offer text. |
| `history_motifs`, `giver_roles` | Compatible committed regional history and actual town resident role. |
| `requires` | The implemented handler is `compare_inscription`. |
| `target` | `kind: "ruin_archive"` and its visible label. |
| `ledger_prompt`, `inscription`, `finding`, `completion` | Step guidance, copied inscription, comparison explanation and changed conversation. |
| `choices`, `answer` | Two to four unique labeled choices and the correct choice ID. |
| `reward` | Supported furnishing item ID and quantity. |

Only `{city_name}` and `{dungeon_name}` are supported bindings. The parser rejects unknown handlers/targets/placeholders, malformed choices, duplicate IDs and unsupported furnishing rewards. The current handler implements reading and reporting; metadata alone cannot create combat objectives, delivery transactions or puzzles.

## Runtime and persistence

[`local_quests.gd`](../scripts/local_quests.gd) handles definition discovery, deterministic offers, state transitions, evidence validation and atomic reward claims. [`local_quest_ui.gd`](../scripts/local_quest_ui.gd) binds actual resident/book interactions, the inscription annotation, quest reader, journal rows and atlas markers. Exploration carries their optional `progress.exploration.quests` snapshot through the existing save/interior/home contract.

The states are `ledger`, `inscription`, `return` and `completed`. At most four unfinished requests can be active, with one accepted request per region. A request freezes its definition, regional-history edition, giver/site/book IDs, copied passages and reward. Acceptance commits the shared regional account without inventing a read source. A previously copied real local ledger can satisfy the first step.

Evidence records the actual ruin ID, floor, readable edition and archive cell. Ledger and inscription capture require gameplay reading near the real accessible anchor. Turn-in requires the original speaker in a local conversation. Independent hashes select offers without consuming combat RNG. Only accepted records persist; the runtime does not plan quests across the endless world. Per-frame archive queries scan at most four active IDs; completed records use direct region/giver lookup and are not enumerated each frame.

Current bindings use actual sources in a town's region. A townless record offers no comparison/history/landmark instead of inventing missing sources. Cross-region independent-site quests need the future geography resolver before adoption; these skip checks do not implement that wider generator.

Older current-generation saves without the nested quest field default to no quests. Restore validates seed/region identity, state/evidence consistency, choice/reward fields and active limits before replacing state, then normalizes integer JSON fields. This additive component requests no world reset.

## Verification

```sh
./godot.sh --headless --script tests/test_local_quests.gd --quit-after 180
./godot.sh --script tools/capture_local_quests.gd --resolution 1280x800
./check.sh
```

The source-backed check exercises deterministic real-place bindings, sequential proof, invalid sites/speakers/choices, full-backpack deferral, duplicate claims and JSON round-trips. Game-backed checks cover actual resident/ledger/archive interaction, saved dungeon evidence, Sanctum return, changed dialogue, furnishing reward and older optional-field defaults. The native helper uses isolated `artifacts/quest-preview-saves` and captures the full journey plus the placed reward at home. Images are `artifacts/quest-*.png`.

Quest variety, preferred request frequency and reward value still need playtesting. Future objective types require their own supported handlers and recovery paths before content entries can use them.

On 2026-10-13, the focused quest/history/discovery/lore/disk-save checks and native journey passed without engine errors/warnings. All nine quest/home images were reviewed at 1280x800. A combined run passed all 37 runtime groups it executed plus six Ruby tests / 47 assertions, freshness and editor import, then its live runner changed and ended with a shell parse error. An immutable repeat encountered an in-flight portable-item compile change. No complete all-lane pass is claimed; repeat the shared suite after active source/checker edits settle. Logs are `/tmp/endless-rowan-quests-*.log`.
