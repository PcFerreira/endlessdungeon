# Combat sound recordings

The selected recordings from [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) by rubberduck and [Magic Spell SFX](https://opengameart.org/content/magic-spell-sfx) by JaggedStone are offered under [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). The project credits both creators even though attribution is not required.

Original downloads and source-page license notices remain in `import_assets/combat_audio/`. These runtime WAV files are mono PCM derivatives with leading silence removed, bounded duration, an ending fade and peak normalization. `SOURCE.json` records each original hash, derivative hash and conversion filter. `ruby tools/build_combat_audio.rb` repeats the conversion using FFmpeg.

The additional Kenney impact recordings stay in their existing adopted pack with its original license and source record. Runtime playback selects variants and changes pitch and volume without changing those files.
