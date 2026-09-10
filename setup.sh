#!/bin/zsh
set -eu
cd "${0:A:h}"
if [[ "$(uname -s)" != Darwin || "$(uname -m)" != arm64 ]]; then
  print -u2 'Bu kurulum macOS ARM64 içindir.'
  exit 1
fi
if ! command -v uv >/dev/null; then
  print -u2 'Python 3.12 kurulum aracı uv gerekli. https://docs.astral.sh/uv/getting-started/installation/'
  exit 1
fi
mkdir -p tools data reports logs
uv python install 3.12.12
if [[ ! -x .venv/bin/python ]]; then uv venv --python 3.12.12 .venv; fi
uv pip install --python .venv/bin/python -r requirements.txt
if [[ ! -x tools/Godot.app/Contents/MacOS/Godot ]]; then
  curl -fL --retry 3 https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_macos.universal.zip -o tools/godot.zip
  .venv/bin/python tools/verify_godot.py
  unzip -q tools/godot.zip -d tools
fi
.venv/bin/python tools/download_data.py
if [[ ! -f data/manifest.json || ! -f data/weights.npz ]]; then
  .venv/bin/python -m brain.connectome prepare
fi
tools/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit > reports/setup-godot.log 2>&1
if rg -q 'SCRIPT ERROR|Parse Error' reports/setup-godot.log; then cat reports/setup-godot.log; exit 1; fi
print 'Hazır. Başlat: ./run.sh   Test: ./test.sh'
