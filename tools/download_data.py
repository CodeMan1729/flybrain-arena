"""MaleCNS v1.0, public HTTPS downloads; immutable upstream SHA256 checks."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def download():
    registry = json.loads((ROOT / 'research/source.lock.json').read_text())
    (ROOT / 'data').mkdir(exist_ok=True)
    for name, info in registry.items():
        target = ROOT / 'data' / name
        if not target.exists():
            partial = target.with_suffix('.partial')
            print(f'Downloading {name}: {info["bytes"] / 1e6:.1f} MB', flush=True)
            subprocess.run(['curl', '-fsSL', '--retry', '3', '--connect-timeout', '20',
                            '-C', '-', info['url'], '-o', str(partial)], check=True)
            with partial.open('rb') as f:
                digest = hashlib.file_digest(f, 'sha256').hexdigest()
            if digest != info['sha256']:
                raise ValueError(f'Checksum mismatch: {partial}; original retained for inspection')
            partial.replace(target)
        with target.open('rb') as f:
            assert hashlib.file_digest(f, 'sha256').hexdigest() == info['sha256'], name
        print(f'Verified {name}', flush=True)

if __name__ == '__main__':
    download()
