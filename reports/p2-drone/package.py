from pathlib import Path
import json,hashlib,shutil,difflib,subprocess,sys
root=Path.cwd();b=root/'reports/p2-drone';original=json.loads((b/'original-hashes.json').read_text());manifest={};diff=[]
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
for n,hash0 in original.items():
 p=root/n;dst=b/'modified'/n;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dst)
 assert sha(b/'original'/n)==hash0
 manifest[n]={'original':hash0,'modified':sha(dst)}
 old=(b/'original'/n).read_text(encoding='utf-8-sig').splitlines(keepends=True) if hash0 else []
 new=p.read_text(encoding='utf-8-sig').splitlines(keepends=True)
 diff.extend(difflib.unified_diff(old,new,fromfile='a/'+n if hash0 else '/dev/null',tofile='b/'+n))
(b/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
(b/'changes.patch').write_text(''.join(diff),encoding='utf-8',newline='\n')
shutil.copyfile(root/'reports/p2-pursuit/rollback.py',b/'rollback.py')
records={p.stem:json.loads(p.read_text()) for p in b.glob('*.json') if p.stem.startswith(('baseline-','modified-')) or p.stem=='render'}
records['scope']={'changed':'Drone visual body, rotor animation, script path, runtime node/window/menu names; control/HP/collision unchanged','manual_playtest':'pending','resource_warnings':'existing ObjectDB/resource cleanup warnings persist in physics suites'}
rehearsal=b/'rollback-rehearsal'
for n in original:
 dst=rehearsal/n;dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(root/n,dst)
for label,args in [('rollback-dry-run',[]),('rollback-rehearsal',['--root',str(rehearsal),'--apply'])]:
 cmd=[sys.executable,str(b/'rollback.py')]+args;p=subprocess.run(cmd,capture_output=True,text=True)
 records[label]=dict(command=cmd,stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode);assert p.returncode==0,records[label]
for n in original:assert sha(rehearsal/n)==original[n]
# Apply the review patch to a normalized original copy; byte restoration uses the hashed rollback above.
patchroot=b/'patch-rehearsal'
for n,h in original.items():
 if h:
  dst=patchroot/n;dst.parent.mkdir(parents=True,exist_ok=True);dst.write_text((b/'original'/n).read_text(encoding='utf-8-sig'),encoding='utf-8',newline='\n')
cmd=['git','apply','--unsafe-paths','--directory=reports/p2-drone/patch-rehearsal',str(b/'changes.patch')]
p=subprocess.run(cmd,capture_output=True,text=True);records['patch-rehearsal']=dict(command=cmd,stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode)
assert p.returncode==0,records['patch-rehearsal']
for n in original:assert (patchroot/n).read_text(encoding='utf-8-sig')==(root/n).read_text(encoding='utf-8-sig'),n
(b/'verification.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
assert json.loads((b/'verification.json').read_text())['modified-smoke']['exit_code']==0
assert (b/'changes.patch').read_text(encoding='utf-8').startswith('--- ')
print('Verified snapshots, review patch application, verification JSON, dry-run and isolated rollback')
