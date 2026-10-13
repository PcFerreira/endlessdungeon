#!/bin/zsh
set -eu
cd "${0:A:h}"
ruby tests/test_content_editor_import.rb
for script in tests/test_content_edits.gd tests/test_content_edit_contracts.gd tests/test_content_editor_assets.gd tests/test_content_editor_publication.gd tests/test_content_editor_runtime.gd tests/test_content_editor_removal.gd; do
  log=$(mktemp -t endless-workbench)
  ./godot.sh --headless --script "$script" --quit-after 600 >"$log" 2>&1
  cat "$log"
  if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:|^FAIL:' "$log" || ! rg -q '^PASS:' "$log"; then
    rm -f "$log"
    exit 1
  fi
  rm -f "$log"
done
log=$(mktemp -t endless-workbench-ui)
./godot.sh --headless --script tools/content_editor/editor.gd --quit-after 600 -- --smoke-test >"$log" 2>&1
cat "$log"
if rg -q 'SCRIPT ERROR:|ERROR:|WARNING:' "$log" || ! rg -q '^PASS:' "$log"; then
  rm -f "$log"
  exit 1
fi
rm -f "$log"
