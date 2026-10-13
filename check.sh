#!/bin/zsh
set -eu
cd "${0:A:h}"
ruby tests/test_asset_importer.rb
ruby tests/test_lore_export.rb
ruby tools/build_lore.rb --check
ruby tests/test_world_asset_builder.rb
ruby tools/build_world_assets.rb --check
ruby tests/test_content_bundles.rb
ruby tests/test_network_manifest.rb
ruby tools/build_content_bundles.rb --check
ruby tools/import_assets.rb --check
check_log=$(mktemp -t endlessdungeon-check)
trap 'rm -f "$check_log"' EXIT
./godot.sh --headless --editor --quit >"$check_log" 2>&1
if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:' "$check_log"; then
  cat "$check_log"
  exit 1
fi
for check in tests/test_remote_world.gd tests/test_online_client.gd tests/test_online_endpoints.gd tests/test_asset_registry.gd tests/test_player_text.gd tests/test_lore.gd tests/test_content_bundles.gd tests/test_enemy_loot.gd tests/test_kill_rewards.gd tests/test_bundle_gameplay.gd tests/test_visibility_display.gd tests/test_world_content.gd tests/test_voxel_monsters.gd tests/test_voxel_monsters_game.gd tests/test_enemies.gd tests/test_animated_style_conversion.gd tests/test_creature_styles.gd tests/test_creature_styles_game.gd tests/test_interiors.gd tests/test_interior_styles.gd tests/test_interior_styles_game.gd tests/test_world_life_catalog.gd tests/test_world_life.gd tests/test_world_activity.gd tests/test_surface_travel.gd tests/test_world_activity_game.gd tests/test_stores.gd tests/test_city_law.gd tests/test_city_law_game.gd tests/test_dynamic_scenery.gd tests/test_assets.gd tests/test_progression.gd tests/test_traversal.gd tests/test_world.gd tests/test_site_planner.gd tests/test_independent_world.gd tests/test_independent_game.gd tests/test_surface_locations.gd tests/test_surface_location_models.gd tests/test_surface_locations_game.gd tests/test_landscape.gd tests/test_town_magic.gd tests/test_town_magic_game.gd tests/test_local_decor_styles.gd tests/test_local_decor_game.gd tests/test_town_types.gd tests/test_town_types_game.gd tests/test_generation_routes.gd tests/test_dungeon.gd tests/test_dungeon_purpose.gd tests/test_dungeon_styles.gd tests/test_dungeon_styles_game.gd tests/test_voxel_characters.gd tests/test_voxel_characters_game.gd tests/test_npc_families.gd tests/test_npc_expansion.gd tests/test_gameplay.gd tests/test_camera.gd tests/test_save_game.gd tests/test_world_edition_saves.gd tests/test_biome_regions.gd tests/test_biome_transitions.gd tests/test_biome_models.gd tests/test_biome_edition_compatibility.gd tests/test_biome_game.gd tests/test_biome_new_journey.gd tests/test_sanctum.gd tests/test_character_inventory.gd tests/test_character_styles.gd tests/test_save_exit.gd tests/test_expansion.gd tests/test_world_ambience.gd tests/test_world_construction.gd tests/test_town_model_voxelizer.gd tests/test_town_architecture.gd tests/test_town_fallback_styles.gd tests/test_town_fallback_game.gd tests/test_environment_styles.gd tests/test_cultural_styles.gd tests/test_exploration.gd tests/test_site_knowledge.gd tests/test_contextual_placement.gd tests/test_wall_support.gd tests/test_regional_history.gd tests/test_local_quests.gd tests/test_sparse_regional_targets.gd tests/test_sparse_regional_game.gd tests/test_world_items.gd tests/test_world_items_game.gd tests/test_surface_items.gd tests/test_item_stacks.gd tests/test_item_stacks_game.gd tests/test_icon_item_geometry.gd tests/test_item_styles.gd tests/test_placed_item_styles.gd tests/test_item_styles_game.gd tests/test_furnishings.gd tests/test_furnished_home.gd tests/test_floating_city.gd tests/test_floating_city_game.gd; do
  ./godot.sh --headless --script "$check" --quit-after 600 >"$check_log" 2>&1
  cat "$check_log"
  if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:' "$check_log" || ! rg -q '^PASS:' "$check_log"; then
    exit 1
  fi
done
