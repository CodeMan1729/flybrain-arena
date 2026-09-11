"""Build the existing Godot game for the browser; install only verified web templates."""
import hashlib
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
def publish_export(source, output):
    """Keep each engine/pack URL bound to its bytes, including across warm caches."""
    for ext in ('html', 'js', 'wasm', 'pck'):
        if not (source / ('index.' + ext)).stat().st_size:
            raise ValueError('Incomplete web export')
    runtime = sorted(p for p in source.iterdir() if p.suffix in ('.js', '.wasm'))
    digest = hashlib.sha256()
    for file in runtime:
        digest.update(file.name.encode() + b'\0' + file.read_bytes())
    executable = 'engine-' + digest.hexdigest()[:16]
    pack = 'game-' + hashlib.sha256((source / 'index.pck').read_bytes()).hexdigest()[:16] + '.pck'
    names = {p.name: executable + p.name.removeprefix('index') for p in runtime}
    names['index.pck'] = pack
    html = (source / 'index.html').read_text()
    match = re.search(r'^const config = (.+);$', html, re.MULTILINE)
    if not match:
        raise ValueError('Godot shell configuration missing')
    config = json.loads(match[1])
    config.update(executable=executable, mainPack=pack)
    config['fileSizes'] = {names.get(name, name): size for name, size in config['fileSizes'].items()}
    html = html[:match.start(1)] + json.dumps(config, separators=(',', ':')) + html[match.end(1):]
    html = html.replace('src="index.js"', f'src="{names["index.js"]}"')
    output.mkdir(parents=True, exist_ok=True)
    # ponytail: retain old content-addressed files for open loaders; prune only with a measured cache/session lifetime.
    for file in source.iterdir():
        if file.name == 'index.html':
            continue
        target = output / names.get(file.name, file.name)
        shutil.copyfile(file, target)
        if target.suffix in ('.wasm', '.pck', '.js'):
            target.with_suffix(target.suffix + '.gz').write_bytes(gzip.compress(target.read_bytes(), mtime=0))
    temporary = output / 'index.html.tmp'
    temporary.write_text(html)
    temporary.replace(output / 'index.html')


def main():
    godot = str(ROOT / 'tools/Godot.app/Contents/MacOS/Godot')
    templates = (Path.home() / 'Library/Application Support/Godot/export_templates' if sys.platform == 'darwin'
                 else Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share')) / 'godot/export_templates') / '4.5.2.stable'
    if not (templates / 'web_nothreads_release.zip').exists():
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
    with tempfile.TemporaryDirectory(prefix='flyfear-export-') as directory:
        source = Path(directory)
        result = subprocess.run([godot, '--headless', '--path', str(ROOT / 'game'), '--export-release', 'Web', str(source / 'index.html')], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout)
        if result.returncode or 'ERROR:' in result.stdout:
            raise SystemExit('Godot export failed; deployment stopped.')
        shutil.copyfile(ROOT / 'web/privacy.html', source / 'privacy.html')
        publish_export(source, output)
    print('Web build ready:', output)


if __name__ == '__main__':
    main()
