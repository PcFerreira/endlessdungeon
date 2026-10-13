# Lore translations

English prose is authored in the content records, not in translation files. Dialogue sources live in [content/dialogue](../content/dialogue/); readable books remain in [books.md](../books.md); discoveries, quests, and regional histories keep their own records. Item and object names live in [player_text.json](../../config/player_text.json); construction names remain in [town_architecture.json](../../config/town_architecture.json). `en.json` and `context.json` in this folder are generated references. Do not edit them directly.

## Stable messages and speaker context

Each dialogue variant has its own stable ID and message key, such as `lore.warden_world_01_v02.text`. Keep that key when editing or translating its wording. A `variant_group` identifies the shared subject and continuity rule. It is separate from the translated prose. The first variant retains the original line ID; additional variants use `_v02` through `_v06`.

The English index includes 5,868 messages: the original 508 lore messages plus 5,360 item, object, category and construction names. The lore messages cover 402 speaker-specific dialogue lines, eighteen neutral replies, and the published books, discovery labels/passages, history notes, and quest text/choices. A whole book passage is one message. A choice key uses its choice ID, and an aftermath key uses its event kind and phase. Reordering records or choices must not rename messages.

`context.json` gives a translator the source file, content type, speaker, event, condition, variant group, named placeholders, and the English text hash. Keep the fountain keeper welcoming, the Milewarden practical, the mender attentive to materials, and the retired delver brief. Future skeleton barks retain old duty language, invokers retain lesson language, and shades retain fragments of intimacy. A translation should preserve those differences.

## Create a translation pack

Regenerate the English reference and runtime lore output:

```sh
ruby tools/build_lore.rb
```

Create a locale template when that language is needed. For example:

```sh
ruby tools/build_lore.rb --locale-template pt-BR > lore/locales/pt-BR.json
```

The locale is a language tag such as `pt-BR`, `es`, or `zh-Hans`. Its filename and `locale` field must agree. The document has `version`, `source_locale`, `locale`, `messages`, and `source_hashes`. Translate values in `messages`. Keep the keys and metadata. An empty value or an omitted message is untranslated; a future runtime resolver must use English for that key.

Do not translate `{city_name}`, `{dungeon_name}`, or any other named placeholder. Keep each message's exact set of placeholder names. Their order and position may change with the language. Translate the complete sentence before inserting the actual place names; never concatenate English sentence fragments around a translated word.

Keep English source hashes until reviewing a changed source passage. The validator rejects a filled translation whose English source has changed. Compare the new English/context references, review the translated message, then copy that message's current hash into `source_hashes`. Empty translations can remain pending. Unknown keys and malformed braces are errors, including a misspelling such as `{town}` in place of `{city_name}`.

Validate translations and refresh the exported packs:

```sh
ruby tools/build_lore.rb
ruby tools/build_lore.rb --check
```

The build writes runtime packs under `assets/lore/locales/`, including an English pack and a manifest of available locales. It preserves human-authored locale files in this folder. After dialogue/content changes, also publish the regular dynamic content catalogue with `ruby tools/import_assets.rb --build`, following the serialized build ownership in `chat.md`.

## Adding or revising content

Add a new line as a complete JSON record with a new stable `id`, `kind: "dialogue"`, `speaker`, `event`, `condition`, `text`, `source_locale: "en"`, `text_key`, `variant_group`, and variant number. Use `lore.<id>.text` for its key. A new wording of an existing once-only memory shares that memory's group. A genuinely different subject needs a different group.

Preserve eligibility and local facts across a variant group. A returning greeting cannot claim a cleared dungeon unless that fact is actually supplied. A different wording must not invent a new relative, occupation, or personal history for the same speaker. Complete variants can vary rhythm and focus without contradicting one another.

Do not replace old IDs with array indices, English sentences, or translated names. Keep already collected history and accepted quest editions intact. If a passage's underlying facts or outcome changes, use the content family's edition rules; an ordinary wording edit still requires translation review through its source hash.

## Future runtime integration

This pass organizes source messages, exports locale packs, and validates translation identity and placeholders. The game still displays English. Language settings and an actual locale resolver remain future work.

A resolver should select by stable key, fall back to English for a missing/empty message, and bind real names after selection. Presentation should retain the selected line's ID and variant group regardless of language. For frozen journal/quest records, preserve the original edition and keep its saved passage as a fallback when that edition's translation is unavailable. Changing language must not reroll terrain, choose a different response, repeat a personal memory, change a reward, or mark an unknown site visited.

Gameplay names use `gameplay.<group>.<stable-content-id>.name`, with groups `items`, `native`, `fallbacks`, and `architecture`. Source paths and IDs remain unchanged when English wording changes. An ID may contain an original asset filename, including its export numbers; that key is translation identity and must never be displayed as the name. ItemCatalog exposes `name_key` beside the current English `name`. [Gameplay copy](../../docs/PLAYER_TEXT.md) describes the display and classification boundary.

Game menus, HUD strings, controls, item descriptions, other town-type configuration prose, fonts, plural forms, and direction of text still need their own key extraction and rendered review. They are outside this message index. Validate long translations and non-Latin scripts in readers, conversation choices, inventory, trade, and journal rows before claiming a language supported.
