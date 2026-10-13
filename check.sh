#!/bin/zsh
set -eu
cd "${0:A:h}"
check_log=$(mktemp -t endlessdungeon-check)
trap 'rm -f "$check_log"' EXIT
./godot.sh --headless --editor --quit >"$check_log" 2>&1
if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:' "$check_log"; then
  cat "$check_log"
  exit 1
fi
for check in tests/test_assets.gd tests/test_progression.gd tests/test_traversal.gd tests/test_world.gd tests/test_generation_routes.gd tests/test_dungeon.gd tests/test_gameplay.gd tests/test_camera.gd tests/test_save_game.gd tests/test_sanctum.gd tests/test_save_exit.gd; do
  ./godot.sh --headless --script "$check" --quit-after 600 >"$check_log" 2>&1
  cat "$check_log"
  if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:' "$check_log" || ! rg -q '^PASS:' "$check_log"; then
    exit 1
  fi
done
