# Content Workbench

Launch `./content-editor.sh` from the project folder, or double-click `content-editor.command` on macOS. On Windows, run `content-editor.bat` with Godot 4 available in `.tools/Godot.exe` or on PATH. The workbench opens its own window and does not start a game session. Ruby is needed only when staging new source assets through the existing import pipeline.

Choose Monsters, Items or Assets in the left pane. Search names, IDs or source packs and browse sixty records per page. Changes remain in memory until Save changes. Discard unsaved reloads the saved file; Revert this record removes that record's overrides. Editing preserves existing catalogue IDs and saved inventory identities.

## Monsters

Edit base health, attack, speed, range, attack windup/recovery, body height, spawn weight and base level. Depth scaling adds dungeon depth minus one to the base level; Fixed keeps that level. Health and attack growth are percentages of their level-one base values. The preview depth control displays the resulting health and attack. Empty overrides preserve the existing thirteen-percent health and seven-percent attack scaling, including their existing caps.

Aggressive on sight starts pursuit when a nearby player is visible. Retaliates when hit lets a neutral monster defend itself. Disable both options for a fully passive monster. The preview's Pursuit mode uses the same engagement policy; Provoke tests retaliation, and Reset clears provocation. Walk loop and Attack preview animation independently of hostility.

The preview uses real game models and their animation clips on a clear test floor. It uses edited speed, range, windup and recovery, without simulating the surrounding world's navigation, terrain or monster packs. Right-drag to orbit and scroll to zoom. The green arrow marks movement front, positive Z. Facing correction rotates the body relative to that direction; Flip 180° exchanges front and back. Animation clip mapping accepts exact idle/walk/attack clip names, displayed in its dialog.

Automatic body mode preserves generated dungeon monsters and climate-compatible surface bodies. Imported uses the selected source model in both contexts. Generated uses the procedural monster body in both contexts. The Dungeon body/Surface body selector and climate selector show the actual corresponding representation.

Configure coins per kill, item/shard probabilities and recovery-orb probability/type. An empty custom table uses normal enemy, habitat, dungeon and class loot. A custom weighted table replaces that contextual item selection, while its item probability still decides whether a roll occurs. Class-incompatible equipment, disabled items and items above the monster's level are excluded. Recovery mode Legacy retains the existing health-every-third-kill/mana cadence; None removes recovery pickups. Simulate 1,000 reward rolls includes coins, ordinary items, shards and recovery orbs for the selected class, dungeon family, climate and preview level.

## Items

Edit names, descriptions, stack sizes, restoration amounts, health/resource bonuses and attack bonus percentage. Equipment needs a slot and at least one supported class. Minimum enemy drop level limits eligibility in monster rewards; it is not a player equipment requirement. Select a staged model or icon and adjust atlas crops through the icon rectangle dialog. Choosing another icon clears the previous crop.

Disabled definitions remain readable for existing saves and inventories, while future loot and monster pools omit them. The editor rejects incomplete equipment, missing grouping fields, nonexistent models, non-image icons, invalid crops and unknown drop references before saving. It decodes images to verify their actual texture contents and visible crop.

Remove item hides the selected item from the active browser and excludes it from future enemy/chest rewards and merchant offers, including stock held in a saved shop. Save changes applies the removal on the next local game restart. Enable Show removed items to find it again, then select Restore item and save. Restoration keeps its earlier stat edits and enabled/disabled setting. Removal works for original and added items, retaining their stable definitions so owned inventory, equipment and saved stock can still load. It preserves source assets, existing placed objects and starter inventory; it does not erase those records from hero saves. Existing custom drop tables can retain a removed item reference, but reward rolls skip it and the drop picker omits it.

## Assets

The browser reads `import_assets` alongside the real imported catalogue. It retains source paths, pack, author and licence metadata. Filter by kind, pack or usage:

| Usage | Meaning |
| --- | --- |
| Game references | Explicit item/monster references, model-query candidates and declared model texture dependencies. |
| Portable only | Available as a generated portable object, with no other indexed game reference. |
| Not referenced | Staged resource without an indexed reference or portable definition. |
| Source only | Original file that has not been staged into the game catalogue. |

These are catalogue and rule references, rather than a trace of encounters or rendered objects. Generated dungeon bodies can replace their original source appearance. The indexed environment configurations are listed in `tools/content_editor/assets.gd`; the report does not claim to discover every arbitrary script reference. Export usage report writes the inventory and reasons to `artifacts/asset-usage.json`.

A staged model can become a new monster or an item, or replace the last selected record's model. A staged texture can become an item icon. New definitions use stable `editor:<asset-id>` identities. Model adoption retains the imported asset ID and its provenance; original files and generated bundle definitions are preserved.

For source-only files, Stage selected asset + rebuild adds one exact import rule under `config/editor_asset_imports.json`, registers that fragment, runs the normal importer and catalogue builders, then runs Godot's resource import. The workbench restarts after a successful import so its resource catalogues are fresh. Save edits first. This explicit action needs Ruby, valid pack `SOURCE.json`/licence documents and a supported glTF/GLB/OBJ, texture or audio file. Unregistered packs and raw FBX files require metadata or conversion before this action. Import errors are retained in `artifacts/content-editor-import.log`.

## Files and publication

`config/content_edits.json` stores the override patches and added definitions. The game applies them after base catalogue generation and localisation. Rebuilding imported bundles preserves this file. Save writes a validated temporary file, backs up the previous version to `content_edits.json.backup`, checks for intervening changes and publishes through a rename. An exclusive `.lock` directory serialises cooperating workbench writers. A writer that ignores this lock can still race the final filesystem instruction; the editor checks fingerprints after staging and directly before publication rather than claiming filesystem compare-and-swap. If a process is forcibly terminated during saving, remove its stale lock only after confirming that editor is no longer running.

Restart local games to load saved edits. Existing packed builds and deployed public-world services retain their pinned data; publishing a new authoritative release remains a separate operation. The standalone editor does not connect to the public world, alter hero saves, rebuild release manifests or restart services.

## Verification

Run `./check-content-editor.sh` for the focused checks. They cover the complete pre-edit item catalogue, consumed equipment/material/portable references, malformed-definition rejection, actual Game health/levels/facing/hostility/rewards/collection/save, reversible item removal with inventory and shop-ledger compatibility, full staged/source asset coverage, provenance-preserving selective imports in a temporary project, live editor controls and a real sixteen-megabyte concurrent publication.

`./content-editor.sh -- --capture` produces native Monster, Item and Asset views in `artifacts/content-editor-*.png`. Native captures exercise actual rendered bodies and the populated browser. Windows launcher syntax is supplied; native visual verification was performed on macOS with Godot 4.7.2.
