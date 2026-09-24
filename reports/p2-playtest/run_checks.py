from pathlib import Path
import subprocess,json,shutil
root=Path.cwd();b=root/'reports/p2-playtest';exe=str(root/'tools/Godot_v4.5.2-stable_win64_console.exe')
def run(label,project,script,fixed=True):
 cmd=[exe,'--headless','--path',str(project),'--script',script]+(['--fixed-fps','60'] if fixed else [])
 p=subprocess.run(cmd,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
 r=dict(command=cmd,cwd=str(root),inputs='offline scene fixtures / recorded neural outputs',stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode)
 (b/(label+'.json')).write_text(json.dumps(r,indent=2),encoding='utf-8');print(label,p.returncode,p.stdout.count('PASS:'),p.stdout if p.returncode else '',p.stderr,flush=True)
fixture=b/'baseline';shutil.copytree(root/'game',fixture/'game',ignore=shutil.ignore_patterns('.godot'),dirs_exist_ok=True)
(fixture/'tests').mkdir(exist_ok=True)
for n in ['weapon_view','pursuit']:shutil.copyfile(root/('tests/'+n+'.gd'),fixture/('tests/'+n+'.gd'))
for n in ['game/player.gd','game/drone.gd']:shutil.copyfile(b/'original'/n,fixture/n)
p=subprocess.run([exe,'--headless','--path',str(fixture/'game'),'--editor','--import','--quit'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
(b/'baseline-import.json').write_text(json.dumps(dict(command=p.args,stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode),indent=2))
for n in ['weapon_view','pursuit']:run('baseline-'+n,fixture/'game','../tests/'+n+'.gd')
for n in ['weapon_view','combat_round','pursuit','fly','gameplay','mobile','hud']:
 run('modified-'+n,root/'game','../tests/'+n+'.gd',n not in ['gameplay','mobile','hud'])
