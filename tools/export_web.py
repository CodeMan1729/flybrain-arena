"""Build the existing Godot game for the browser; install only verified web templates."""
import hashlib
import gzip
import os
from pathlib import Path
import shutil
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
godot = str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot')
templates = (Path.home() / 'Library/Application Support/Godot/export_templates' if sys.platform == 'darwin'
             else Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'godot/export_templates') / '4.5.2.stable'
if not (templates / 'web_release.zip').exists():
    archive = ROOT / 'tools/Godot_v4.5.2-stable_export_templates.tpz'
    if not archive.exists():
        temporary = archive.with_suffix('.partial')
        subprocess.run(['curl', '-fL', '--retry', '3', '--max-time', '600',
                        'https://github.com/godotengine/godot-builds/releases/download/4.5.2-stable/Godot_v4.5.2-stable_export_templates.tpz',
                        '-o', str(temporary)], check=True)
        temporary.replace(archive)
    expected = next(line.split()[0] for line in (ROOT / 'research/godot-SHA512-SUMS.txt').read_text().splitlines() if line.endswith(archive.name))
    with archive.open('rb') as source:
        if hashlib.file_digest(source, 'sha512').hexdigest() != expected:
            raise SystemExit('Godot web template SHA512 mismatch; export stopped.')
    templates.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for name in source.namelist():
            if name.startswith('templates/web_') or name == 'templates/version.txt':
                (templates / Path(name).name).write_bytes(source.read(name))
output = ROOT / 'build/web'
output.mkdir(parents=True, exist_ok=True)
result = subprocess.run([godot, '--headless', '--path', str(ROOT / 'game'), '--export-release', 'Web', str(output / 'index.html')], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
print(result.stdout)
if result.returncode or 'ERROR:' in result.stdout:
    raise SystemExit('Godot export failed; deployment stopped.')
shutil.copyfile(ROOT / 'web/privacy.html', output / 'privacy.html')
if not all((output / ('index.' + ext)).stat().st_size > 0 for ext in ('html', 'js', 'wasm', 'pck')):
    raise SystemExit('Incomplete web export')
for file in output.iterdir():
    if file.suffix in ('.wasm', '.pck', '.js'):
        file.with_suffix(file.suffix + '.gz').write_bytes(gzip.compress(file.read_bytes(), mtime=0))
print('Web build ready:', output)
