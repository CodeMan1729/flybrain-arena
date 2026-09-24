"""Resolve a native test engine without macOS-only hardcoded launch paths."""
import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]


def godot_path():
    override = os.environ.get('GODOT_BIN')
    if override:
        path = Path(override)
        if path.is_file(): return path.resolve()
        executable = shutil.which(override)
        if executable: return Path(executable)
        raise FileNotFoundError('GODOT_BIN does not resolve to an executable')
    names = (['Godot_v4.5.2-stable_win64_console.exe','Godot_v4.5.2-stable_win64.exe'] if sys.platform=='win32'
             else ['Godot.app/Contents/MacOS/Godot'])
    for name in names:
        path=ROOT/'tools'/name
        if path.is_file(): return path
    installed=shutil.which('godot') or shutil.which('godot4')
    if installed:return Path(installed)
    raise FileNotFoundError('Install Godot or set GODOT_BIN')
