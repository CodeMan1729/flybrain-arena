"""Restore this turn's originals only; preserve unrelated workspace changes."""
import argparse
import hashlib
import json
from pathlib import Path

bundle = Path(__file__).resolve().parent
parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=bundle.parents[1])
args = parser.parse_args()
root = args.root.resolve()
manifest = json.loads((bundle / 'artifact-hashes.json').read_text(encoding='utf8'))

def digest(data):
    return hashlib.sha256(data).hexdigest()

# Validate all paths and hashes before writing anything.
for name, hashes in manifest.items():
    target = (root / name).resolve()
    if not target.is_relative_to(root):
        raise SystemExit('Target path leaves selected root: ' + name)
    if not target.is_file() or digest(target.read_bytes()) != hashes['modified']:
        raise SystemExit('Later edits detected; rollback stopped: ' + name)
    if hashes['original'] is not None:
        original = bundle / 'original' / name
        if digest(original.read_bytes()) != hashes['original']:
            raise SystemExit('Original hash mismatch: ' + name)
for name, hashes in manifest.items():
    target = root / name
    if hashes['original'] is None:
        target.unlink()
    else:
        target.write_bytes((bundle / 'original' / name).read_bytes())
        assert digest(target.read_bytes()) == hashes['original']
print('Restored originals for', len(manifest), 'files; unrelated paths untouched.')
