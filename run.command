#!/bin/zsh
set -eu
project_dir="$(cd "$(dirname "$0")" && pwd)"
game_engine="${GODOT_BIN:-}"
if [[ -z "$game_engine" ]]; then
  for candidate in /Applications/Godot.app/Contents/MacOS/Godot /private/tmp/newgame-godot/Godot.app/Contents/MacOS/Godot; do
    if [[ -x "$candidate" ]]; then game_engine="$candidate"; break; fi
  done
fi
if [[ -z "$game_engine" ]]; then
  print 'Install Godot 4.5.1 or set GODOT_BIN to your Godot executable.'
  exit 1
fi
export GODOT_BIN="$game_engine"
exec python3 "$project_dir/tools/workspace.py" run RingRush "$@"
