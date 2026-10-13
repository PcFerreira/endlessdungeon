# Asset and lore imports

Run `ruby tools/import_assets.rb --build` after changing source packs, lore or import rules. The importer generates `assets/imported/catalog.json`, copies selected files and their dependencies, and preserves publisher licenses and credits. An unchanged build leaves the output untouched. Failed validation preserves the previous usable output.

```sh
ruby tools/import_assets.rb --scan > /tmp/asset-candidates.json
ruby tools/import_assets.rb --build
ruby tools/import_assets.rb --check
./godot.sh --headless --editor --import
```

`--scan` lists all discovered source candidates and publishable lore, including alternate model formats and preview images. `--build` applies `config/asset_imports.json`. `--check` fails when the generated catalog or copied file hashes are stale. Run the Godot editor import after a changed build and before loading new resources in the game. Source collections remain excluded by `import_assets/.gdignore`.

## Add an asset pack

Place the pack under `import_assets/` and put `SOURCE.json` at its root. Discovery uses these records, so a new pack does not need an entry in Ruby or GDScript. Pack IDs must be unique and contain letters, digits, underscores or hyphens. Keep the original publisher license files and include the applicable legal text. For example:

```json
{
  "id": "new_castles",
  "title": "New Castles",
  "author": "Creator Name",
  "source": "https://publisher.example/pack",
  "license": "CC0-1.0",
  "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
  "categories": ["Castles", "Architecture"],
  "attribution_required": false,
  "attribution_text": "New Castles by Creator Name. License: CC0-1.0."
}
```

Use the actual publisher terms and URL. A pack's source record does not replace its license. Packs under `import_assets/license_review/` are excluded from discovery. Existing legacy sources without `SOURCE.json` still use `tools/adopt_assets.rb`; add metadata before selecting them through this importer.

Select packs with rules in `config/asset_imports.json`:

```json
{
  "pack": "new_castles",
  "kinds": ["model"],
  "include": ["**/*.glb", "**/*.gltf"],
  "exclude": ["**/preview/**"],
  "tags": ["architecture", "fortress"]
}
```

`pack` accepts glob patterns, including `*` for future packs. `include` and `exclude` match paths relative to the pack root. `kinds` accepts `model`, `texture` and `audio`. `match_tags` requires every listed tag to be present before applying the rule. `tags` adds labels to selected records. Set `enabled` to `false` to disable a rule. New matching files in an enabled pack are included on the next build.

The shipped rules select Cube World scenery and NPC models and Kenney Castle models. They publish 116 model files. They preserve existing `assets/expansion/` and legacy game paths. The generated selection can grow through JSON rules as the world systems adopt more packs.

Models use glTF, GLB or OBJ. The importer reads GLB JSON chunks as well as glTF files, preserving external buffers and images. OBJ files retain their MTL and referenced textures. PNG, JPEG, SVG, OGG, WAV and MP3 are supported. Select one preferred representation to avoid importing alternate exports of the same design. FBX is visible in discovery but rejected during building because its external dependencies are not handled portably. Export FBX, Blender or voxel sources to glTF/GLB before selection. Legacy MTL map options also require normalized texture references.

Every copied file gets a recorded SHA-256 hash. Dependencies must remain inside their pack; absolute paths, remote model dependencies and symlinks are rejected. Builds are serialized per project and assembled before replacing the managed output. Removing a selection removes its generated files on the next build. Changed builds discard model `.import` metadata so the next editor import regenerates cached scenes and their extracted textures. Unchanged builds preserve the existing output and cache metadata. Stable `.uid` sidecars for unchanged resources are retained. The importer will not replace an existing output directory unless it has the importer ownership marker. Edit sources or configuration rather than generated files.

## Asset identity and transforms

A model ID is its pack ID followed by its original relative path, including the extension. For example, `kenney_castle_kit/content/Models/GLB format/wall.glb`. Moving or renaming the source changes that ID. Use semantic aliases to keep consumer code independent of filenames:

```json
"overrides": {
  "kenney_castle_kit/content/Models/GLB format/wall.glb": {
    "aliases": ["castle_wall"],
    "tags": ["city-wall"],
    "scale": 1.0,
    "rotation_degrees": [0, 90, 0],
    "offset": [0, 0, 0]
  }
}
```

Overrides belong at the config root. IDs and aliases must be unique. Unknown override IDs fail the build. Tags derive from publisher categories and filename words, plus configured tags. They describe available art; they do not define collision, equipment statistics, navigation or encounter rules.

## Add text under `/lore`

The importer scans `lore/**/*.md` for publishable entries and `lore/content/**/*.json` for structured entries. Existing `Book ID` sections and authored dialogue tables are supported. Their six books and 39 dialogue lines retain their IDs, titles, author names, passages and conditions. Other specification and research pages are omitted unless they contain explicit entry metadata.

For a new standalone book, add `lore/content/a-letter.md`:

```markdown
---
id: book_a_letter
kind: book
title: A Letter from the Crossing
author: The gatekeeper
tags: [crossroads, winter]
placement: town-library
---
The passage players will read goes here.
```

The body becomes the player-facing text. Front matter remains metadata. Keep IDs stable so save references continue to work. Books require a title; an omitted author displays as Anonymous. Multiline passages keep their paragraph breaks. Use UTF-8 text.

For dialogue, rumors, journal passages or other text, create JSON files containing an object or an array of objects:

```json
[
  {
    "id": "keeper_crossing_rumor",
    "kind": "dialogue",
    "speaker": "fountain_keeper",
    "event": "topic_crossing",
    "condition": "Any",
    "text": "The crossing opens after the morning bell.",
    "tags": ["crossroads"]
  },
  {
    "id": "journal_old_crossing",
    "kind": "journal",
    "title": "The Old Crossing",
    "text": "A passage for the field journal.",
    "tags": ["crossroads"]
  }
]
```

Dialogue requires `speaker` and `event`; `condition` defaults to `Any`. Additional metadata such as placement, biome restrictions and weight is preserved for game selectors. Metadata alone does not implement a new gameplay condition or journal rule. To keep a large passage in a separate file, replace `text` with `file`, using a path relative to the JSON entry. The referenced text must remain under `/lore`.

For externally licensed passages, provide `author`, `source`, `license`, `license_url` and `license_file`. The build requires these fields whenever `license` is declared. `license_file` points to the original notice relative to the entry file; the build copies that notice unchanged. Provide `attribution_text` for the required credit wording. License and credit fields are preserved in generated records and credits. Project lore without an external license declaration retains its existing authorship terms. It is not automatically assigned CC0.

## Runtime API

```gdscript
const Registry = preload("res://scripts/asset_registry.gd")
var assets := Registry.new()

var candidates := assets.find("model", ["castle"])
var model := assets.instantiate("castle_wall")
var icon := assets.resource("my_pack/icons/key.png")
var passage := assets.text("book_a_letter")
var books := assets.books()
var lines := assets.dialogue_lines()
```

`find(kind, tags, pack)` returns records sorted by stable ID. Every requested tag must match. Empty arguments omit that filter. `get_asset(id)` accepts IDs or aliases and returns an independent metadata copy. `resource(id)` lazily loads a Godot resource; `instantiate(id)` returns an independent model node while preserving scene hierarchies, rigs and animations. Instances belong to their caller and must be freed normally. Configured transforms apply to a wrapper node.

`books()` returns a dictionary keyed by book ID. `dialogue_lines()` returns dialogue records compatible with the lore selector. Generic text uses `kind = "text"`, with its authored kind preserved as `content_type` and a tag. `reload()` clears cached resources after a successful catalog load; a failed reload preserves the previous usable catalog and records an error string. Already-created models remain owned by their callers.

Runtime access uses only the generated content. Authoring folders are not required in exports. Configure Godot export filters to include `assets/imported/catalog.json`, the runtime resources, `CREDITS.md` and the required license notices. Preserve credits for the content actually shipped.

## Verification

```sh
ruby tests/test_asset_importer.rb
ruby tools/import_assets.rb --check
ruby tools/check_asset_pipeline.rb
```

The isolated Godot check builds from real GLB, glTF, OBJ, PNG and OGG assets and adds temporary Markdown/JSON lore. It removes authoring sources before checking runtime access. It also checks the Scenery consumer with a real OBJ, aliases, ground origins, materials and normalized footprints. It allows the temple MTL's expected warnings about ambient light ignored in PBR; other import warnings and errors fail. Set `GODOT_BIN` if the executable is not in a standard location. `check.sh` also runs the Ruby importer tests, freshness check, runtime registry test and dynamic scenery test with the game checks.

These checks cover discovery, dependency paths, generated records, loading and instantiation. They do not verify rendered appearance, scale, collision, navigation, animation retargeting or gameplay placement.

## Creature and item catalogues

Run `ruby tools/build_content_bundles.rb` before importing changed creature/item sources. Its JSON selectors and semantic profiles emit `assets/bundles/catalog.json`, a complete staged representation inventory and `config/generated_content_imports.json`. The importer combines independent `rule_files` with its existing rules and aliases. Derived packs retain their original source/object/hash `CONVERSIONS.json` and license notices. See [Creature and item bundles](CONTENT_BUNDLES.md) for conversion, stable identities, atlas icons, runtime spawning/loot and verification.
