# Cultural, festival and fantastic towns

Sixteen additional town identities cover the user's eight requested inspirations. There are now thirty-four selectable identities including the six baseline templates. Each new identity has four named neighborhoods, supported signature trades, market/garden names, local accounts/customs, a distinct civic form and one of eight native exterior styles. The [field notes](../lore/town-themes.md) describe their inhabitants' traditions in the Endless World's voice.

| Inspiration | Town IDs and names | Visible exterior detail | Supported signature uses |
| --- | --- | --- | --- |
| Japanese | `city_rainwood` Rainwood Street; `city_reedpaper` Reedpaper Court | Vertical wooden window lattices and dark roof ridges | Scribes |
| Chinese | `city_jadebeam` Jadebeam Court; `city_porcelain_exchange` Porcelain Exchange | Stepped corner brackets and colored roof ridges | Smithy; charmwright |
| Korean | `city_warmstone` Warmstone Village; `city_moonjar` Moonjar Commons | Quiet tile ridges and crossed wooden window grids | Bakery; charmwright |
| Halloween | `city_harvestmask` Harvestmask Hollow; `city_candlewake` Candlewake Borough | Small glowing harvest faces at windows | Bakery; scribe |
| Christmas | `city_evergreen_hearth` Evergreen Hearth; `city_giftmakers` Giftmakers Square | Evergreen wreaths and alternating roof lights | Bakery; charmwright |
| Cyberpunk | `city_neon_relay` Neon Relay; `city_chrome_bazaar` Chrome Bazaar | Emissive circuit lines and small roof relay boxes | Scribe; smithy |
| Mage | `city_spellbinders` Spellbinders Ward; `city_observatory` Observatory Court | Window rune grids and crossed roof glyphs | Scribes |
| Fairy | `city_dewbell` Dewbell Commons; `city_petalweave` Petalweave Court | Petal ornaments and small facade vine details | Apothecary; charmwright |

These towns represent traditions carried from different former worlds. Japanese, Chinese and Korean references remain separate. Resident appearance, faith, temperament and political authority are not selected from a real-world nationality. Coherent local model families still follow Surveyor/Rowan's actual source rules. The baseline safe Crossroads start remains unchanged.

## Architecture references and adaptation

The Kyoto tourism guide describes machiya as townhouses and documents wooden lattices. Rainwood/Reedpaper borrow those domestic workshop details. Their compact existing footprints do not reproduce the narrow, deep historical street plan. [Kyoto Tourist Information Center, Machiya guide](https://global.kyoto.travel/resource/global/download/18-pdf.pdf).

The Palace Museum describes dougong bracket sets as the transition between roof and walls in Chinese timber construction. Jadebeam/Porcelain use small stepped decorative accents to suggest that joinery tradition. These voxel ornaments have no structural simulation and do not claim to reconstruct a particular historical building. [Palace Museum, Bracket sets](https://en.pgm.org.cn/2024-04/18/c_980606.htm).

The AURI National Hanok Center explains ondol and maru as responses to cold and heat. Warmstone's remembered household arrangements draw on that distinction; floor heating and seasonal room simulation are later systems. Moonjar's vessel motif draws on the National Museum of Korea's white porcelain moon jar. The small civic silhouette is an original voxel interpretation. [AURI, Ondol and Maru](https://www.hanokdb.kr/theology_eng/sub_04_04), [National Museum of Korea, Moon-Jar](https://www.museum.go.kr/ENG/contents/E0403000000.do?relicId=941&schM=relic_represent_view).

The customs and supernatural accounts are original fantasy writing. They are not historical claims about the referenced cultures. Roof and facade details are compact interpretations on the existing house shells; complete heritage streets, courtyard compounds and new building footprints require a separate layout/art pass.

Current native review shows the Japanese/Chinese/Korean identities sharing the available timber/medieval shells with their own decorative accents and local texts. Their source roof colors can supersede the native appearance palette. Complete culture-specific building kits remain a further art/layout expansion; these profiles do not certify those kits.

## Runtime integration

`config/town_types.json` adds `theme_id` and `exterior_style` to the sixteen new definitions. The selector validates the eight supported themes/styles and exposes `city.theme_id` and `city.exterior_profile`. The profile contains its native style and two colors. Existing definitions without these fields keep their existing appearance component behavior.

`scripts/town_style.gd` builds at most two merged decorative meshes per actual house. Its initial voxel component now uses Surveyor's block/faceted DecorGeometry adaptation. It receives the actual rendered house-model bounds, retains the real house ID and uses the existing WorldView cutaway material for opaque parts. Small emissive accents share one material per town. No extra lights, collision, animation ticks, particles, actors or inventory resources are added. The component streams with the actual city chunk.

The original shell-space recipes keep accent boxes inside the owning house footprint and below `house.height + 1.06`. Actual model references adapt those recipes to imported roof/footprint bounds; civic and household lights clear their real supports. See [local decorative families](LOCAL_DECOR_FAMILIES.md) for that later height/family acceptance. Decorations do not extend doors, walls, walkable surfaces or source-object bounds. Roof markers and facade trim are structural decoration, not newly registered portable goods. Public roads, books, residents, lot IDs, primary anchors and ruin placement retain the identity-layer contract.

The current three layouts per parent template remain. Themes do not create distinct settlement sizes or irregular sites. Festival themes can occur whenever their climate permits; Halloween/Christmas do not depend on a new calendar. Cyberpunk uses visible arcane circuits and remembered technology without adding functional electronics. Mage towns do not grant new spells. Fairy towns do not require new flying actors or miniature collision bodies.

Current imported market/farm ensembles still use their parent recipes. Native crop fallback metadata varies by theme. The staged `kaykit_halloween`, `kenney_holiday_kit` and `kenney_graveyard_kit` packs are candidates for Aster's later curated scene ensembles. This pass imports no assets and does not automatically mix those packs into biome/NPC families. Specialized storefront stock follows Rowan-Market's actual supported use/source rules, rather than the theme's descriptive trade alone.

## Verification and handoffs

The existing town-type test requires all sixteen requested IDs, all thirty-four reachable identities, valid climate/signature uses, connected doors/lots/books/residents and repeated generation. It also validates every themed house accent's footprint/height bounds, built mesh budget and actual house IDs. The actual Game test uses Rainwood's keeper/custom and scribe entrance, verifies the streamed accent meshes and disk-restores the exterior profile without changing combat RNG or inventory.

`tools/capture_town_types.gd` captures every added identity from opposing views and adds detail views for the sixteen new exterior themes. It uses isolated preview saves/settings. The original primary-anchor/density/magic regression remains the compatibility check. New data can change which theme a regenerated town selects; actual city/house/lot IDs and frozen quest/history editions retain their existing contracts. Generator edition 4/save envelope 2 remain, with no world reset or migration.

Townwright authored the new definitions, initial accent component, field notes and focused checks. Lorekeeper reviewed the field notes and linked them from the lore index; town-config text remains outside the published lore locale index. Surveyor supplied the later family/actual-support decoration adaptation. Aster/Surveyor/Rowan retain construction palettes and coherent local asset/NPC families. Wren/Wayfarer retain ownership/law, Compass/Rowan retain discovery/history/quests, and Flint retains furnishings. Further complete cultural building plans, stock, species and mechanics need their owners' implementation and verification.

The final current-source repeats of the thirty-four-identity/access/bounds test and actual Rainwood/store-entrance/save test exit zero with PASS and no warnings/errors (`/tmp/endless-town-themes-current.log`, `...-game-current.log`). Native output covers all twenty-eight additions from opposing views and the sixteen exterior detail views; all sixteen new theme details were reviewed. The tests leave actual player saves/settings untouched. Whole-suite and staged edition-5 activation remain the shared integration owners' separate evidence.
