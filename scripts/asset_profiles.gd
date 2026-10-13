extends RefCounted

const CUBE := "res://assets/expansion/quaternius_cube_world/Environment/glTF/"
const TOWN := "res://assets/expansion/kenney_fantasy_town_kit/Models/GLB format/"
const TRAVEL := "res://assets/expansion/kenney_survival_kit/Models/GLB format/"
const PROPS := "res://assets/expansion/quaternius_fantasy_props/Exports/glTF/"
const FURNITURE := "res://assets/expansion/kaykit_furniture/content/addons/kaykit_furniture_bits/Assets/gltf/"
const CAVE := "res://assets/expansion/kenney_modular_cave_kit/Models/GLB format/"
const MODELS := {
	"tree_a": [CUBE + "Tree_1.gltf", .95, 2.2], "tree_b": [CUBE + "Tree_2.gltf", .95, 2.2], "tree_c": [CUBE + "Tree_3.gltf", .95, 2.3],
	"dead_a": [CUBE + "DeadTree_1.gltf", .85, 1.9], "dead_b": [CUBE + "DeadTree_2.gltf", .85, 1.8], "dead_c": [CUBE + "DeadTree_3.gltf", .85, 2.0],
	"bush": [CUBE + "Bush.gltf", .65, .45], "mushroom": [CUBE + "Mushroom.gltf", .75, .8], "rock": [CUBE + "Rock1.gltf", .80, .60], "rock_b": [CUBE + "Rock2.gltf", .80, .55],
	"flowers": [CUBE + "Flowers_1.gltf", .55, .45], "flowers_b": [CUBE + "Flowers_2.gltf", .55, .5], "plant": [CUBE + "Plant_2.gltf", .65, .5],
	"fence": [CUBE + "Fence_Center.gltf", .85, .70], "cart": [CUBE + "Cart.gltf", .82, .80],
	"stall": [TOWN + "stall.glb", .90, 1.30], "bench": [TOWN + "stall-bench.glb", .80, .55], "lantern": [TOWN + "lantern.glb", .40, .80],
	"tent": [TRAVEL + "tent.glb", .95, 1.1], "bedroll": [TRAVEL + "bedroll.glb", .8, .12], "campfire": [TRAVEL + "campfire-pit.glb", .65, .25],
	"signpost": [TRAVEL + "signpost-single.glb", .70, .95], "log": [TRAVEL + "tree-log.glb", .85, .35],
	"bookstand": [PROPS + "BookStand.gltf", .65, .85], "book": [PROPS + "Book_Simplified_Single.gltf", .32, .10], "bookcase": [PROPS + "Bookcase_2.gltf", .90, 1.5],
	"scroll": [PROPS + "Scroll_1.gltf", .4, .15], "workbench": [PROPS + "Workbench.gltf", .85, .8], "anvil": [PROPS + "Anvil.gltf", .7, .65], "wall_lantern": [PROPS + "Lantern_Wall.gltf", .30, .65],
	"bed": [FURNITURE + "bed_single_A.gltf", .85, .55], "table": [FURNITURE + "table_medium.gltf", .85, .70],
	"wall_shelf": [FURNITURE + "shelf_B_large_decorated.gltf", 1.1, .55],
	"cave_floor": [CAVE + "template-floor.glb", .98, 0.0], "cave_wall": [CAVE + "template-wall.glb", .98, 1.3],
	"mushroom_tall": ["res://assets/expansion/kenney_nature_kit/Models/GLTF format/mushroom_tanTall.glb", .85, 1.50],
	"stump": ["res://assets/expansion/kenney_nature_kit/Models/GLTF format/stump_old.glb", .75, .65]
}
