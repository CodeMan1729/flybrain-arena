"""Package P4 text + real WAVs; verify binary patch and guarded rollback."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

base=Path(__file__).resolve().parent
root=base.parent.parent
manifest=json.loads((base/'manifest.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
for name,hashes in manifest.items():
    assert sha(base/'original'/name)==hashes['original'],name
    hashes['modified']=sha(root/name)
    dst=base/'modified'/name;dst.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,dst)
(base/'manifest.json').write_text(json.dumps(manifest,indent=2))
diff=subprocess.run(['git','diff','--no-index','--binary','--no-renames','original','modified'],
                    cwd=base,capture_output=True)
assert diff.returncode==1,diff.stderr
patch=diff.stdout.replace(b'a/original/',b'a/').replace(b'b/modified/',b'b/')
# New-file headers use both prefixes of the modified tree; deletions the original tree.
patch=patch.replace(b'a/modified/',b'a/').replace(b'b/original/',b'b/')
(base/'changes.patch').write_bytes(patch)
shutil.copy2(root/'reports/p3-neural/rollback.py',base/'rollback.py')
records=[]
def run(cmd,cwd):
    p=subprocess.run(cmd,cwd=cwd,capture_output=True,text=True,encoding='utf-8',errors='replace')
    records.append({'command':cmd,'cwd':str(cwd),'stdout':p.stdout,'stderr':p.stderr,'exit_code':p.returncode})
    assert p.returncode==0,records[-1]
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
        for name,h in manifest.items():assert sha(target/name)==h['modified'],'Patch bytes differ: '+name
    else:
        run([sys.executable,str(base/'rollback.py'),'--root',str(target),'--apply'],root)
        for name,h in manifest.items():assert sha(target/name)==h['original'],name
run([sys.executable,str(base/'rollback.py')],root)
(base/'package-verification.json').write_text(json.dumps(records,indent=2))
print('Verified P4 binary patch, snapshots and rollback:',len(manifest),'files')
