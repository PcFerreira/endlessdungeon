# Credits

Music by Eric Matyas

www.soundimage.org

The nine supplied recordings are from [Soundimage's Fantasy collection](https://soundimage.org/fantasywonder/) and are used under the [Soundimage International Public License](https://soundimage.org/sample-page/). Attribution follows the author's [in-game credit instructions](https://soundimage.org/attribution-info/). Source recordings are unchanged. Godot loops them and adjusts playback volume during area transitions.

| Track | Area |
| --- | --- |
| Fantascape | Title and Sunlit Meadows |
| Netherplace | Cities |
| Lost Jungle | Greenwood |
| Fantasy Game Background | Amber Wastes |
| Our Mountain v003 | Frostlands |
| City Beneath the Waves v001 | Shores |
| Misty Bog | Ashen Crypt floors |
| Spells a-Brewin | Violet Sanctum floors and player pocket home |
| Strange Phenomenon | Verdant Tomb floors |

## Environment and particles

- KayKit Dungeon Pack 1.1 by [Kay Lousberg](https://www.kaylousberg.com): barrels, crates, banners, wall torches, and floor tiles. [Included CC0 license](assets/environment/kaykit/License.txt).
- Ultimate Modular Ruins Pack by [Quaternius](https://quaternius.com): gothic arches, stag statues, and pots. [Included CC0 license](assets/environment/quaternius/License.txt).
- Particle Pack by [Kenney](https://kenney.nl): flame, mist, and magic textures. [Included CC0 license](assets/particles/License.txt).
- RPG UI Pack by [Kenney](https://kenney.nl): panels, buttons, and vitality/resource bars. [Included CC0 license](assets/ui/rpg/License.txt).
- Fantasy UI Borders by [Kenney](https://kenney.nl): ornate frames and dividers. [Included CC0 license](assets/ui/fantasy/License.txt).
- Cinzel typeface: [SIL Open Font License](assets/fonts/OFL.txt).

Voxel terrain, vegetation, buildings, characters, spell icons, sanctum sigil, cutaway shader, and synthesized combat sounds are original project work. Forgotten Realms is an aesthetic reference; no Forgotten Realms artwork or characters are included.

The main menu provides an in-game Credits screen. Supplied source collections remain in `import_assets/`. Adopted runtime files live in `assets/`; `assets/source_manifest.json` records their original paths and SHA-256 hashes. Run `ruby tools/adopt_assets.rb` to repeat the selection from the supplied packs. The RPG pack's `barBlue_horizontalBlue.png` is adopted as `barBlue_horizontalMid.png`; its image bytes are unchanged.
