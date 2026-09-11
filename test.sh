#!/bin/zsh
set -eu
cd "${0:A:h}"
.venv/bin/python -m unittest discover -s tests -v
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/settings.gd
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/gameplay.gd
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/fly.gd
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/brain_view.gd
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/hud.gd
./tools/Godot.app/Contents/MacOS/Godot --headless --path game --script ../tests/mobile.gd
./run.sh --headless --smoke
print 'Python ve headless oynanış testleri geçti. Görünür 1080p ölçüm: ./run.sh --benchmark'
