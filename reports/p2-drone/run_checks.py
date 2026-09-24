from pathlib import Path
import subprocess,json,shutil
root=Path.cwd();base=root/'reports/p2-drone';exe=str(root/'tools/Godot_v4.5.2-stable_win64_console.exe')
records=[]
def run(label,project,script):
 cmd=[exe,'--headless','--path',str(project),'--script',script,'--fixed-fps','60']
 p=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
 r=dict(label=label,command=cmd,cwd=str(root),inputs='offline scripted drives; no live neural backend',stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode)
 (base/(label+'.json')).write_text(json.dumps(r,indent=2),encoding='utf-8'); print(label,p.returncode,p.stdout,p.stderr)
fixture=base/'baseline';shutil.copytree(root/'game',fixture/'game',ignore=shutil.ignore_patterns('.godot'),dirs_exist_ok=True)
(fixture/'tests').mkdir(exist_ok=True);shutil.copyfile(root/'tests/drone_visual.gd',fixture/'tests/drone_visual.gd')
for n in ['game/fly.gd','game/main.gd','game/main.tscn']:shutil.copyfile(base/'original'/n,fixture/n)
# Baseline copied assets require an import once in their isolated project.
p=subprocess.run([exe,'--headless','--path',str(fixture/'game'),'--editor','--import','--quit'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
(base/'baseline-import.json').write_text(json.dumps(dict(command=p.args,stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode),indent=2))
run('baseline-visual',fixture/'game','../tests/drone_visual.gd')
run('modified-visual',root/'game','../tests/drone_visual.gd')
run('modified-combat',root/'game','../tests/combat_round.gd')
run('modified-pursuit',root/'game','../tests/pursuit.gd')
run('modified-flight',root/'game','../tests/fly.gd')
