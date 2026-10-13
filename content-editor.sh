#!/bin/zsh
set -eu
cd "${0:A:h}"
exec ./godot.sh --script res://tools/content_editor/editor.gd "$@"
