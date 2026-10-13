# Regional histories and collections

Town books, residents and roadside landmarks can now share an account of the same region. Three original history profiles describe a shared measure of hospitality, names kept for returning travelers and a borrowed lamp. Each profile binds its town and ruin names to real generated places. The linked ruin is the same one used by the region's roadside discovery.

Read a town book with E to see its local archive appendix. Talk to a resident and choose **Local history** for the spoken account. Read the roadside landmark for the third source. Open J to see regional collection progress and reread the sources you have collected. The regional record can mark its actual ruin on the atlas.

The journal labels a collection complete once every available source has been read. Quiet regions omit the landmark requirement; a collection therefore does not depend on a nonexistent marker. Collection completion records an account and uses no backpack slots or skill points.

[Local history quests](LOCAL_QUESTS.md) add optional resident requests to compare that account with a real ruin inscription. Accepting freezes the shared account, while proof still requires actual source reading. Correct reporting changes the resident's conversation and awards a supported home furnishing once.

When a local supper or delivery has finished, reading a local source can record its aftermath. Active events and events from another town cannot supply completed facts. The journal preserves the latest observed note per supported event kind, including the actual instance ID and finish tick. It keeps that note when the visible episode ends. Returning in a later cycle can update the note without accumulating an endless event log. Reading a saved journal page does not observe a distant town.

## Authoring

Profiles live in `lore/content/regional_history/`. The existing importer discovers JSON entries through its lore glob. Each profile has authored kind `regional_history`, runtime text kind and the importer's normalized `regional-history` tag. Adding another supported profile requires metadata and the normal serialized catalogue build/import; no filename list exists in GDScript.

| Field | Use |
| --- | --- |
| `id`, `version`, `motif` | Stable profile identity and edition. |
| `title`, `author`, `text` | Shared account. |
| `landmark_text`, `book_text`, `witness_text` | Source-specific accounts. |
| `biomes` | Eligible numeric base biomes; empty means all. |
| `requires` | Supported capabilities: `regional_history`, `collection`, `event_aftermath`. |
| `collection` | Required supported sources: `landmark`, `book`, `witness`. Unavailable anchors are omitted by the planner. |
| `event_notes` | Recipes with `kind`, `phase: "aftermath"` and `text`, matched against actual WorldLife events. |

Only `{city_name}` and `{dungeon_name}` are supported bindings. Unknown placeholders, capabilities, duplicate IDs/sources/event kinds and malformed values are rejected. Source passages are limited to 1,500 characters and definition titles/authors to 128; discovery source passages are limited to 4,000 so the combined collected passage fits the existing save limit. Metadata can add another profile or a note for a runtime-supported event; it does not implement a new event handler.

## Runtime and saves

[`regional_history.gd`](../scripts/regional_history.gd) queries the registry, validates profiles, selects a deterministic eligible history and manages source/aftermath records. [`exploration.gd`](../scripts/exploration.gd) connects real nearby anchors, reading, atlas markers and journal presentation. Expansion retains its normal book and dialogue behavior, with narrow local-history hooks. WorldLife remains the authority for event timing and facts.

An independent history hash selects the profile; no combat RNG is consumed. Plans are requested for the interacting region rather than enumerating the world. Only regions where a source was actually read become persistent records.

Optional `progress.exploration.regions` contains version 1 and records keyed by the existing generator/seed/coordinate region ID. Each collected region freezes resolved text, profile edition, source requirements and ruin identity. New profiles cannot rewrite an already collected account. New landmark reads append that region's account to the saved discovery text; older discovery passages remain unchanged. Existing current-generation saves without the nested field default to an empty regional collection. This component adds no reset; generator changes remain owned by the geography lane.

Validation checks region/seed identity, source membership, finite integer fields, resolved passages and matching event-note recipes. Restore validates before replacing current state and normalizes numeric JSON fields. Regional records carry through disk saves, fresh scenes, interiors and Sanctum return through the existing exploration progress contract.

## Verification

```sh
./godot.sh --headless --script tests/test_regional_history.gd --quit-after 180
./godot.sh --script tools/capture_regional_history.gd --resolution 1280x800
./check.sh
```

The focused test covers deterministic binding to actual town/ruin facts, duplicate-free source progress, quiet-region completion, malformed data, frozen editions and JSON normalization. Game-backed checks use actual book/landmark E, the live resident topic, completed local episodes, bounded later-cycle notes, disk saves, Sanctum return and older optional-field defaults.

The native helper uses isolated saves/settings under `artifacts/history-preview-saves` and captures the local book appendix, conversation/topic reader, landmark, aftermath, journal and completed account. It checks registry-backed content and the real atlas target. Images are `artifacts/history-*.png`. Long-session performance and preferred story/collection cadence remain playtesting work.

On 2026-10-13, source-backed and registry-backed regional checks, original exploration/lore checks and disk-save regressions passed without engine errors/warnings. The native helper passed; all seven screens were reviewed at 1280x800. A combined attempt passed importer tests but stopped at catalogue freshness during the other agents' pending bundle rebuild. Repeat the full checker after their serialized build/import handoff; these focused results do not certify later asset changes.
