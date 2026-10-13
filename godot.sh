#!/bin/zsh
set -e
cd "${0:A:h}"
for engine in ".tools/Godot.app/Contents/MacOS/Godot" "/Applications/Godot.app/Contents/MacOS/Godot"; do
  if [[ -x "$engine" ]]; then
    exec "$engine" --path "$PWD" "$@"
  fi
done
if command -v godot >/dev/null 2>&1; then
  exec godot --path "$PWD" "$@"
fi
if command -v godot4 >/dev/null 2>&1; then
  exec godot4 --path "$PWD" "$@"
fi
echo "Godot 4 is required. Download it from https://godotengine.org/download/macos/ or open project.godot in your Godot editor."
exit 1
