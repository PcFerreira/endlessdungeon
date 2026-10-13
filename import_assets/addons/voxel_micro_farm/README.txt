VOXEL MICRO FARM — GODOT EDITION 1.0.2
Dopamine King | Tested: Godot 4.7.2 Standard, Windows x64, Compatibility

INSTALL
Extract the ZIP at your Godot project's root so addons/voxel_micro_farm is
directly inside it. Wait for the first import to finish. This is an art library;
there is no editor plugin to enable, and no external service is required.
No Blender, Unity, .NET, autoload or custom InputMap dependency is required.

START
Open addons/voxel_micro_farm/examples/farm_showcase.tscn and press F6.
The second example is examples/asset_overview.tscn, grouped into four sections
with camera-facing labels: crops/harvest, ground/fences, tools/containers,
and nature/details. Zoom in to inspect individual models.
Drag any scenes/<category>/*.tscn into your own scene to place an asset.
The optional complete demo project ZIP can instead be opened through project.godot.

EXAMPLE CONTROLS
1 = farm; 2 = asset overview; mouse wheel = zoom; right-drag = pan;
R = reset camera; H = open/close gate and chest; Space = next of six sounds.
Both examples include their own lighting, camera and environment. When copying
objects into another scene, choose lighting suitable for your game's renderer.
The asset overview shows the decorative island at 30% scale to fit its cell;
the reusable island scene and the farm showcase use full scale.

CONTENTS
36 GLB source models and 36 reusable Godot scene assets (44 meshes total).
33,344 triangles across the complete model library, excluding example repetition.
Four crops: carrot, daikon, corn and tomato. Each has three stages and a harvest item.
Three tools, three containers, four fence assets, four ground assets,
tree, rock, bush, path, grass tuft and a decorative island.
36 transparent 256x256 inventory icons; six short mono PCM WAV sounds.
Two examples: farm showcase and labelled asset overview.
Shared native meshes and a shared palette material are supplied for reuse.

SCALE, MATERIALS AND COLLISION
1 Godot unit = 1 metre. Ground tiles cover 1x1 metre; the modelling grid is 0.02m.
Fence connections follow a 1m placement grid. End-post overlap can be avoided
by hiding a Post_End_X / Post_End_Y part and disabling its associated collision.
Roots have identity transforms. Some hand tools have grip-centred origins;
place them using the visible mesh or consult the bounds in the editor.
Crops are designed to sit in soil and may extend below their root plane.
Use the scene wrappers for configured material and collision. GLBs are supplied
as editable source geometry; their default imported materials may look different.
The palette uses nearest filtering and flat normals. UVs use shared colour
swatches, so they are not unique texture-painting/lightmap UVs. Godot-generated
UV2 lightmaps, LOD variants and normal/metallic/roughness texture sets are not supplied.
Simple static collision is supplied on relevant objects; crops, harvest items
and grass tufts do not block movement. Island collision is a coarse box, not
a walkable detailed terrain mesh. Replace colliders for precise gameplay needs.
Gate and chest collision follows the pivot. Their movement here is a visual
example, not a physics-driven door controller; use AnimatableBody3D if needed.

HINGES
The gate's Pivot_Gate child rotates about local Y. The chest's Pivot_Lid rotates
about local X. The viewer demonstrates open angles of -15 and -68 degrees.
Reusable asset scenes and the overview start closed; the farm starts open.
The first H press changes their state in either example. Named hinge groups
are scoped to the example instance, so unrelated Pivot nodes are unaffected.
All six audio previews are explicit resource references for export dependency
tracking; they do not depend on scanning raw WAV filenames at runtime.
Meshes/materials are shared resources, while Node3D transforms belong to each
instance. To customise only one instance's material, make that material unique.

LIMITATIONS
This release is an art starter pack with viewing/hinge/audio demonstrations.
It does not include farming gameplay, characters, save/load, seasons, multiplayer,
music, ambient audio, character rigs or pre-authored animation clips.
Only Godot 4.7.2 Standard on Windows x64 with Compatibility has been validated.
Other versions/renderers/platforms are not claimed as tested.

LICENSE
Free personal and commercial use under the included LICENSE.
You may modify and incorporate assets into games and other finished works.
Do not resell or redistribute original or modified assets as an asset library.
No attribution or additional licence payment is required. Read the full terms.

SUPPORT
Dopamine King — chellocsay@gmail.com
https://dopamine-king.fancy-bloom-3544.chatgpt.site/

中文快速开始
将 addons/voxel_micro_farm 放入工程根目录，等待导入完成。
打开 examples/farm_showcase.tscn 后按 F6；1/2 切换展示场景，H 开关门和箱盖，
空格试听音效，滚轮缩放，右键拖动平移，R 重置视角。
将 scenes 中的资产场景拖入你的关卡即可使用。1 单位为 1 米。
首版为美术资产和展示示例，不包含完整种植玩法；免费商用许可详见 LICENSE。
