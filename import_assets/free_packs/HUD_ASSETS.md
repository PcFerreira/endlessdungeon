# Medieval magic HUD assets

Use Kenney's Fantasy UI Borders for ornate frames over dark panels, the RPG Expansion for vitality/aether bars, and 7Soul1's icons for the spell bar. Tint the borders to the game's gold accent and use the project's existing Cinzel font for labels. This combination is a suggested direction; all source assets remain unchanged.

| Pack | HUD role | Downloaded files | Publisher and license |
| --- | --- | --- | --- |
| Kenney Fantasy UI Borders | Ornate panel edges, spell slots, headings and dividers | [PNG frames](kenney_fantasy_ui_borders/PNG/) and [editable SVG](kenney_fantasy_ui_borders/Vector/fantasy-ui-borders.svg) | [Publisher](https://kenney.nl/assets/fantasy-ui-borders), CC0 |
| Kenney UI Pack: RPG Expansion | Health/mana/resource bars, buttons, panels and sliders | [PNG components](kenney_ui_pack_rpg_expansion/PNG/) | [Publisher](https://kenney.nl/assets/ui-pack-rpg-expansion), CC0 |
| Kenney UI Pack: Pixel Adventure | Pixel panel construction, button states and compact controls | [Small/large UI tiles](kenney_ui_pack_pixel_adventure/Tiles/) | [Publisher](https://kenney.nl/assets/ui-pack-pixel-adventure), CC0 |
| Free Fantasy Game GUI by pzUH | Parchment windows, wooden trim, ribbons and decorative resource bars | [Windows atlas](fantasy_game_gui/png/Windows.png), [button atlas](fantasy_game_gui/png/Button.png), [SVG sources](fantasy_game_gui/svg/) | [Publisher](https://opengameart.org/content/free-fantasy-game-gui), CC0 |
| 496 RPG Icons by Henrique Lazarini / 7Soul1 | Spell schools, books, potions, equipment and inventory | [Individual icons](fantasy_rpg_icons_496/) | [Publisher](https://opengameart.org/content/496-pixel-art-icons-for-medievalfantasy-rpg), CC0 |

## Component mapping

| Game element | Source to start with |
| --- | --- |
| Ten-slot spell bar | Fantasy UI Borders `PNG/Default/Border/` or `PNG/Default/Panel/` plus the 496-icons pack |
| Vitality bar | RPG Expansion `PNG/barBack_horizontalLeft.png`, `barBack_horizontalMid.png`, `barBack_horizontalRight.png` and the red fill variants |
| Aether bar | The same RPG Expansion backing pieces with `barBlue_horizontalLeft.png`, `barBlue_horizontalMid.png`, `barBlue_horizontalRight.png` |
| Fire spells | 496-icons `S_Fire*.png` |
| Frost spells | 496-icons `S_Ice*.png` |
| Arcane spells | 496-icons `S_Magic*.png` |
| Spellbook and inventory | 496-icons `W_Book*.png`, item/potion icons, plus framed panels |
| Quest, pause and upgrade windows | Fantasy UI Borders panels, or pzUH's `Windows.png` parchment frames |
| Hover/pressed controls | Pixel Adventure thin/thick outline variants or RPG Expansion button variants |
| Menu feedback | The already downloaded `kenney_interface_sounds/` pack |

The decorative border pack includes both default and double-size exports. The pzUH PNGs are atlases, not individual controls: `Windows.png` is 4868 by 3787 and `Button.png` is 1860 by 4999. Slice selected rectangles into AtlasTextures or export individual components from the SVG sources. Use resizable panel styles and segmented fills for bars; set pixel textures to nearest filtering when adopting them.

The five HUD packs use CC0. Their `LICENSE_SOURCE.md`, `SOURCE.json`, full CC0 text and any supplied license files are retained. The Fantasy UI Borders sample mentions the Aoboshi One font; it is a sample font reference and no font binary was downloaded. The pzUH sample's font is also not bundled. Use the existing project's font and its separate OFL notice for runtime text.
