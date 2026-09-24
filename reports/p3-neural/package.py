"""Package only this phase, exercise patch application and guarded rollback."""
import difflib
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

base=Path(__file__).resolve().parent
root=base.parent.parent
manifest=json.loads((base/'manifest.json').read_text())
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
patch=[]
for name, hashes in manifest.items():
    source=root/name
    before=base/'original'/name
    assert sha(before)==hashes['original'], name
    hashes['modified']=sha(source)
    dest=base/'modified'/name;dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,dest)
    old=before.read_text(encoding='utf-8-sig') if before.exists() else ''
    new=source.read_text(encoding='utf-8-sig')
    # Keep BOM bytes in text diffs where present, so applying reproduces exact files.
    old=before.read_bytes().decode('utf-8') if before.exists() else ''
    new=source.read_bytes().decode('utf-8')
    patch.extend(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),
                                    fromfile='a/'+name if before.exists() else '/dev/null',tofile='b/'+name))
(base/'manifest.json').write_text(json.dumps(manifest,indent=2))
(base/'changes.patch').write_text(''.join(patch),encoding='utf-8',newline='')
shutil.copy2(root/'reports/p2-damage15/rollback.py',base/'rollback.py')
records=[]
def run(cmd,cwd):
    p=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace')
    records.append({'command':cmd,'cwd':str(cwd),'stdout':p.stdout,'stderr':p.stderr,'exit_code':p.returncode})
    assert p.returncode==0, records[-1]
for role in ('patch-rehearsal','rollback-rehearsal'):
    target=(base/role).resolve();assert target.is_relative_to(base)
    target.mkdir(exist_ok=True)
    for name,h in manifest.items():
        src=base/('original' if role=='patch-rehearsal' else 'modified')/name
        dst=target/name;dst.parent.mkdir(parents=True,exist_ok=True)
        if src.exists():shutil.copy2(src,dst)
        elif dst.exists():
            assert dst.resolve().is_relative_to(target)
            dst.unlink()
    if role=='patch-rehearsal':
        run(['git','init','-q'],target)
        run(['git','apply','--check',str(base/'changes.patch')],target)
        run(['git','apply',str(base/'changes.patch')],target)
        # Git can normalize CRLF on patch input; actual restored files must match snapshot bytes.
        for name,h in manifest.items():assert sha(target/name)==h['modified'], 'Patch bytes differ: '+name
    else:
        run([sys.executable,str(base/'rollback.py'),'--root',str(target),'--apply'],root)
        for name,h in manifest.items():assert sha(target/name)==h['original'],name
run([sys.executable,str(base/'rollback.py')],root)
(base/'package-verification.json').write_text(json.dumps(records,indent=2))
print('Verified snapshots, applied patch, rehearsed rollback:',len(manifest),'files')
