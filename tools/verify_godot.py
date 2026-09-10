import hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
line=next(x for x in (root/'research/godot-SHA512-SUMS.txt').read_text().splitlines() if x.endswith('Godot_v4.5.2-stable_macos.universal.zip'))
with (root/'tools/godot.zip').open('rb') as f:
    if hashlib.file_digest(f,'sha512').hexdigest()!=line.split()[0]: raise SystemExit('Godot SHA512 uyuşmuyor; kurulum durdu.')
print('Godot SHA512 doğrulandı.')
