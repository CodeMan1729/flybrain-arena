#!/bin/zsh
set -eu
cd "${0:A:h}"
if [[ ! -x .venv/bin/python || ! -x tools/Godot.app/Contents/MacOS/Godot || ! -f data/weights.npz ]]; then
  ./setup.sh
fi
exec .venv/bin/python tools/launch.py "$@"
