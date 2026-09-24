"""Restore this handoff only. Default: verify; --apply: restore; --root: isolated rehearsal."""
import argparse, hashlib, json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');p.add_argument('--root',type=Path);a=p.parse_args()
base=Path(__file__).resolve().parent
root=(a.root or base.parent.parent).resolve()
manifest=json.loads((base/'manifest.json').read_text())
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
for name, hashes in manifest.items():
 target=(root/name).resolve()
 assert target.is_relative_to(root), name
 assert sha(target)==hashes['modified'], 'Changed since handoff: '+name
 assert sha(base/'original'/name)==hashes['original'], 'Backup mismatch: '+name
print('Verified modified files and original hashes')
if a.apply:
 for name, hashes in manifest.items():
  target=root/name
  if hashes['original'] is None: target.unlink()
  else: target.write_bytes((base/'original'/name).read_bytes())
  assert sha(target)==hashes['original'], name
 print('Rollback verified: original bytes restored; added files removed')
