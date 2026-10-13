# Cities, castles and temples

Four more free packs are staged for medieval settlements, fortifications, temples and palaces. All four use CC0. Original models, material dependencies and publisher notices are preserved; each pack includes a source record, full license text and SHA-256 file list.

| Purpose | Downloaded pack | Staged contents | Publisher |
| --- | --- | --- | --- |
| Castle construction | [Kenney Castle Kit](kenney_castle_kit/content/Models/GLB%20format/) | 76 GLB files: walls, narrow walls, tower sections, doors, stairs, bridges, banners, catapults and other props. OBJ/FBX alternatives are retained. | [Source](https://kenney.nl/assets/castle-kit) |
| Complete settlement landmarks | [KayKit Medieval Hexagon: Free](kaykit_medieval_hexagon/content/addons/kaykit_medieval_hexagon_pack/Assets/gltf/) | 221 glTF files, including castles, churches, homes, taverns, markets, blacksmiths, mills, mines, barracks, archery ranges, walls, bridges and terrain. Many buildings have four faction colors. OBJ alternatives are retained. | [Source](https://github.com/KayKit-Game-Assets/KayKit-Medieval-Hexagon-Pack-1.0) |
| Modular streets and buildings | [Quaternius Medieval Village: Standard](quaternius_medieval_village/glTF/) | 176 glTF files: brick/wood walls, floors, roofs, doors, window frames, stairs, balconies, corners and overhangs, with buffers and textures. | [Source](https://quaternius.com/packs/medievalvillagemegakit.html) |
| Temples, palaces and ruins | [Modular Temple Pack](fsp_modular_temple/content/Modular%20Temple/) | 213 OBJ meshes with a shared MTL: walls, towers, floors, stairs, pillars, arches, balconies, ruined pieces, doors, levers and puzzle conduits. | [Source](https://fertile-soil-productions.itch.io/temple-modular-collection) |

File totals include modular pieces, color variants and terrain props. They do not represent that many unique complete buildings. The Kenney download contains 76 GLB files even though its current publisher page advertises 75 assets. KayKit has 263 OBJ files alongside 221 glTF files; the alternatives are preserved but were not counted as additional unique buildings.

## Location combinations

These are proposed uses of the downloaded files. World placement, interiors, collision and gameplay still require implementation.

| Location | Suggested files and companion packs |
| --- | --- |
| Walled city or border fortress | Castle Kit walls, tower sections and doorways; KayKit `building_castle_*`, barracks and archery ranges; existing faction banners and workshop props |
| Dense medieval street | Medieval Village brick/wood walls, overhangs, balconies, roofs and stairs; existing Fantasy Town market stalls and KayKit furniture |
| Trade town | KayKit homes, taverns, markets, blacksmiths and mills; existing food, crafting props, merchant stalls and inventory icons |
| Church district or fortified sanctuary | KayKit `building_church_*` and castle walls; temple-kit pillars, stairs and balconies for adjoining courts |
| Sandstone temple or palace | Temple-kit curved walls, towers, arches, balconies and sandstone materials; existing arcane effects, cauldrons, books and candles |
| Abandoned sacred site | Temple-kit `Wall_Ruined_*` and `Floor_Ruined_*`, vegetation from Nature Kit, arcane effects and existing dungeon ambience |
| Puzzle chamber | Temple-kit `Puzzle_Control_Lever.obj`, sliding pillars and conduit pieces. These are static props; puzzle rules and movable-object setup remain game work. |

Use each kit as a consistent construction family. Measure scale, doorway clearance, pivots and grid increments before mixing modules from different creators. KayKit's hexagonal ground tiles need adaptation for the current square-grid world; individual buildings can be placed separately. Complete building models do not guarantee accessible interiors.

The Quaternius download is the free Standard subset, retrieved from a public mirror pinned to a specific Git revision. All 376 mirrored files matched their Git blob hashes. The pack page advertises 304 models across tiers; this download contains 176 model files. Paid PRO/SOURCE models, custom collision packages, shaders and engine scenes are excluded. Original Standard license terms are retained.

## Licenses and checks

CC0 does not require attribution, but creator/source records and optional credit text are retained in each `SOURCE.json` and `LICENSE_SOURCE.md`. The temple archive has no bundled license document; its saved publisher page declares CC0, and the full CC0 legal text is included beside the assets. Existing CC BY packs still require the credits in [ATTRIBUTION.md](ATTRIBUTION.md).

The scoped check is recorded in [architecture_validation.json](architecture_validation.json). It checks the 473 new GLB/glTF files and their dependencies, plus the 213 temple OBJ meshes in an isolated Godot project. Original OBJ alternatives for Kenney and KayKit, and FBX files, are retained without an import check. Godot reports that the temple MTL's legacy ambient-light settings are ignored in PBR; its original material file remains unchanged.

These checks do not review rendered appearance, collision, navigation, procedural layout rules or gameplay integration. `import_assets/.gdignore` keeps the staging collection outside the normal game import scan.
